import CloudKit
import CryptoKit
import Foundation
import Observation

enum CloudKitSnapshotState: Equatable {
    case checking
    case unavailable(String)
    case syncing
    case synced(Date)
    case error(String)

    var title: String {
        switch self {
        case .checking: String(localized: "Checking iCloud…")
        case .unavailable: String(localized: "iCloud unavailable")
        case .syncing: String(localized: "Syncing to iCloud…")
        case .synced: String(localized: "Backed up to iCloud")
        case .error: String(localized: "iCloud sync issue")
        }
    }

    var detail: String {
        switch self {
        case .checking: String(localized: "Checking account and private database status.")
        case .unavailable(let reason), .error(let reason): reason
        case .syncing: String(localized: "Your local data remains available while sync runs.")
        case .synced(let date): String(localized: "Last synced \(date.formatted(date: .abbreviated, time: .shortened)).")
        }
    }
}

/// Private CloudKit snapshot storage for personal-device recovery. The payload is a
/// CKAsset-backed file rather than a record string, so large archives are supported.
@Observable
@MainActor
final class CloudKitSnapshotService {
    static let shared = CloudKitSnapshotService()

    private let container: CKContainer
    private let database: CKDatabase
    private let recordID = CKRecord.ID(recordName: "current")
    private let defaults: UserDefaults
    private let lastDigestKey = "TouchPoint.CloudKit.LastDigest"

    private(set) var state: CloudKitSnapshotState = .checking

    init(
        containerIdentifier: String = "iCloud.app.gettouchpoint.TouchPoint",
        defaults: UserDefaults = .standard
    ) {
        let resolvedContainer = CKContainer(identifier: containerIdentifier)
        container = resolvedContainer
        database = resolvedContainer.privateCloudDatabase
        self.defaults = defaults
    }

    /// Reconciles a complete local archive. A newer local digest is uploaded; a newer
    /// cloud snapshot is returned for the caller to import. Local state always stays
    /// usable if account, network, or CloudKit configuration is unavailable.
    func synchronize(
        archiveData: Data,
        localModifiedAt: Date,
        hasLocalUserData: Bool
    ) async -> Data? {
        state = .checking
        do {
            let accountStatus = try await accountStatus()
            guard accountStatus == .available else {
                let reason = accountStatus == .noAccount
                    ? "Sign in to iCloud to enable private recovery backup."
                    : "This device's iCloud account is not available. Local data is still safe on this device."
                state = .unavailable(reason)
                return nil
            }

            state = .syncing
            let digest = SHA256.hash(data: archiveData).map { String(format: "%02x", $0) }.joined()
            let previousDigest = defaults.string(forKey: lastDigestKey)
            let hasSyncMetadata = previousDigest != nil
            let remote = try await fetchRemote()

            // Avoid rewriting the record (and advancing its timestamp) when both
            // devices already have identical content.
            if let remote, let payload = remote.payload, digestFor(payload) == digest {
                defaults.set(digest, forKey: lastDigestKey)
                state = .synced(remote.modifiedAt)
                return nil
            }

            // A fresh install has no knowledge of whether its seeded/empty store is
            // meaningful. Bootstrap from an existing private snapshot first; this
            // prevents a new device's sample data from overwriting a real backup.
            if let remote, !hasSyncMetadata, !hasLocalUserData, let payload = remote.payload {
                defaults.set(digestFor(payload), forKey: lastDigestKey)
                state = .synced(remote.modifiedAt)
                return payload
            }

            // If local content still matches the last successful sync, only the cloud
            // side changed. Restore it without relying on possibly skewed device clocks.
            if let remote, previousDigest == digest, let payload = remote.payload {
                defaults.set(digestFor(payload), forKey: lastDigestKey)
                state = .synced(remote.modifiedAt)
                return payload
            }

            if let remote, remote.modifiedAt > localModifiedAt, let payload = remote.payload {
                defaults.set(digestFor(payload), forKey: lastDigestKey)
                state = .synced(remote.modifiedAt)
                return payload
            }

            let uploadedAt = max(Date.now, localModifiedAt)
            do {
                try await saveRemote(payload: archiveData, modifiedAt: uploadedAt)
            } catch let cloudError as CKError where cloudError.code == .serverRecordChanged {
                // A second device may have won the race. Re-read and honor the
                // last-modified policy instead of blindly replacing its snapshot.
                if let conflict = try? await fetchRemote(),
                   conflict.modifiedAt > localModifiedAt,
                   let payload = conflict.payload {
                    defaults.set(digestFor(payload), forKey: lastDigestKey)
                    state = .synced(conflict.modifiedAt)
                    return payload
                }
                // The conflicting cloud snapshot is older; retry against its fresh
                // change tag so the newer local archive can win safely.
                try await saveRemote(payload: archiveData, modifiedAt: uploadedAt)
            }
            defaults.set(digest, forKey: lastDigestKey)
            state = .synced(uploadedAt)
            return nil
        } catch {
            state = .error(Self.userFacingError(error))
            return nil
        }
    }

    func clearError() {
        if case .error = state { state = .checking }
    }

    /// Called when the caller could not persist a returned snapshot. Keeping metadata
    /// unset makes the next reconciliation retry the cloud snapshot instead of
    /// incorrectly treating the failed import as complete.
    func resetLocalSyncMetadata() {
        defaults.removeObject(forKey: lastDigestKey)
        state = .error("The iCloud snapshot could not be applied locally. Touch Point will retry it later.")
    }

    private func accountStatus() async throws -> CKAccountStatus {
        try await withCheckedThrowingContinuation { continuation in
            container.accountStatus { status, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: status) }
            }
        }
    }

    private struct RemoteSnapshot {
        let payload: Data?
        let modifiedAt: Date
    }

    private func fetchRemote() async throws -> RemoteSnapshot? {
        do {
            let record = try await database.record(for: recordID)
            let modifiedAt = (record["modifiedAt"] as? Date) ?? .distantPast
            let payload: Data?
            if let asset = record["payload"] as? CKAsset, let fileURL = asset.fileURL {
                let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                if let size = attributes[.size] as? NSNumber,
                   size.intValue > AppStore.maximumArchiveBytes {
                    throw AppPersistenceError.archiveTooLarge
                }
                payload = try Data(contentsOf: fileURL)
            } else {
                payload = nil
            }
            return RemoteSnapshot(payload: payload, modifiedAt: modifiedAt)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    private func saveRemote(payload: Data, modifiedAt: Date) async throws {
        let record: CKRecord
        do {
            record = try await database.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: "TouchPointSnapshot", recordID: recordID)
        }

        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("touchpoint-snapshot-\(UUID().uuidString).json")
        try payload.write(to: temporaryURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }
        record["payload"] = CKAsset(fileURL: temporaryURL)
        record["modifiedAt"] = modifiedAt as CKRecordValue
        record["schemaVersion"] = 1 as CKRecordValue
        _ = try await database.save(record)
    }

    private func digestFor(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func userFacingError(_ error: Error) -> String {
        if let cloudError = error as? CKError {
            switch cloudError.code {
            case .networkFailure, .networkUnavailable, .serviceUnavailable, .requestRateLimited:
                return "iCloud is temporarily offline. Your local data is safe; Touch Point will retry later."
            case .notAuthenticated:
                return "Sign in to iCloud to enable private recovery backup."
            default: break
            }
        }
        return "iCloud could not save this snapshot. Your local data is safe; try Sync now later."
    }
}
