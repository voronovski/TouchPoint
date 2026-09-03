import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = AppStore.live
    @State private var preferences = AppPreferences()

    var body: some View {
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
        .task {
            await synchronizeNotifications()
        }
        .onChange(of: store.events) {
            Task { await synchronizeNotifications() }
        }
        .onChange(of: store.people) {
            Task { await synchronizeNotifications() }
        }
        .onChange(of: scenePhase) {
            guard scenePhase == .active else { return }
            Task { await synchronizeNotifications() }
        }
    }

    private func synchronizeNotifications() async {
        try? await LocalNotificationScheduler.synchronize(
            events: store.events,
            people: store.people
        )
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
