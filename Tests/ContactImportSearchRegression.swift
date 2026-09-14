import Contacts
import Foundation

@main
struct ContactImportSearchRegression {
    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        precondition(condition(), message)
    }

    static func main() {
        let contact = CNMutableContact()
        contact.givenName = "Алексей"
        contact.middleName = "Иванович"
        contact.familyName = "Петров"
        contact.nickname = "Лёша"
        contact.organizationName = "Café Studio"
        contact.phoneNumbers = [
            CNLabeledValue(label: CNLabelHome, value: CNPhoneNumber(stringValue: "+7 (999) 123-45-67")),
            CNLabeledValue(label: CNLabelWork, value: CNPhoneNumber(stringValue: "+1 (415) 555-0199"))
        ]
        contact.emailAddresses = [
            CNLabeledValue(label: CNLabelHome, value: "alex@example.com" as NSString),
            CNLabeledValue(label: CNLabelWork, value: "petrov@studio.test" as NSString)
        ]
        let entry = ContactImportEntry(contact: contact)
        for query in ["", "  \n ", "алекс", "ПЕТРОВ", " Петров   Алексей ", "иванович",
                      "Лёша", "cafe", "STUDIO", "PETROV@STUDIO.TEST", "alex@example",
                      "9991234567", "+1 415 555 0199", "5550199", "123-45-67"] {
            expect(entry.matches(query), "Expected a match for: \(query)")
        }
        for query in ["Мария", "Петров Мария", "0000000", "nobody@test.com", "999 wrong"] {
            expect(!entry.matches(query), "Unexpected match for: \(query)")
        }
        expect(entry.person.firstName == "Алексей Иванович", "Import preserves structured names")
        expect(entry.person.lastName == "Петров", "Import preserves last name")
        expect(entry.person.preferredName == "Лёша", "Import preserves nickname")
        expect(entry.person.phone == "+7 (999) 123-45-67", "Import keeps the existing primary-phone behavior")
        expect(entry.person.email == "alex@example.com", "Import keeps the existing primary-email behavior")
        expect(entry.person.preferredContactMethod == .sms, "Phone contacts prefer SMS")
        let unnamed = ContactImportEntry(contact: CNMutableContact())
        expect(!unnamed.person.name.isEmpty, "Nameless contacts have a display fallback")
        expect(unnamed.person.preferredContactMethod == .reminder, "No contact details means reminders")
        print("PASS: contact import search, Cyrillic, case, diacritics, multiple words, all phones/emails, formatted numbers, and import mapping")
    }
}
