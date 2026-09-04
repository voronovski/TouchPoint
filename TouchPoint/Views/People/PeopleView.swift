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
            $0.name.localizedCaseInsensitiveContains(query)
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
        for person in imported {
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
    }

    private func normalizedContactKey(name: String, email: String, phone: String) -> String {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !normalizedEmail.isEmpty { return "email:\(normalizedEmail)" }
        let normalizedPhone = phone.filter(\.isNumber)
        if !normalizedPhone.isEmpty { return "phone:\(normalizedPhone)" }
        return "name:\(name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
    }
}

private struct PersonListRow: View {
    let person: Person

    var body: some View {
        HStack(spacing: 12) {
            PersonAvatar(person: person)
            VStack(alignment: .leading, spacing: 3) {
                Text(person.name)
                    .font(.subheadline.weight(.semibold))
                Text(person.organization.isEmpty ? person.relationship.title : person.organization)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}

private struct FlowTagView: View {
    let tags: [String]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
    }
}

private struct PersonDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let personID: UUID
    @State private var editingPerson: Person?
    @State private var showingDeleteConfirmation = false

    private var person: Person? {
        store.people.first { $0.id == personID }
    }

    private var events: [GreetingEvent] {
        store.events.filter { $0.personID == personID }.sorted { $0.date < $1.date }
    }

    var body: some View {
        List {
            if let person {
                Section {
                    HStack(spacing: 14) {
                        PersonAvatar(person: person, size: 54)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(person.name).font(.headline)
                            Text(person.organization.isEmpty ? person.relationship.title : person.organization)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Contact") {
                    if !person.phone.isEmpty {
                        Label(person.phone, systemImage: "phone")
                    }
                    if !person.email.isEmpty {
                        Label(person.email, systemImage: "envelope")
                    }
                    Label(person.preferredContactMethod.title, systemImage: person.preferredContactMethod.icon)
                    Label(person.preferredLanguage, systemImage: "character.bubble")
                    Label(person.timeZoneIdentifier.replacingOccurrences(of: "_", with: " "), systemImage: "globe")
                }

                if !person.notes.isEmpty || !person.tags.isEmpty {
                    Section("Context") {
                        if !person.notes.isEmpty {
                            Text(person.notes)
                                .font(.subheadline)
                        }
                        if !person.tags.isEmpty {
                            FlowTagView(tags: person.tags)
                        }
                    }
                }

                Section("Important dates") {
                    if person.importantDates.isEmpty {
                        Text("No important dates yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(person.importantDates.sorted(by: importantDateSort)) { importantDate in
                            Label {
                                HStack {
                                    Text(importantDate.displayName)
                                    Spacer()
                                    Text(importantDate.formatted)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: importantDate.occasion.icon)
                                    .foregroundStyle(importantDate.occasion.tint)
                            }
                        }
                    }
                }

                Section("Planned greetings") {
                    if events.isEmpty {
                        Text("No greetings planned")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(events) { event in
                            NavigationLink {
                                GreetingDetailView(eventID: event.id)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(event.displayName)
                                        Text(event.date.touchPointDay(in: person.timeZoneIdentifier))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    StatusPill(status: store.status(for: event))
                                }
                            }
                        }
                    }
                }
            }
        }
        .overlay {
            if person == nil {
                ContentUnavailableView("Person unavailable", systemImage: "person.slash")
            }
        }
        .navigationTitle(person?.name ?? "Person")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let person {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Edit") { editingPerson = person }
                    Menu {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete person", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(item: $editingPerson) { person in
            PersonEditorView(person: person)
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

    private func deletePerson() {
        guard person != nil else { return }
        if store.deletePerson(id: personID) { dismiss() }
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
        (!draft.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
         !draft.phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
            Form {
                Section("Person") {
                    TextField("Full name", text: $draft.name)
                        .textContentType(.name)
                    TextField("Organization (optional)", text: $draft.organization)
                        .textContentType(.organizationName)
                    Picker("Relationship", selection: $draft.relationship) {
                        ForEach(Relationship.allCases) { relationship in
                            Text(relationship.title).tag(relationship)
                        }
                    }
                }

                Section("Contact") {
                    TextField("Phone", text: $draft.phone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $draft.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    Picker("Preferred method", selection: $draft.preferredContactMethod) {
                        ForEach(ContactMethod.allCases) { method in
                            Label(method.title, systemImage: method.icon).tag(method)
                        }
                    }
                }

                Section("Preferences") {
                    Picker("Preferred language", selection: $draft.preferredLanguage) {
                        ForEach(languageOptionsForDraft, id: \.self) { language in
                            Text(language).tag(language)
                        }
                    }
                    Button {
                        showingTimeZonePicker = true
                    } label: {
                        HStack {
                            Text("Time zone")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(timeZoneDisplayName(draft.timeZoneIdentifier))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Section("Context") {
                    TextEditor(text: $draft.notes)
                        .frame(minHeight: 90)
                        .overlay(alignment: .topLeading) {
                            if draft.notes.isEmpty {
                                Text("Private notes about this person")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .allowsHitTesting(false)
                            }
                        }
                    TextField("Tags (comma separated)", text: $tagsText)
                        .textInputAutocapitalization(.never)
                }

                Section {
                    ForEach(draft.importantDates) { importantDate in
                        Button {
                            editingDate = importantDate
                        } label: {
                            HStack(spacing: 12) {
                                IconTile(systemImage: importantDate.occasion.icon, tint: importantDate.occasion.tint)
                                Text(importantDate.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(importantDate.formatted)
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        draft.importantDates.remove(atOffsets: offsets)
                    }

                    Button {
                        addingDate = true
                    } label: {
                        Label("Add important date", systemImage: "calendar.badge.plus")
                    }
                    .buttonStyle(TouchPointTertiaryButtonStyle())
                } header: {
                    Text("Important dates")
                } footer: {
                    Text("Dates repeat every year. The year is intentionally not stored.")
                }
            }
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
                ImportantDateEditorView(date: newImportantDate) { savedDate in
                    draft.importantDates.append(savedDate)
                    addingDate = false
                }
            }
            .sheet(item: $editingDate) { importantDate in
                ImportantDateEditorView(date: importantDate) { savedDate in
                    guard let index = draft.importantDates.firstIndex(where: { $0.id == savedDate.id }) else { return }
                    draft.importantDates[index] = savedDate
                    editingDate = nil
                }
            }
            .sheet(isPresented: $showingTimeZonePicker) {
                TimeZonePickerView(selection: $draft.timeZoneIdentifier)
            }
            .alert("Person not saved", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError ?? "")
            }
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
        draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.email = draft.email.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.phone = draft.phone.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.organization = draft.organization.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.preferredLanguage = draft.preferredLanguage.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.notes = draft.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .reduce(into: [String]()) { result, tag in
                if !result.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) {
                    result.append(tag)
                }
            }

        let didSave = isEditing ? store.updatePerson(draft) : store.addPerson(draft)
        guard didSave else {
            saveError = store.persistenceError ?? "Touch Point could not save this person."
            return
        }
        dismiss()
    }
}

private struct ImportantDateEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var date: ImportantDate
    @State private var showingOccasionPicker = false
    let onSave: (ImportantDate) -> Void

    init(date: ImportantDate, onSave: @escaping (ImportantDate) -> Void) {
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
                                Text(date.occasion.title)
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
                    if date.occasion == .custom {
                        Text("A custom occasion needs a name.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
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
                OccasionPickerSheet(
                    selection: [date.occasion],
                    options: Occasion.contactSpecificCases,
                    mode: .single
                ) { selection in
                    if let selected = selection.first { date.occasion = selected }
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
