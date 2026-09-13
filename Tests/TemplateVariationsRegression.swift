import Foundation

// Run with scripts/test-template-variations.sh. Exercises the production model/store.
@main
struct TemplateVariationsRegression {
    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        precondition(condition(), message)
    }

    static func main() throws {
        let person = Person(name: "Alex Example", organization: "Example", relationship: .friend,
                            importantDates: [ImportantDate(occasion: .birthday, month: 12, day: 10)])
        let template = GreetingTemplate(title: "Rotating birthday", occasions: [.birthday],
                                        body: "One {{first_name}}", bodyVariations: ["Two {{name}}", "Three {{organization}}"])
        let expected = ["One Alex", "Two Alex Example", "Three Example", "One Alex"]
        func store(_ templates: [GreetingTemplate] = [template]) -> AppStore {
            AppStore(people: [person], events: [], templates: templates)
        }
        func preview(_ store: AppStore) -> String {
            store.renderedBody(for: store.templates[0], person: person, occasion: .birthday, senderName: "")
        }
        func greeting(_ store: AppStore, recurrence: EventRecurrence = .oneTime) -> GreetingEvent {
            GreetingEvent(personID: person.id, occasion: .birthday, date: .now, method: .reminder,
                          status: .planned, message: preview(store), sourceTemplateID: template.id,
                          sourceTemplateRevision: store.templates[0].revisionNumber, recurrence: recurrence)
        }

        let rotation = store()
        for text in expected {
            expect(preview(rotation) == text, "Sequence must be 1, 2, 3, 1")
            expect(preview(rotation) == text, "Preview must not consume a variation")
            expect(rotation.addGreeting(greeting(rotation)), "Greeting should save")
        }
        expect(rotation.events.map(\.message) == expected, "Saved messages remain unchanged")
        expect(rotation.templates[0].revisionNumber == 1, "Rotation must not create content revisions")
        let restored = store([])
        let archive = try rotation.exportSnapshot()
        expect(restored.importSnapshot(archive), "Archive should import")
        expect(preview(restored) == "Two Alex Example", "Queue survives persistence")

        let failed = AppStore(people: [person], events: [], templates: [template], allowsEphemeralPersistence: false)
        expect(!failed.addGreeting(greeting(failed)), "Unavailable storage must reject saving")
        expect(preview(failed) == expected[0] && failed.events.isEmpty,
               "Failed save must roll back queue and greeting")

        let annual = store()
        let original = greeting(annual, recurrence: .annual)
        expect(annual.addGreeting(original), "Annual greeting should save")
        expect(annual.completeGreeting(id: original.id), "Annual greeting should complete")
        expect(annual.events.count == 2 && annual.events[1].message == expected[1], "Next annual greeting uses variation two")
        expect(annual.completeGreeting(id: original.id), "Repeated completion is idempotent")
        expect(annual.events.count == 2 && preview(annual) == expected[2], "Repeated completion must not consume a variation")
        expect(annual.skipGreeting(id: annual.events[1].id), "Annual greeting should skip")
        expect(annual.events[2].message == expected[2] && preview(annual) == expected[0], "Annual continuation wraps")

        let recipients = (0..<4).map { index in
            Person(name: "Person\(index)", relationship: .friend,
                   importantDates: [ImportantDate(occasion: .birthday, month: 12, day: 10)])
        }
        let bulkTemplate = GreetingTemplate(title: "Bulk", occasions: [.birthday], body: "One", bodyVariations: ["Two", "Three"])
        let bulk = AppStore(people: recipients, events: [], templates: [bulkTemplate])
        expect(bulk.scheduleYear(personIDs: Set(recipients.map(\.id)), occasions: [.birthday], method: .reminder, senderName: "") == 4,
               "Planner must schedule all recipients")
        expect(bulk.events.map(\.message) == ["One", "Two", "Three", "One"], "Planner must rotate within one batch")
        expect(bulk.scheduleYear(personIDs: Set(recipients.map(\.id)), occasions: [.birthday], method: .reminder, senderName: "") == 0,
               "Planner must skip duplicates")
        expect(bulk.templates[0].nextVariationIndex == 1, "Skipped duplicates must not consume variations")

        var staleDraft = template
        staleDraft.bodyVariations = ["Changed two", "Changed three"]
        expect(rotation.updateTemplate(staleDraft), "Editing variations should save")
        expect(rotation.templates[0].nextVariationIndex == 1, "Stale draft must preserve current queue")
        expect(rotation.templates[0].revisionNumber == 2, "Variation edits must create a content revision")
        let revision = rotation.templateRevisions(for: template.id)[0]
        expect(rotation.restoreTemplateRevision(templateID: template.id, revisionID: revision.id), "Revision should restore")
        expect(rotation.templates[0].messageBodies == template.messageBodies, "Restoration includes every variation")
        let copy = rotation.duplicateTemplate(id: template.id)!
        expect(copy.messageBodies == template.messageBodies && copy.nextVariationIndex == 0, "Duplicate starts its own queue at one")
        var reduced = rotation.templates[0]
        reduced.bodyVariations = []
        expect(rotation.updateTemplate(reduced), "Removing variations should save")
        expect(preview(rotation) == expected[0], "Removing variations leaves a valid queue")

        var legacy = try JSONSerialization.jsonObject(with: JSONEncoder().encode(template)) as! [String: Any]
        legacy.removeValue(forKey: "bodyVariations")
        legacy.removeValue(forKey: "nextVariationIndex")
        legacy.removeValue(forKey: "body")
        let oldTemplate = try JSONDecoder().decode(GreetingTemplate.self, from: JSONSerialization.data(withJSONObject: legacy))
        expect(oldTemplate.messageBodies == [template.body] && oldTemplate.nextVariationIndex == 0, "Legacy message becomes variation one")
        let single = store([oldTemplate])
        for _ in 0..<3 {
            expect(single.addGreeting(greeting(single)), "Single-message templates still save")
            expect(preview(single) == expected[0], "Single-message templates keep using their message")
        }
        var oldSnapshot = try JSONSerialization.jsonObject(with: JSONEncoder().encode(TemplateContentSnapshot(template: template))) as! [String: Any]
        oldSnapshot.removeValue(forKey: "bodyVariations")
        let decoded = try JSONDecoder().decode(TemplateContentSnapshot.self, from: JSONSerialization.data(withJSONObject: oldSnapshot))
        expect(decoded.bodyVariations == nil, "Old revision snapshots must decode")
        var invalid = template
        invalid.bodyVariations = ["   "]
        expect(!invalid.validationErrors.isEmpty, "Blank variations must be rejected")
        invalid.bodyVariations = ["Hello {{unknown}}"]
        expect(!invalid.validationErrors.isEmpty, "All variations must validate interpolation tokens")
        print("PASS: rotation, preview, persistence, rollback, annual recurrence, batch planning, revision history, duplication, legacy data and validation")
    }
}
