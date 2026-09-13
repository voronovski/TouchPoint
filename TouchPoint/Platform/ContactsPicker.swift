@preconcurrency import Contacts
@preconcurrency import ContactsUI
import SwiftUI

/// Presents Apple's system contact picker without requesting full address-book access.
/// The picker returns only the contacts the user explicitly selects.
struct ContactsPicker: UIViewControllerRepresentable {
    let onSelect: ([Person]) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.predicateForEnablingContact = NSPredicate(
            format: "phoneNumbers.@count > 0 OR emailAddresses.@count > 0"
        )
        picker.displayedPropertyKeys = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactNicknameKey,
            CNContactOrganizationNameKey,
            CNContactPhoneNumbersKey,
            CNContactEmailAddressesKey
        ]
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onSelect: ([Person]) -> Void
        let onCancel: () -> Void

        init(onSelect: @escaping ([Person]) -> Void, onCancel: @escaping () -> Void) {
            self.onSelect = onSelect
            self.onCancel = onCancel
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            onCancel()
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            onSelect([Self.person(from: contact)])
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            let people = MainActor.assumeIsolated {
                var result: [Person] = []
                result.reserveCapacity(contacts.count)
                for contact in contacts {
                    result.append(Self.person(from: contact))
                }
                return result
            }
            onSelect(people)
        }

        private static func person(from contact: CNContact) -> Person {
            let fullName = CNContactFormatter.string(from: contact, style: .fullName)
                ?? [contact.givenName, contact.familyName]
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
            let email = contact.emailAddresses
                .map { ($0.value as String).trimmingCharacters(in: .whitespacesAndNewlines) }
                .first { !$0.isEmpty } ?? ""
            let phone = contact.phoneNumbers
                .map { $0.value.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first { !$0.isEmpty } ?? ""
            let relationship: Relationship = .friend
            let method: ContactMethod = !phone.isEmpty ? .sms : (!email.isEmpty ? .email : .reminder)
            let givenNames = [contact.givenName, contact.middleName].filter { !$0.isEmpty }.joined(separator: " ")
            let hasStructuredName = !givenNames.isEmpty || !contact.familyName.isEmpty
            return Person(
                name: fullName.isEmpty ? "Unnamed contact" : fullName,
                firstName: hasStructuredName ? givenNames : nil,
                preferredName: contact.nickname,
                lastName: hasStructuredName ? contact.familyName : nil,
                email: email,
                phone: phone,
                organization: contact.organizationName,
                relationship: relationship,
                preferredContactMethod: method
            )
        }
    }
}
