import SwiftUI

struct PeopleView: View {
    @Environment(AppStore.self) private var store
    @State private var query = ""
    @State private var showingNewPerson = false

    private var filteredPeople: [Person] {
        guard !query.isEmpty else { return store.people }
        return store.people.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.email.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredPeople) { person in
                NavigationLink {
                    PersonDetailView(person: person)
                } label: {
                    HStack(spacing: 12) {
                        PersonAvatar(person: person)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(person.name)
                                .font(.subheadline.weight(.semibold))
                            Text(person.relationship.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
            .overlay {
                if filteredPeople.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(text: $query, prompt: "Name or email")
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
                NewPersonView()
            }
        }
    }
}

private struct PersonDetailView: View {
    @Environment(AppStore.self) private var store
    let person: Person

    private var events: [GreetingEvent] {
        store.events.filter { $0.personID == person.id }.sorted { $0.date < $1.date }
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    PersonAvatar(person: person, size: 54)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(person.name).font(.headline)
                        Text(person.relationship.rawValue)
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
                Label(person.preferredLanguage, systemImage: "character.bubble")
                Label(person.timeZoneIdentifier.replacingOccurrences(of: "_", with: " "), systemImage: "globe")
            }

            Section("Important dates") {
                if events.isEmpty {
                    Text("No important dates yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(events) { event in
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.occasion.rawValue)
                                Text(event.date.touchPointDay)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: event.occasion.icon)
                                .foregroundStyle(event.occasion.tint)
                        }
                    }
                }
            }
        }
        .navigationTitle(person.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct NewPersonView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var relationship: Relationship = .client

    var body: some View {
        NavigationStack {
            Form {
                Section("Person") {
                    TextField("Full name", text: $name)
                        .textContentType(.name)
                    Picker("Relationship", selection: $relationship) {
                        ForEach(Relationship.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                }

                Section("Contact") {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Phone", text: $phone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle("New person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        store.addPerson(
                            Person(
                                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                email: email,
                                phone: phone,
                                relationship: relationship
                            )
                        )
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
