import Foundation
import UserNotifications

enum LocalNotificationScheduler {
    private static let identifierPrefix = "touchpoint.greeting."

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    static func synchronize(events: [GreetingEvent], people: [Person]) async throws {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        guard status.allowsScheduling else { return }

        let existingIdentifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: existingIdentifiers)

        let peopleByID = Dictionary(uniqueKeysWithValues: people.map { ($0.id, $0) })
        let now = Date.now

        for event in events where event.date > now && ![.completed, .skipped].contains(event.status) {
            guard let person = peopleByID[event.personID] else { continue }

            let content = UNMutableNotificationContent()
            content.title = "\(event.occasion.title) for \(person.name)"
            content.body = notificationBody(for: event)
            content.sound = .default
            content.userInfo = ["greetingID": event.id.uuidString]

            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
            var components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: event.date
            )
            components.timeZone = calendar.timeZone

            let request = UNNotificationRequest(
                identifier: identifier(for: event.id),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
            try await center.add(request)
        }
    }

    private static func identifier(for eventID: UUID) -> String {
        identifierPrefix + eventID.uuidString
    }

    private static func notificationBody(for event: GreetingEvent) -> String {
        switch event.method {
        case .sms:
            "Your greeting is ready. Open TouchPoint to continue in Messages."
        case .email:
            "Your greeting is ready. Open TouchPoint to continue in Mail."
        case .reminder:
            "It is time to reach out. Open TouchPoint when you are ready."
        }
    }
}

private extension UNAuthorizationStatus {
    var allowsScheduling: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            true
        case .notDetermined, .denied:
            false
        @unknown default:
            false
        }
    }
}
