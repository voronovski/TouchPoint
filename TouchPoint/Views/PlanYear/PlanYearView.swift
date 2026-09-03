import SwiftUI

struct PlanYearView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppPreferences.self) private var preferences
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPeople: Set<UUID> = []
    @State private var relationshipFilter: Relationship? = .client
    @State private var didSetInitialFilter = false
    @State private var selectedOccasions: Set<Occasion> = [.birthday]
    @State private var contactMethod: ContactMethod = .sms
    @State private var usePreferredContactMethods = true
    @State private var templateIDsByOccasion: [Occasion: UUID] = [:]
    @State private var step = 0
    @State private var scheduledCount: Int?

    private let stepTitles = ["People", "Occasions", "Message", "Review"]

    private var visiblePeople: [Person] {
        let people = if let relationshipFilter {
            store.people.filter { $0.relationship == relationshipFilter }
        } else {
            store.people
        }
        return people.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var allVisiblePeopleSelected: Bool {
        !visiblePeople.isEmpty && visiblePeople.allSatisfy { selectedPeople.contains($0.id) }
    }

    private var schedulableCount: Int {
        store.schedulableGreetingCount(
            personIDs: selectedPeople,
            occasions: selectedOccasions
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressHeader

                Group {
                    switch step {
                    case 0: peopleStep
                    case 1: occasionsStep
                    case 2: messageStep
                    default: reviewStep
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
                Text(scheduledResultMessage)
            }
            .onAppear {
                guard !didSetInitialFilter else { return }
                relationshipFilter = preferences.focus == .all ? nil : preferences.focus.defaultRelationship
                didSetInitialFilter = true
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
                                Text(person.relationship.title)
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
                                    Label(relationship.title, systemImage: "checkmark")
                                } else {
                                    Text(relationship.title)
                                }
                            }
                        }
                    } label: {
                        Label(relationshipFilter?.title ?? "All relationships", systemImage: "line.3.horizontal.decrease")
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
                ForEach(preferences.focus.occasionPriority) { occasion in
                    Button {
                        toggle(occasion, in: &selectedOccasions)
                    } label: {
                        HStack(spacing: 12) {
                            IconTile(systemImage: occasion.icon, tint: occasion.tint)
                            Text(occasion.title)
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

    private var messageStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TouchPointMetric.sectionSpacing) {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeading(title: "How you will reach out")
                    SurfaceCard {
                        VStack(spacing: 0) {
                            Toggle("Use each person's preferred method", isOn: $usePreferredContactMethods)
                                .font(.subheadline.weight(.semibold))
                                .padding(TouchPointMetric.cardPadding)

                            if !usePreferredContactMethods {
                                Divider()
                                ForEach(Array(ContactMethod.allCases.enumerated()), id: \.element.id) { index, method in
                                    Button {
                                        contactMethod = method
                                    } label: {
                                        HStack(spacing: 12) {
                                            IconTile(systemImage: method.icon, tint: .accentColor)
                                            Text(method.title)
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
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionHeading(title: "Greeting templates")
                    SurfaceCard {
                        VStack(spacing: 0) {
                            ForEach(Array(orderedSelectedOccasions.enumerated()), id: \.element.id) { index, occasion in
                                templateMenu(for: occasion)

                                if index < orderedSelectedOccasions.count - 1 {
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

    private var reviewStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TouchPointMetric.sectionSpacing) {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeading(title: "Plan summary")
                    SurfaceCard {
                        VStack(spacing: 0) {
                            reviewRow(
                                icon: "person.2",
                                title: "People",
                                value: selectedPeople.count.formatted()
                            )
                            Divider().padding(.leading, 52)
                            reviewRow(
                                icon: "calendar.badge.plus",
                                title: "Greetings to add",
                                value: schedulableCount.formatted()
                            )
                            Divider().padding(.leading, 52)
                            reviewRow(
                                icon: usePreferredContactMethods ? "person.crop.circle.badge.checkmark" : contactMethod.icon,
                                title: "Action",
                                value: usePreferredContactMethods ? "Preferred methods" : contactMethod.title
                            )
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionHeading(title: "Messages")
                    SurfaceCard {
                        VStack(spacing: 0) {
                            ForEach(Array(orderedSelectedOccasions.enumerated()), id: \.element.id) { index, occasion in
                                HStack(spacing: 12) {
                                    IconTile(systemImage: occasion.icon, tint: occasion.tint)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(occasion.title)
                                            .font(.subheadline.weight(.semibold))
                                        Text(templateTitle(for: occasion))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        if let preview = templatePreview(for: occasion) {
                                            Text(preview)
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                                .lineLimit(2)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(TouchPointMetric.cardPadding)

                                if index < orderedSelectedOccasions.count - 1 {
                                    Divider().padding(.leading, 52)
                                }
                            }
                        }
                    }
                }

                Label {
                    Text(reviewExplanation)
                } icon: {
                    Image(systemName: schedulableCount == 0 ? "exclamationmark.triangle" : "checkmark.circle")
                        .foregroundStyle(schedulableCount == 0 ? TouchPointColor.amber : Color.accentColor)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, TouchPointMetric.screenPadding)
            .padding(.vertical, 8)
        }
    }

    private var orderedSelectedOccasions: [Occasion] {
        preferences.focus.occasionPriority.filter { selectedOccasions.contains($0) }
    }

    private func matchingTemplates(for occasion: Occasion) -> [GreetingTemplate] {
        store.templates
            .filter {
                !$0.isArchived && $0.occasions.contains(occasion)
                    && (usePreferredContactMethods || $0.channels.isEmpty || $0.channels.contains(contactMethod))
            }
            .sorted {
                if $0.isDefault != $1.isDefault {
                    return $0.isDefault
                }
                if $0.isFavorite != $1.isFavorite {
                    return $0.isFavorite
                }
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
    }

    private func templateTitle(for occasion: Occasion) -> String {
        guard let templateID = templateIDsByOccasion[occasion],
              let template = store.templates.first(where: { $0.id == templateID }) else {
            return "Automatic recommendation"
        }
        return template.title
    }

    private func templatePreview(for occasion: Occasion) -> String? {
        guard let personID = selectedPeople.first,
              let person = store.people.first(where: { $0.id == personID }) else { return nil }
        let method = usePreferredContactMethods ? person.preferredContactMethod : contactMethod
        let template = templateIDsByOccasion[occasion]
            .flatMap { id in store.templates.first(where: { $0.id == id }) }
            ?? store.resolveTemplate(for: person, occasion: occasion, channel: method)
        return store.renderedBody(for: template, person: person, occasion: occasion)
    }

    private func templateMenu(for occasion: Occasion) -> some View {
        Menu {
            Button {
                templateIDsByOccasion.removeValue(forKey: occasion)
            } label: {
                if templateIDsByOccasion[occasion] == nil {
                    Label("Automatic recommendation", systemImage: "checkmark")
                } else {
                    Text("Automatic recommendation")
                }
            }

            let templates = matchingTemplates(for: occasion)
            if !templates.isEmpty {
                Divider()
            }
            ForEach(templates) { template in
                Button {
                    templateIDsByOccasion[occasion] = template.id
                } label: {
                    if templateIDsByOccasion[occasion] == template.id {
                        Label(template.title, systemImage: "checkmark")
                    } else {
                        Text(template.title)
                    }
                }
            }
        } label: {
            HStack(spacing: 12) {
                IconTile(systemImage: occasion.icon, tint: occasion.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(occasion.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(templateTitle(for: occasion))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(TouchPointMetric.cardPadding)
            .contentShape(Rectangle())
        }
    }

    private func reviewRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            IconTile(systemImage: icon)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.trailing)
        }
        .padding(TouchPointMetric.cardPadding)
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
                        method: contactMethod,
                        templateIDsByOccasion: templateIDsByOccasion,
                        usePreferredContactMethods: usePreferredContactMethods
                    )
                }
            } label: {
                PrimaryButtonLabel(
                    title: primaryActionTitle,
                    systemImage: step == stepTitles.count - 1 ? "calendar.badge.plus" : "chevron.right"
                )
            }
            .buttonStyle(TouchPointPrimaryButtonStyle())
            .disabled(cannotContinue)
            .opacity(cannotContinue ? 0.45 : 1)
        }
        .padding(TouchPointMetric.screenPadding)
        .background(.bar)
    }

    private var primaryActionTitle: String {
        switch step {
        case 2:
            "Review plan"
        case 3:
            "Schedule \(schedulableCount) \(schedulableCount == 1 ? "greeting" : "greetings")"
        default:
            "Continue"
        }
    }

    private var cannotContinue: Bool {
        switch step {
        case 0: selectedPeople.isEmpty
        case 1: selectedOccasions.isEmpty
        case 3: schedulableCount == 0
        default: false
        }
    }

    private var reviewExplanation: String {
        if schedulableCount == 0 {
            return "No new greetings can be added. The selected people may be missing these dates, or matching greetings may already be planned."
        }
        return "Only greetings with an available date are added. Each message is personalized now and remains editable before you open Messages or Mail."
    }

    private var scheduledResultMessage: String {
        let count = scheduledCount ?? 0
        if count == 1 {
            return "1 greeting was added to your calendar."
        }
        return "\(count) greetings were added to your calendar."
    }

    private var actionExplanation: String {
        if usePreferredContactMethods {
            return "Each greeting uses that person's preferred contact method. Touch Point prepares the message, but you always review and send it."
        }
        switch contactMethod {
        case .sms:
            return "On the scheduled day, TouchPoint opens Messages with the recipient and greeting filled in. You tap Send."
        case .email:
            return "On the scheduled day, TouchPoint opens Mail with the recipient, subject, and greeting filled in. You tap Send."
        case .reminder:
            return "TouchPoint reminds you to reach out and lets you mark the greeting complete."
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
