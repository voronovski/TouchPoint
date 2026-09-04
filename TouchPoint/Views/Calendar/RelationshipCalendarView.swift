import SwiftUI

struct RelationshipCalendarView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.calendar) private var calendar
    @State private var status: GreetingStatus?
    @State private var displayedMonth = Date()
    @State private var isCustomRange = false
    @State private var customStart = Date()
    @State private var customEnd = Date()
    @State private var refreshTick = Date()
    @State private var showingDateRange = false
    @State private var showingNewGreeting = false

    private var statusFilteredEvents: [GreetingEvent] {
        _ = refreshTick
        return store.events
            .filter { status == nil || store.status(for: $0) == status }
            .sorted { $0.date < $1.date }
    }

    private var visibleEvents: [GreetingEvent] {
        let bounds = activeDayKeyBounds
        return statusFilteredEvents.filter { event in
            let key = recipientDayKey(for: event)
            return key >= bounds.start && key <= bounds.end
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: TouchPointMetric.sectionSpacing) {
                    periodBar
                    resultSummary

                    if visibleEvents.isEmpty {
                        emptyState
                    } else {
                        ForEach(groupedEvents) { group in
                            eventGroup(group)
                        }
                    }
                }
                .padding(.horizontal, TouchPointMetric.screenPadding)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingDateRange = true
                    } label: {
                        Label("Date range", systemImage: "calendar")
                    }

                    statusMenu

                    Button {
                        showingNewGreeting = true
                    } label: {
                        Label("Add greeting", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingDateRange) {
                CalendarDateRangeSheet(
                    initialStart: dateRangeSeed.start,
                    initialEnd: dateRangeSeed.end,
                    onApply: applyCustomRange,
                    onReset: resetToCurrentMonth
                )
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

    private var statusMenu: some View {
        Menu {
            Button {
                status = nil
            } label: {
                if status == nil {
                    Label("All", systemImage: "checkmark")
                } else {
                    Text("All")
                }
            }

            Divider()

            ForEach(GreetingStatus.allCases) { option in
                Button {
                    status = option
                } label: {
                    filterMenuLabel(option.title, isSelected: status == option)
                }
            }
        } label: {
            Label(
                "Filter greetings",
                systemImage: status == nil
                    ? "line.3.horizontal.decrease"
                    : "line.3.horizontal.decrease.circle.fill"
            )
        }
        .accessibilityValue(status?.title ?? String(localized: "All"))
    }

    @ViewBuilder
    private func filterMenuLabel(_ title: String, isSelected: Bool) -> some View {
        if isSelected {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }

    private var periodBar: some View {
        HStack(spacing: 8) {
            if !isCustomRange {
                periodChevron("chevron.backward", label: "Previous month", action: showPreviousMonth)
            }

            Button {
                showingDateRange = true
            } label: {
                HStack(spacing: 6) {
                    Text(periodLabel)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Choose date range")

            if !isCustomRange {
                periodChevron("chevron.forward", label: "Next month", action: showNextMonth)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    private func periodChevron(
        _ systemImage: String,
        label: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 34)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(label)
    }

    private var resultSummary: some View {
        HStack(spacing: 10) {
            Label(eventCountLabel, systemImage: "calendar.badge.clock")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if let status {
                StatusPill(status: status)
            }

            Spacer(minLength: 0)

            if !isShowingCurrentMonth {
                Button("This month", action: resetToCurrentMonth)
                    .font(.subheadline.weight(.semibold))
            }
        }
        .frame(minHeight: 28)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(
                store.events.isEmpty ? "No greetings yet" : "No greetings",
                systemImage: store.events.isEmpty ? "calendar.badge.plus" : "calendar"
            )
        } description: {
            Text(emptyDescription)
        } actions: {
            if let nearestEvent {
                Button("Show nearest greeting") {
                    showMonth(containing: nearestEvent)
                }
                .buttonStyle(.borderedProminent)
            } else if status != nil {
                Button("Clear status filter") {
                    status = nil
                }
                .buttonStyle(.bordered)
            } else {
                Button("Add greeting") {
                    showingNewGreeting = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: TouchPointMetric.cardRadius, style: .continuous))
    }

    private func eventGroup(_ group: EventDayGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(group.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            SurfaceCard {
                VStack(spacing: 0) {
                    ForEach(Array(group.events.enumerated()), id: \.element.id) { index, event in
                        NavigationLink {
                            GreetingDetailView(eventID: event.id)
                        } label: {
                            CalendarEventRow(event: event)
                        }
                        .buttonStyle(.plain)

                        if index < group.events.count - 1 {
                            Divider().padding(.leading, 64)
                        }
                    }
                }
            }
        }
    }

    private var groupedEvents: [EventDayGroup] {
        let groups = Dictionary(grouping: visibleEvents) { recipientDayKey(for: $0) }
        return groups.compactMap { key, events in
            let sortedEvents = events.sorted { $0.date < $1.date }
            guard let first = sortedEvents.first else { return nil }
            let timeZoneID = store.person(for: first)?.timeZoneIdentifier ?? TimeZone.current.identifier
            var style = Date.FormatStyle(date: .long, time: .omitted)
            style.timeZone = TimeZone(identifier: timeZoneID) ?? .current
            return EventDayGroup(id: key, title: first.date.formatted(style), events: sortedEvents)
        }
        .sorted { $0.id < $1.id }
    }

    private var activeDayKeyBounds: (start: String, end: String) {
        if isCustomRange {
            return (
                deviceDayKey(for: min(customStart, customEnd)),
                deviceDayKey(for: max(customStart, customEnd))
            )
        }

        let interval = calendar.dateInterval(of: .month, for: displayedMonth)
            ?? DateInterval(start: displayedMonth, duration: 0)
        let finalDay = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.start
        return (deviceDayKey(for: interval.start), deviceDayKey(for: finalDay))
    }

    private var periodLabel: String {
        if isCustomRange {
            let start = min(customStart, customEnd).formatted(date: .abbreviated, time: .omitted)
            let end = max(customStart, customEnd).formatted(date: .abbreviated, time: .omitted)
            return "\(start) – \(end)"
        }

        return displayedMonth.formatted(.dateTime.month(.wide).year())
    }

    private var eventCountLabel: String {
        if visibleEvents.count == 1 {
            return String(localized: "1 greeting")
        }
        return String(localized: "\(visibleEvents.count) greetings")
    }

    private var emptyDescription: String {
        if store.events.isEmpty {
            return String(localized: "Add a greeting or plan the year to build your calendar.")
        }
        if status != nil {
            return String(localized: "There are no greetings with this status in the selected period.")
        }
        return String(localized: "There are no greetings in the selected period.")
    }

    private var nearestEvent: GreetingEvent? {
        guard !statusFilteredEvents.isEmpty else { return nil }
        return statusFilteredEvents.min { lhs, rhs in
            abs(lhs.date.timeIntervalSinceNow) < abs(rhs.date.timeIntervalSinceNow)
        }
    }

    private var dateRangeSeed: (start: Date, end: Date) {
        if isCustomRange {
            return (customStart, customEnd)
        }
        let interval = calendar.dateInterval(of: .month, for: displayedMonth)
        let start = interval?.start ?? displayedMonth
        let end = calendar.date(byAdding: .day, value: -1, to: interval?.end ?? displayedMonth) ?? displayedMonth
        return (start, end)
    }

    private var isShowingCurrentMonth: Bool {
        !isCustomRange && calendar.isDate(displayedMonth, equalTo: .now, toGranularity: .month)
    }

    private func showPreviousMonth() {
        if let date = calendar.date(byAdding: .month, value: -1, to: displayedMonth) {
            displayedMonth = date
        }
    }

    private func showNextMonth() {
        if let date = calendar.date(byAdding: .month, value: 1, to: displayedMonth) {
            displayedMonth = date
        }
    }

    private func showMonth(containing event: GreetingEvent) {
        var recipientCalendar = Calendar(identifier: .gregorian)
        if let person = store.person(for: event) {
            recipientCalendar.timeZone = TimeZone(identifier: person.timeZoneIdentifier) ?? .current
        }
        let components = recipientCalendar.dateComponents([.year, .month], from: event.date)
        displayedMonth = calendar.date(from: components) ?? event.date
        isCustomRange = false
    }

    private func applyCustomRange(start: Date, end: Date) {
        customStart = min(start, end)
        customEnd = max(start, end)
        isCustomRange = true
        showingDateRange = false
    }

    private func resetToCurrentMonth() {
        displayedMonth = .now
        isCustomRange = false
        showingDateRange = false
    }

    private func recipientDayKey(for event: GreetingEvent) -> String {
        var recipientCalendar = Calendar(identifier: .gregorian)
        if let person = store.person(for: event) {
            recipientCalendar.timeZone = TimeZone(identifier: person.timeZoneIdentifier) ?? .current
        }
        let components = recipientCalendar.dateComponents([.year, .month, .day], from: event.date)
        return dayKey(from: components)
    }

    private func deviceDayKey(for date: Date) -> String {
        dayKey(from: calendar.dateComponents([.year, .month, .day], from: date))
    }

    private func dayKey(from components: DateComponents) -> String {
        String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}

private struct CalendarEventRow: View {
    @Environment(AppStore.self) private var store
    let event: GreetingEvent

    var body: some View {
        if let person = store.person(for: event) {
            HStack(alignment: TouchPointMetric.rowContentAlignment, spacing: 12) {
                PersonAvatar(person: person)

                VStack(alignment: .leading, spacing: 5) {
                    Text(person.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(event.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) {
                            eventMetadata(person: person)
                            Spacer(minLength: 0)
                            StatusPill(status: store.status(for: event))
                        }

                        VStack(alignment: .leading, spacing: 7) {
                            eventMetadata(person: person)
                            StatusPill(status: store.status(for: event))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 3)
                    .accessibilityHidden(true)
            }
            .padding(TouchPointMetric.cardPadding)
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
        }
    }

    private func eventMetadata(person: Person) -> some View {
        HStack(spacing: 10) {
            Label(event.date.touchPointTime(in: person.timeZoneIdentifier), systemImage: "clock")
            Label(event.method.title, systemImage: event.method.icon)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
}

private struct CalendarDateRangeSheet: View {
    let onApply: (Date, Date) -> Void
    let onReset: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var start: Date
    @State private var end: Date

    init(
        initialStart: Date,
        initialEnd: Date,
        onApply: @escaping (Date, Date) -> Void,
        onReset: @escaping () -> Void
    ) {
        self.onApply = onApply
        self.onReset = onReset
        _start = State(initialValue: initialStart)
        _end = State(initialValue: initialEnd)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                DatePicker("From", selection: $start, displayedComponents: .date)
                DatePicker("To", selection: $end, displayedComponents: .date)

                Button("Reset to current month") {
                    onReset()
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .navigationTitle("Date Range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onApply(start, end)
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(230), .medium])
        .presentationDragIndicator(.visible)
    }
}

private struct EventDayGroup: Identifiable {
    let id: String
    let title: String
    let events: [GreetingEvent]
}
