import SwiftUI
import WidgetKit

struct TouchPointNextGreetingEntry: TimelineEntry {
    let date: Date
    let snapshot: TouchPointWidgetSnapshot
}

struct TouchPointNextGreetingProvider: TimelineProvider {
    func placeholder(in context: Context) -> TouchPointNextGreetingEntry {
        TouchPointNextGreetingEntry(
            date: .now,
            snapshot: TouchPointWidgetSnapshot(
                generatedAt: .now,
                eventID: UUID(),
                occasionTitle: "Birthday",
                personName: "A contact",
                eventDate: Calendar.current.date(byAdding: .day, value: 3, to: .now),
                statusTitle: "Planned"
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TouchPointNextGreetingEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TouchPointNextGreetingEntry>) -> Void) {
        let current = entry()
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        completion(Timeline(entries: [current], policy: .after(refreshDate)))
    }

    private func entry() -> TouchPointNextGreetingEntry {
        TouchPointNextGreetingEntry(
            date: .now,
            snapshot: TouchPointWidgetSnapshotStore.read() ?? .empty
        )
    }
}

struct TouchPointNextGreetingWidgetView: View {
    let entry: TouchPointNextGreetingEntry

    var body: some View {
        Group {
            if entry.snapshot.isEmpty {
                emptyState
            } else {
                greetingState
            }
        }
        .widgetURL(entry.snapshot.deepLink ?? URL(string: "touchpoint://plan"))
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No upcoming greetings")
                .font(.headline)
                .minimumScaleFactor(0.8)
            Text("You’re all caught up.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var greetingState: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "bell")
                    .foregroundStyle(Color.accentColor)
                Text("Next greeting")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(entry.snapshot.occasionTitle ?? "Greeting")
                .font(.headline)
                .lineLimit(2)
            if let personName = entry.snapshot.personName {
                Text("for \(personName)")
                    .font(.subheadline)
                    .lineLimit(1)
            } else {
                Text("for your contact")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if let eventDate = entry.snapshot.eventDate {
                Text(eventDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct TouchPointNextGreetingWidget: Widget {
    static let kind = TouchPointWidgetSnapshotStore.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: TouchPointNextGreetingProvider()) { entry in
            TouchPointNextGreetingWidgetView(entry: entry)
        }
        .configurationDisplayName("Next greeting")
        .description("See the nearest planned greeting from Touch Point.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct TouchPointWidgetBundle: WidgetBundle {
    var body: some Widget {
        TouchPointNextGreetingWidget()
    }
}
