import SwiftUI

struct RelationshipCalendarView: View {
    @Environment(AppStore.self) private var store
    @State private var status: GreetingStatus?

    private var visibleEvents: [GreetingEvent] {
        store.events
            .filter { status == nil || $0.status == status }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            List {
                if !visibleEvents.isEmpty {
                    ForEach(groupedEvents, id: \.day) { group in
                        Section(group.day.formatted(.dateTime.month(.wide).day())) {
                            ForEach(group.events) { event in
                                NavigationLink {
                                    GreetingDetailView(eventID: event.id)
                                } label: {
                                    EventRow(event: event)
                                }
                                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                            }
                        }
                    }
                }
            }
            .overlay {
                if visibleEvents.isEmpty {
                    ContentUnavailableView(
                        "No greetings",
                        systemImage: "calendar",
                        description: Text("Try another status filter or plan new greetings.")
                    )
                }
            }
            .navigationTitle("Calendar")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("All") { status = nil }
                        Divider()
                        ForEach(GreetingStatus.allCases) { option in
                            Button {
                                status = option
                            } label: {
                                if status == option {
                                    Label(option.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(option.rawValue)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                    }
                    .accessibilityLabel("Filter greetings")
                }
            }
        }
    }

    private var groupedEvents: [(day: Date, events: [GreetingEvent])] {
        let groups = Dictionary(grouping: visibleEvents) { Calendar.current.startOfDay(for: $0.date) }
        return groups
            .map { (day: $0.key, events: $0.value.sorted { $0.date < $1.date }) }
            .sorted { $0.day < $1.day }
    }
}
