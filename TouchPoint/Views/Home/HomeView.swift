import SwiftUI

struct HomeView: View {
    @Environment(AppStore.self) private var store
    @State private var horizon: PlanningHorizon = .week
    @State private var showingPlanYear = false
    @State private var selectedEvent: GreetingEvent?

    private var upcomingEvents: [GreetingEvent] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let end = calendar.date(byAdding: .day, value: horizon.days, to: start) ?? start

        return store.events
            .filter { $0.date >= start && $0.date < end }
            .sorted { $0.date < $1.date }
    }

    private var nextEvent: GreetingEvent? {
        store.events
            .filter { $0.date >= Calendar.current.startOfDay(for: .now) }
            .sorted { $0.date < $1.date }
            .first
    }

    private var weekEventCount: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        return store.events.filter { $0.date >= start && $0.date < end }.count
    }

    private var approvalCount: Int {
        store.events.filter { $0.status == .approval }.count
    }

    private var workloadSummary: String {
        let greetings = weekEventCount == 1 ? "1 greeting" : "\(weekEventCount) greetings"
        let approvals = approvalCount == 1 ? "1 needs approval" : "\(approvalCount) need approval"
        return "\(greetings) this week · \(approvals)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: TouchPointMetric.sectionSpacing) {
                    welcomeHeader
                    nextUpSection
                    planYearCard
                    scheduleSection
                }
                .padding(.horizontal, TouchPointMetric.screenPadding)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("TouchPoint")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingPlanYear) {
                PlanYearView()
            }
            .sheet(item: $selectedEvent) { event in
                NavigationStack {
                    GreetingDetailView(eventID: event.id, showsDoneButton: true)
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
                Text(workloadSummary)
                    .font(.subheadline.weight(.semibold))
            }

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var nextUpSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(title: "Next up")

            if let nextEvent, let person = store.person(for: nextEvent) {
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: 12) {
                            PersonAvatar(person: person, size: 46)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(person.name)
                                    .font(.headline)
                                Label(nextEvent.occasion.rawValue, systemImage: nextEvent.occasion.icon)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                            StatusPill(status: nextEvent.status)
                        }

                        Divider()

                        HStack {
                            Label(nextEvent.date.touchPointDay, systemImage: "calendar")
                            Spacer()
                            Label(nextEvent.date.touchPointTime, systemImage: "clock")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                        Button {
                            selectedEvent = nextEvent
                        } label: {
                            PrimaryButtonLabel(
                                title: nextEvent.status == .approval ? "Review greeting" : "View greeting",
                                systemImage: nextEvent.status == .approval ? "checkmark.message" : "arrow.right"
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
                        Text("Plan the year")
                            .font(.headline)
                        Text("Choose people and occasions once. TouchPoint will build the schedule.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    showingPlanYear = true
                } label: {
                    PrimaryButtonLabel(title: "Plan greetings", systemImage: "wand.and.sparkles")
                }
                .buttonStyle(TouchPointPrimaryButtonStyle())
            }
            .padding(TouchPointMetric.cardPadding)
        }
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Schedule")
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
                            EventRow(event: event)
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
                    Text(event.occasion.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(event.date.touchPointDay)
                        .font(.caption.weight(.semibold))
                    Label(event.delivery.rawValue, systemImage: event.delivery.icon)
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
