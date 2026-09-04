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
    /// Sparse recipient exceptions. Automatic resolution remains the default for everyone else.
    @State private var templateIDsByPersonAndOccasion: [UUID: [Occasion: UUID]] = [:]
    @State private var showingRecipientOverrides = false
    @State private var showingOccasionPicker = false
    @State private var step = 0
    @State private var scheduledCount: Int?
    @State private var schedulingError: String?

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
            .alert("Greetings not saved", isPresented: Binding(
                get: { schedulingError != nil },
                set: { if !$0 { schedulingError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(schedulingError ?? "")
            }
            .onAppear {
                guard !didSetInitialFilter else { return }
                relationshipFilter = preferences.focus == .all ? nil : preferences.focus.defaultRelationship
                didSetInitialFilter = true
            }
            .sheet(isPresented: $showingRecipientOverrides) {
                recipientOverridesSheet
            }
            .sheet(isPresented: $showingOccasionPicker) {
                OccasionPickerSheet(
                    selection: orderedSelectedOccasions,
                    options: preferences.focus.occasionPriority,
                    mode: .multiple
                ) { selection in
                    updateSelectedOccasions(selection)
                }
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
            Section {
                Button { showingOccasionPicker = true } label: {
                    HStack(spacing: 12) {
                        IconTile(systemImage: "calendar.badge.plus", tint: .accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Choose occasions")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(selectedOccasionSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Text(selectedOccasions.count.formatted())
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens a searchable multi-select occasion list")
            } footer: {
                Text("Search all moments or expand Personal, U.S. holidays, Observances, and Latin American dates.")
            }

            if !orderedSelectedOccasions.isEmpty {
                Section("Selected") {
                    ForEach(orderedSelectedOccasions) { occasion in
                        HStack(spacing: 12) {
                            IconTile(systemImage: occasion.icon, tint: occasion.tint)
                            Text(occasion.title)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.accent)
                        }
                    }
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

                VStack(alignment: .leading, spacing: 10) {
                    SectionHeading(title: "Recipient exceptions")
                    SurfaceCard {
                        Button {
                            showingRecipientOverrides = true
                        } label: {
                            HStack(spacing: 12) {
                                IconTile(systemImage: "person.crop.circle.badge.exclamationmark", tint: .accentColor)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Customize specific people")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(recipientOverrideSummary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(TouchPointMetric.cardPadding)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
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
                                        if let overrideSummary = recipientOverrideSummary(for: occasion) {
                                            Text(overrideSummary)
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                        }
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

                if !preflightWarnings.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeading(title: "Before scheduling")
                        SurfaceCard {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(preflightWarnings, id: \.self) { warning in
                                    Label(warning, systemImage: "exclamationmark.triangle")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(TouchPointMetric.cardPadding)
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

    private var selectedOccasionSummary: String {
        let titles = orderedSelectedOccasions.map(\.title)
        if titles.isEmpty { return String(localized: "No occasions selected") }
        if titles.count <= 2 { return titles.joined(separator: ", ") }
        return String(localized: "\(titles.prefix(2).joined(separator: ", ")) and \(titles.count - 2) more")
    }

    private func updateSelectedOccasions(_ selection: [Occasion]) {
        let nextSelection = Set(selection)
        selectedOccasions = nextSelection
        templateIDsByOccasion = templateIDsByOccasion.filter { nextSelection.contains($0.key) }
        templateIDsByPersonAndOccasion = templateIDsByPersonAndOccasion.reduce(into: [:]) { result, entry in
            let filtered = entry.value.filter { nextSelection.contains($0.key) }
            if !filtered.isEmpty { result[entry.key] = filtered }
        }
    }

    private var selectedPeopleInOrder: [Person] {
        store.people
            .filter { selectedPeople.contains($0.id) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var recipientOverrideCount: Int {
        templateIDsByPersonAndOccasion.reduce(0) { count, entry in
            guard selectedPeople.contains(entry.key) else { return count }
            return count + entry.value.filter { occasion, templateID in
                selectedOccasions.contains(occasion)
                    && isValidRecipientOverride(templateID, occasion: occasion)
            }.count
        }
    }

    private var recipientOverrideSummary: String {
        if recipientOverrideCount == 0 {
            return "Automatic recommendations for everyone"
        }
        let peopleCount = templateIDsByPersonAndOccasion.filter { personID, overrides in
            selectedPeople.contains(personID) &&
            overrides.contains { occasion, templateID in
                selectedOccasions.contains(occasion)
                    && isValidRecipientOverride(templateID, occasion: occasion)
            }
        }.count
        let overrides = recipientOverrideCount == 1 ? "1 override" : "\(recipientOverrideCount) overrides"
        let people = peopleCount == 1 ? "1 person" : "\(peopleCount) people"
        return "\(overrides) for \(people) · Automatic for everyone else"
    }

    private func recipientOverrideSummary(for occasion: Occasion) -> String? {
        let names = selectedPeopleInOrder.compactMap { person -> String? in
            guard let templateID = templateIDsByPersonAndOccasion[person.id]?[occasion],
                  isValidRecipientOverride(templateID, occasion: occasion) else { return nil }
            return person.name
        }
        guard !names.isEmpty else { return nil }
        if names.count <= 2 {
            return "Overrides: \(names.joined(separator: ", "))"
        }
        return "Overrides: \(names.prefix(2).joined(separator: ", ")) + \(names.count - 2) more"
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

    private func matchingTemplates(for occasion: Occasion, person: Person) -> [GreetingTemplate] {
        let method = usePreferredContactMethods ? person.preferredContactMethod : contactMethod
        let language = person.preferredLanguage.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return store.templates
            .filter { template in
                guard !template.isArchived, template.occasions.contains(occasion) else { return false }
                let relationshipMatches = template.relationships.isEmpty || template.relationships.contains(person.relationship)
                let channelMatches = template.channels.isEmpty || template.channels.contains(method)
                let languageMatches = language.isEmpty || template.languages.isEmpty
                    || template.languages.contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == language }
                return relationshipMatches && channelMatches && languageMatches
            }
            .sorted {
                if $0.isDefault != $1.isDefault { return $0.isDefault }
                if $0.isFavorite != $1.isFavorite { return $0.isFavorite }
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
    }

    private func templateTitle(for occasion: Occasion) -> String {
        guard let template = occasionOverrideTemplate(for: occasion) else {
            return "Automatic recommendation"
        }
        return template.title
    }

    private func occasionOverrideTemplate(for occasion: Occasion) -> GreetingTemplate? {
        guard let templateID = templateIDsByOccasion[occasion] else { return nil }
        return store.templates.first {
            $0.id == templateID && !$0.isArchived && $0.occasions.contains(occasion)
        }
    }

    private func templatePreview(for occasion: Occasion) -> String? {
        guard let person = selectedPeopleInOrder.first else { return nil }
        let method = usePreferredContactMethods ? person.preferredContactMethod : contactMethod
        let template = templateIDsByPersonAndOccasion[person.id]?[occasion]
            .flatMap { id in store.templates.first(where: { $0.id == id }) }
            ?? occasionOverrideTemplate(for: occasion)
            ?? store.resolveTemplate(for: person, occasion: occasion, channel: method)
        return store.renderedBody(
            for: template,
            person: person,
            occasion: occasion,
            senderName: preferences.senderName
        )
    }

    private func recipientTemplateTitle(for person: Person, occasion: Occasion) -> String {
        if let templateID = templateIDsByPersonAndOccasion[person.id]?[occasion],
           let template = store.templates.first(where: {
               $0.id == templateID && !$0.isArchived && $0.occasions.contains(occasion)
           }) {
            return template.title
        }
        if let template = occasionOverrideTemplate(for: occasion) {
            return "Occasion setting · \(template.title)"
        }
        return "Automatic recommendation"
    }

    private func setRecipientTemplate(_ templateID: UUID?, personID: UUID, occasion: Occasion) {
        var overrides = templateIDsByPersonAndOccasion[personID] ?? [:]
        if let templateID {
            overrides[occasion] = templateID
        } else {
            overrides.removeValue(forKey: occasion)
        }
        if overrides.isEmpty {
            templateIDsByPersonAndOccasion.removeValue(forKey: personID)
        } else {
            templateIDsByPersonAndOccasion[personID] = overrides
        }
    }

    private func recipientOverrideMenu(for person: Person, occasion: Occasion) -> some View {
        Menu {
            Button {
                setRecipientTemplate(nil, personID: person.id, occasion: occasion)
            } label: {
                if templateIDsByPersonAndOccasion[person.id]?[occasion] == nil {
                    if let occasionTemplate = occasionOverrideTemplate(for: occasion) {
                        Label("Occasion setting · \(occasionTemplate.title)", systemImage: "checkmark")
                    } else {
                        Label("Automatic recommendation", systemImage: "checkmark")
                    }
                } else {
                    Text(occasionOverrideTemplate(for: occasion).map { "Occasion setting · \($0.title)" } ?? "Automatic recommendation")
                }
            }

            let templates = matchingTemplates(for: occasion, person: person)
            if !templates.isEmpty { Divider() }
            ForEach(templates) { template in
                Button {
                    setRecipientTemplate(template.id, personID: person.id, occasion: occasion)
                } label: {
                    if templateIDsByPersonAndOccasion[person.id]?[occasion] == template.id {
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
                    Text(recipientTemplateTitle(for: person, occasion: occasion))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(TouchPointMetric.cardPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var recipientOverridesSheet: some View {
        NavigationStack {
            List {
                Section {
                    Text("Automatic recommendations use each recipient's relationship, preferred contact method, and language. Choose a template only for people who need an exception.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Selected people") {
                    ForEach(selectedPeopleInOrder) { person in
                        NavigationLink {
                            recipientOverrideDetail(for: person)
                        } label: {
                            HStack(spacing: 12) {
                                PersonAvatar(person: person)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(person.name)
                                        .font(.subheadline.weight(.semibold))
                                    Text(recipientDetailSubtitle(for: person))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Recipient exceptions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingRecipientOverrides = false }
                }
            }
        }
    }

    private func recipientDetailSubtitle(for person: Person) -> String {
        let count = templateIDsByPersonAndOccasion[person.id]?.filter { occasion, templateID in
            selectedOccasions.contains(occasion)
                && isValidRecipientOverride(templateID, occasion: occasion)
        }.count ?? 0
        if count == 0 { return "Automatic recommendations" }
        return count == 1 ? "1 custom template" : "\(count) custom templates"
    }

    private func isValidRecipientOverride(_ templateID: UUID, occasion: Occasion) -> Bool {
        store.templates.contains {
            $0.id == templateID && !$0.isArchived && $0.occasions.contains(occasion)
        }
    }

    private func recipientOverrideDetail(for person: Person) -> some View {
        List {
            Section {
                Text("Choose a template for this person and occasion. Automatic uses the best channel and language match.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("Occasions") {
                ForEach(orderedSelectedOccasions) { occasion in
                    recipientOverrideMenu(for: person, occasion: occasion)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(person.name)
        .navigationBarTitleDisplayMode(.inline)
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
        .buttonStyle(.plain)
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
                    let count = store.scheduleYear(
                        personIDs: selectedPeople,
                        occasions: selectedOccasions,
                        method: contactMethod,
                        templateIDsByOccasion: templateIDsByOccasion,
                        templateIDsByPersonAndOccasion: templateIDsByPersonAndOccasion,
                        usePreferredContactMethods: usePreferredContactMethods,
                        senderName: preferences.senderName
                    )
                    if count == 0 {
                        schedulingError = store.persistenceError ?? "Touch Point could not save these greetings."
                    } else {
                        scheduledCount = count
                    }
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

    private var preflightWarnings: [String] {
        var warnings: [String] = []
        let selected = selectedPeopleInOrder
        let missingPhone = selected.filter { $0.phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        let missingEmail = selected.filter { $0.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count

        if usePreferredContactMethods {
            let smsWithoutPhone = selected.filter {
                $0.preferredContactMethod == .sms && $0.phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }.count
            let emailWithoutEmail = selected.filter {
                $0.preferredContactMethod == .email && $0.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }.count
            if smsWithoutPhone > 0 {
                warnings.append("\(smsWithoutPhone) \(smsWithoutPhone == 1 ? "person has" : "people have") Text message selected but no phone number; Touch Point will fall back to Email or Reminder.")
            }
            if emailWithoutEmail > 0 {
                warnings.append("\(emailWithoutEmail) \(emailWithoutEmail == 1 ? "person has" : "people have") Email selected but no email address; Touch Point will fall back to Text message or Reminder.")
            }
        } else {
            if contactMethod == .sms && missingPhone > 0 {
                warnings.append("Text message is selected, but \(missingPhone) selected \(missingPhone == 1 ? "person has" : "people have") no phone number. Their greeting will use Email or Reminder when possible.")
            }
            if contactMethod == .email && missingEmail > 0 {
                warnings.append("Email is selected, but \(missingEmail) selected \(missingEmail == 1 ? "person has" : "people have") no email address. Their greeting will use Text message or Reminder when possible.")
            }
        }
        return warnings
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
