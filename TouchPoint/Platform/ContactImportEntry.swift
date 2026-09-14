import Contacts
import Foundation

/// A transient phone-book entry. Only explicitly selected entries become saved people.
struct ContactImportEntry: Identifiable {
    let id: String
    let person: Person
    private let searchText: String
    private let phoneDigits: [String]

    init(contact: CNContact) {
        id = contact.identifier
        person = Self.person(from: contact)
        let phones = contact.phoneNumbers.map { $0.value.stringValue }
        let emails = contact.emailAddresses.map { $0.value as String }
        searchText = ([person.name, contact.givenName, contact.middleName,
                       contact.familyName, contact.nickname, contact.organizationName]
                      + phones + emails).joined(separator: " ")
        phoneDigits = phones.map { $0.filter(\.isNumber) }
    }

    func matches(_ query: String) -> Bool {
        let terms = query.split(whereSeparator: \.isWhitespace)
        if terms.isEmpty { return true }
        if terms.allSatisfy({ searchText.localizedStandardContains(String($0)) }) { return true }
        // Ignore formatting when searching a phone number, but not letters in a name.
        let digits = query.filter(\.isNumber)
        return !digits.isEmpty
            && query.allSatisfy { $0.isNumber || $0.isWhitespace || "+()- .".contains($0) }
            && phoneDigits.contains { $0.contains(digits) }
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
            name: fullName.isEmpty ? String(localized: "Unnamed contact") : fullName,
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

/// Contact enumeration is synchronous, so keep it off the UI actor.
actor PhoneBookLoader {
    func load() throws -> [ContactImportEntry] {
        let keys: [CNKeyDescriptor] = [
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactMiddleNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactNicknameKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor
        ]
        let request = CNContactFetchRequest(keysToFetch: keys)
        request.sortOrder = .userDefault
        var entries: [ContactImportEntry] = []
        try CNContactStore().enumerateContacts(with: request) { contact, _ in
            entries.append(ContactImportEntry(contact: contact))
        }
        return entries
    }
}
