import SwiftUI
import UIKit
import UniformTypeIdentifiers
import UserNotifications

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppPreferences.self) private var preferences
    @Environment(CloudKitSnapshotService.self) private var cloudKit
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var notificationStatus: UNAuthorizationStatus?
    @State private var notificationError: String?
    @State private var isSynchronizingNotifications = false
    @State private var isSynchronizingCloudKit = false
    @State private var exportDocument: TouchPointArchiveDocument?
    @State private var showingArchiveExporter = false
    @State private var showingArchiveImporter = false
    @State private var archiveError: String?
    @State private var showingRecoveryConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                focusSettingsSection
                remindersSettingsSection
                aboutSettingsSection
                cloudSettingsSection
                archiveSettingsSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await refreshNotificationStatus()
            }
            .onChange(of: scenePhase) {
                guard scenePhase == .active else { return }
                Task { await refreshNotificationStatus() }
            }
            .alert("Reminders unavailable", isPresented: Binding(
                get: { notificationError != nil },
                set: { if !$0 { notificationError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(notificationError ?? "")
            }
            .alert("Archive unavailable", isPresented: Binding(
                get: { archiveError != nil },
                set: { if !$0 { archiveError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(archiveError ?? "")
            }
            .confirmationDialog("Restore recovered local backup?", isPresented: $showingRecoveryConfirmation, titleVisibility: .visible) {
                Button("Restore backup", role: .destructive) { restoreRecoveredSnapshot() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The recovered file will replace the current in-memory data only after it passes validation and saves successfully.")
            }
            .fileImporter(isPresented: $showingArchiveImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
                importArchive(result)
            }
            .fileExporter(
                isPresented: $showingArchiveExporter,
                document: exportDocument,
                contentType: .json,
                defaultFilename: "TouchPoint-Archive.json"
            ) { result in
                if case .failure(let error) = result { archiveError = error.localizedDescription }
            }
        }
    }

    private var focusSettingsSection: some View {
        Section {
            ForEach(Focus.allCases) { focus in
                Button { preferences.focus = focus } label: {
                    HStack(alignment: .top, spacing: 12) {
                        IconTile(systemImage: focus.icon, tint: preferences.focus == focus ? Color.accentColor : Color.secondary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(focus.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                            Text(focus.subtitle).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if preferences.focus == focus {
                            Image(systemName: "checkmark").font(.subheadline.weight(.bold)).foregroundStyle(.accent)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("Focus")
        } footer: {
            Text("Focus adjusts which relationships and priorities appear first. Your people, dates, templates, and plans stay unchanged.")
        }
    }

    private var remindersSettingsSection: some View {
        Section {
            LabeledContent {
                Text(notificationStatusTitle).foregroundStyle(.secondary)
            } label: {
                Label("Local reminders", systemImage: "bell")
            }
            reminderAuthorizationAction
            VStack(alignment: .leading, spacing: 10) {
                Text("Remind me").font(.subheadline.weight(.semibold))
                ForEach([0, 1, 3, 7], id: \.self) { days in reminderLeadTimeRow(days) }
                DatePicker("Reminder time", selection: reminderTimeBinding, displayedComponents: .hourAndMinute)
                Toggle("Hide names in notifications", isOn: Binding(
                    get: { preferences.hideReminderNames },
                    set: { preferences.hideReminderNames = $0 }
                ))
            }
            Button { synchronizeNotificationsNow() } label: {
                Label(isSynchronizingNotifications ? "Syncing reminders…" : "Sync reminders now", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(isSynchronizingNotifications)
            if let syncError = preferences.notificationSyncError {
                Label(syncError, systemImage: "exclamationmark.triangle.fill").font(.footnote).foregroundStyle(.red)
            }
        } header: {
            Text("Reminders")
        } footer: {
            Text("Touch Point uses on-device notifications for upcoming actions. It never sends the greeting for you.")
        }
    }

    @ViewBuilder
    private var reminderAuthorizationAction: some View {
        switch notificationStatus {
        case .notDetermined:
            Button { enableReminders() } label: { Label("Enable reminders", systemImage: "bell.badge") }
        case .denied:
            Button {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                openURL(url)
            } label: { Label("Open System Settings", systemImage: "gear") }
        default:
            EmptyView()
        }
    }

    private func reminderLeadTimeRow(_ days: Int) -> some View {
        let isSelected = preferences.reminderLeadTimes.contains(days)
        return Button {
            if isSelected {
                if preferences.reminderLeadTimes.count > 1 { preferences.reminderLeadTimes.remove(days) }
            } else {
                preferences.reminderLeadTimes.insert(days)
            }
        } label: {
            HStack {
                Text(leadTimeTitle(days))
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private var aboutSettingsSection: some View {
        Section("About") {
            LabeledContent("App", value: "Touch Point")
            LabeledContent("Version", value: appVersion)
        }
    }

    private var cloudSettingsSection: some View {
        Section {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: cloudStatusIcon).foregroundStyle(cloudStatusColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text(cloudKit.state.title).font(.subheadline.weight(.semibold))
                    Text(cloudKit.state.detail).font(.caption).foregroundStyle(.secondary)
                }
            }
            Button { synchronizeCloudKit() } label: {
                Label(isSynchronizingCloudKit ? "Syncing…" : "Sync iCloud now", systemImage: "arrow.triangle.2.circlepath.icloud")
            }
            .disabled(isSynchronizingCloudKit)
        } header: {
            Text("Private iCloud backup")
        } footer: {
            Text("Touch Point keeps working locally without an account or network. Your complete private snapshot is used for recovery on another device; it is not shared with other people.")
        }
    }

    private var archiveSettingsSection: some View {
        Section {
            Button {
                do {
                    exportDocument = try TouchPointArchiveDocument(data: store.exportArchive())
                    showingArchiveExporter = true
                }
                catch { archiveError = error.localizedDescription }
            } label: { Label("Export all Touch Point data", systemImage: "square.and.arrow.up") }
            Button { showingArchiveImporter = true } label: {
                Label("Replace with an archive…", systemImage: "square.and.arrow.down")
            }
            if store.recoverableSnapshotData() != nil {
                Button(role: .destructive) { showingRecoveryConfirmation = true } label: {
                    Label("Restore recovered local backup", systemImage: "arrow.uturn.backward.circle")
                }
            }
        } header: {
            Text("Local archive")
        } footer: {
            Text("An archive includes people, dates, greetings, templates, revisions, and usage history. Replacing data is validated before it is saved.")
        }
    }

    private var notificationStatusTitle: String {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral:
            "Enabled"
        case .denied:
            "Off"
        case .notDetermined:
            "Not enabled"
        case nil:
            "Checking"
        @unknown default:
            "Unavailable"
        }
    }

    private func enableReminders() {
        Task {
            do {
                let granted = try await LocalNotificationScheduler.requestAuthorization()
                await refreshNotificationStatus()
                guard granted else { return }
                let result = try await LocalNotificationScheduler.synchronize(events: store.events, people: store.people, settings: reminderSettings)
                preferences.notificationSyncError = result.droppedCount > 0
                    ? "Only the nearest 64 reminders are scheduled. Touch Point will add later reminders as dates get closer."
                    : nil
            } catch {
                notificationError = error.localizedDescription
                preferences.notificationSyncError = error.localizedDescription
            }
        }
    }

    private func synchronizeNotificationsNow() {
        isSynchronizingNotifications = true
        Task {
            defer { isSynchronizingNotifications = false }
            do {
                let result = try await LocalNotificationScheduler.synchronize(
                    events: store.events,
                    people: store.people,
                    settings: reminderSettings
                )
                preferences.notificationSyncError = result.droppedCount > 0
                    ? "Only the nearest 64 reminders are scheduled. Touch Point will add later reminders as dates get closer."
                    : nil
            } catch {
                preferences.notificationSyncError = error.localizedDescription
            }
        }
    }

    private var reminderSettings: LocalReminderSettings {
        LocalReminderSettings(
            leadTimesDays: preferences.reminderLeadTimes,
            hour: preferences.reminderHour,
            minute: preferences.reminderMinute,
            hidesNames: preferences.hideReminderNames
        )
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: preferences.reminderHour, minute: preferences.reminderMinute, second: 0, of: .now) ?? .now
            },
            set: { value in
                let components = Calendar.current.dateComponents([.hour, .minute], from: value)
                preferences.reminderHour = components.hour ?? 9
                preferences.reminderMinute = components.minute ?? 0
            }
        )
    }

    private func leadTimeTitle(_ days: Int) -> String {
        switch days {
        case 0: "On the day"
        case 1: "1 day before"
        default: "\(days) days before"
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        guard let build, !build.isEmpty else { return version }
        return "\(version) (\(build))"
    }

    private func refreshNotificationStatus() async {
        notificationStatus = await LocalNotificationScheduler.authorizationStatus()
    }

    private var cloudStatusIcon: String {
        switch cloudKit.state {
        case .synced: "checkmark.icloud"
        case .syncing: "arrow.triangle.2.circlepath.icloud"
        case .error: "exclamationmark.icloud"
        default: "icloud"
        }
    }

    private var cloudStatusColor: Color {
        switch cloudKit.state {
        case .synced: .green
        case .error: .red
        case .syncing: .accentColor
        default: .secondary
        }
    }

    private func synchronizeCloudKit() {
        isSynchronizingCloudKit = true
        Task {
            defer { isSynchronizingCloudKit = false }
            do {
                let archive = try store.exportArchive()
                if let remote = await cloudKit.synchronize(
                    archiveData: archive,
                    localModifiedAt: store.lastModifiedAt,
                    hasLocalUserData: store.hasUserContent
                ) {
                    guard store.importArchive(remote, preservingModifiedAt: true) else {
                        cloudKit.resetLocalSyncMetadata()
                        archiveError = store.persistenceError ?? "The iCloud snapshot could not be restored."
                        return
                    }
                }
            } catch {
                archiveError = error.localizedDescription
            }
        }
    }

    private func importArchive(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            guard store.importArchive(data) else {
                archiveError = store.persistenceError ?? "This archive could not be imported."
                return
            }
        } catch {
            archiveError = error.localizedDescription
        }
    }

    private func restoreRecoveredSnapshot() {
        guard !store.restoreCorruptSnapshot() else { return }
        archiveError = store.persistenceError ?? "The recovered local backup could not be restored."
    }
}

struct TouchPointArchiveDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
