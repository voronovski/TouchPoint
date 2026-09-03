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
        picker.displayedPropertyKeys = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
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
            let email = contact.emailAddresses.first?.value as String? ?? ""
            let phone = contact.phoneNumbers.first?.value.stringValue ?? ""
            let relationship: Relationship = .friend
            let method: ContactMethod = !phone.isEmpty ? .sms : (!email.isEmpty ? .email : .reminder)
            return Person(
                name: fullName.isEmpty ? "Unnamed contact" : fullName,
                email: email,
                phone: phone,
                organization: contact.organizationName,
                relationship: relationship,
                preferredContactMethod: method
            )
        }
    }
}
