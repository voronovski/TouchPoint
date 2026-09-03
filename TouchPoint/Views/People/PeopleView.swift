import SwiftUI

struct PeopleView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppPreferences.self) private var preferences
    @State private var query = ""
    @State private var showingNewPerson = false

    private var filteredPeople: [Person] {
        let matches = query.isEmpty ? store.people : store.people.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.email.localizedCaseInsensitiveContains(query)
                || $0.organization.localizedCaseInsensitiveContains(query)
        }

        return matches.sorted {
            let leftRank = preferences.mode.relationshipRank($0.relationship)
            let rightRank = preferences.mode.relationshipRank($1.relationship)
            if leftRank != rightRank {
                return leftRank < rightRank
            }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            List {
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
                    Button {
                        showingNewPerson = true
                    } label: {
                        Label("Add person", systemImage: "person.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewPerson) {
                PersonEditorView(
                    person: nil,
                    defaultRelationship: preferences.mode.defaultRelationship
                )
            }
        }
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

private struct PersonDetailView: View {
    @Environment(AppStore.self) private var store
    let personID: UUID
    @State private var editingPerson: Person?

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

                Section("Important dates") {
                    if person.importantDates.isEmpty {
                        Text("No important dates yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(person.importantDates.sorted(by: importantDateSort)) { importantDate in
                            Label {
                                HStack {
                                    Text(importantDate.occasion.title)
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
                                        Text(event.occasion.title)
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") { editingPerson = person }
                }
            }
        }
        .sheet(item: $editingPerson) { person in
            PersonEditorView(person: person)
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

    private let isEditing: Bool
    private let supportedTimeZones = [
        "America/Los_Angeles",
        "America/Denver",
        "America/Chicago",
        "America/New_York",
        "Europe/London",
        "Europe/Paris",
        "Asia/Tokyo",
        "Australia/Sydney"
    ]

    init(person: Person?, defaultRelationship: Relationship = .client) {
        let draft = person ?? Person(name: "", relationship: defaultRelationship)
        _draft = State(initialValue: draft)
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
        return preferences.mode == .professional && draft.relationship == .client
            ? "New client"
            : "New person"
    }

    private var saveTitle: String {
        if isEditing {
            return "Save"
        }
        return preferences.mode == .professional && draft.relationship == .client
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
                    TextField("Preferred language", text: $draft.preferredLanguage)
                    Picker("Time zone", selection: $draft.timeZoneIdentifier) {
                        ForEach(timeZoneOptions, id: \.self) { identifier in
                            Text(identifier.replacingOccurrences(of: "_", with: " ")).tag(identifier)
                        }
                    }
                }

                Section {
                    ForEach(draft.importantDates) { importantDate in
                        Button {
                            editingDate = importantDate
                        } label: {
                            HStack(spacing: 12) {
                                IconTile(systemImage: importantDate.occasion.icon, tint: importantDate.occasion.tint)
                                Text(importantDate.occasion.title)
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
        }
    }

    private var timeZoneOptions: [String] {
        if supportedTimeZones.contains(draft.timeZoneIdentifier) {
            return supportedTimeZones
        }
        return [draft.timeZoneIdentifier] + supportedTimeZones
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

        if isEditing {
            store.updatePerson(draft)
        } else {
            store.addPerson(draft)
        }
        dismiss()
    }
}

private struct ImportantDateEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var date: ImportantDate
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
                    Picker("Occasion", selection: $date.occasion) {
                        ForEach(Occasion.contactSpecificCases) { occasion in
                            Text(occasion.title).tag(occasion)
                        }
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
                    Button("Save") { onSave(date) }
                }
            }
            .onChange(of: date.month) {
                date.day = min(date.day, maximumDay)
            }
        }
    }
}
