import SwiftUI
import WidgetKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = AppStore.live
    @State private var preferences = AppPreferences()
    @State private var navigation = TouchPointNavigation.shared
    @State private var notificationSyncTask: Task<Void, Never>?
    @State private var cloudKit = CloudKitSnapshotService.shared
    @State private var cloudKitSyncTask: Task<Void, Never>?
    @State private var widgetSnapshotTask: Task<Void, Never>?

    var body: some View {
        @Bindable var navigation = navigation
        Group {
            if preferences.hasCompletedOnboarding {
                MainAppView()
            } else {
                OnboardingView()
            }
        }
        .tint(.accentColor)
        .environment(store)
        .environment(preferences)
        .environment(navigation)
        .environment(cloudKit)
        .task {
            scheduleNotificationSync()
            scheduleCloudKitSync()
            scheduleWidgetSnapshot()
        }
        .onChange(of: store.events) {
            scheduleNotificationSync()
            scheduleCloudKitSync()
            scheduleWidgetSnapshot()
        }
        .onChange(of: store.people) {
            scheduleNotificationSync()
            scheduleCloudKitSync()
            scheduleWidgetSnapshot()
        }
        .onChange(of: store.templates) {
            scheduleCloudKitSync()
        }
        .onChange(of: store.templateGroups) {
            scheduleCloudKitSync()
        }
        .onChange(of: store.templateRevisions) {
            scheduleCloudKitSync()
        }
        .onChange(of: store.templateUsage) {
            scheduleCloudKitSync()
        }
        .onChange(of: scenePhase) {
            guard scenePhase == .active else { return }
            scheduleNotificationSync()
            scheduleCloudKitSync()
            scheduleWidgetSnapshot()
        }
        .onChange(of: preferences.reminderLeadTimes) {
            scheduleNotificationSync()
        }
        .onChange(of: preferences.reminderHour) {
            scheduleNotificationSync()
        }
        .onChange(of: preferences.reminderMinute) {
            scheduleNotificationSync()
        }
        .onChange(of: preferences.hideReminderNames) {
            scheduleNotificationSync()
            scheduleWidgetSnapshot()
        }
        .onOpenURL { url in
            routeDeepLink(url)
        }
        .sheet(item: $navigation.destination) { destination in
            switch destination {
            case .greeting(let eventID):
                NavigationStack {
                    GreetingDetailView(eventID: eventID, showsDoneButton: true)
                }
            case .plan:
                PlanYearView()
            case .addPerson:
                QuickAddPersonView()
            }
        }
    }

    private func scheduleNotificationSync() {
        notificationSyncTask?.cancel()
        notificationSyncTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            do {
                let result = try await LocalNotificationScheduler.synchronize(
                    events: store.events,
                    people: store.people,
                    settings: LocalReminderSettings(
                        leadTimesDays: preferences.reminderLeadTimes,
                        hour: preferences.reminderHour,
                        minute: preferences.reminderMinute,
                        hidesNames: preferences.hideReminderNames
                    )
                )
                preferences.notificationSyncError = result.droppedCount > 0
                    ? "Only the nearest 64 reminders are scheduled. Touch Point will add later reminders as dates get closer."
                    : nil
            } catch {
                preferences.notificationSyncError = error.localizedDescription
            }
        }
    }

    private func scheduleCloudKitSync() {
        cloudKitSyncTask?.cancel()
        cloudKitSyncTask = Task {
            try? await Task.sleep(nanoseconds: 650_000_000)
            guard !Task.isCancelled else { return }
            guard let archive = try? store.exportArchive() else { return }
            if let remote = await cloudKit.synchronize(
                archiveData: archive,
                localModifiedAt: store.lastModifiedAt,
                hasLocalUserData: store.hasUserContent
            ) {
                if !store.importArchive(remote, preservingModifiedAt: true) {
                    cloudKit.resetLocalSyncMetadata()
                }
            }
        }
    }

    private func scheduleWidgetSnapshot() {
        widgetSnapshotTask?.cancel()
        widgetSnapshotTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            publishWidgetSnapshot()
        }
    }

    private func publishWidgetSnapshot() {
        let sortedEvents = store.events
            .filter { ![.completed, .skipped].contains(store.status(for: $0)) }
            .sorted { lhs, rhs in
                let lhsStatus = store.status(for: lhs)
                let rhsStatus = store.status(for: rhs)
                if lhsStatus == .ready && rhsStatus != .ready { return true }
                if rhsStatus == .ready && lhsStatus != .ready { return false }
                return lhs.date < rhs.date
            }

        let snapshot: TouchPointWidgetSnapshot
        if let event = sortedEvents.first {
            let person = store.people.first { $0.id == event.personID }
            snapshot = TouchPointWidgetSnapshot(
                generatedAt: .now,
                eventID: event.id,
                occasionTitle: event.displayName,
                personName: preferences.hideReminderNames ? nil : person?.name,
                eventDate: event.date,
                statusTitle: store.status(for: event).title
            )
        } else {
            snapshot = .empty
        }
        TouchPointWidgetSnapshotStore.publish(snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: TouchPointWidgetSnapshotStore.widgetKind)
    }

    private func routeDeepLink(_ url: URL) {
        guard url.scheme?.lowercased() == "touchpoint" else { return }
        switch url.host?.lowercased() {
        case "greeting":
            guard let rawID = url.pathComponents.last, let id = UUID(uuidString: rawID) else { return }
            navigation.openGreeting(id)
        case "plan":
            navigation.openPlan()
        case "add-person":
            navigation.openAddPerson()
        default:
            break
        }
    }
}

private struct MainAppView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }

            RelationshipCalendarView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }

            PeopleView()
                .tabItem {
                    Label("People", systemImage: "person.2")
                }

            TemplatesView()
                .tabItem {
                    Label("Templates", systemImage: "rectangle.stack")
                }
        }
        .tint(.accentColor)
    }
}

#Preview {
    ContentView()
}
