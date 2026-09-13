import Foundation

@main
struct OccasionLibraryRegression {
    static func expect(_ value: @autoclosure () -> Bool, _ message: String) { precondition(value(), message) }

    static func main() throws {
        let template = GreetingTemplate(title: "My occasion message", occasions: [.birthday],
            body: "Hello {{first_name}} — {{occasion}} on {{date}}", bodyVariations: ["Next {{first_name}} — {{occasion}}"],
            emailSubject: "About {{occasion}}")
        let store = AppStore(people: [], events: [], templates: [template])
        let group = OccasionNode(name: "My occasions", isGroup: true)
        let subgroup = OccasionNode(name: "Milestones", parentID: group.id, isGroup: true)
        var occasion = OccasionNode(name: "First meeting", parentID: subgroup.id, templateID: template.id)
        expect(store.saveOccasionNode(group) && store.saveOccasionNode(subgroup) && store.saveOccasionNode(occasion), "Tree should save")
        expect(store.occasionPath(occasion) == "My occasions / Milestones / First meeting", "Nested path")
        var cycle = group; cycle.parentID = subgroup.id
        expect(!store.saveOccasionNode(cycle), "Cycle must be rejected")
        var invalidParent = occasion; invalidParent.parentID = occasion.id
        expect(!store.saveOccasionNode(invalidParent), "Self parenting must be rejected")
        var invalidDate = occasion; invalidDate.dateRule = .fixedDate; invalidDate.month = 2; invalidDate.day = 30
        expect(!store.saveOccasionNode(invalidDate), "Invalid fixed date must be rejected")

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Pacific/Kiritimati")!
        let today = calendar.dateComponents([.month, .day], from: .now)
        let important = ImportantDate(occasion: .custom, month: today.month!, day: today.day!, customName: occasion.title, occasionID: occasion.id)
        var person = Person(name: "Alex Example", email: "alex@example.com", relationship: .friend,
                            timeZoneIdentifier: calendar.timeZone.identifier, importantDates: [important])
        expect(store.addPerson(person), "Person and automatic greeting should save")
        expect(store.events.count == 1, "Exactly one greeting")
        let event = store.events[0]
        expect(event.sourceTemplateID == template.id && event.occasionID == occasion.id && event.sourceImportantDateID == important.id, "Stable source links")
        expect(event.message.contains("Hello Alex") && event.message.contains(occasion.title) && !event.message.contains("{{"), "Template tokens must render")
        expect(event.subject == "About First meeting", "Subject should render")
        expect(event.recurrence == .annual && calendar.isDateInToday(event.date) && calendar.component(.hour, from: event.date) == 9, "Recipient-local date at 9 AM, including today")
        expect(store.updatePerson(person) && store.events.count == 1, "Repeated save must be idempotent")
        expect(store.scheduleYear(personIDs: [person.id], occasions: [.custom], method: .reminder) == 0, "Year planner must skip automatic greeting")

        person.importantDates[0].month = today.month! == 12 ? 1 : today.month! + 1
        person.importantDates[0].day = 12
        expect(store.updatePerson(person), "Date edit")
        expect(store.events.count == 1 && store.events[0].id == event.id, "Date edit updates, not duplicates")
        expect(calendar.component(.month, from: store.events[0].date) == person.importantDates[0].month, "Updated date")
        expect(store.events[0].message == event.message, "Date edits preserve authored message")
        expect(store.completeGreeting(id: event.id), "Complete annual greeting")
        expect(store.events.count == 2 && store.events[1].sourceImportantDateID == important.id, "Annual continuation retains link")
        expect(store.events[1].message == "Next Alex — First meeting", "Annual continuation uses next template variation")
        person.importantDates.removeAll()
        expect(store.updatePerson(person), "Remove date")
        expect(store.events.count == 1 && store.events[0].status == .completed, "Remove only pending linked greetings, preserve history")

        let noTemplate = OccasionNode(name: "No automatic greeting")
        expect(store.saveOccasionNode(noTemplate), "Unlinked occasion")
        person.importantDates = [ImportantDate(occasion: .custom, month: 12, day: 8, customName: noTemplate.title, occasionID: noTemplate.id)]
        expect(store.updatePerson(person) && store.events.count == 1, "Without template only save date")
        let second = OccasionNode(name: occasion.title, parentID: group.id, templateID: template.id)
        expect(store.saveOccasionNode(second), "Same label, distinct identity")
        person.importantDates = [occasion, second].map { ImportantDate(occasion: .custom, month: 12, day: 8, customName: $0.title, occasionID: $0.id) }
        expect(store.updatePerson(person) && store.events.count == 3, "Distinct occasions with same label and day must both schedule")
        expect(store.scheduleYear(personIDs: [person.id], occasions: [.custom], method: .reminder) == 0, "Identity-aware bulk deduplication")

        var renamedPerson = store.people[0]
        renamedPerson.importantDates[0].customName = "Renamed label"
        let renameCheck = AppStore(people: [renamedPerson], events: store.events, templates: store.templates, occasionNodes: store.occasionNodes)
        expect(renameCheck.scheduleYear(personIDs: [person.id], occasions: [.custom], method: .reminder) == 0, "Stable identity prevents duplicates after a label change")

        let archive = try store.exportArchive()
        let restored = AppStore(people: [], events: [], templates: [])
        expect(restored.importArchive(archive), "Archive restores")
        expect(restored.occasionNodes == store.occasionNodes && restored.people == store.people && restored.events == store.events, "All tree, date and greeting links round-trip")
        expect(restored.deleteOccasionNode(id: subgroup.id), "Delete group")
        expect(restored.occasionNodes.first { $0.id == occasion.id }?.parentID == group.id, "Promote children on group deletion")
        expect(restored.deleteOccasionNode(id: occasion.id), "Delete occasion")
        expect(restored.events.count == store.events.count && restored.people[0].importantDates.count == 2, "Delete library occasion preserves dates and history")
        expect(restored.deleteTemplate(id: template.id), "Delete template")
        expect(restored.occasionNodes.allSatisfy { $0.templateID == nil }, "Detach deleted template")
        let roundTrip = AppStore(people: [], events: [], templates: [])
        let cleanedArchive = try restored.exportArchive()
        expect(roundTrip.importArchive(cleanedArchive), "Deleted associations must still export and import")

        let blocked = AppStore(people: [], events: [], templates: [template], occasionNodes: store.occasionNodes, allowsEphemeralPersistence: false)
        expect(!blocked.addPerson(person), "Persistence failure")
        expect(blocked.people.isEmpty && blocked.events.isEmpty && blocked.templates[0].nextVariationIndex == 0, "Rollback person, greeting and variation atomically")
        occasion.name = "Changed"
        expect(!blocked.saveOccasionNode(occasion) && blocked.occasionNodes == store.occasionNodes, "Rollback tree edit")
        var stopped = person; stopped.communicationStopped = true
        let optOut = AppStore(people: [], events: [], templates: [template], occasionNodes: store.occasionNodes)
        expect(optOut.addPerson(stopped) && optOut.events.isEmpty, "Respect communication opt-out")

        var holiday = store.occasionNodes.first { $0.builtInOccasion == .thanksgiving }!
        holiday.templateID = template.id
        expect(store.saveOccasionNode(holiday), "Attach holiday template")
        let holidayDate = ImportantDate(occasion: .thanksgiving, month: 1, day: 1, customName: holiday.title, occasionID: holiday.id)
        let thanksgiving = store.nextImportantDate(holidayDate, for: person)!
        expect(calendar.component(.month, from: thanksgiving) == 11 && calendar.component(.weekday, from: thanksgiving) == 5, "Moving holiday uses calendar rule")
        let leap = ImportantDate(occasion: .custom, month: 2, day: 29, customName: "Leap day", occasionID: second.id)
        let year2027 = calendar.date(from: DateComponents(year: 2027, month: 1, day: 1))!
        let leap2027 = store.nextImportantDate(leap, for: person, after: year2027)!
        expect(calendar.component(.day, from: leap2027) == 28, "Leap day clamps in non-leap year")
        let year2028 = calendar.date(from: DateComponents(year: 2028, month: 1, day: 1))!
        expect(calendar.component(.day, from: store.nextImportantDate(leap, for: person, after: year2028)!) == 29, "Leap date recovers in leap year")

        var legacy = try JSONSerialization.jsonObject(with: archive) as! [String: Any]
        legacy["version"] = 9; legacy.removeValue(forKey: "occasionNodes")
        let migrated = AppStore(people: [], events: [], templates: [])
        let legacyData = try JSONSerialization.data(withJSONObject: legacy)
        expect(migrated.importArchive(legacyData), "Legacy archives remain readable")
        expect(migrated.occasionNodes == OccasionNode.defaults(), "Seed tree only for legacy payloads")
        print("PASS: occasion tree CRUD, validation, templates, automatic scheduling, time zones, deduplication, date edits, annual recurrence, history, archive migration and rollback")
    }
}
