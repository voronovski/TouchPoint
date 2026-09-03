import SwiftUI

struct NewGreetingView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var personID: UUID?
    @State private var occasion: Occasion = .birthday
    @State private var customName = ""
    @State private var date = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
    @State private var recurrence: EventRecurrence = .oneTime
    @State private var method: ContactMethod = .reminder
    @State private var message = ""
    @State private var saveError: String?

    private var selectedPerson: Person? {
        store.people.first { $0.id == personID }
    }

    private var availableMethods: [ContactMethod] {
        selectedPerson.map(store.availableContactMethods(for:)) ?? [.reminder]
    }

    var body: some View {
        NavigationStack {
            Form {
                if store.people.isEmpty {
                    ContentUnavailableView(
                        "Add a person first",
                        systemImage: "person.badge.plus",
                        description: Text("A greeting needs someone to contact. Add them in People, then return here.")
                    )
                } else {
                    Section("Person") {
                        Picker("Person", selection: $personID) {
                            Text("Choose a person").tag(UUID?.none)
                            ForEach(store.people.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) { person in
                                Text(person.name).tag(Optional(person.id))
                            }
                        }
                    }

                    Section("Occasion") {
                        Picker("Type", selection: $occasion) {
                            ForEach(Occasion.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                        TextField(
                            occasion == .custom
                                ? String(localized: "Custom occasion name")
                                : String(localized: "Custom name (optional)"),
                            text: $customName
                        )
                        if occasion == .custom {
                            Text("A custom occasion needs a name.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section("Schedule") {
                        DatePicker("Date and time", selection: $date)
                        Picker("Recurrence", selection: $recurrence) {
                            ForEach(EventRecurrence.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                        Picker("Contact method", selection: $method) {
                            ForEach(availableMethods) { option in
                                Label(option.title, systemImage: option.icon).tag(option)
                            }
                        }
                    }

                    Section("Message") {
                        TextEditor(text: $message)
                            .frame(minHeight: 120)
                        Text("Leave this blank to start with the best matching template. You can edit it later.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("New greeting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .disabled(
                            personID == nil
                                || store.people.isEmpty
                                || (occasion == .custom && normalizedCustomName == nil)
                        )
                }
            }
            .onChange(of: personID) {
                guard let person = selectedPerson else { return }
                method = store.resolvedContactMethod(for: person, preferred: person.preferredContactMethod) ?? .reminder
            }
            .alert("Greeting not saved", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError ?? "")
            }
        }
    }

    private func save() {
        guard let person = selectedPerson else { return }
        guard occasion != .custom || normalizedCustomName != nil else { return }
        let resolvedMethod = store.resolvedContactMethod(for: person, preferred: method) ?? .reminder
        let template = store.resolveTemplate(for: person, occasion: occasion, channel: resolvedMethod)
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = trimmedMessage.isEmpty
            ? store.renderedBody(
                for: template,
                person: person,
                occasion: occasion,
                date: date,
                occasionName: normalizedCustomName
            )
            : trimmedMessage
        let event = GreetingEvent(
            personID: person.id,
            occasion: occasion,
            date: date,
            method: resolvedMethod,
            status: .planned,
            message: body,
            subject: template.flatMap {
                store.renderedEmailSubject(
                    for: $0,
                    person: person,
                    occasion: occasion,
                    date: date,
                    occasionName: normalizedCustomName
                )
            },
            sourceTemplateID: template?.id,
            sourceTemplateRevision: template?.revisionNumber,
            customName: normalizedCustomName,
            recurrence: recurrence
        )
        guard store.addGreeting(event) else {
            saveError = store.persistenceError ?? "Touch Point could not save this greeting."
            return
        }
        dismiss()
    }

    private var normalizedCustomName: String? {
        let trimmed = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
