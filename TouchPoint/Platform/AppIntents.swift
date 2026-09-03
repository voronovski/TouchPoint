import AppIntents
import Foundation

struct OpenNextGreetingIntent: AppIntent {
    static var title: LocalizedStringResource = "Open next greeting"
    static var description = IntentDescription("Open the next planned greeting in Touch Point.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        let eventID = await MainActor.run {
            let store = AppStore.live
            return store.events
                .filter { ![.completed, .skipped].contains(store.status(for: $0)) }
                .sorted { lhs, rhs in
                    if store.status(for: lhs) == .ready && store.status(for: rhs) != .ready { return true }
                    if store.status(for: rhs) == .ready && store.status(for: lhs) != .ready { return false }
                    return lhs.date < rhs.date
                }
                .first?.id
        }
        if let eventID {
            await MainActor.run { TouchPointNavigation.shared.openGreeting(eventID) }
        }
        return .result()
    }
}

struct OpenGreetingPlanIntent: AppIntent {
    static var title: LocalizedStringResource = "Open greeting plan"
    static var description = IntentDescription("Open the greeting planning screen in Touch Point.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        await MainActor.run { TouchPointNavigation.shared.openPlan() }
        return .result()
    }
}

struct AddPersonIntent: AppIntent {
    static var title: LocalizedStringResource = "Add person"
    static var description = IntentDescription("Open Touch Point's form for adding a person.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        await MainActor.run { TouchPointNavigation.shared.openAddPerson() }
        return .result()
    }
}

struct TouchPointShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: OpenNextGreetingIntent(), phrases: ["Open next greeting in \(.applicationName)"], shortTitle: "Next greeting", systemImageName: "bell")
        AppShortcut(intent: OpenGreetingPlanIntent(), phrases: ["Open greeting plan in \(.applicationName)"], shortTitle: "Plan greetings", systemImageName: "calendar.badge.plus")
        AppShortcut(intent: AddPersonIntent(), phrases: ["Add a person in \(.applicationName)"], shortTitle: "Add person", systemImageName: "person.badge.plus")
    }
}
