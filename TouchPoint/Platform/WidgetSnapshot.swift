import Foundation

/// Small, privacy-aware payload shared by the app and its WidgetKit extension.
/// It is intentionally kept in iCloud KVS so the widget does not require a new
/// App Group or access to the full local persistence store.
struct TouchPointWidgetSnapshot: Codable, Equatable, Sendable {
    let generatedAt: Date
    let eventID: UUID?
    let occasionTitle: String?
    let personName: String?
    let eventDate: Date?
    let statusTitle: String?

    static let empty = TouchPointWidgetSnapshot(
        generatedAt: .now,
        eventID: nil,
        occasionTitle: nil,
        personName: nil,
        eventDate: nil,
        statusTitle: nil
    )

    var isEmpty: Bool { eventID == nil || eventDate == nil }

    var deepLink: URL? {
        guard let eventID else { return nil }
        return URL(string: "touchpoint://greeting/\(eventID.uuidString)")
    }
}

enum TouchPointWidgetSnapshotStore {
    static let key = "TouchPoint.WidgetSnapshot"
    static let widgetKind = "TouchPointNextGreetingWidget"
    private static let store = NSUbiquitousKeyValueStore.default

    static func publish(_ snapshot: TouchPointWidgetSnapshot) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }
        store.set(data, forKey: key)
        store.synchronize()
    }

    static func read() -> TouchPointWidgetSnapshot? {
        guard let data = store.object(forKey: key) as? Data else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(TouchPointWidgetSnapshot.self, from: data)
    }
}
