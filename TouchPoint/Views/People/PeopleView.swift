import SwiftUI

struct PeopleView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppPreferences.self) private var preferences
    @State private var query = ""
    @State private var showingNewPerson = false
    @State private var showingContactsPicker = false
    @State private var importMessage: String?

    private var filteredPeople: [Person] {
        let focusMatches = store.people.filter {
            preferences.focus.includes($0.relationship)
        }
        let matches = query.isEmpty ? focusMatches : focusMatches.filter {
            $0.displayName.localizedCaseInsensitiveContains(query)
                || $0.email.localizedCaseInsensitiveContains(query)
                || $0.organization.localizedCaseInsensitiveContains(query)
        }

        return matches.sorted {
            if preferences.focus == .all {
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            let leftRank = preferences.focus.relationshipRank($0.relationship)
            let rightRank = preferences.focus.relationshipRank($1.relationship)
            if leftRank != rightRank {
                return leftRank < rightRank
            }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Focus", selection: focusBinding) {
                        ForEach(Focus.allCases) { focus in
                            Text(focus.title).tag(focus)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Label("Focus", systemImage: preferences.focus.icon)
                } footer: {
                    Text("Showing " + preferences.focus.title.lowercased() + " relationships. Choose All to see everyone.")
                }

                if let persistenceError = store.persistenceError {
                    Section {
                        Label(persistenceError, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                ForEach(filteredPeople) { person in
                    NavigationLink {
                        PersonDetailView(personID: person.id)
                    } label: {
                        PersonListRow(person: person)
                    }
                }
            }
            .overlay {
                if filteredPeople.isEmpty && store.persistenceError == nil {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(text: $query, prompt: "Name, email, or organization")
            .navigationTitle("People")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showingContactsPicker = true
                        } label: {
                            Label("Import from Contacts", systemImage: "person.crop.circle.badge.plus")
                        }
                        Button {
                            showingNewPerson = true
                        } label: {
                            Label("Add person", systemImage: "person.badge.plus")
                        }
                    } label: {
                        Label("Add person", systemImage: "person.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewPerson) {
                PersonEditorView(
                    person: nil,
                    defaultRelationship: preferences.focus.defaultRelationship
                )
            }
            .sheet(isPresented: $showingContactsPicker) {
                ContactsPicker(
                    onSelect: importContacts,
                    onCancel: { showingContactsPicker = false }
                )
                .ignoresSafeArea()
            }
            .alert("Contacts imported", isPresented: Binding(
                get: { importMessage != nil },
                set: { if !$0 { importMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importMessage ?? "")
            }
        }
    }

    private var focusBinding: Binding<Focus> {
        Binding(
            get: { preferences.focus },
            set: { preferences.focus = $0 }
        )
    }

    private func importContacts(_ imported: [Person]) {
        showingContactsPicker = false
        let existing = Set(store.people.map { normalizedContactKey(name: $0.name, email: $0.email, phone: $0.phone) })
        var seen = existing
        var uniquePeople: [Person] = []
        let skippedMissingContact = imported.contains { !$0.hasContactInfo }
        for person in imported {
            guard person.hasContactInfo else { continue }
            let key = normalizedContactKey(name: person.name, email: person.email, phone: person.phone)
            guard !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            uniquePeople.append(person)
        }
        let added = store.addPeople(uniquePeople)
        if !uniquePeople.isEmpty, added == 0, let error = store.persistenceError {
            importMessage = error
            return
        }
        importMessage = added == 0
            ? "No new contacts were added. Existing people were left unchanged."
            : "Added " + String(added) + " " + (added == 1 ? "person" : "people") + " from Contacts."
        if skippedMissingContact {
            importMessage = (importMessage ?? "") + "\n\n"
                + String(localized: "Contacts without a phone number or email address were skipped.")
        }
    }

    private func normalizedContactKey(name: String, email: String, phone: String) -> String {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !normalizedEmail.isEmpty { return "email:\(normalizedEmail)" }
        let normalizedPhone = phone.filter(\.isNumber)
        if !normalizedPhone.isEmpty { return "phone:\(normalizedPhone)" }
        return "name:\(name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
    }
}

struct PeopleMissingDatesView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppPreferences.self) private var preferences

    private var people: [Person] {
        store.peopleMissingDates(focus: preferences.focus)
    }

    var body: some View {
        List {
            ForEach(people) { person in
                NavigationLink(value: person.id) {
                    PersonListRow(person: person)
                }
            }
        }
        .navigationDestination(for: UUID.self) { personID in
            PersonDetailView(personID: personID)
        }
        .overlay {
            if people.isEmpty {
                ContentUnavailableView(
                    "No missing dates",
                    systemImage: "calendar.badge.checkmark",
                    description: Text("Everyone in this focus has at least one saved date.")
                )
            }
        }
        .navigationTitle("People without dates")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PersonListRow: View {
    let person: Person

    var body: some View {
        HStack(spacing: 12) {
            PersonAvatar(person: person)
            VStack(alignment: .leading, spacing: 3) {
                Text(person.displayName)
                    .font(.subheadline.weight(.semibold))
                Text(person.organization.isEmpty ? person.relationship.title : person.organization)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if person.communicationStopped {
                    Label("Communication stopped", systemImage: "person.slash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 3)
    }
}

private struct PersonDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let personID: UUID
    @State private var editingPerson: Person?
    @State private var showingStopCommunicationConfirmation = false
    @State private var communicationError: String?

    private var person: Person? {
        store.people.first { $0.id == personID }
    }

    private var events: [GreetingEvent] {
        store.events.filter { $0.personID == personID }.sorted { $0.date < $1.date }
    }

    var body: some View {
        ScrollView {
            if let person {
                VStack(alignment: .leading, spacing: TouchPointMetric.sectionSpacing) {
                    summaryCard(person)
                    contactSection(person)
                    preferencesSection(person)
                    communicationSection

                    if !person.notes.isEmpty || !person.tags.isEmpty {
                        contextSection(person)
                    }

                    importantDatesSection(person)
                    greetingsSection(person)
                }
                .padding(.horizontal, TouchPointMetric.screenPadding)
                .padding(.vertical, TouchPointMetric.scrollPadding)
            }
        }
        .background(Color(.systemGroupedBackground))
        .overlay {
            if person == nil {
                ContentUnavailableView("Person unavailable", systemImage: "person.slash")
            }
        }
        .navigationTitle(person?.displayName ?? "Person")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let person {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Edit") { editingPerson = person }
                }
            }
        }
        .sheet(item: $editingPerson, onDismiss: {
            if person == nil { dismiss() }
        }) { person in
            PersonEditorView(person: person)
        }
        .alert("Stop communication with this person?", isPresented: $showingStopCommunicationConfirmation) {
            Button("Stop and delete greetings", role: .destructive) {
                setCommunicationStopped(true)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All planned greetings for this person, including overdue greetings, will be deleted from the queue. Completed and skipped greetings will remain in history. Deleted greetings cannot be restored.")
        }
        .alert("Changes not saved", isPresented: Binding(
            get: { communicationError != nil },
            set: { if !$0 { communicationError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(communicationError ?? "")
        }
    }

    private func summaryCard(_ person: Person) -> some View {
        SurfaceCard {
            HStack(alignment: TouchPointMetric.rowContentAlignment, spacing: 12) {
                PersonAvatar(person: person, size: 44)
                VStack(alignment: .leading, spacing: 8) {
                    Text(person.displayName)
                        .font(.title3.weight(.bold))
                    Text(person.relationship.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !person.organization.isEmpty {
                        Text(person.organization)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(TouchPointMetric.cardPadding)
        }
    }

    private func contactSection(_ person: Person) -> some View {
        SurfaceSection(title: "Contact") {
            if !person.phone.isEmpty {
                FormValueRow(title: "Phone", value: person.phone, systemImage: "phone")
                    .textSelection(.enabled)
                SurfaceRowDivider()
            }
            if !person.email.isEmpty {
                FormValueRow(title: "Email", value: person.email, systemImage: "envelope")
                    .textSelection(.enabled)
                SurfaceRowDivider()
            }
            FormValueRow(title: "Preferred method", value: person.preferredContactMethod.title,
                         systemImage: person.preferredContactMethod.icon)
        }
    }

    private func preferencesSection(_ person: Person) -> some View {
        SurfaceSection(title: "Preferences") {
            FormValueRow(title: "Preferred language", value: person.preferredLanguage,
                         systemImage: "character.bubble")
            SurfaceRowDivider()
            FormValueRow(title: "Time zone",
                         value: person.timeZoneIdentifier.replacingOccurrences(of: "_", with: " "),
                         systemImage: "globe")
        }
    }

    private var communicationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SurfaceSection(title: "Communication") {
                HStack(alignment: TouchPointMetric.rowContentAlignment, spacing: 12) {
                    FormIconTile(systemImage: "person.slash")
                    Toggle("Stop communication", isOn: Binding(
                        get: { person?.communicationStopped ?? false },
                        set: { stopped in
                            if stopped {
                                showingStopCommunicationConfirmation = true
                            } else {
                                setCommunicationStopped(false)
                            }
                        }
                    ))
                    .font(.subheadline.weight(.semibold))
                    .tint(.accentColor)
                }
                .padding(TouchPointMetric.cardPadding)
            }
            Text("Use this when the person asks you to stop contacting them. Planned greetings are removed and new greetings cannot be scheduled while this is on. Turning it off does not restore deleted greetings.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, TouchPointMetric.cardPadding)
        }
    }

    private func contextSection(_ person: Person) -> some View {
        SurfaceSection(title: "Context") {
            if !person.notes.isEmpty {
                HStack(alignment: TouchPointMetric.rowContentAlignment, spacing: 12) {
                    FormIconTile(systemImage: "note.text")
                    Text(person.notes)
                        .font(.subheadline)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(TouchPointMetric.cardPadding)
            }
            if !person.tags.isEmpty {
                if !person.notes.isEmpty { SurfaceRowDivider() }
                HStack(alignment: TouchPointMetric.rowContentAlignment, spacing: 12) {
                    FormIconTile(systemImage: "tag")
                    Text(person.tags.joined(separator: ", "))
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(TouchPointMetric.cardPadding)
            }
        }
    }

    private func importantDatesSection(_ person: Person) -> some View {
        SurfaceSection(title: "Important dates") {
            if person.importantDates.isEmpty {
                emptyRow("No important dates yet", systemImage: "calendar")
            } else {
                ForEach(Array(person.importantDates.sorted(by: importantDateSort).enumerated()), id: \.element.id) { index, date in
                    if index > 0 { SurfaceRowDivider() }
                    HStack(alignment: TouchPointMetric.rowContentAlignment, spacing: 12) {
                        IconTile(systemImage: date.occasion.icon, tint: date.occasion.tint)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(date.displayName)
                                .font(.subheadline.weight(.semibold))
                            Text(date.formatted)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(TouchPointMetric.cardPadding)
                }
            }
        }
    }

    private func greetingsSection(_ person: Person) -> some View {
        SurfaceSection(title: "Planned greetings") {
            if events.isEmpty {
                emptyRow("No greetings planned", systemImage: "calendar.badge.clock")
            } else {
                ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                    if index > 0 { SurfaceRowDivider() }
                    NavigationLink {
                        GreetingDetailView(eventID: event.id)
                    } label: {
                        HStack(alignment: TouchPointMetric.rowContentAlignment, spacing: 12) {
                            IconTile(systemImage: event.occasion.icon, tint: event.occasion.tint)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(event.displayName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(event.date.touchPointDay(in: person.timeZoneIdentifier))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                StatusPill(status: store.status(for: event))
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }
                        .padding(TouchPointMetric.cardPadding)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func emptyRow(_ title: LocalizedStringKey, systemImage: String) -> some View {
        HStack(spacing: 12) {
            FormIconTile(systemImage: systemImage)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(TouchPointMetric.cardPadding)
    }

    private func setCommunicationStopped(_ stopped: Bool) {
        if !store.setCommunicationStopped(stopped, personID: personID) {
            communicationError = store.persistenceError ?? String(localized: "The communication setting could not be saved. Please try again.")
        }
    }

    private func importantDateSort(_ lhs: ImportantDate, _ rhs: ImportantDate) -> Bool {
        (lhs.month, lhs.day) < (rhs.month, rhs.day)
    }
}

private struct PersonEditorView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppPreferences.self) private var preferences
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Person
    @State private var addingDate = false
    @State private var editingDate: ImportantDate?
    @State private var showingTimeZonePicker = false
    @State private var showingDeleteConfirmation = false
    @State private var tagsText: String
    @State private var saveError: String?

    private let isEditing: Bool
    private let languageOptions = TouchPointLanguage.supported

    init(person: Person?, defaultRelationship: Relationship = .client) {
        let draft = person ?? Person(name: "", relationship: defaultRelationship)
        _draft = State(initialValue: draft)
        _tagsText = State(initialValue: draft.tags.joined(separator: ", "))
        isEditing = person != nil
    }

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        draft.hasContactInfo
    }

    private var navigationTitle: String {
        if isEditing {
            return "Edit person"
        }
        return preferences.focus == .work && draft.relationship == .client
            ? "New client"
            : "New person"
    }

    private var saveTitle: String {
        if isEditing {
            return "Save"
        }
        return preferences.focus == .work && draft.relationship == .client
            ? "Add client"
            : "Add"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TouchPointMetric.sectionSpacing) {
                    personSection
                    contactSection
                    preferencesSection
                    contextSection
                    importantDatesSection

                    if let saveError {
                        SurfaceCard {
                            Label(saveError, systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(TouchPointMetric.cardPadding)
                        }
                    }

                    if isEditing {
                        TouchPointDeleteButton(title: "Delete person") {
                            showingDeleteConfirmation = true
                        }
                        .confirmationDialog("Delete this person?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                            Button("Delete person and greetings", role: .destructive) {
                                deletePerson()
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("This also removes the person's planned greetings and cannot be undone.")
                        }
                    }
                }
                .padding(.horizontal, TouchPointMetric.screenPadding)
                .padding(.vertical, TouchPointMetric.scrollPadding)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saveTitle) { save() }
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $addingDate) {
                ImportantDateEditorView(date: newImportantDate, person: draft) { savedDate in
                    draft.importantDates.append(savedDate)
                    addingDate = false
                }
            }
            .sheet(item: $editingDate) { importantDate in
                ImportantDateEditorView(date: importantDate, person: draft) { savedDate in
                    guard let index = draft.importantDates.firstIndex(where: { $0.id == savedDate.id }) else { return }
                    draft.importantDates[index] = savedDate
                    editingDate = nil
                }
            }
            .sheet(isPresented: $showingTimeZonePicker) {
                TimeZonePickerView(selection: $draft.timeZoneIdentifier)
            }
            .onChange(of: draft) { saveError = nil }
            .onChange(of: tagsText) { saveError = nil }
        }
    }

    private var personSection: some View {
        SurfaceSection(title: "Person") {
            FormFieldRow(title: "First name", systemImage: "person") {
                TextField("First name", text: $draft.firstName,
                          prompt: Text("First name").foregroundStyle(Color(uiColor: .placeholderText)))
                    .textContentType(.givenName)
            }
            SurfaceRowDivider()
            FormFieldRow(title: "Preferred name (optional)", systemImage: "person") {
                TextField("Preferred name (optional)", text: $draft.preferredName,
                          prompt: Text("Preferred name (optional)").foregroundStyle(Color(uiColor: .placeholderText)))
                    .textContentType(.nickname)
            }
            SurfaceRowDivider()
            FormFieldRow(title: "Last name", systemImage: "person") {
                TextField("Last name", text: $draft.lastName,
                          prompt: Text("Last name").foregroundStyle(Color(uiColor: .placeholderText)))
                    .textContentType(.familyName)
            }
            SurfaceRowDivider()
            FormFieldRow(title: "Organization (optional)", systemImage: "building.2") {
                TextField("Organization (optional)", text: $draft.organization,
                          prompt: Text("Organization (optional)").foregroundStyle(Color(uiColor: .placeholderText)))
                    .textContentType(.organizationName)
            }
            SurfaceRowDivider()
            Menu {
                Picker("Relationship", selection: $draft.relationship) {
                    ForEach(Relationship.allCases) { relationship in
                        Text(relationship.title).tag(relationship)
                    }
                }
            } label: {
                FormValueRow(title: "Relationship", value: draft.relationship.title,
                             systemImage: "person.2", showsDisclosure: true)
            }
            .buttonStyle(.plain)
        }
    }

    private var contactSection: some View {
        SurfaceSection(title: "Contact") {
            Text("Enter a phone number or email address.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(TouchPointMetric.cardPadding)
            FormFieldRow(title: "Phone", systemImage: "phone") {
                TextField("Phone", text: $draft.phone,
                          prompt: Text("Phone").foregroundStyle(Color(uiColor: .placeholderText)))
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
            }
            SurfaceRowDivider()
            FormFieldRow(title: "Email", systemImage: "envelope") {
                TextField("Email", text: $draft.email,
                          prompt: Text("Email").foregroundStyle(Color(uiColor: .placeholderText)))
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            SurfaceRowDivider()
            Menu {
                Picker("Preferred method", selection: $draft.preferredContactMethod) {
                    ForEach(ContactMethod.allCases) { method in
                        Label(method.title, systemImage: method.icon).tag(method)
                    }
                }
            } label: {
                FormValueRow(title: "Preferred method", value: draft.preferredContactMethod.title,
                             systemImage: draft.preferredContactMethod.icon, showsDisclosure: true)
            }
            .buttonStyle(.plain)
        }
    }

    private var preferencesSection: some View {
        SurfaceSection(title: "Preferences") {
            Menu {
                Picker("Preferred language", selection: $draft.preferredLanguage) {
                    ForEach(languageOptionsForDraft, id: \.self) { language in
                        Text(language).tag(language)
                    }
                }
            } label: {
                FormValueRow(title: "Preferred language", value: draft.preferredLanguage,
                             systemImage: "character.bubble", showsDisclosure: true)
            }
            .buttonStyle(.plain)
            SurfaceRowDivider()
            Button {
                showingTimeZonePicker = true
            } label: {
                FormValueRow(title: "Time zone", value: timeZoneDisplayName(draft.timeZoneIdentifier),
                             systemImage: "globe", showsDisclosure: true)
            }
            .buttonStyle(.plain)
        }
    }

    private var contextSection: some View {
        SurfaceSection(title: "Context") {
            FormFieldRow(title: "Private notes about this person", systemImage: "note.text",
                         alignment: TouchPointMetric.multilineTextFieldAlignment) {
                TextEditor(text: $draft.notes)
                    .font(.subheadline)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 90)
                    .padding(.horizontal, -5)
                    .accessibilityLabel("Private notes about this person")
            }
            SurfaceRowDivider()
            FormFieldRow(title: "Tags (comma separated)", systemImage: "tag") {
                TextField("Tags (comma separated)", text: $tagsText,
                          prompt: Text("").foregroundStyle(Color(uiColor: .placeholderText)))
                    .textInputAutocapitalization(.never)
            }
        }
    }

    private var importantDatesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SurfaceSection(title: "Important dates") {
                ForEach(draft.importantDates) { date in
                    HStack(spacing: 0) {
                        Button {
                            editingDate = date
                        } label: {
                            HStack(alignment: TouchPointMetric.rowContentAlignment, spacing: 12) {
                                IconTile(systemImage: date.occasion.icon, tint: date.occasion.tint)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(date.displayName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(date.formatted)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                                    .accessibilityHidden(true)
                            }
                            .padding(TouchPointMetric.cardPadding)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Button(role: .destructive) {
                            draft.importantDates.removeAll { $0.id == date.id }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.red)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("Delete") + Text(": ") + Text(date.displayName))
                    }
                    SurfaceRowDivider()
                }
                Button {
                    addingDate = true
                } label: {
                    Label("Add important date", systemImage: "calendar.badge.plus")
                }
                .buttonStyle(TouchPointTertiaryButtonStyle())
                .padding(TouchPointMetric.cardPadding)
            }
            Text("Dates repeat every year. The year is intentionally not stored.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, TouchPointMetric.cardPadding)
        }
    }

    private var languageOptionsForDraft: [String] {
        languageOptions.contains { $0.caseInsensitiveCompare(draft.preferredLanguage) == .orderedSame }
            ? languageOptions
            : [draft.preferredLanguage] + languageOptions
    }

    private func timeZoneDisplayName(_ identifier: String) -> String {
        let name = TimeZone(identifier: identifier)?.localizedName(for: .generic, locale: .current)
        return name ?? identifier.replacingOccurrences(of: "_", with: " ")
    }

    private var newImportantDate: ImportantDate {
        let components = Calendar.current.dateComponents([.month, .day], from: .now)
        return ImportantDate(
            occasion: .birthday,
            month: components.month ?? 1,
            day: components.day ?? 1
        )
    }

    private func save() {
        guard canSave else { return }
        var personToSave = draft
        personToSave.firstName = personToSave.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        personToSave.preferredName = personToSave.preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
        personToSave.lastName = personToSave.lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        personToSave.email = personToSave.email.trimmingCharacters(in: .whitespacesAndNewlines)
        personToSave.phone = personToSave.phone.trimmingCharacters(in: .whitespacesAndNewlines)
        personToSave.organization = personToSave.organization.trimmingCharacters(in: .whitespacesAndNewlines)
        personToSave.preferredLanguage = personToSave.preferredLanguage.trimmingCharacters(in: .whitespacesAndNewlines)
        personToSave.notes = personToSave.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        personToSave.tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .reduce(into: [String]()) { result, tag in
                if !result.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) {
                    result.append(tag)
                }
            }

        let didSave = isEditing ? store.updatePerson(personToSave) : store.addPerson(personToSave)
        guard didSave else {
            saveError = store.persistenceError ?? "Touch Point could not save this person."
            return
        }
        dismiss()
    }

    private func deletePerson() {
        guard isEditing else { return }
        guard store.deletePerson(id: draft.id) else {
            saveError = store.persistenceError ?? String(localized: "Changes not saved")
            return
        }
        dismiss()
    }
}

private struct ImportantDateEditorView: View {
    @Environment(AppStore.self) private var store
    let person: Person
    private var node: OccasionNode? { store.occasionNode(for: date) }
    @Environment(\.dismiss) private var dismiss
    @State private var date: ImportantDate
    @State private var showingOccasionPicker = false
    let onSave: (ImportantDate) -> Void

    init(date: ImportantDate, person: Person, onSave: @escaping (ImportantDate) -> Void) {
        self.person = person
        _date = State(initialValue: date)
        self.onSave = onSave
    }

    private var maximumDay: Int {
        var components = DateComponents()
        components.calendar = .current
        components.year = 2000
        components.month = date.month
        guard let monthDate = components.date,
              let range = Calendar.current.range(of: .day, in: .month, for: monthDate) else {
            return 31
        }
        return range.count
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Occasion") {
                    Button { showingOccasionPicker = true } label: {
                        HStack(spacing: 12) {
                            IconTile(systemImage: date.occasion.icon, tint: date.occasion.tint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Occasion")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(node?.title ?? date.occasion.title)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens a searchable occasion list")
                    TextField(date.occasion == .custom
                        ? String(localized: "Custom occasion name")
                        : String(localized: "Custom name (optional)"), text: Binding(
                        get: { date.customName ?? "" },
                        set: { date.customName = $0.isEmpty ? nil : $0 }
                    ))
                    if date.occasion == .custom && date.customName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                        Text("A custom occasion needs a name.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    if let template = store.attachedTemplate(for: node) {
                        LabeledContent("Template", value: template.title)
                        Text("Saving this person will automatically plan an annual greeting using this template.")
                    } else {
                        Text("Attach a template in Occasions to automatically plan a greeting when adding this date.")
                    }
                }
                Section("Annual date") {
                    Picker("Month", selection: $date.month) {
                        ForEach(1...12, id: \.self) { month in
                            Text(Calendar.current.monthSymbols[month - 1]).tag(month)
                        }
                    }
                    Picker("Day", selection: $date.day) {
                        ForEach(1...maximumDay, id: \.self) { day in
                            Text(day.formatted()).tag(day)
                        }
                    }
                }
                .disabled(node?.dateRule == .calendar)
            }
            .navigationTitle("Important date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmedName = date.customName?.trimmingCharacters(in: .whitespacesAndNewlines)
                        date.customName = trimmedName?.isEmpty == false ? trimmedName : nil
                        onSave(date)
                    }
                    .disabled(
                        date.occasion == .custom
                            && date.customName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false
                    )
                }
            }
            .onChange(of: date.month) {
                date.day = min(date.day, maximumDay)
            }
            .sheet(isPresented: $showingOccasionPicker) {
                OccasionLibraryPicker(selectionID: node?.id) { selected in
                    date.occasion = selected.occasion
                    date.occasionID = selected.id
                    date.customName = selected.builtInOccasion == .custom ? nil : selected.title
                    if let next = store.nextOccasionDate(selected, for: person) {
                        var calendar = Calendar(identifier: .gregorian)
                        calendar.timeZone = TimeZone(identifier: person.timeZoneIdentifier) ?? .current
                        date.month = calendar.component(.month, from: next)
                        date.day = calendar.component(.day, from: next)
                    }
                }
            }
        }
    }
}

private struct TimeZonePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: String
    @State private var query = ""

    private var zones: [String] {
        let all = TimeZone.knownTimeZoneIdentifiers.sorted {
            TimeZonePickerView.displayName(for: $0).localizedStandardCompare(TimeZonePickerView.displayName(for: $1)) == .orderedAscending
        }
        guard !query.isEmpty else { return all }
        return all.filter {
            $0.localizedCaseInsensitiveContains(query)
                || Self.displayName(for: $0).localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List(zones, id: \.self) { identifier in
                Button {
                    selection = identifier
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Self.displayName(for: identifier))
                            Text(identifier)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if selection == identifier {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
            }
            .searchable(text: $query, prompt: "City or time zone")
            .navigationTitle("Time zone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private static func displayName(for identifier: String) -> String {
        let zone = TimeZone(identifier: identifier)
        return zone?.localizedName(for: .generic, locale: .current)
            ?? identifier.replacingOccurrences(of: "_", with: " ")
    }
}
