import SwiftUI

struct ContentView: View {
    @State private var store = AppStore.preview

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
        .environment(store)
    }
}

#Preview {
    ContentView()
}
