import Foundation

@main
struct PersonContactRegression {
    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        precondition(condition(), message)
    }

    static func main() throws {
        let empty = Person(name: "No contact", relationship: .friend)
        let whitespace = Person(name: "Blank contact", email: " \n\t", phone: " \t\n", relationship: .friend)
        let phoneOnly = Person(name: "Phone only", phone: " +1 415 555 0100 ", relationship: .friend)
        let emailOnly = Person(name: "Email only", email: " person@example.com ", relationship: .friend)
        let both = Person(name: "Both", email: "both@example.com", phone: "+1 415 555 0101", relationship: .friend)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("touchpoint-contact-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let persistenceURL = directory.appendingPathComponent("store.json")
        let store = AppStore(people: [], events: [], templates: [], persistenceURL: persistenceURL)

        expect(!store.addPerson(empty), "Adding a person without either contact must fail")
        expect(!store.addPerson(whitespace), "Whitespace must not satisfy the contact requirement")
        expect(store.people.isEmpty && store.lastModifiedAt == .distantPast,
               "Rejected additions must not mutate or persist the store")
        expect(!FileManager.default.fileExists(atPath: persistenceURL.path),
               "Rejected additions must not create a file")
        expect(store.persistenceError != nil, "Rejected additions must explain the requirement")
        expect(store.addPerson(phoneOnly), "Phone alone must be sufficient")
        expect(store.persistenceError == nil, "Successful saving must clear the prior validation error")
        expect(store.addPerson(emailOnly), "Email alone must be sufficient")
        expect(store.addPerson(both), "Providing both must be supported")

        let previousPeople = store.people
        let previousModifiedAt = store.lastModifiedAt
        let previousData = try Data(contentsOf: persistenceURL)
        expect(store.addPeople([Person(name: "Valid", email: "valid@example.com", relationship: .friend), whitespace]) == 0,
               "Batch creation must reject contacts without either field")
        expect(store.people == previousPeople && store.lastModifiedAt == previousModifiedAt,
               "A rejected mixed batch must remain atomic")
        let dataAfterRejection = try Data(contentsOf: persistenceURL)
        expect(dataAfterRejection == previousData, "A rejected batch must not change the saved file")
        let batch = AppStore(people: [], events: [], templates: [])
        expect(batch.addPeople([phoneOnly, emailOnly, both]) == 3, "Valid batches must add everyone")
        expect(batch.people == [phoneOnly, emailOnly, both], "Batch contents must be preserved")

        let failure = AppStore(people: [], events: [], templates: [], allowsEphemeralPersistence: false)
        expect(!failure.addPerson(phoneOnly) && failure.people.isEmpty,
               "A failed disk write must still roll back a valid individual addition")
        expect(failure.addPeople([phoneOnly, emailOnly]) == 0 && failure.people.isEmpty,
               "A failed disk write must still roll back the entire valid batch")

        // Existing archives may predate the creation requirement; recovery must preserve them.
        let legacy = AppStore(people: [empty], events: [], templates: [])
        let archive = try legacy.exportSnapshot()
        let restored = AppStore(people: [], events: [], templates: [])
        expect(restored.importSnapshot(archive) && restored.people == [empty],
               "Existing people must remain recoverable from legacy backups")
        print("PASS: required contact, whitespace, phone/email alternatives, atomic batches, persistence rollback, legacy recovery")
    }
}
