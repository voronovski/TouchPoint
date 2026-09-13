import Foundation

@main
struct MissingDatesRegression {
    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        precondition(condition(), message)
    }

    static func main() {
        let friend = Person(name: "Alice", email: "alice@example.com", relationship: .friend)
        let client = Person(name: "Bob", email: "bob@example.com", relationship: .client)
        let family = Person(name: "Carol", email: "carol@example.com", relationship: .family)
        let colleague = Person(name: "Dan", email: "dan@example.com", relationship: .colleague)
        let store = AppStore(people: [colleague, family, client, friend], events: [], templates: [])
        expect(store.peopleMissingDates(focus: .all).map(\.id) == [friend.id, client.id, family.id, colleague.id],
               "All people with no dates must appear in name order")
        expect(store.peopleMissingDates(focus: .work).map(\.id) == [client.id, colleague.id],
               "Work focus must include only clients and colleagues")
        expect(store.peopleMissingDates(focus: .personal).map(\.id) == [friend.id, family.id],
               "Personal focus must include only friends and family")

        for occasion in Occasion.allCases {
            var edited = friend
            edited.importantDates = [ImportantDate(occasion: occasion, month: 5, day: 12)]
            expect(store.updatePerson(edited), "Saving any type of date must succeed")
            expect(!store.peopleMissingDates(focus: .all).contains { $0.id == friend.id },
                   "Any saved date must remove a person, even without a birthday: \(occasion)")
        }
        expect(store.updatePerson(friend), "Removing the final date must save")
        expect(store.peopleMissingDates(focus: .personal).map(\.id) == [friend.id, family.id],
               "Removing the final date must put a person back in the list")

        let lastPerson = AppStore(people: [friend], events: [], templates: [])
        var withDate = friend
        withDate.importantDates = [ImportantDate(occasion: .weddingAnniversary, month: 6, day: 1)]
        expect(lastPerson.updatePerson(withDate), "The final missing person's date must save")
        expect(lastPerson.peopleMissingDates(focus: .all).isEmpty,
               "The count and list must become empty after the last person receives a date")
        expect(store.deletePerson(id: client.id), "Deleting a person must succeed")
        expect(store.peopleMissingDates(focus: .work).map(\.id) == [colleague.id],
               "Deleted people must disappear from the list")
        print("PASS: all date types, focus, ordering, profile edits, final date removal, empty state, deletion")
    }
}
