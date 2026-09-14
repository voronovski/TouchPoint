import Foundation

@main
struct PersonContactRegression {
    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        precondition(condition(), message)
    }

    static func main() throws {
        let child = Person(name: "Child", relationship: .family,
                           importantDates: [ImportantDate(occasion: .birthday, month: 12, day: 13)])
        let whitespace = Person(name: "Blank contact", email: " \n\t", phone: " \t\n", relationship: .friend)
        let unnamed = Person(name: " \n\t", phone: "123", relationship: .friend)
        let phoneOnly = Person(name: "Phone only", phone: " +1 415 555 0100 ", relationship: .friend)
        let emailOnly = Person(name: "Email only", email: " person@example.com ", relationship: .friend)
        let both = Person(name: "Both", email: "both@example.com", phone: "+1 415 555 0101", relationship: .friend)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("touchpoint-contact-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let persistenceURL = directory.appendingPathComponent("store.json")
        let store = AppStore(people: [], events: [], templates: [], persistenceURL: persistenceURL)

        expect(!store.addPerson(unnamed), "A name is required even with contact details")
        expect(store.people.isEmpty && store.lastModifiedAt == .distantPast,
               "Rejected additions must not mutate the store")
        expect(!FileManager.default.fileExists(atPath: persistenceURL.path), "Rejected additions must not create a file")
        expect(store.addPerson(child), "A child's name and date must save without contacts or templates")
        expect(store.persistenceError == nil, "Successful saving clears validation errors")
        expect(store.people[0].preferredContactMethod == .reminder, "No contacts means reminder only")
        expect(store.availableContactMethods(for: child) == [.reminder], "No unusable methods are offered")
        expect(store.events.count == 1 && store.events[0].method == .reminder, "A date creates a reminder without a template")
        let reminder = store.events[0]
        expect(reminder.recurrence == .annual && reminder.sourceImportantDateID == child.importantDates[0].id,
               "Reminder retains the annual date link")
        expect(reminder.sourceTemplateID == nil, "A template is optional")
        expect(store.updatePerson(child) && store.events.count == 1 && store.events[0].id == reminder.id,
               "Saving the same person again does not duplicate reminders")
        expect(store.addPerson(whitespace), "Blank contacts are optional")
        expect(store.people.last?.preferredContactMethod == .reminder, "Whitespace contacts use reminders")
        expect(store.addPerson(phoneOnly) && store.addPerson(emailOnly) && store.addPerson(both), "Phone and email remain supported")
        var edited = both; edited.phone = ""; edited.email = ""
        expect(store.updatePerson(edited), "All contact details can be removed")
        expect(store.people.last?.preferredContactMethod == .reminder, "Editing also stores reminder-only preference")

        let previousPeople = store.people
        let previousEvents = store.events
        let previousModifiedAt = store.lastModifiedAt
        let previousData = try Data(contentsOf: persistenceURL)
        expect(store.addPeople([whitespace, unnamed]) == 0, "Batch creation rejects empty names atomically")
        expect(store.people == previousPeople && store.events == previousEvents && store.lastModifiedAt == previousModifiedAt,
               "A rejected batch must leave all state intact")
        let dataAfterRejection = try Data(contentsOf: persistenceURL)
        expect(dataAfterRejection == previousData, "A rejected batch must not change the saved file")
        let batch = AppStore(people: [], events: [], templates: [])
        expect(batch.addPeople([child, whitespace, phoneOnly, emailOnly]) == 4, "Import accepts people without contacts")
        expect(batch.events.count == 1 && batch.people[0].preferredContactMethod == .reminder, "Import also creates date reminders")

        let failure = AppStore(people: [], events: [], templates: [], allowsEphemeralPersistence: false)
        expect(!failure.addPerson(child) && failure.people.isEmpty && failure.events.isEmpty,
               "Failed writes roll back both person and reminder")
        expect(failure.addPeople([child, whitespace]) == 0 && failure.people.isEmpty && failure.events.isEmpty,
               "A failed batch rolls back its reminders too")
        let archive = try store.exportSnapshot()
        let restored = AppStore(people: [], events: [], templates: [])
        expect(restored.importSnapshot(archive) && restored.people == store.people && restored.events == store.events,
               "Name-only people and reminders survive backup restoration")
        expect(store.completeGreeting(id: reminder.id), "Reminder can be completed")
        expect(store.events.count == 2 && store.events.last?.sourceImportantDateID == reminder.sourceImportantDateID,
               "Completing an annual reminder creates next year's reminder")
        print("PASS: name-only people, optional contacts, date reminders, recurrence, imports, deduplication, persistence and rollback")
    }
}
