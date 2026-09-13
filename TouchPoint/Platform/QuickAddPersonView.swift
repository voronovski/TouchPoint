import SwiftUI

struct QuickAddPersonView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var firstName = ""
    @State private var preferredName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var relationship: Relationship = .friend
    @State private var validationMessage: String?

    private var canSave: Bool {
        (!firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            && Person.hasContactInfo(phone: phone, email: email)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Person") {
                    TextField("First name", text: $firstName)
                        .textContentType(.givenName)
                    TextField("Preferred name (optional)", text: $preferredName)
                        .textContentType(.nickname)
                    TextField("Last name", text: $lastName)
                        .textContentType(.familyName)
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Phone", text: $phone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                    Picker("Relationship", selection: $relationship) {
                        ForEach(Relationship.allCases) { relationship in
                            Text(relationship.title).tag(relationship)
                        }
                    }
                }
                Section {
                    Text("Enter a phone number or email address.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("You can add birthdays and other important dates later from People.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .alert("Person not saved", isPresented: Binding(
                get: { validationMessage != nil },
                set: { if !$0 { validationMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(validationMessage ?? "")
            }
        }
    }

    private func save() {
        let trimmedFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFirstName.isEmpty || !trimmedLastName.isEmpty else {
            validationMessage = "Enter a name to add this person."
            return
        }
        let didSave = store.addPerson(Person(
            firstName: trimmedFirstName,
            preferredName: preferredName.trimmingCharacters(in: .whitespacesAndNewlines),
            lastName: trimmedLastName,
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
            relationship: relationship
        ))
        guard didSave else {
            validationMessage = store.persistenceError ?? "Touch Point could not save this person."
            return
        }
        dismiss()
    }
}
