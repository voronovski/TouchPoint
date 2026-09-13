import Foundation

@main
struct PersonNamesRegression {
    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        precondition(condition(), message)
    }

    static func main() throws {
        let legacy = try JSONDecoder().decode(Person.self, from: Data(#"{"name":"Mary Jane van Buren","email":"mary@example.com"}"#.utf8))
        expect(legacy.firstName == "Mary" && legacy.lastName == "Jane van Buren", "Migration must preserve every part of a legacy name")
        expect(legacy.preferredName.isEmpty && legacy.name == "Mary Jane van Buren", "Legacy full-name tokens must remain compatible")
        let mononym = try JSONDecoder().decode(Person.self, from: Data(#"{"name":"Prince"}"#.utf8))
        expect(mononym.firstName == "Prince" && mononym.lastName.isEmpty && mononym.displayName == "Prince", "Single names must remain valid")
        var person = Person(firstName: "Mary Jane", preferredName: "MJ", lastName: "van Buren", relationship: .friend)
        expect(person.displayName == "Mary Jane \"MJ\" van Buren", "Preferred name must appear between first and last in quotes")
        let restored = try JSONDecoder().decode(Person.self, from: JSONEncoder().encode(person))
        expect(restored == person, "Structured names must round-trip without re-splitting compound first names")
        var template = GreetingTemplate(title: "Names", occasions: [.birthday], body: "{{first_name}}|{{preferred_name}}|{{last_name}}|{{name}}", emailSubject: "For {{preferred_name}} {{last_name}}")
        expect(template.validationErrors.isEmpty, "All name tokens must be offered and accepted")
        let store = AppStore(people: [person], events: [], templates: [template])
        expect(store.renderedBody(for: template, person: person, occasion: .birthday, senderName: "") == "Mary Jane|MJ|van Buren|Mary Jane van Buren", "Each token must use its whole stored field")
        expect(store.renderedEmailSubject(for: template, person: person, occasion: .birthday, senderName: "") == "For MJ van Buren", "Name tokens must render in email subjects")
        let archive = try store.exportSnapshot()
        let imported = AppStore(people: [], events: [], templates: [])
        expect(imported.importSnapshot(archive) && imported.people.first == person, "Backup import must preserve all name fields")
        person.preferredName = "   "
        expect(person.displayName == "Mary Jane van Buren", "Blank preferred names must omit quotes and extra spaces")
        template.body = "{{preferred_name}}"
        expect(store.renderedBody(for: template, person: person, occasion: .birthday, senderName: "").isEmpty, "An optional blank token must resolve to empty")
        person.firstName = ""
        person.lastName = "Ng"
        expect(person.displayName == "Ng", "Missing first name must not create a leading space")
        print("Person names regression tests passed")
    }
}
