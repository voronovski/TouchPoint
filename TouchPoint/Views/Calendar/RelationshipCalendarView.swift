import SwiftUI

struct RelationshipCalendarView: View {
    @Environment(AppStore.self) private var store
    @State private var status: GreetingStatus?
    @State private var refreshTick = Date()
    @State private var showingNewGreeting = false

    private var visibleEvents: [GreetingEvent] {
        store.events
            .filter { status == nil || store.status(for: $0) == status }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            List {
                if !visibleEvents.isEmpty {
                    ForEach(groupedEvents) { group in
                        Section(group.title) {
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
                    Button {
                        showingNewGreeting = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add greeting")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("All") { status = nil }
                        Divider()
                        ForEach(GreetingStatus.allCases) { option in
                            Button {
                                status = option
                            } label: {
                                if status == option {
                                    Label(option.title, systemImage: "checkmark")
                                } else {
                                    Text(option.title)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                    }
                    .accessibilityLabel("Filter greetings")
                }
            }
            .sheet(isPresented: $showingNewGreeting) {
                NewGreetingView()
            }
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(60))
                    refreshTick = .now
                }
            }
        }
    }

    private var groupedEvents: [EventDayGroup] {
        let groups = Dictionary(grouping: visibleEvents) { recipientDayKey(for: $0) }
        return groups.map { key, events in
            let sortedEvents = events.sorted { $0.date < $1.date }
            let first = sortedEvents[0]
            let timeZoneID = store.person(for: first)?.timeZoneIdentifier ?? TimeZone.current.identifier
            var style = Date.FormatStyle(date: .long, time: .omitted)
            style.timeZone = TimeZone(identifier: timeZoneID) ?? .current
            return EventDayGroup(id: key, title: first.date.formatted(style), events: sortedEvents)
        }
        .sorted { $0.id < $1.id }
    }

    private func recipientDayKey(for event: GreetingEvent) -> String {
        var calendar = Calendar(identifier: .gregorian)
        if let person = store.person(for: event) {
            calendar.timeZone = TimeZone(identifier: person.timeZoneIdentifier) ?? .current
        }
        let components = calendar.dateComponents([.year, .month, .day], from: event.date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}

private struct EventDayGroup: Identifiable {
    let id: String
    let title: String
    let events: [GreetingEvent]
}
