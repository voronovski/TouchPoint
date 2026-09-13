import Foundation

@main
struct CommunicationStopRegression {
    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        precondition(condition(), message)
    }

    static func main() throws {
        let person = Person(name: "Test recipient", relationship: .friend,
                            importantDates: [ImportantDate(occasion: .birthday, month: 12, day: 10)])
        let other = Person(name: "Other recipient", relationship: .friend,
                           importantDates: [ImportantDate(occasion: .birthday, month: 12, day: 10)])
        func greeting(_ owner: Person, status: GreetingStatus = .planned, date: Date = .now) -> GreetingEvent {
            GreetingEvent(personID: owner.id, occasion: .birthday, date: date,
                          method: .reminder, status: status, message: "Hello", recurrence: .annual)
        }
        let future = greeting(person, date: .now.addingTimeInterval(86_400))
        let overdue = greeting(person, date: .now.addingTimeInterval(-86_400))
        let ready = greeting(person, status: .ready)
        let completed = greeting(person, status: .completed)
        let skipped = greeting(person, status: .skipped)
        let unrelated = greeting(other)
        let originalEvents = [future, overdue, ready, completed, skipped, unrelated]
        let store = AppStore(people: [person, other], events: originalEvents, templates: [])
        expect(store.setCommunicationStopped(true, personID: person.id), "Stopping must save")
        expect(store.people[0].communicationStopped, "The preference must be enabled")
        expect(Set(store.events.map(\.id)) == Set([completed.id, skipped.id, unrelated.id]),
               "Remove the entire pending queue, preserving history and other people")
        expect(store.contactablePeople.map(\.id) == [other.id], "Stopped recipients must not be selectable")
        expect(!store.addGreeting(future), "Manual planning must reject a stopped recipient")
        expect(!store.restoreGreeting(id: skipped.id), "Restoring skipped greetings must be blocked")
        var edited = skipped
        edited.status = .planned
        expect(!store.updateGreeting(edited), "Editing must not reintroduce a queued greeting")
        expect(!store.rescheduleGreeting(id: skipped.id, date: .now), "Rescheduling must be blocked")
        expect(store.schedulableGreetingCount(personIDs: [person.id], occasions: [.birthday]) == 0,
               "Preview must exclude stopped recipients")
        expect(store.scheduleYear(personIDs: [person.id], occasions: [.birthday], method: .reminder, senderName: "") == 0,
               "Year planning must exclude stopped recipients")
        expect(store.completeGreeting(id: skipped.id), "History can still be marked complete")
        expect(store.events.count == 3, "Annual recurrence must not restart communication")

        var staleEditor = person
        staleEditor.notes = "Edited context"
        expect(store.updatePerson(staleEditor), "Other profile edits should work")
        expect(store.people[0].communicationStopped, "A stale editor must preserve the opt-out")

        let restored = AppStore(people: [], events: [], templates: [])
        let archive = try store.exportSnapshot()
        expect(restored.importSnapshot(archive), "Archive must restore")
        expect(restored.people[0].communicationStopped && restored.events.count == 3,
               "Opt-out and queue removal must survive archive/cloud serialization")
        expect(store.setCommunicationStopped(false, personID: person.id), "Communication can resume")
        expect(store.events.count == 3, "Resuming must not restore deleted greetings")
        expect(store.addGreeting(future), "New greetings can be planned after resuming")

        let failure = AppStore(people: [person, other], events: originalEvents, templates: [],
                               allowsEphemeralPersistence: false)
        expect(!failure.setCommunicationStopped(true, personID: person.id), "A failed disk write must report failure")
        expect(!failure.people[0].communicationStopped && failure.events == originalEvents,
               "Failed persistence must roll back both the preference and the entire queue")

        var legacy = try JSONSerialization.jsonObject(with: JSONEncoder().encode(person)) as! [String: Any]
        legacy.removeValue(forKey: "communicationStopped")
        let decoded = try JSONDecoder().decode(Person.self, from: JSONSerialization.data(withJSONObject: legacy))
        expect(!decoded.communicationStopped, "Existing contacts must remain contactable")
        print("PASS: stop/resume, pending queue deletion, history, planning guards, annual recurrence, archive, rollback, legacy data")
    }
}
