import Foundation

@main
struct TemplateEditingRegression {
    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        precondition(condition(), message)
    }

    static func main() throws {
        let oldHome = GreetingTemplate(title: "A year at home", occasions: [.homeAnniversary],
            body: "Happy home anniversary, {{first_name}}! I hope your home is still your favorite place to be.",
            isFavorite: true, isBuiltIn: true)
        let oldClient = GreetingTemplate(title: "A client home milestone", occasions: [.homeAnniversary],
            body: "Happy home anniversary, {{first_name}}! I hope this milestone still brings you plenty of joy.",
            emailSubject: "Happy home anniversary", isBuiltIn: true)
        let person = Person(name: "Alex Example", relationship: .friend)
        let event = GreetingEvent(personID: person.id, occasion: .homeAnniversary, date: .now,
            method: .sms, status: .planned, message: "An already planned greeting", sourceTemplateID: oldHome.id)
        let oldArchive = AppDataSnapshot(version: 7, people: [person], events: [event], templates: [oldHome, oldClient])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var legacyJSON = try JSONSerialization.jsonObject(with: encoder.encode(oldArchive)) as! [String: Any]
        var legacyTemplates = legacyJSON["templates"] as! [[String: Any]]
        for index in legacyTemplates.indices {
            legacyTemplates[index]["isDefault"] = true
            legacyTemplates[index]["isLocked"] = true
            legacyTemplates[index]["isApproved"] = true
            legacyTemplates[index]["approvedAt"] = "2026-01-01T00:00:00Z"
        }
        legacyJSON["templates"] = legacyTemplates
        let store = AppStore(people: [], events: [], templates: [])
        let legacyData = try JSONSerialization.data(withJSONObject: legacyJSON)
        expect(store.importSnapshot(legacyData), "Old locked libraries must import")
        expect(store.templates.filter { $0.occasions.contains(.homeAnniversary) }.count == 2, "Both Home anniversary starters must remain available")
        let migrated = store.templates.first { $0.id == oldHome.id }!
        expect(migrated.title == oldHome.title && migrated.occasions == [.homeAnniversary], "Legacy Home anniversary templates must keep their identity and occasion")
        expect(migrated.body == oldHome.body && migrated.iconID == "house", "Text and icon must match Home anniversary")
        expect(store.templates.first { $0.id == oldClient.id }?.emailSubject == "Happy home anniversary", "Client template subject must remain Home anniversary")
        expect(store.events.first?.message == event.message && store.events.first?.occasion == event.occasion, "Migration must preserve existing scheduled greetings")
        var edited = migrated
        edited.title = "Our custom anniversary"
        edited.body = "Hello {{preferred_name}}"
        edited.bodyVariations = ["Dear {{first_name}}"]
        expect(store.updateTemplate(edited), "Previously locked built-in templates must be editable")
        let revision = store.templateRevisions(for: edited.id).first!
        expect(store.restoreTemplateRevision(templateID: edited.id, revisionID: revision.id), "Built-in revisions must be restorable")
        expect(store.updateTemplate(edited), "Built-in template must remain editable after restoring")
        expect(store.deleteTemplate(id: oldClient.id), "Built-in templates must be deletable")
        let copy = AppStore(people: [], events: [], templates: [])
        let saved = try store.exportSnapshot()
        expect(copy.importSnapshot(saved), "Edited library must reload")
        expect(copy.templates.map(\.id) == store.templates.map(\.id)
            && copy.templates.map { TemplateContentSnapshot(template: $0) } == store.templates.map { TemplateContentSnapshot(template: $0) },
            "Reload must neither reseed deleted templates nor overwrite renamed entries")
        expect(copy.hasUserContent, "A changed starter library must count as user content for cloud reconciliation")
        for template in copy.templates {
            expect(copy.deleteTemplate(id: template.id), "Every template must be deletable")
        }
        let emptyReload = AppStore(people: [], events: [], templates: [])
        let emptySaved = try copy.exportSnapshot()
        expect(emptyReload.importSnapshot(emptySaved) && emptyReload.templates.isEmpty, "An intentionally empty library must stay empty")
        var usageArchive = try JSONSerialization.jsonObject(with: saved) as! [String: Any]
        usageArchive["version"] = 8
        usageArchive["usage"] = [["kind": "scheduled", "templateID": oldClient.id.uuidString]]
        usageArchive["templateUsage"] = usageArchive["usage"]
        var usageTemplates = usageArchive["templates"] as! [[String: Any]]
        for index in usageTemplates.indices {
            usageTemplates[index]["usageCount"] = 99
            usageTemplates[index]["lastUsedAt"] = "2026-01-01T00:00:00Z"
        }
        usageArchive["templates"] = usageTemplates
        let usageData = try JSONSerialization.data(withJSONObject: usageArchive)
        let withoutUsage = AppStore(people: [], events: [], templates: [])
        expect(withoutUsage.importSnapshot(usageData), "Old usage metadata must be ignored on import")
        expect(withoutUsage.templates.map(\.id) == store.templates.map(\.id), "Version 8 migration must preserve deletions")
        let cleaned = try JSONSerialization.jsonObject(with: withoutUsage.exportSnapshot()) as! [String: Any]
        expect(cleaned["usage"] == nil && cleaned["templateUsage"] == nil, "Archives must not contain usage records")
        expect((cleaned["templates"] as! [[String: Any]]).allSatisfy {
            $0["usageCount"] == nil && $0["lastUsedAt"] == nil
        }, "Template statistics must not be persisted")
        let replacedHome = GreetingTemplate(id: oldHome.id, title: "Happy wedding anniversary", occasions: [.weddingAnniversary],
            body: "Happy wedding anniversary, {{first_name}}! Wishing you both many more years of love, happiness, and wonderful memories together.",
            iconID: "heart", colorToken: "rose", isBuiltIn: true)
        let replacedClient = GreetingTemplate(id: oldClient.id, title: "Wedding anniversary wishes", occasions: [.weddingAnniversary],
            body: "Happy wedding anniversary, {{first_name}}! Warm wishes to you both for a wonderful celebration and many happy years ahead.",
            iconID: "heart", colorToken: "rose", emailSubject: "Happy wedding anniversary", isBuiltIn: true)
        let wedding = GreetingTemplate(title: "Celebrate together", occasions: [.weddingAnniversary],
            body: "Happy anniversary! Wishing you both another year full of great memories.", isBuiltIn: true)
        let rollback = AppStore(people: [], events: [], templates: [])
        let rollbackData = try encoder.encode(AppDataSnapshot(version: 10, people: [person], events: [event],
            templates: [replacedHome, replacedClient, wedding]))
        expect(rollback.importSnapshot(rollbackData), "Previously migrated library must load")
        expect(rollback.templates.map(\.id) == [oldHome.id, oldClient.id, wedding.id], "Rollback must not seed or duplicate templates")
        expect(rollback.templates[0].title == oldHome.title && rollback.templates[0].body == oldHome.body
            && rollback.templates[0].occasions == [.homeAnniversary] && rollback.templates[0].iconID == "house"
            && rollback.templates[0].colorToken == "blue", "Personal Home anniversary template must be restored")
        expect(rollback.templates[1].body == oldClient.body && rollback.templates[1].emailSubject == oldClient.emailSubject
            && rollback.templates[1].colorToken == "teal", "Client Home anniversary template must be restored")
        expect(rollback.templates[2].body == wedding.body && rollback.templates[2].occasions == [.weddingAnniversary], "Original wedding templates must be preserved")
        expect(rollback.events[0].message == event.message && rollback.templateRevisions.count == 2, "Rollback must preserve greetings and retain undo history")
        let rollbackSaved = try rollback.exportSnapshot()
        expect(rollback.importSnapshot(rollbackSaved) && rollback.templateRevisions.count == 2, "Rollback must run only once")
        var customized = replacedHome
        customized.body = "My edited anniversary greeting"
        let customData = try encoder.encode(AppDataSnapshot(version: 10, people: [], events: [], templates: [customized]))
        expect(rollback.importSnapshot(customData) && rollback.templates.count == 1
            && rollback.templates[0].body == customized.body && rollback.templates[0].occasions == [.weddingAnniversary],
            "Rollback must preserve user edits and deleted starters")
        let formerDefault = GreetingTemplate(title: "Former default", occasions: [.birthday], body: "Old choice",
            relationships: [.friend], channels: [.sms], languages: ["English"], updatedAt: Date(timeIntervalSince1970: 100))
        let recentMatch = GreetingTemplate(title: "Matching template", occasions: [.birthday], body: "New choice",
            relationships: [.friend], channels: [.sms], languages: ["English"], updatedAt: Date(timeIntervalSince1970: 200))
        let defaultSnapshot = AppDataSnapshot(version: 11, people: [], events: [], templates: [formerDefault, recentMatch])
        var defaultJSON = try JSONSerialization.jsonObject(with: encoder.encode(defaultSnapshot)) as! [String: Any]
        var defaultTemplates = defaultJSON["templates"] as! [[String: Any]]
        defaultTemplates[0]["isDefault"] = true
        defaultJSON["templates"] = defaultTemplates
        let defaultData = try JSONSerialization.data(withJSONObject: defaultJSON)
        let noDefaults = AppStore(people: [], events: [], templates: [])
        expect(noDefaults.importSnapshot(defaultData), "Legacy default flags must not prevent importing")
        expect(noDefaults.templates.count == 2, "Default removal must not reseed deleted starters")
        expect(noDefaults.resolveTemplate(occasion: .birthday, relationship: .friend, channel: .sms, language: "English")?.id == recentMatch.id,
            "Legacy default flags must no longer boost automatic template selection")
        expect(noDefaults.resolveTemplate(occasion: .birthday, relationship: .client, channel: .sms, language: "English") == nil,
            "Recipient matching must remain intact")
        let noDefaultsJSON = try JSONSerialization.jsonObject(with: noDefaults.exportSnapshot()) as! [String: Any]
        expect((noDefaultsJSON["templates"] as! [[String: Any]]).allSatisfy { $0["isDefault"] == nil },
            "Default state must no longer be exported")
        let encoded = try JSONSerialization.jsonObject(with: encoder.encode(edited)) as! [String: Any]
        expect(encoded["isLocked"] == nil && encoded["isApproved"] == nil && encoded["approvedAt"] == nil, "Governance state must no longer be persisted")
        let failed = AppStore(people: [], events: [], templates: [edited], allowsEphemeralPersistence: false)
        expect(!failed.deleteTemplate(id: edited.id) && failed.templates == [edited], "Failed deletion must roll back")
        edited.body = "Another message"
        expect(!failed.updateTemplate(edited) && failed.templateRevisions.isEmpty, "Failed edits must roll back revisions")
        print("PASS: editable/deletable starters, legacy governance removal, Home anniversary rollback, history, archive persistence and rollback")
    }
}
