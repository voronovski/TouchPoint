import SwiftUI

struct HomeView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppPreferences.self) private var preferences
    @State private var horizon: PlanningHorizon = .week
    @State private var showingPlanYear = false
    @State private var showingSettings = false
    @State private var selectedEvent: GreetingEvent?
    @State private var refreshTick = Date()

    private var focusedEvents: [GreetingEvent] {
        guard preferences.focus != .all else { return store.events }
        return store.events.filter { event in
            guard let person = store.person(for: event) else { return false }
            return preferences.focus.includes(person.relationship)
        }
    }

    private var upcomingEvents: [GreetingEvent] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let end = calendar.date(byAdding: .day, value: horizon.days, to: start) ?? start

        return focusedEvents
            .filter { $0.date >= start && $0.date < end }
            .sorted { $0.date < $1.date }
    }

    private var nextEvent: GreetingEvent? {
        focusedEvents
            .filter { ![.completed, .skipped].contains(store.status(for: $0)) }
            .sorted {
                if store.status(for: $0) == .ready && store.status(for: $1) != .ready { return true }
                if store.status(for: $1) == .ready && store.status(for: $0) != .ready { return false }
                return $0.date < $1.date
            }
            .first
    }

    private var weekEventCount: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        return focusedEvents.filter { $0.date >= start && $0.date < end }.count
    }

    private var readyCount: Int {
        focusedEvents.filter { store.status(for: $0) == .ready }.count
    }

    private var workloadSummary: String {
        let greetings = weekEventCount == 1 ? "1 greeting" : "\(weekEventCount) greetings"
        let ready = readyCount == 1 ? "1 ready to send" : "\(readyCount) ready to send"
        return "\(greetings) this week · \(ready)"
    }

    private var headerSummary: String {
        switch preferences.focus {
        case .all: workloadSummary
        case .work: "Work focus · " + workloadSummary
        case .personal: "Personal focus · " + workloadSummary
        }
    }

    private var planTitle: String {
        "Plan greetings"
    }

    private var planDescription: String {
        "Choose people and occasions once. Touch Point will build your schedule."
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: TouchPointMetric.sectionSpacing) {
                    welcomeHeader
                    insightsSection
                    nextUpSection
                    planYearCard
                    scheduleSection
                }
                .padding(.horizontal, TouchPointMetric.screenPadding)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Touch Point")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showingPlanYear) {
                PlanYearView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(item: $selectedEvent) { event in
                NavigationStack {
                    GreetingDetailView(eventID: event.id, showsDoneButton: true)
                }
            }
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(60))
                    refreshTick = .now
                }
            }
        }
    }

    private var insights: [(String, String, String)] {
        let focusedPeople = preferences.focus == .all
            ? store.people
            : store.people.filter { preferences.focus.includes($0.relationship) }
        let missingDates = focusedPeople.filter { person in
            !person.importantDates.contains { $0.occasion == .birthday }
        }.count
        let missingContact = focusedPeople.filter {
            $0.phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && $0.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.count
        let unplanned = store.schedulableGreetingCount(
            personIDs: Set(focusedPeople.map(\.id)),
            occasions: Set(Occasion.allCases)
        )
        var result: [(String, String, String)] = []
        if missingDates > 0 { result.append(("calendar.badge.exclamationmark", "Missing dates", "Add birthdays for \(missingDates) \(missingDates == 1 ? "person" : "people")")) }
        if missingContact > 0 { result.append(("person.crop.circle.badge.exclamationmark", "Missing contact info", "Add a phone or email for \(missingContact) \(missingContact == 1 ? "person" : "people")")) }
        if unplanned > 0 { result.append(("calendar.badge.plus", "Unplanned greetings", "\(unplanned) greeting\(unplanned == 1 ? "" : "s") can be added")) }
        return result
    }

    @ViewBuilder
    private var insightsSection: some View {
        if !insights.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeading(title: "Keep your circle current")
                SurfaceCard {
                    VStack(spacing: 0) {
                        ForEach(Array(insights.enumerated()), id: \.offset) { index, insight in
                            HStack(spacing: 12) {
                                IconTile(systemImage: insight.0, tint: TouchPointColor.amber)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(insight.1).font(.subheadline.weight(.semibold))
                                    Text(insight.2).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(TouchPointMetric.cardPadding)
                            if index < insights.count - 1 { Divider().padding(.leading, 64) }
                        }
                    }
                }
            }
        }
    }

    private var welcomeHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                Image(systemName: "sparkles")
                    .font(.headline)
                    .foregroundStyle(.accent)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(headerSummary)
                    .font(.subheadline.weight(.semibold))
            }

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var nextUpSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(title: "Next action")

            if let nextEvent, let person = store.person(for: nextEvent) {
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: 12) {
                            PersonAvatar(person: person, size: 46)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(person.name)
                                    .font(.headline)
                                Label(nextEvent.displayName, systemImage: nextEvent.occasion.icon)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                            StatusPill(status: store.status(for: nextEvent))
                        }

                        Divider()

                        HStack {
                            Label(
                                nextEvent.date.touchPointDay(in: person.timeZoneIdentifier),
                                systemImage: "calendar"
                            )
                            Spacer()
                            Label(
                                nextEvent.date.touchPointTime(in: person.timeZoneIdentifier),
                                systemImage: "clock"
                            )
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                        Button {
                            selectedEvent = nextEvent
                        } label: {
                            PrimaryButtonLabel(
                                title: store.status(for: nextEvent) == .ready ? "Prepare greeting" : "View greeting",
                                systemImage: store.status(for: nextEvent) == .ready ? nextEvent.method.icon : "arrow.right"
                            )
                        }
                        .buttonStyle(TouchPointPrimaryButtonStyle())
                    }
                    .padding(TouchPointMetric.cardPadding)
                }
            }
        }
    }

    private var planYearCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    IconTile(systemImage: "calendar.badge.plus", tint: .accentColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(planTitle)
                            .font(.headline)
                        Text(planDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    showingPlanYear = true
                } label: {
                    PrimaryButtonLabel(
                        title: "Plan greetings",
                        systemImage: "wand.and.sparkles"
                    )
                }
                .buttonStyle(TouchPointPrimaryButtonStyle())
            }
            .padding(TouchPointMetric.cardPadding)
        }
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Upcoming")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("Planning horizon", selection: $horizon) {
                    ForEach(PlanningHorizon.allCases) { horizon in
                        Text(horizon.rawValue).tag(horizon)
                    }
                }
                .pickerStyle(.menu)
            }

            if upcomingEvents.isEmpty {
                ContentUnavailableView(
                    "Nothing scheduled",
                    systemImage: "calendar.badge.checkmark",
                    description: Text("This time range is clear.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: TouchPointMetric.cardRadius, style: .continuous))
            } else {
                SurfaceCard {
                    VStack(spacing: 0) {
                        ForEach(Array(upcomingEvents.enumerated()), id: \.element.id) { index, event in
                            Button {
                                selectedEvent = event
                            } label: {
                                EventRow(event: event)
                            }
                            .buttonStyle(.plain)
                            if index < upcomingEvents.count - 1 {
                                Divider().padding(.leading, 64)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct EventRow: View {
    @Environment(AppStore.self) private var store
    let event: GreetingEvent

    var body: some View {
        if let person = store.person(for: event) {
            HStack(spacing: 12) {
                PersonAvatar(person: person)

                VStack(alignment: .leading, spacing: 3) {
                    Text(person.name)
                        .font(.subheadline.weight(.semibold))
                    Text(event.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(event.date.touchPointDay(in: person.timeZoneIdentifier))
                        .font(.caption.weight(.semibold))
                    Label(event.method.title, systemImage: event.method.icon)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(TouchPointMetric.cardPadding)
            .accessibilityElement(children: .combine)
        }
    }
}
