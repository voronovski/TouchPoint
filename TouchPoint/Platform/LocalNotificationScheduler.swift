import Foundation
import UserNotifications

struct LocalReminderSettings: Sendable, Equatable {
    var leadTimesDays: Set<Int> = [0]
    var hour: Int = 9
    var minute: Int = 0
    var hidesNames = false

    var normalized: LocalReminderSettings {
        var copy = self
        copy.leadTimesDays = Set(leadTimesDays.filter { (0...30).contains($0) })
        if copy.leadTimesDays.isEmpty { copy.leadTimesDays = [0] }
        copy.hour = min(max(hour, 0), 23)
        copy.minute = min(max(minute, 0), 59)
        return copy
    }
}

struct LocalNotificationSyncResult: Sendable, Equatable {
    let scheduledCount: Int
    let droppedCount: Int
}

enum LocalNotificationScheduler {
    private static let identifierPrefix = "touchpoint.greeting."
    private static let categoryIdentifier = "touchpoint.greeting.category"
    private static let maximumPendingNotifications = 64

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    static func synchronize(
        events: [GreetingEvent],
        people: [Person],
        settings: LocalReminderSettings? = nil
    ) async throws -> LocalNotificationSyncResult {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        try Task.checkCancellation()

        let existingIdentifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }
        try Task.checkCancellation()
        center.removePendingNotificationRequests(withIdentifiers: existingIdentifiers)
        guard status.allowsScheduling else {
            return LocalNotificationSyncResult(scheduledCount: 0, droppedCount: 0)
        }
        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: categoryIdentifier,
                actions: [UNNotificationAction(identifier: "OPEN", title: "Open", options: [.foreground])],
                intentIdentifiers: [],
                options: []
            )
        ])

        let peopleByID = Dictionary(uniqueKeysWithValues: people.map { ($0.id, $0) })
        let now = Date.now
        let resolvedSettings = (settings ?? LocalReminderSettings()).normalized
        let candidates: [(GreetingEvent, Person, Date, Int)] = events
            // Keep today's events even when their model date is normalized to
            // midnight; reminderDate below is the source of truth for whether
            // the actual delivery time is still in the future.
            .filter { ![.completed, .skipped].contains($0.status) }
            .flatMap { event -> [(GreetingEvent, Person, Date, Int)] in
                guard let person = peopleByID[event.personID], !person.communicationStopped else { return [] }
                return resolvedSettings.leadTimesDays.compactMap { leadDays -> (GreetingEvent, Person, Date, Int)? in
                    let fireDate = reminderDate(
                        eventDate: event.date,
                        person: person,
                        leadDays: leadDays,
                        hour: resolvedSettings.hour,
                        minute: resolvedSettings.minute
                    )
                    guard fireDate > now else { return nil }
                    return (event, person, fireDate, leadDays)
                }
            }
            .sorted { lhs, rhs in
                if lhs.2 != rhs.2 { return lhs.2 < rhs.2 }
                return lhs.0.id.uuidString < rhs.0.id.uuidString
            }

        let retained = candidates.prefix(maximumPendingNotifications)
        for (event, person, fireDate, leadDays) in retained {
            try Task.checkCancellation()
            let content = UNMutableNotificationContent()
            content.title = title(for: event, person: person, hidesName: resolvedSettings.hidesNames)
            content.body = notificationBody(for: event, person: person, hidesName: resolvedSettings.hidesNames, leadDays: leadDays)
            content.sound = .default
            content.categoryIdentifier = categoryIdentifier
            content.userInfo = ["greetingID": event.id.uuidString]

            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: person.timeZoneIdentifier) ?? .current
            var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            components.timeZone = calendar.timeZone
            let request = UNNotificationRequest(
                identifier: identifier(for: event.id, leadDays: leadDays),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
            try await center.add(request)
        }
        return LocalNotificationSyncResult(scheduledCount: retained.count, droppedCount: candidates.count - retained.count)
    }

    private static func reminderDate(eventDate: Date, person: Person, leadDays: Int, hour: Int, minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: person.timeZoneIdentifier) ?? .current
        let shifted = calendar.date(byAdding: .day, value: -leadDays, to: eventDate) ?? eventDate
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: shifted) ?? shifted
    }

    private static func identifier(for eventID: UUID, leadDays: Int) -> String {
        "\(identifierPrefix)\(eventID.uuidString).\(leadDays)"
    }

    private static func title(for event: GreetingEvent, person: Person, hidesName: Bool) -> String {
        hidesName ? "Touch Point reminder" : "\(event.displayName) for \(person.name)"
    }

    private static func notificationBody(for event: GreetingEvent, person: Person, hidesName: Bool, leadDays: Int) -> String {
        let timing: String
        switch leadDays {
        case 0: timing = "today"
        case 1: timing = "tomorrow"
        default: timing = "in \(leadDays) days"
        }
        let recipient = hidesName ? "your contact" : person.name
        switch event.method {
        case .sms: return "Your greeting for \(recipient) is ready \(timing). Open TouchPoint to continue in Messages."
        case .email: return "Your greeting for \(recipient) is ready \(timing). Open TouchPoint to continue in Mail."
        case .reminder: return "It is time to reach out to \(recipient) \(timing). Open TouchPoint when you are ready."
        }
    }
}

private extension UNAuthorizationStatus {
    var allowsScheduling: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral: true
        case .notDetermined, .denied: false
        @unknown default: false
        }
    }
}
