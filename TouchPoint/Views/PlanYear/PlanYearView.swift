import SwiftUI

struct PlanYearView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPeople: Set<UUID> = []
    @State private var relationshipFilter: Relationship? = .client
    @State private var selectedOccasions: Set<Occasion> = [.birthday]
    @State private var contactMethod: ContactMethod = .sms
    @State private var step = 0
    @State private var scheduledCount: Int?

    private let stepTitles = ["People", "Occasions", "Action"]

    private var visiblePeople: [Person] {
        guard let relationshipFilter else { return store.people }
        return store.people.filter { $0.relationship == relationshipFilter }
    }

    private var allVisiblePeopleSelected: Bool {
        !visiblePeople.isEmpty && visiblePeople.allSatisfy { selectedPeople.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressHeader

                Group {
                    switch step {
                    case 0: peopleStep
                    case 1: occasionsStep
                    default: actionStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                footer
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Plan the year")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Year planned", isPresented: Binding(
                get: { scheduledCount != nil },
                set: { if !$0 { scheduledCount = nil } }
            )) {
                Button("Done") { dismiss() }
            } message: {
                Text("\(scheduledCount ?? 0) greetings were added to your calendar.")
            }
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ForEach(stepTitles.indices, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? Color.accentColor : Color(.systemFill))
                        .frame(height: 4)
                }
            }
            Text("Step \(step + 1) of \(stepTitles.count) · \(stepTitles[step])")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, TouchPointMetric.screenPadding)
        .padding(.vertical, 12)
    }

    private var peopleStep: some View {
        List {
            Section {
                ForEach(visiblePeople) { person in
                    Button {
                        toggle(person.id, in: &selectedPeople)
                    } label: {
                        HStack(spacing: 12) {
                            PersonAvatar(person: person)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(person.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(person.relationship.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: selectedPeople.contains(person.id) ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(selectedPeople.contains(person.id) ? Color.accentColor : Color.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                HStack {
                    Menu {
                        Button("All relationships") { relationshipFilter = nil }
                        Divider()
                        ForEach(Relationship.allCases) { relationship in
                            Button {
                                relationshipFilter = relationship
                            } label: {
                                if relationshipFilter == relationship {
                                    Label(relationship.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(relationship.rawValue)
                                }
                            }
                        }
                    } label: {
                        Label(relationshipFilter?.rawValue ?? "All relationships", systemImage: "line.3.horizontal.decrease")
                    }
                    .textCase(nil)

                    Spacer()
                    Button(allVisiblePeopleSelected ? "Clear" : "Select all") {
                        let visibleIDs = Set(visiblePeople.map(\.id))
                        if allVisiblePeopleSelected {
                            selectedPeople.subtract(visibleIDs)
                        } else {
                            selectedPeople.formUnion(visibleIDs)
                        }
                    }
                    .textCase(nil)
                }
            } footer: {
                Text("Filter by relationship, then select the people to include. You can fine-tune each greeting later.")
            }
        }
        .listStyle(.insetGrouped)
    }

    private var occasionsStep: some View {
        List {
            Section("Choose occasions") {
                ForEach(Occasion.allCases) { occasion in
                    Button {
                        toggle(occasion, in: &selectedOccasions)
                    } label: {
                        HStack(spacing: 12) {
                            IconTile(systemImage: occasion.icon, tint: occasion.tint)
                            Text(occasion.rawValue)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: selectedOccasions.contains(occasion) ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(selectedOccasions.contains(occasion) ? Color.accentColor : Color.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var actionStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TouchPointMetric.sectionSpacing) {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeading(title: "How you will reach out")
                    SurfaceCard {
                        VStack(spacing: 0) {
                            ForEach(Array(ContactMethod.allCases.enumerated()), id: \.element.id) { index, method in
                                Button {
                                    contactMethod = method
                                } label: {
                                    HStack(spacing: 12) {
                                        IconTile(systemImage: method.icon, tint: .accentColor)
                                        Text(method.rawValue)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Image(systemName: contactMethod == method ? "checkmark.circle.fill" : "circle")
                                            .font(.title3)
                                            .foregroundStyle(contactMethod == method ? Color.accentColor : Color.secondary)
                                    }
                                    .padding(TouchPointMetric.cardPadding)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                if index < ContactMethod.allCases.count - 1 {
                                    Divider().padding(.leading, 52)
                                }
                            }
                        }
                    }
                }

                Label {
                    Text(actionExplanation)
                } icon: {
                    Image(systemName: "hand.tap")
                        .foregroundStyle(.accent)
                }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, TouchPointMetric.screenPadding)
            .padding(.vertical, 8)
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if step > 0 {
                Button {
                    withAnimation(.snappy) { step -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 50, height: 50)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(.rect(cornerRadius: TouchPointMetric.cardRadius, style: .continuous))
                }
                .accessibilityLabel("Previous step")
            }

            Button {
                if step < stepTitles.count - 1 {
                    withAnimation(.snappy) { step += 1 }
                } else {
                    scheduledCount = store.scheduleYear(
                        personIDs: selectedPeople,
                        occasions: selectedOccasions,
                        method: contactMethod
                    )
                }
            } label: {
                PrimaryButtonLabel(
                    title: step == stepTitles.count - 1 ? "Schedule greetings" : "Continue",
                    systemImage: step == stepTitles.count - 1 ? "calendar.badge.plus" : "chevron.right"
                )
            }
            .buttonStyle(TouchPointPrimaryButtonStyle())
            .disabled(step == 0 && selectedPeople.isEmpty || step == 1 && selectedOccasions.isEmpty)
            .opacity(step == 0 && selectedPeople.isEmpty || step == 1 && selectedOccasions.isEmpty ? 0.45 : 1)
        }
        .padding(TouchPointMetric.screenPadding)
        .background(.bar)
    }

    private var actionExplanation: String {
        switch contactMethod {
        case .sms:
            "On the scheduled day, TouchPoint opens Messages with the recipient and greeting filled in. You tap Send."
        case .email:
            "On the scheduled day, TouchPoint opens Mail with the recipient, subject, and greeting filled in. You tap Send."
        case .reminder:
            "TouchPoint reminds you to reach out and lets you mark the greeting complete."
        }
    }

    private func toggle<T: Hashable>(_ value: T, in set: inout Set<T>) {
        if set.contains(value) {
            set.remove(value)
        } else {
            set.insert(value)
        }
    }
}
