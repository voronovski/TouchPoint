import Foundation
import Observation

@Observable
final class AppStore {
    static let currentPersistenceVersion = 7
    static let maximumArchiveBytes = 25 * 1_024 * 1_024
    private static let recoveryBackupPathKey = "TouchPoint.RecoveryBackupPath"

    var people: [Person]
    var events: [GreetingEvent]
    var templates: [GreetingTemplate]
    var templateGroups: [TemplateGroup]
    /// Previous content snapshots, kept outside templates so the active library stays small.
    var templateRevisions: [TemplateRevision]
    /// Metadata-only usage events; no message text or person identifiers are stored here.
    var templateUsage: [TemplateUsageRecord]
    /// Short alias for clients that refer to groups simply as `groups`.
    var groups: [TemplateGroup] {
        get { templateGroups }
        set { templateGroups = newValue }
    }
    var persistenceError: String?
    /// If loading failed, this points at the untouched corrupt payload so callers can
    /// offer diagnostics or a manual recovery flow.
    private(set) var corruptSnapshotBackupURL: URL?
    var hasRecoverableSnapshot: Bool { corruptSnapshotBackupURL != nil }
    private let persistenceURL: URL?
    private let allowsEphemeralPersistence: Bool
    private(set) var lastModifiedAt: Date

    /// Distinguishes a fresh built-in-only workspace from meaningful local content
    /// when a device performs its first CloudKit reconciliation.
    var hasUserContent: Bool {
        if !people.isEmpty || !events.isEmpty || !templateRevisions.isEmpty || !templateUsage.isEmpty { return true }
        if templates.contains(where: { !$0.isBuiltIn }) { return true }
        let builtInGroupIDs = Set(templates.filter(\.isBuiltIn).compactMap(\.groupID))
        return templateGroups.contains { !builtInGroupIDs.contains($0.id) }
    }

    init(
        people: [Person],
        events: [GreetingEvent],
        templates: [GreetingTemplate],
        templateGroups: [TemplateGroup] = [],
        templateRevisions: [TemplateRevision] = [],
        templateUsage: [TemplateUsageRecord] = [],
        persistenceURL: URL? = nil,
        persistenceError: String? = nil,
        corruptSnapshotBackupURL: URL? = nil,
        allowsEphemeralPersistence: Bool = true,
        lastModifiedAt: Date = .distantPast
    ) {
        self.people = people
        self.events = events
        self.templates = templates
        self.templateGroups = templateGroups
        self.templateRevisions = templateRevisions
        self.templateUsage = templateUsage
        self.persistenceURL = persistenceURL
        self.allowsEphemeralPersistence = allowsEphemeralPersistence
        self.persistenceError = persistenceError
        self.corruptSnapshotBackupURL = corruptSnapshotBackupURL
        self.lastModifiedAt = lastModifiedAt
    }

    func person(for event: GreetingEvent) -> Person? {
        people.first { $0.id == event.personID }
    }

    @discardableResult
    func addPerson(_ person: Person) -> Bool {
        people.append(person)
        guard save() else { people.removeLast(); return false }
        return true
    }

    /// Imports a prepared batch with one atomic disk commit. Either every person is
    /// retained or the in-memory collection is restored unchanged.
    @discardableResult
    func addPeople(_ newPeople: [Person]) -> Int {
        guard !newPeople.isEmpty else { return 0 }
        let previous = mutableState
        people.append(contentsOf: newPeople)
        guard save() else { restore(previous); return 0 }
        return newPeople.count
    }

    @discardableResult
    func updatePerson(_ person: Person) -> Bool {
        guard let index = people.firstIndex(where: { $0.id == person.id }) else { return false }
        let previous = people[index]
        people[index] = person
        guard save() else { people[index] = previous; return false }
        return true
    }

    /// Removes a person and all greetings scheduled for them. Usage records tied to
    /// those greetings are removed as well; unrelated template history is retained.
    @discardableResult
    func deletePerson(id: UUID) -> Bool {
        guard let index = people.firstIndex(where: { $0.id == id }) else { return false }
        let previous = mutableState
        let eventIDs = Set(events.filter { $0.personID == id }.map(\.id))
        people.remove(at: index)
        events.removeAll { $0.personID == id }
        templateUsage.removeAll { record in
            guard let eventID = record.eventID else { return false }
            return eventIDs.contains(eventID)
        }
        guard save() else { restore(previous); return false }
        return true
    }

    @discardableResult
    func deletePerson(_ person: Person) -> Bool { deletePerson(id: person.id) }

    @discardableResult
    func removePerson(id: UUID) -> Bool { deletePerson(id: id) }

    /// A transaction snapshot used to roll back mutations when the on-disk commit fails.
    private var mutableState: MutableState {
        MutableState(people: people, events: events, templates: templates,
                     groups: templateGroups, revisions: templateRevisions, usage: templateUsage,
                     lastModifiedAt: lastModifiedAt)
    }

    private func restore(_ state: MutableState) {
        people = state.people; events = state.events; templates = state.templates
        templateGroups = state.groups; templateRevisions = state.revisions; templateUsage = state.usage
        lastModifiedAt = state.lastModifiedAt
    }

    @discardableResult
    func addTemplate(_ template: GreetingTemplate) -> Bool {
        let previous = mutableState
        var inserted = template
        if inserted.isBuiltIn {
            inserted.isApproved = true
            inserted.approvedAt = inserted.approvedAt ?? inserted.createdAt
            inserted.isLocked = true
        }
        inserted.revisionNumber = max(1, inserted.revisionNumber)
        templates.append(inserted)
        guard save() else { restore(previous); return false }
        return true
    }

    @discardableResult
    func updateTemplate(_ template: GreetingTemplate) -> Bool {
        updateTemplateResult(template)
    }

    /// Updates a template while preserving source compatibility with the original void API.
    /// Returns false when the template is locked/built-in and its content was changed.
    @discardableResult
    func updateTemplateResult(_ template: GreetingTemplate) -> Bool {
        guard let index = templates.firstIndex(where: { $0.id == template.id }) else { return false }
        let previous = mutableState
        let current = templates[index]
        let currentContent = TemplateContentSnapshot(template: current)
        let incomingContent = TemplateContentSnapshot(template: template)
        let contentChanged = currentContent != incomingContent

        guard !contentChanged || (!current.isLocked && !current.isBuiltIn) else { return false }

        var updated = template
        // These fields are owned by the store and must not be overwritten by a stale editor draft.
        updated.isBuiltIn = current.isBuiltIn
        updated.usageCount = current.usageCount
        updated.lastUsedAt = current.lastUsedAt
        updated.revisionNumber = current.revisionNumber
        updated.isApproved = current.isApproved
        updated.approvedAt = current.approvedAt
        updated.isLocked = current.isLocked
        if contentChanged {
            templateRevisions.append(
                TemplateRevision(
                    templateID: current.id,
                    number: current.revisionNumber,
                    snapshot: currentContent
                )
            )
            retainTemplateRevisionLimit(for: current.id)
            updated.revisionNumber = current.revisionNumber + 1
            updated.isApproved = false
            updated.approvedAt = nil
        }
        if current.isBuiltIn {
            // Shipped templates are immutable starter content, even if an old editor draft
            // or a hand-written JSON payload tries to clear their protection flags.
            updated.isApproved = true
            updated.approvedAt = current.approvedAt ?? current.createdAt
            updated.isLocked = true
        }
        updated.updatedAt = contentChanged ? .now : current.updatedAt
        templates[index] = updated
        guard save() else { restore(previous); return false }
        return true
    }

    @discardableResult
    func duplicateTemplate(id: UUID, title: String? = nil) -> GreetingTemplate? {
        guard let source = templates.first(where: { $0.id == id }) else { return nil }
        let previous = mutableState
        var copy = GreetingTemplate(
            title: title ?? "\(source.title) copy",
            occasions: source.occasions,
            body: source.body,
            isFavorite: false,
            iconSemantic: source.iconSemantic,
            iconID: source.iconID,
            colorToken: source.colorToken,
            groupID: source.groupID,
            relationships: source.relationships,
            channels: source.channels,
            languages: source.languages,
            emailSubject: source.emailSubject,
            isDefault: false,
            isBuiltIn: false,
            isApproved: false,
            approvedAt: nil,
            isLocked: false
        )
        copy.updatedAt = copy.createdAt
        templates.append(copy)
        guard save() else { restore(previous); return nil }
        return copy
    }

    @discardableResult
    func duplicateTemplate(_ template: GreetingTemplate, title: String? = nil) -> GreetingTemplate? {
        duplicateTemplate(id: template.id, title: title)
    }

    @discardableResult
    func deleteTemplate(id: UUID) -> Bool {
        guard let index = templates.firstIndex(where: { $0.id == id }),
              !templates[index].isBuiltIn,
              !templates[index].isLocked else {
            return false
        }
        let previous = mutableState
        templates.remove(at: index)
        templateRevisions.removeAll { $0.templateID == id }
        templateUsage.removeAll { $0.templateID == id }
        guard save() else { restore(previous); return false }
        return true
    }

    @discardableResult
    func archiveTemplate(id: UUID, archived: Bool = true) -> Bool {
        guard let index = templates.firstIndex(where: { $0.id == id }) else { return false }
        let previous = mutableState
        templates[index].isArchived = archived
        templates[index].updatedAt = .now
        guard save() else { restore(previous); return false }
        return true
    }

    @discardableResult
    func setTemplateFavorite(id: UUID, isFavorite: Bool) -> Bool {
        guard let index = templates.firstIndex(where: { $0.id == id }) else { return false }
        let previous = mutableState
        templates[index].isFavorite = isFavorite
        templates[index].updatedAt = .now
        guard save() else { restore(previous); return false }
        return true
    }

    @discardableResult
    func toggleTemplateFavorite(id: UUID) -> Bool {
        guard let template = templates.first(where: { $0.id == id }) else { return false }
        return setTemplateFavorite(id: id, isFavorite: !template.isFavorite)
    }

    /// Approves or clears approval for this local library. Approval is not a team/server claim.
    @discardableResult
    func setTemplateApproval(id: UUID, approved: Bool, at date: Date = .now) -> Bool {
        guard let index = templates.firstIndex(where: { $0.id == id }) else { return false }
        if templates[index].isBuiltIn && !approved { return false }
        let previous = mutableState
        templates[index].isApproved = approved
        templates[index].approvedAt = approved ? date : nil
        templates[index].updatedAt = date
        guard save() else { restore(previous); return false }
        return true
    }

    /// Locks or unlocks local editing. Built-in templates remain immutable and locked.
    @discardableResult
    func setTemplateLock(id: UUID, locked: Bool) -> Bool {
        guard let index = templates.firstIndex(where: { $0.id == id }) else { return false }
        if templates[index].isBuiltIn && !locked { return false }
        let previous = mutableState
        templates[index].isLocked = locked
        templates[index].updatedAt = .now
        guard save() else { restore(previous); return false }
        return true
    }

    func templateRevisions(for templateID: UUID) -> [TemplateRevision] {
        templateRevisions
            .filter { $0.templateID == templateID }
            .sorted { lhs, rhs in
                if lhs.number != rhs.number { return lhs.number > rhs.number }
                return lhs.createdAt > rhs.createdAt
            }
    }

    func usageRecords(for templateID: UUID) -> [TemplateUsageRecord] {
        templateUsage
            .filter { $0.templateID == templateID }
            .sorted { $0.occurredAt > $1.occurredAt }
    }

    /// Restoring is additive: it creates a new revision and leaves the old revision intact.
    @discardableResult
    func restoreTemplateRevision(templateID: UUID, revisionID: UUID) -> Bool {
        guard let revision = templateRevisions.first(where: {
            $0.id == revisionID && $0.templateID == templateID
        }),
        let current = templates.first(where: { $0.id == templateID }) else {
            return false
        }
        var restored = current
        let snapshot = revision.snapshot
        restored.title = snapshot.title
        restored.occasions = snapshot.occasions
        restored.body = snapshot.body
        restored.iconSemantic = snapshot.iconSemantic
        restored.iconID = snapshot.iconID
        restored.colorToken = snapshot.colorToken
        restored.groupID = snapshot.groupID.flatMap { groupID in
            templateGroups.contains(where: { $0.id == groupID }) ? groupID : nil
        }
        restored.relationships = snapshot.relationships
        restored.channels = snapshot.channels
        restored.languages = snapshot.languages
        restored.emailSubject = snapshot.emailSubject
        return updateTemplateResult(restored)
    }

    @discardableResult
    func setTemplateDefault(id: UUID, isDefault: Bool = true) -> Bool {
        guard let index = templates.firstIndex(where: { $0.id == id }) else { return false }
        let previous = mutableState
        let occasions = Set(templates[index].occasions)
        let relationships = Set(templates[index].relationships)
        let channels = Set(templates[index].channels)
        let languages = Set(templates[index].languages.map { $0.lowercased() })
        for otherIndex in templates.indices where
            otherIndex != index
                && !occasions.isDisjoint(with: templates[otherIndex].occasions)
                && relationships == Set(templates[otherIndex].relationships)
                && channels == Set(templates[otherIndex].channels)
                && languages == Set(templates[otherIndex].languages.map { $0.lowercased() }) {
            templates[otherIndex].isDefault = false
        }
        templates[index].isDefault = isDefault
        templates[index].updatedAt = .now
        guard save() else { restore(previous); return false }
        return true
    }

    // MARK: Template groups

    @discardableResult
    func addTemplateGroup(_ group: TemplateGroup) -> Bool {
        let previous = mutableState
        templateGroups.append(group)
        normalizeGroupOrder()
        guard save() else { restore(previous); return false }
        return true
    }

    @discardableResult
    func addGroup(_ group: TemplateGroup) -> Bool { addTemplateGroup(group) }

    @discardableResult
    func updateTemplateGroup(_ group: TemplateGroup) -> Bool {
        guard let index = templateGroups.firstIndex(where: { $0.id == group.id }) else { return false }
        let previous = mutableState
        var updated = group
        updated.updatedAt = .now
        templateGroups[index] = updated
        guard save() else { restore(previous); return false }
        return true
    }

    @discardableResult
    func updateGroup(_ group: TemplateGroup) -> Bool { updateTemplateGroup(group) }

    @discardableResult
    func deleteTemplateGroup(id: UUID) -> Bool {
        guard let index = templateGroups.firstIndex(where: { $0.id == id }), !templateGroups[index].isBuiltIn else {
            return false
        }
        let previous = mutableState
        templateGroups.remove(at: index)
        for templateIndex in templates.indices where templates[templateIndex].groupID == id {
            templates[templateIndex].groupID = nil
            templates[templateIndex].updatedAt = .now
        }
        normalizeGroupOrder()
        guard save() else { restore(previous); return false }
        return true
    }

    @discardableResult
    func deleteGroup(id: UUID) -> Bool { deleteTemplateGroup(id: id) }

    @discardableResult
    func reorderTemplateGroups(ids: [UUID]) -> Bool {
        let previous = mutableState
        let currentIDs = Set(templateGroups.map(\.id))
        guard currentIDs == Set(ids), ids.count == templateGroups.count else { return false }
        for (order, id) in ids.enumerated() {
            guard let index = templateGroups.firstIndex(where: { $0.id == id }) else { continue }
            templateGroups[index].sortOrder = order
            templateGroups[index].updatedAt = .now
        }
        templateGroups.sort { $0.sortOrder < $1.sortOrder }
        guard save() else { restore(previous); return false }
        return true
    }

    @discardableResult
    func reorderGroups(ids: [UUID]) -> Bool { reorderTemplateGroups(ids: ids) }

    func templates(in groupID: UUID) -> [GreetingTemplate] {
        templates.filter { $0.groupID == groupID && !$0.isArchived }
    }

    private func normalizeGroupOrder() {
        templateGroups.sort { $0.sortOrder == $1.sortOrder ? $0.createdAt < $1.createdAt : $0.sortOrder < $1.sortOrder }
        for index in templateGroups.indices { templateGroups[index].sortOrder = index }
    }

    private func retainTemplateRevisionLimit(for templateID: UUID) {
        let revisions = templateRevisions
            .filter { $0.templateID == templateID }
            .sorted {
                if $0.number != $1.number { return $0.number > $1.number }
                return $0.createdAt > $1.createdAt
            }
        let retainedIDs = Set(revisions.prefix(50).map(\.id))
        templateRevisions.removeAll { $0.templateID == templateID && !retainedIDs.contains($0.id) }
    }

    // MARK: Resolution and rendering

    /// Finds the best active template. Empty audiences are generic fallbacks; a non-empty
    /// audience is only eligible when it contains the requested value.
    func resolveTemplate(
        occasion: Occasion,
        relationship: Relationship? = nil,
        channel: ContactMethod? = nil,
        language: String? = nil
    ) -> GreetingTemplate? {
        let requestedLanguage = language?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return templates
            .filter { !$0.isArchived && $0.occasions.contains(occasion) }
            .filter { template in
                relationship == nil || template.relationships.isEmpty || template.relationships.contains(relationship!)
            }
            .filter { template in
                channel == nil || template.channels.isEmpty || template.channels.contains(channel!)
            }
            .filter { template in
                guard let requestedLanguage, !requestedLanguage.isEmpty, !template.languages.isEmpty else { return true }
                return template.languages.contains { $0.lowercased() == requestedLanguage }
            }
            .sorted { lhs, rhs in
                let left = resolutionScore(lhs, relationship: relationship, channel: channel, language: requestedLanguage)
                let right = resolutionScore(rhs, relationship: relationship, channel: channel, language: requestedLanguage)
                if left != right { return left > right }
                if lhs.usageCount != rhs.usageCount { return lhs.usageCount > rhs.usageCount }
                if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            .first
    }

    func resolveTemplate(
        for person: Person,
        occasion: Occasion,
        channel: ContactMethod? = nil,
        language: String? = nil
    ) -> GreetingTemplate? {
        resolveTemplate(
            occasion: occasion,
            relationship: person.relationship,
            channel: channel ?? person.preferredContactMethod,
            language: language ?? person.preferredLanguage
        )
    }

    private func resolutionScore(
        _ template: GreetingTemplate,
        relationship: Relationship?,
        channel: ContactMethod?,
        language: String?
    ) -> Int {
        var score = 0
        if relationship != nil && !template.relationships.isEmpty { score += 16 }
        if channel != nil && !template.channels.isEmpty { score += 8 }
        if let language, !language.isEmpty, template.languages.contains(where: { $0.lowercased() == language }) { score += 8 }
        if template.isDefault { score += 4 }
        if template.isFavorite { score += 2 }
        if template.isBuiltIn { score += 1 }
        return score
    }

    func renderedBody(
        for template: GreetingTemplate?,
        person: Person,
        occasion: Occasion,
        date: Date? = nil,
        occasionName: String? = nil,
        senderName: String = AppPreferences.storedSenderName
    ) -> String {
        let source = template?.body
            ?? "Wishing you a wonderful \((normalizedCustomName(occasionName) ?? occasion.title).lowercased()), {{first_name}}!"
        return renderTokens(
            source,
            person: person,
            occasion: occasion,
            date: date,
            occasionName: occasionName,
            senderName: senderName
        )
    }

    func renderedEmailSubject(
        for template: GreetingTemplate,
        person: Person,
        occasion: Occasion,
        date: Date? = nil,
        occasionName: String? = nil,
        senderName: String = AppPreferences.storedSenderName
    ) -> String? {
        guard let subject = template.emailSubject, !subject.isEmpty else { return nil }
        return renderTokens(
            subject,
            person: person,
            occasion: occasion,
            date: date,
            occasionName: occasionName,
            senderName: senderName
        )
    }

    /// Converts literal recipient names in an edited greeting back into supported
    /// placeholders. Full name is checked first so a first-name replacement can never
    /// partially corrupt it.
    func templateTextReplacingRecipientNames(_ text: String, person: Person) -> String {
        let fullName = person.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstName = fullName.split(separator: " ").first.map(String.init) ?? fullName
        guard !fullName.isEmpty else { return text }
        var result = text.replacingOccurrences(of: fullName, with: "{{name}}")
        if !firstName.isEmpty, firstName != fullName {
            result = result.replacingOccurrences(of: firstName, with: "{{first_name}}")
        }
        return result
    }

    @discardableResult
    func saveAsTemplate(for eventID: UUID, title: String? = nil) -> GreetingTemplate? {
        guard let event = events.first(where: { $0.id == eventID }),
              let person = people.first(where: { $0.id == event.personID }) else { return nil }
        var template = GreetingTemplate(
            title: title ?? event.occasion.title + " message",
            occasions: [event.occasion],
            body: templateTextReplacingRecipientNames(event.message, person: person),
            iconSemantic: "occasion", iconID: event.occasion.icon,
            colorToken: event.occasion.defaultColorToken,
            relationships: [person.relationship], channels: [event.method],
            languages: [person.preferredLanguage]
        )
        if let subject = event.subject {
            template.emailSubject = templateTextReplacingRecipientNames(subject, person: person)
        }
        guard addTemplate(template) else { return nil }
        return templates.first(where: { $0.id == template.id }) ?? template
    }

    @discardableResult
    func saveGreetingAsTemplate(eventID: UUID, title: String? = nil) -> GreetingTemplate? {
        saveAsTemplate(for: eventID, title: title)
    }

    private func renderTokens(
        _ source: String,
        person: Person,
        occasion: Occasion,
        date: Date?,
        occasionName: String? = nil,
        senderName: String
    ) -> String {
        let firstName = person.name.split(separator: " ").first.map(String.init) ?? person.name
        let dateText = recipientDateText(date ?? .now, person: person)
        let renderedOccasion = normalizedCustomName(occasionName) ?? occasion.title
        return source
            .replacingOccurrences(of: "{{first_name}}", with: firstName)
            .replacingOccurrences(of: "{{name}}", with: person.name)
            .replacingOccurrences(of: "{{organization}}", with: person.organization)
            .replacingOccurrences(of: "{{occasion}}", with: renderedOccasion)
            .replacingOccurrences(of: "{{date}}", with: dateText)
            .replacingOccurrences(of: "{{sender_name}}", with: senderName.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func normalizedCustomName(_ name: String?) -> String? {
        guard let name else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func recipientDateText(_ date: Date, person: Person) -> String {
        var style = Date.FormatStyle(date: .long, time: .omitted)
        style.timeZone = TimeZone(identifier: person.timeZoneIdentifier) ?? .current
        return date.formatted(style)
    }

    @discardableResult
    func recordTemplateUsage(id: UUID, at date: Date = .now) -> Bool {
        guard templates.contains(where: { $0.id == id }) else { return false }
        let previous = mutableState
        recordUsage(
            templateID: id,
            revision: templates.first(where: { $0.id == id })?.revisionNumber,
            eventID: nil,
            kind: .scheduled,
            occasion: nil,
            channel: nil,
            at: date,
            incrementSummary: true
        )
        guard save() else { restore(previous); return false }
        return true
    }

    /// Records that a composer was opened for a scheduled event. This is intentionally
    /// separate from completion because opening a composer is not evidence of delivery.
    @discardableResult
    func recordComposerOpened(eventID: UUID, at date: Date = .now) -> Bool {
        guard let event = events.first(where: { $0.id == eventID }),
              let templateID = event.sourceTemplateID else { return false }
        let previous = mutableState
        recordUsage(
            templateID: templateID,
            revision: event.sourceTemplateRevision,
            eventID: eventID,
            kind: .composerOpened,
            occasion: event.occasion,
            channel: event.method,
            at: date,
            incrementSummary: false
        )
        guard save() else { restore(previous); return false }
        return true
    }

    private func recordUsage(
        templateID: UUID,
        revision: Int?,
        eventID: UUID?,
        kind: TemplateUsageKind,
        occasion: Occasion?,
        channel: ContactMethod?,
        at date: Date,
        incrementSummary: Bool
    ) {
        templateUsage.append(
            TemplateUsageRecord(
                templateID: templateID,
                templateRevision: revision,
                eventID: eventID,
                occurredAt: date,
                kind: kind,
                occasion: occasion,
                channel: channel
            )
        )
        if incrementSummary,
           let index = templates.firstIndex(where: { $0.id == templateID }) {
            templates[index].usageCount += 1
            templates[index].lastUsedAt = date
        }
    }

    func event(id: UUID) -> GreetingEvent? {
        events.first { $0.id == id }
    }

    /// Adds a single manually planned greeting. This is the entry point for custom,
    /// one-time, and annual events created outside the bulk year planner.
    @discardableResult
    func addGreeting(_ event: GreetingEvent) -> Bool {
        guard people.contains(where: { $0.id == event.personID }) else {
            persistenceError = "The selected person is no longer available."
            return false
        }
        let previous = mutableState
        events.append(event)
        if let templateID = event.sourceTemplateID,
           templates.contains(where: { $0.id == templateID }) {
            recordUsage(
                templateID: templateID,
                revision: event.sourceTemplateRevision,
                eventID: event.id,
                kind: .scheduled,
                occasion: event.occasion,
                channel: event.method,
                at: .now,
                incrementSummary: true
            )
        }
        guard save() else { restore(previous); return false }
        return true
    }

    @discardableResult
    func completeGreeting(id: UUID) -> Bool {
        guard let index = events.firstIndex(where: { $0.id == id }) else { return false }
        guard events[index].status != .completed else { return true }
        let previous = mutableState
        events[index].status = .completed
        ensureNextAnnualOccurrence(after: events[index])
        if let templateID = events[index].sourceTemplateID {
            recordUsage(
                templateID: templateID,
                revision: events[index].sourceTemplateRevision,
                eventID: id,
                kind: .completed,
                occasion: events[index].occasion,
                channel: events[index].method,
                at: .now,
                incrementSummary: false
            )
        }
        guard save() else { restore(previous); return false }
        return true
    }

    @discardableResult
    func skipGreeting(id: UUID) -> Bool {
        guard let index = events.firstIndex(where: { $0.id == id }) else { return false }
        guard events[index].status != .skipped else { return true }
        let previous = mutableState
        events[index].status = .skipped
        ensureNextAnnualOccurrence(after: events[index])
        if let templateID = events[index].sourceTemplateID {
            recordUsage(
                templateID: templateID,
                revision: events[index].sourceTemplateRevision,
                eventID: id,
                kind: .skipped,
                occasion: events[index].occasion,
                channel: events[index].method,
                at: .now,
                incrementSummary: false
            )
        }
        guard save() else { restore(previous); return false }
        return true
    }

    /// Keeps an annual series alive when its current occurrence is completed or skipped.
    /// A matching future occurrence is never duplicated.
    private func ensureNextAnnualOccurrence(after event: GreetingEvent) {
        guard event.recurrence == .annual,
              let person = people.first(where: { $0.id == event.personID }) else { return }
        let calendar = calendar(for: person)
        var nextDate = calendar.date(byAdding: .year, value: 1, to: event.date) ?? event.date
        while nextDate <= Date.now {
            guard let advanced = calendar.date(byAdding: .year, value: 1, to: nextDate) else { return }
            nextDate = advanced
        }
        let duplicateExists = events.contains { candidate in
            candidate.id != event.id
                && candidate.personID == event.personID
                && candidate.occasion == event.occasion
                && candidate.customName == event.customName
                && calendar.isDate(candidate.date, inSameDayAs: nextDate)
        }
        guard !duplicateExists else { return }

        let sourceTemplate = event.sourceTemplateID.flatMap { id in templates.first { $0.id == id } }
        let message = sourceTemplate.map {
            renderedBody(
                for: $0,
                person: person,
                occasion: event.occasion,
                date: nextDate,
                occasionName: event.customName
            )
        } ?? event.message
        let subject = sourceTemplate.flatMap {
            renderedEmailSubject(
                for: $0,
                person: person,
                occasion: event.occasion,
                date: nextDate,
                occasionName: event.customName
            )
        } ?? event.subject
        events.append(GreetingEvent(
            personID: event.personID,
            occasion: event.occasion,
            date: nextDate,
            method: event.method,
            status: .planned,
            message: message,
            subject: subject,
            sourceTemplateID: event.sourceTemplateID,
            sourceTemplateRevision: event.sourceTemplateRevision,
            customName: event.customName,
            recurrence: .annual
        ))
    }

    @discardableResult
    func restoreGreeting(id: UUID) -> Bool {
        guard let index = events.firstIndex(where: { $0.id == id }), events[index].status == .skipped else { return false }
        let previous = mutableState
        events[index].status = .planned
        guard save() else { restore(previous); return false }
        return true
    }

    @discardableResult
    func updateGreetingMessage(id: UUID, message: String) -> Bool {
        guard let index = events.firstIndex(where: { $0.id == id }) else { return false }
        guard events[index].message != message else { return true }
        let previous = mutableState
        events[index].message = message
        if let templateID = events[index].sourceTemplateID {
            recordUsage(
                templateID: templateID,
                revision: events[index].sourceTemplateRevision,
                eventID: id,
                kind: .messageEdited,
                occasion: events[index].occasion,
                channel: events[index].method,
                at: .now,
                incrementSummary: false
            )
        }
        guard save() else { restore(previous); return false }
        return true
    }

    /// Updates all editable scheduling fields in one atomic operation.
    @discardableResult
    func updateGreeting(_ event: GreetingEvent) -> Bool {
        guard let index = events.firstIndex(where: { $0.id == event.id }) else { return false }
        let previous = mutableState
        events[index] = event
        guard save() else { restore(previous); return false }
        return true
    }

    @discardableResult
    func deleteGreeting(id: UUID) -> Bool {
        guard let index = events.firstIndex(where: { $0.id == id }) else { return false }
        let previous = mutableState
        events.remove(at: index)
        templateUsage.removeAll { $0.eventID == id }
        guard save() else { restore(previous); return false }
        return true
    }

    @discardableResult
    func rescheduleGreeting(id: UUID, date: Date, method: ContactMethod? = nil) -> Bool {
        guard let index = events.firstIndex(where: { $0.id == id }) else { return false }
        let previous = mutableState
        let person = people.first { $0.id == events[index].personID }
        if let person {
            let requested = method ?? events[index].method
            guard let resolved = resolvedContactMethod(for: person, preferred: requested) else {
                persistenceError = "No available contact method for this recipient."
                return false
            }
            events[index].method = resolved
        } else if let method { events[index].method = method }
        events[index].date = date
        guard save() else { restore(previous); return false }
        return true
    }

    @discardableResult
    func updateGreetingDate(id: UUID, date: Date) -> Bool { rescheduleGreeting(id: id, date: date) }

    /// Contact methods are resolved from actual recipient data. Reminder is always
    /// available and the enum order makes fallback deterministic: SMS, email, reminder.
    func availableContactMethods(for person: Person) -> [ContactMethod] {
        var result: [ContactMethod] = []
        if !person.phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { result.append(.sms) }
        if !person.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { result.append(.email) }
        result.append(.reminder)
        return result
    }

    func contactMethods(for person: Person) -> [ContactMethod] {
        availableContactMethods(for: person)
    }

    func resolvedContactMethod(for person: Person, preferred: ContactMethod? = nil) -> ContactMethod? {
        let available = availableContactMethods(for: person)
        if let preferred, available.contains(preferred) { return preferred }
        return available.first
    }

    func resolvedContactMethod(for person: Person, requested: ContactMethod?) -> ContactMethod? {
        resolvedContactMethod(for: person, preferred: requested)
    }

    func contactMethodDiagnostics(for person: Person, requested: ContactMethod) -> String? {
        guard !availableContactMethods(for: person).contains(requested) else { return nil }
        let fallback = resolvedContactMethod(for: person, preferred: nil)?.title ?? "none"
        return requested.title + " is unavailable because this recipient has no matching contact detail. Using " + fallback + "."
    }

    func contactMethodDiagnostic(for person: Person, requested: ContactMethod) -> String? {
        contactMethodDiagnostics(for: person, requested: requested)
    }

    func status(for event: GreetingEvent) -> GreetingStatus {
        if event.status == .planned && event.date <= .now {
            return .ready
        }
        return event.status
    }

    @discardableResult
    func scheduleYear(
        personIDs: Set<UUID>,
        occasions: Set<Occasion>,
        method: ContactMethod,
        templateIDsByOccasion: [Occasion: UUID] = [:],
        templateIDsByPersonAndOccasion: [UUID: [Occasion: UUID]] = [:],
        usePreferredContactMethods: Bool = false,
        senderName: String = AppPreferences.storedSenderName
    ) -> Int {
        let referenceDate = Date.now
        let previous = mutableState
        let selectedPeople = people.filter { personIDs.contains($0.id) }
        var created = 0

        for person in selectedPeople {
            let calendar = calendar(for: person)
            for occasion in occasions {
                let occurrences = plannedOccurrences(
                    for: occasion,
                    person: person,
                    after: referenceDate,
                    calendar: calendar
                )
                for occurrence in occurrences {
                    let date = occurrence.date
                    let customName = occurrence.customName
                    guard !isAlreadyScheduled(
                        personID: person.id,
                        occasion: occasion,
                        customName: customName,
                        date: date,
                        calendar: calendar
                    ) else { continue }

                    guard let resolvedMethod = resolvedContactMethod(
                        for: person,
                        preferred: usePreferredContactMethods ? person.preferredContactMethod : method
                    ) else { continue }
                    // A recipient exception is the most specific choice. If one is not set,
                    // preserve the occasion-wide override, then fall back to contextual resolution.
                    let recipientTemplate = templateIDsByPersonAndOccasion[person.id]?[occasion].flatMap { templateID in
                        templates.first { $0.id == templateID && !$0.isArchived && $0.occasions.contains(occasion) }
                    }
                    let occasionTemplate = templateIDsByOccasion[occasion].flatMap { templateID in
                        templates.first { $0.id == templateID && !$0.isArchived && $0.occasions.contains(occasion) }
                    }
                    let explicitTemplate = recipientTemplate ?? occasionTemplate
                    let template = explicitTemplate ?? resolveTemplate(
                        for: person,
                        occasion: occasion,
                        channel: resolvedMethod
                    )

                    let eventID = UUID()
                    events.append(
                        GreetingEvent(
                            id: eventID,
                            personID: person.id,
                            occasion: occasion,
                            date: date,
                            method: resolvedMethod,
                            status: .planned,
                            message: renderedBody(
                                for: template,
                                person: person,
                                occasion: occasion,
                                date: date,
                                occasionName: customName,
                                senderName: senderName
                            ),
                            subject: template.flatMap {
                                renderedEmailSubject(
                                    for: $0,
                                    person: person,
                                    occasion: occasion,
                                    date: date,
                                    occasionName: customName,
                                    senderName: senderName
                                )
                            },
                            sourceTemplateID: template?.id,
                            sourceTemplateRevision: template?.revisionNumber,
                            customName: customName
                        )
                    )
                    if let template {
                        recordUsage(
                            templateID: template.id,
                            revision: template.revisionNumber,
                            eventID: eventID,
                            kind: .scheduled,
                            occasion: occasion,
                            channel: resolvedMethod,
                            at: referenceDate,
                            incrementSummary: true
                        )
                    }
                    created += 1
                }
            }
        }

        if created > 0 {
            guard save() else { restore(previous); return 0 }
        }
        return created
    }

    func schedulableGreetingCount(
        personIDs: Set<UUID>,
        occasions: Set<Occasion>
    ) -> Int {
        let referenceDate = Date.now

        return people
            .filter { personIDs.contains($0.id) }
            .reduce(into: 0) { count, person in
                let calendar = calendar(for: person)
                for occasion in occasions {
                    for occurrence in plannedOccurrences(
                        for: occasion,
                        person: person,
                        after: referenceDate,
                        calendar: calendar
                    ) {
                        guard !isAlreadyScheduled(
                            personID: person.id,
                            occasion: occasion,
                            customName: occurrence.customName,
                            date: occurrence.date,
                            calendar: calendar
                        ) else {
                            continue
                        }
                        count += 1
                    }
                }
            }
    }

    private func isAlreadyScheduled(
        personID: UUID,
        occasion: Occasion,
        customName: String? = nil,
        date: Date,
        calendar: Calendar
    ) -> Bool {
        events.contains {
            $0.personID == personID
                && $0.occasion == occasion
                && (occasion != .custom || normalizedCustomName($0.customName) == normalizedCustomName(customName))
                && calendar.isDate($0.date, inSameDayAs: date)
        }
    }

    private func plannedOccurrences(
        for occasion: Occasion,
        person: Person,
        after referenceDate: Date,
        calendar: Calendar
    ) -> [(date: Date, customName: String?)] {
        if occasion == .custom {
            return person.importantDates
                .filter { $0.occasion == .custom }
                .compactMap { importantDate in
                    guard let date = nextDate(
                        for: occasion,
                        person: person,
                        after: referenceDate,
                        calendar: calendar,
                        importantDate: importantDate
                    ) else { return nil }
                    return (date, normalizedCustomName(importantDate.customName))
                }
        }

        guard let date = nextDate(
            for: occasion,
            person: person,
            after: referenceDate,
            calendar: calendar
        ) else { return [] }
        let customName = person.importantDates
            .first(where: { $0.occasion == occasion })
            .flatMap { normalizedCustomName($0.customName) }
        return [(date, customName)]
    }

    private func nextDate(
        for occasion: Occasion,
        person: Person,
        after referenceDate: Date,
        calendar: Calendar,
        importantDate: ImportantDate? = nil
    ) -> Date? {
        let startOfRecipientDay = calendar.startOfDay(for: referenceDate)
        let currentYear = calendar.component(.year, from: referenceDate)

        for year in currentYear...(currentYear + 1) {
            guard let candidate = occurrenceDate(
                for: occasion,
                person: person,
                year: year,
                calendar: calendar,
                importantDate: importantDate
            ) else {
                return nil
            }
            if candidate >= startOfRecipientDay {
                return candidate
            }
        }

        return nil
    }

    private func occurrenceDate(
        for occasion: Occasion,
        person: Person,
        year: Int,
        calendar: Calendar,
        importantDate: ImportantDate? = nil
    ) -> Date? {
        switch occasion {
        case .clientAppreciation:
            if let saved = person.importantDates.first(where: { $0.occasion == occasion }) {
                return fixedOccurrence(month: saved.month, day: saved.day, year: year, calendar: calendar)
            }
            return fixedOccurrence(month: 11, day: 5, year: year, calendar: calendar)
        case .birthday, .homeAnniversary, .weddingAnniversary, .workAnniversary, .custom:
            guard let saved = importantDate ?? person.importantDates.first(where: { $0.occasion == occasion }) else {
                return nil
            }
            return fixedOccurrence(month: saved.month, day: saved.day, year: year, calendar: calendar)
        case .newYearsDay:
            return fixedOccurrence(month: 1, day: 1, year: year, calendar: calendar)
        case .martinLutherKingJrDay:
            return weekdayOccurrence(month: 1, weekday: 2, ordinal: 3, year: year, calendar: calendar)
        case .presidentsDay:
            return weekdayOccurrence(month: 2, weekday: 2, ordinal: 3, year: year, calendar: calendar)
        case .memorialDay:
            return lastWeekdayOccurrence(month: 5, weekday: 2, year: year, calendar: calendar)
        case .juneteenth:
            return fixedOccurrence(month: 6, day: 19, year: year, calendar: calendar)
        case .independenceDay:
            return fixedOccurrence(month: 7, day: 4, year: year, calendar: calendar)
        case .laborDay:
            return weekdayOccurrence(month: 9, weekday: 2, ordinal: 1, year: year, calendar: calendar)
        case .columbusDay:
            return weekdayOccurrence(month: 10, weekday: 2, ordinal: 2, year: year, calendar: calendar)
        case .veteransDay:
            return fixedOccurrence(month: 11, day: 11, year: year, calendar: calendar)
        case .thanksgiving:
            return weekdayOccurrence(month: 11, weekday: 5, ordinal: 4, year: year, calendar: calendar)
        case .christmas:
            return fixedOccurrence(month: 12, day: 25, year: year, calendar: calendar)
        case .valentinesDay:
            return fixedOccurrence(month: 2, day: 14, year: year, calendar: calendar)
        case .internationalWomensDay:
            return fixedOccurrence(month: 3, day: 8, year: year, calendar: calendar)
        case .earthDay:
            return fixedOccurrence(month: 4, day: 22, year: year, calendar: calendar)
        case .mothersDay:
            return weekdayOccurrence(month: 5, weekday: 1, ordinal: 2, year: year, calendar: calendar)
        case .fathersDay:
            return weekdayOccurrence(month: 6, weekday: 1, ordinal: 3, year: year, calendar: calendar)
        case .halloween:
            return fixedOccurrence(month: 10, day: 31, year: year, calendar: calendar)
        case .threeKingsDay:
            return fixedOccurrence(month: 1, day: 6, year: year, calendar: calendar)
        case .cincoDeMayo:
            return fixedOccurrence(month: 5, day: 5, year: year, calendar: calendar)
        case .mexicanMothersDay:
            return fixedOccurrence(month: 5, day: 10, year: year, calendar: calendar)
        case .mexicanIndependenceDay:
            return fixedOccurrence(month: 9, day: 16, year: year, calendar: calendar)
        case .hispanicHeritageMonth:
            return fixedOccurrence(month: 9, day: 15, year: year, calendar: calendar)
        case .diaDeLaRaza:
            return fixedOccurrence(month: 10, day: 12, year: year, calendar: calendar)
        case .diaDeLosMuertos:
            return fixedOccurrence(month: 11, day: 2, year: year, calendar: calendar)
        case .ourLadyOfGuadalupe:
            return fixedOccurrence(month: 12, day: 12, year: year, calendar: calendar)
        case .lasPosadas:
            return fixedOccurrence(month: 12, day: 16, year: year, calendar: calendar)
        case .nochebuena:
            return fixedOccurrence(month: 12, day: 24, year: year, calendar: calendar)
        case .franceNationalDay:
            return fixedOccurrence(month: 7, day: 14, year: year, calendar: calendar)
        case .franceVictoryInEuropeDay:
            return fixedOccurrence(month: 5, day: 8, year: year, calendar: calendar)
        case .franceArmisticeDay:
            return fixedOccurrence(month: 11, day: 11, year: year, calendar: calendar)
        case .germanLaborDay:
            return fixedOccurrence(month: 5, day: 1, year: year, calendar: calendar)
        case .germanUnityDay:
            return fixedOccurrence(month: 10, day: 3, year: year, calendar: calendar)
        case .germanReformationDay:
            return fixedOccurrence(month: 10, day: 31, year: year, calendar: calendar)
        case .italianLiberationDay:
            return fixedOccurrence(month: 4, day: 25, year: year, calendar: calendar)
        case .italianRepublicDay:
            return fixedOccurrence(month: 6, day: 2, year: year, calendar: calendar)
        case .italianAssumptionDay:
            return fixedOccurrence(month: 8, day: 15, year: year, calendar: calendar)
        case .portugalFreedomDay:
            return fixedOccurrence(month: 4, day: 25, year: year, calendar: calendar)
        case .portugalDay:
            return fixedOccurrence(month: 6, day: 10, year: year, calendar: calendar)
        case .portugalRepublicDay:
            return fixedOccurrence(month: 10, day: 5, year: year, calendar: calendar)
        case .russiaDefenderOfFatherlandDay:
            return fixedOccurrence(month: 2, day: 23, year: year, calendar: calendar)
        case .russiaVictoryDay:
            return fixedOccurrence(month: 5, day: 9, year: year, calendar: calendar)
        case .russiaDay:
            return fixedOccurrence(month: 6, day: 12, year: year, calendar: calendar)
        case .russiaNationalUnityDay:
            return fixedOccurrence(month: 11, day: 4, year: year, calendar: calendar)
        case .ukraineConstitutionDay:
            return fixedOccurrence(month: 6, day: 28, year: year, calendar: calendar)
        case .ukraineIndependenceDay:
            return fixedOccurrence(month: 8, day: 24, year: year, calendar: calendar)
        case .ukraineDefendersDay:
            return fixedOccurrence(month: 10, day: 1, year: year, calendar: calendar)
        case .japanNationalFoundationDay:
            return fixedOccurrence(month: 2, day: 11, year: year, calendar: calendar)
        case .japanConstitutionMemorialDay:
            return fixedOccurrence(month: 5, day: 3, year: year, calendar: calendar)
        case .japanCultureDay:
            return fixedOccurrence(month: 11, day: 3, year: year, calendar: calendar)
        case .japanLaborThanksgivingDay:
            return fixedOccurrence(month: 11, day: 23, year: year, calendar: calendar)
        case .koreaIndependenceMovementDay:
            return fixedOccurrence(month: 3, day: 1, year: year, calendar: calendar)
        case .koreaLiberationDay:
            return fixedOccurrence(month: 8, day: 15, year: year, calendar: calendar)
        case .koreaNationalFoundationDay:
            return fixedOccurrence(month: 10, day: 3, year: year, calendar: calendar)
        case .koreaHangulDay:
            return fixedOccurrence(month: 10, day: 9, year: year, calendar: calendar)
        case .chinaLaborDay:
            return fixedOccurrence(month: 5, day: 1, year: year, calendar: calendar)
        case .chinaNationalDay:
            return fixedOccurrence(month: 10, day: 1, year: year, calendar: calendar)
        }
    }

    private func fixedOccurrence(month: Int, day: Int, year: Int, calendar: Calendar) -> Date? {
        let resolvedDay = validDay(
            month: month,
            requestedDay: day,
            year: year,
            calendar: calendar
        )
        var components = DateComponents()
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = resolvedDay
        components.hour = 9
        return calendar.date(from: components)
    }

    private func weekdayOccurrence(
        month: Int,
        weekday: Int,
        ordinal: Int,
        year: Int,
        calendar: Calendar
    ) -> Date? {
        var components = DateComponents()
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.weekday = weekday
        components.weekdayOrdinal = ordinal
        components.hour = 9
        return calendar.date(from: components)
    }

    private func lastWeekdayOccurrence(
        month: Int,
        weekday: Int,
        year: Int,
        calendar: Calendar
    ) -> Date? {
        var components = DateComponents()
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month + 1
        components.day = 0
        components.hour = 9
        guard let lastDay = calendar.date(from: components) else { return nil }
        let currentWeekday = calendar.component(.weekday, from: lastDay)
        let daysBack = (currentWeekday - weekday + 7) % 7
        return calendar.date(byAdding: .day, value: -daysBack, to: lastDay)
    }

    private func validDay(
        month: Int,
        requestedDay: Int,
        year: Int,
        calendar: Calendar
    ) -> Int {
        var components = DateComponents()
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = 1
        guard let date = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: date) else {
            return requestedDay
        }
        return min(requestedDay, range.count)
    }

    private func calendar(for person: Person) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: person.timeZoneIdentifier) ?? .current
        return calendar
    }

    @discardableResult
    private func save(preservingModifiedAt: Bool = false) -> Bool {
        // Preview stores intentionally have no backing file and remain mutable in memory.
        guard let persistenceURL else {
            if allowsEphemeralPersistence { return true }
            persistenceError = "Changes cannot be saved because local storage is unavailable."
            return false
        }

        do {
            try FileManager.default.createDirectory(
                at: persistenceURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let snapshotModifiedAt = preservingModifiedAt && lastModifiedAt != .distantPast ? lastModifiedAt : Date.now
            let snapshot = StoredAppData(
                version: Self.currentPersistenceVersion,
                modifiedAt: snapshotModifiedAt,
                people: people,
                events: events,
                templates: templates,
                templateGroups: templateGroups,
                templateRevisions: templateRevisions,
                templateUsage: templateUsage
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let encoded = try encoder.encode(snapshot)
            try encoded.write(to: persistenceURL, options: .atomic)
            // Protect private contact data while keeping background notification access
            // available after the first device unlock.
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: persistenceURL.path
            )
            lastModifiedAt = snapshotModifiedAt
            persistenceError = nil
            return true
        } catch {
            persistenceError = "Changes could not be saved on this device. \(error.localizedDescription)"
            return false
        }
    }

    private func upgradeTemplateLibraryIfNeeded() {
        func group(named name: String, icon: String, color: String) -> TemplateGroup {
            if let existing = templateGroups.first(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
                return existing
            }
            let group = TemplateGroup(
                name: name,
                iconSemantic: name.lowercased(),
                iconID: icon,
                colorToken: color,
                sortOrder: templateGroups.count
            )
            templateGroups.append(group)
            return group
        }

        let personal = group(named: "Personal", icon: "heart", color: "rose")
        let work = group(named: "Work", icon: "briefcase", color: "teal")
        let seasonal = group(named: "Seasonal", icon: "gift", color: "forest")

        for index in templates.indices where templates[index].groupID == nil {
            if templates[index].occasions.contains(.clientAppreciation) {
                templates[index].groupID = work.id
            } else if templates[index].occasions.contains(.christmas) || templates[index].occasions.contains(.thanksgiving) {
                templates[index].groupID = seasonal.id
            } else {
                templates[index].groupID = personal.id
            }
        }

        let builtIns = Self.builtInTemplates(
            personalGroupID: personal.id,
            workGroupID: work.id,
            seasonalGroupID: seasonal.id
        )
        for builtIn in builtIns {
            if let index = templates.firstIndex(where: {
                $0.title.localizedCaseInsensitiveCompare(builtIn.title) == .orderedSame
            }) {
                // v1/v2 shipped these texts without library metadata. Preserve the text itself,
                // but promote the known starter entries into the richer built-in library.
                templates[index].isBuiltIn = true
                templates[index].groupID = builtIn.groupID
                templates[index].iconSemantic = builtIn.iconSemantic
                templates[index].iconID = builtIn.iconID
                templates[index].colorToken = builtIn.colorToken
                if templates[index].relationships.isEmpty { templates[index].relationships = builtIn.relationships }
                if templates[index].channels.isEmpty { templates[index].channels = builtIn.channels }
                if templates[index].languages.isEmpty { templates[index].languages = builtIn.languages }
                if templates[index].emailSubject == nil { templates[index].emailSubject = builtIn.emailSubject }
                templates[index].isDefault = builtIn.isDefault
            } else {
                templates.append(builtIn)
            }
        }
        for index in templates.indices where templates[index].isBuiltIn {
            templates[index].isApproved = true
            templates[index].approvedAt = templates[index].approvedAt ?? templates[index].createdAt
            templates[index].isLocked = true
        }
        normalizeGroupOrder()
    }

    private static func builtInTemplates(
        personalGroupID: UUID,
        workGroupID: UUID,
        seasonalGroupID: UUID
    ) -> [GreetingTemplate] {
        [
            GreetingTemplate(
                title: "Warm and simple", occasions: [.birthday],
                body: "Happy birthday, {{first_name}}! Wishing you a wonderful day and a bright year ahead.",
                isFavorite: true, iconID: "birthday.cake", colorToken: "coral", groupID: personalGroupID,
                relationships: [.family, .friend], channels: [.sms], languages: ["English"], isDefault: true, isBuiltIn: true
            ),
            GreetingTemplate(
                title: "Birthday note", occasions: [.birthday],
                body: "Happy birthday, {{first_name}}! I hope the year ahead brings plenty of reasons to celebrate.",
                iconID: "envelope", colorToken: "coral", groupID: personalGroupID,
                relationships: [.family, .friend], channels: [.email], languages: ["English"],
                emailSubject: "Happy birthday, {{first_name}}", isDefault: true, isBuiltIn: true
            ),
            GreetingTemplate(
                title: "Un cumpleaños especial", occasions: [.birthday],
                body: "¡Feliz cumpleaños, {{first_name}}! Que tengas un día maravilloso y un año lleno de alegrías.",
                iconID: "birthday.cake", colorToken: "coral", groupID: personalGroupID,
                relationships: [.family, .friend], channels: [.sms, .email], languages: ["Spanish"], isDefault: true, isBuiltIn: true
            ),
            GreetingTemplate(
                title: "A year at home", occasions: [.homeAnniversary],
                body: "Happy home anniversary, {{first_name}}! I hope your home is still your favorite place to be.",
                isFavorite: true, iconID: "house", colorToken: "blue", groupID: personalGroupID,
                relationships: [.family, .friend], languages: ["English"], isDefault: true, isBuiltIn: true
            ),
            GreetingTemplate(
                title: "Celebrate together", occasions: [.weddingAnniversary],
                body: "Happy anniversary! Wishing you both another year full of great memories.",
                iconID: "heart", colorToken: "rose", groupID: personalGroupID,
                relationships: [.family, .friend], channels: [.sms], languages: ["English"], isDefault: true, isBuiltIn: true
            ),
            GreetingTemplate(
                title: "Anniversary letter", occasions: [.weddingAnniversary],
                body: "Warm wishes on your anniversary. May the next chapter bring even more joy to you both.",
                iconID: "envelope", colorToken: "rose", groupID: personalGroupID,
                relationships: [.family, .friend], channels: [.email], languages: ["English"],
                emailSubject: "Warm anniversary wishes", isDefault: true, isBuiltIn: true
            ),
            GreetingTemplate(
                title: "Professional birthday", occasions: [.birthday],
                body: "Happy birthday, {{first_name}}! Wishing you continued success and a wonderful year ahead.",
                iconID: "briefcase", colorToken: "teal", groupID: workGroupID,
                relationships: [.client, .colleague], channels: [.email, .sms], languages: ["English"], isDefault: true, isBuiltIn: true
            ),
            GreetingTemplate(
                title: "Client thank you", occasions: [.clientAppreciation],
                body: "Thinking of you today, {{first_name}}. Thank you for trusting me to be part of your journey.",
                iconID: "hands.sparkles", colorToken: "teal", groupID: workGroupID,
                relationships: [.client], channels: [.email, .sms], languages: ["English"],
                emailSubject: "Thank you, {{first_name}}", isDefault: true, isBuiltIn: true
            ),
            GreetingTemplate(
                title: "A client home milestone", occasions: [.homeAnniversary],
                body: "Happy home anniversary, {{first_name}}! I hope this milestone still brings you plenty of joy.",
                iconID: "house", colorToken: "teal", groupID: workGroupID,
                relationships: [.client], channels: [.email], languages: ["English"],
                emailSubject: "Happy home anniversary", isDefault: true, isBuiltIn: true
            ),
            GreetingTemplate(
                title: "Grateful for you", occasions: [.thanksgiving],
                body: "Happy Thanksgiving, {{first_name}}! I am grateful to have you in my life.",
                iconID: "leaf", colorToken: "amber", groupID: seasonalGroupID,
                relationships: [.family, .friend], channels: [.sms], languages: ["English"], isDefault: true, isBuiltIn: true
            ),
            GreetingTemplate(
                title: "Thanksgiving appreciation", occasions: [.thanksgiving],
                body: "This Thanksgiving, I wanted to say how much I appreciate our relationship. Warm wishes to you, {{first_name}}.",
                iconID: "leaf", colorToken: "amber", groupID: seasonalGroupID,
                relationships: [.client, .colleague], channels: [.email], languages: ["English"],
                emailSubject: "With appreciation this Thanksgiving", isDefault: true, isBuiltIn: true
            ),
            GreetingTemplate(
                title: "Merry and bright", occasions: [.christmas],
                body: "Merry Christmas, {{first_name}}! Wishing you a joyful day and a bright holiday season.",
                iconID: "gift", colorToken: "forest", groupID: seasonalGroupID,
                relationships: [.family, .friend], channels: [.sms], languages: ["English"], isDefault: true, isBuiltIn: true
            ),
            GreetingTemplate(
                title: "Holiday appreciation", occasions: [.christmas],
                body: "Warm holiday wishes, {{first_name}}. Thank you for being an important part of this year.",
                iconID: "gift", colorToken: "forest", groupID: seasonalGroupID,
                relationships: [.client, .colleague], channels: [.email], languages: ["English"],
                emailSubject: "Warm holiday wishes", isDefault: true, isBuiltIn: true
            )
        ]
    }
}

extension AppStore {
    static var live: AppStore {
        guard let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return AppStore(
                people: [], events: [], templates: preview.templates,
                templateGroups: preview.templateGroups,
                persistenceError: "Local storage is unavailable on this device.",
                allowsEphemeralPersistence: false
            )
        }

        let url = applicationSupport
            .appendingPathComponent("TouchPoint", isDirectory: true)
            .appendingPathComponent("touchpoint-data.json")

        guard FileManager.default.fileExists(atPath: url.path) else {
            let store = AppStore(
                people: [], events: [], templates: [], templateGroups: [],
                persistenceURL: url,
                corruptSnapshotBackupURL: recoverableSnapshotURL()
            )
            store.upgradeTemplateLibraryIfNeeded()
            store.save()
            return store
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let size = attributes[.size] as? NSNumber,
               size.intValue > Self.maximumArchiveBytes {
                throw AppPersistenceError.archiveTooLarge
            }
            let snapshot = try decoder.decode(StoredAppData.self, from: Data(contentsOf: url))
            guard (1...Self.currentPersistenceVersion).contains(snapshot.version) else {
                throw AppPersistenceError.unsupportedVersion(snapshot.version)
            }
            try validate(AppDataSnapshot(
                version: snapshot.version,
                modifiedAt: snapshot.modifiedAt,
                people: snapshot.people,
                events: snapshot.events,
                templates: snapshot.templates,
                groups: snapshot.templateGroups,
                revisions: snapshot.templateRevisions,
                usage: snapshot.templateUsage
            ))
            let store = AppStore(
                people: snapshot.people,
                events: snapshot.events,
                templates: snapshot.templates,
                templateGroups: snapshot.templateGroups,
                templateRevisions: snapshot.templateRevisions,
                templateUsage: snapshot.templateUsage,
                persistenceURL: url,
                corruptSnapshotBackupURL: recoverableSnapshotURL(),
                lastModifiedAt: snapshot.modifiedAt
            )
            if snapshot.version < Self.currentPersistenceVersion {
                store.upgradeTemplateLibraryIfNeeded()
                store.save()
            }
            return store
        } catch {
            let backupURL = Self.backupCorruptSnapshot(at: url)
            let recoveryMessage = backupURL == nil
                ? "Saved data could not be loaded and a recovery copy could not be created. The original file was left untouched."
                : "Saved data could not be loaded. A recovery backup was created; the workspace starts empty."
            let store = AppStore(
                people: [], events: [], templates: [], templateGroups: [],
                persistenceURL: backupURL == nil ? nil : url,
                persistenceError: recoveryMessage,
                corruptSnapshotBackupURL: backupURL,
                allowsEphemeralPersistence: backupURL != nil
            )
            store.upgradeTemplateLibraryIfNeeded()
            // Replace the unreadable primary file with a valid empty workspace only
            // after preserving the original bytes in the recovery backup. This avoids
            // repeating the same failed migration on every launch.
            if backupURL != nil { _ = store.save() }
            store.persistenceError = recoveryMessage
            return store
        }
    }

    private static func backupCorruptSnapshot(at url: URL) -> URL? {
        guard let payload = try? Data(contentsOf: url) else { return nil }
        let stamp = ISO8601DateFormatter().string(from: .now).replacingOccurrences(of: ":", with: "-")
        let backup = url.deletingLastPathComponent().appendingPathComponent("touchpoint-data.corrupt-\(stamp).json")
        do {
            try payload.write(to: backup, options: .atomic)
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: backup.path
            )
            UserDefaults.standard.set(backup.path, forKey: recoveryBackupPathKey)
            return backup
        } catch { return nil }
    }

    private static func recoverableSnapshotURL() -> URL? {
        guard let path = UserDefaults.standard.string(forKey: recoveryBackupPathKey),
              FileManager.default.fileExists(atPath: path) else {
            UserDefaults.standard.removeObject(forKey: recoveryBackupPathKey)
            return nil
        }
        return URL(fileURLWithPath: path)
    }

    static var preview: AppStore {
        let people = [
            Person(name: "Anna Smith", email: "anna@example.com", phone: "+1 415 555 0136", organization: "Smith Realty", relationship: .client, importantDates: [.init(occasion: .birthday, month: 9, day: 2), .init(occasion: .homeAnniversary, month: 10, day: 3)]),
            Person(name: "Marcus Lee", email: "marcus@example.com", phone: "+1 206 555 0174", relationship: .friend, timeZoneIdentifier: "America/Denver", importantDates: [.init(occasion: .birthday, month: 10, day: 18), .init(occasion: .homeAnniversary, month: 9, day: 4)]),
            Person(name: "Sofia Ramirez", email: "sofia@example.com", phone: "+1 512 555 0191", organization: "Ramirez Family", relationship: .client, preferredContactMethod: .email, preferredLanguage: "Spanish", timeZoneIdentifier: "America/Chicago", importantDates: [.init(occasion: .birthday, month: 9, day: 7)]),
            Person(name: "Daniel Kim", email: "daniel@example.com", phone: "+1 917 555 0128", organization: "Northstar Lending", relationship: .colleague, timeZoneIdentifier: "America/New_York", importantDates: [.init(occasion: .birthday, month: 12, day: 8)]),
            Person(name: "Maya Thompson", email: "maya@example.com", phone: "+1 310 555 0182", relationship: .family, importantDates: [.init(occasion: .birthday, month: 5, day: 20), .init(occasion: .weddingAnniversary, month: 9, day: 20)])
        ]

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        func date(_ offset: Int, hour: Int = 9) -> Date {
            let day = calendar.date(byAdding: .day, value: offset, to: today) ?? today
            return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
        }

        let events = [
            GreetingEvent(personID: people[0].id, occasion: .birthday, date: date(0, hour: 8), method: .sms, status: .planned, message: "Happy birthday, Anna! Wishing you a bright year ahead."),
            GreetingEvent(personID: people[1].id, occasion: .homeAnniversary, date: date(2), method: .sms, status: .planned, message: "One year already. Hope your home is still your favorite place."),
            GreetingEvent(personID: people[2].id, occasion: .birthday, date: date(5, hour: 10), method: .email, status: .planned, message: "Feliz cumpleanos, Sofia!"),
            GreetingEvent(personID: people[3].id, occasion: .clientAppreciation, date: date(9), method: .reminder, status: .planned),
            GreetingEvent(personID: people[4].id, occasion: .weddingAnniversary, date: date(18), method: .sms, status: .planned),
            GreetingEvent(personID: people[1].id, occasion: .birthday, date: date(-2), method: .sms, status: .completed)
        ]

        let personalGroup = TemplateGroup(name: "Personal", iconSemantic: "personal", iconID: "heart", colorToken: "rose", sortOrder: 0)
        let workGroup = TemplateGroup(name: "Work", iconSemantic: "work", iconID: "briefcase", colorToken: "teal", sortOrder: 1)
        let seasonalGroup = TemplateGroup(name: "Seasonal", iconSemantic: "seasonal", iconID: "gift", colorToken: "forest", sortOrder: 2)
        let templateGroups = [personalGroup, workGroup, seasonalGroup]

        let templates = builtInTemplates(
            personalGroupID: personalGroup.id,
            workGroupID: workGroup.id,
            seasonalGroupID: seasonalGroup.id
        )

        return AppStore(people: people, events: events, templates: templates, templateGroups: templateGroups)
    }
}

private struct StoredAppData: Codable {
    let version: Int
    let modifiedAt: Date
    let people: [Person]
    let events: [GreetingEvent]
    let templates: [GreetingTemplate]
    let templateGroups: [TemplateGroup]
    let templateRevisions: [TemplateRevision]
    let templateUsage: [TemplateUsageRecord]

    init(
        version: Int,
        modifiedAt: Date = .now,
        people: [Person],
        events: [GreetingEvent],
        templates: [GreetingTemplate],
        templateGroups: [TemplateGroup] = [],
        templateRevisions: [TemplateRevision] = [],
        templateUsage: [TemplateUsageRecord] = []
    ) {
        self.version = version
        self.modifiedAt = modifiedAt
        self.people = people
        self.events = events
        self.templates = templates
        self.templateGroups = templateGroups
        self.templateRevisions = templateRevisions
        self.templateUsage = templateUsage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        modifiedAt = try container.decodeIfPresent(Date.self, forKey: .modifiedAt) ?? .distantPast
        people = try container.decodeIfPresent([Person].self, forKey: .people) ?? []
        events = try container.decodeIfPresent([GreetingEvent].self, forKey: .events) ?? []
        templates = try container.decodeIfPresent([GreetingTemplate].self, forKey: .templates) ?? []
        templateGroups = try container.decodeIfPresent([TemplateGroup].self, forKey: .templateGroups) ?? []
        templateRevisions = try container.decodeIfPresent([TemplateRevision].self, forKey: .templateRevisions) ?? []
        templateUsage = try container.decodeIfPresent([TemplateUsageRecord].self, forKey: .templateUsage) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case version, modifiedAt, people, events, templates, templateGroups, templateRevisions, templateUsage
    }
}

enum AppPersistenceError: LocalizedError {
    case unsupportedVersion(Int)
    case archiveTooLarge
    case invalidArchive(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            "TouchPoint data version \(version) is not supported by this build."
        case .archiveTooLarge:
            "The archive is larger than the 25 MB safety limit."
        case .invalidArchive(let reason):
            "The archive is inconsistent: \(reason)"
        }
    }
}

/// Stable, complete application payload used for backup/restore and CloudKit sync.
/// No UI-only or device-specific values are included.
struct AppDataSnapshot: Codable, Equatable {
    let version: Int
    let modifiedAt: Date
    let people: [Person]
    let events: [GreetingEvent]
    let templates: [GreetingTemplate]
    let groups: [TemplateGroup]
    let revisions: [TemplateRevision]
    let usage: [TemplateUsageRecord]

    init(version: Int = AppStore.currentPersistenceVersion, modifiedAt: Date = .now,
         people: [Person], events: [GreetingEvent], templates: [GreetingTemplate],
         groups: [TemplateGroup] = [], revisions: [TemplateRevision] = [],
         usage: [TemplateUsageRecord] = []) {
        self.version = version; self.modifiedAt = modifiedAt
        self.people = people; self.events = events; self.templates = templates
        self.groups = groups; self.revisions = revisions; self.usage = usage
    }

    /// Compatibility aliases make this payload convenient for services that use the
    /// local store's naming (`templateGroups`, `templateRevisions`, `templateUsage`).
    var templateGroups: [TemplateGroup] { groups }
    var templateRevisions: [TemplateRevision] { revisions }
    var templateUsage: [TemplateUsageRecord] { usage }

    private enum CodingKeys: String, CodingKey {
        case version, modifiedAt, people, events, templates, groups, templateGroups
        case revisions, templateRevisions, usage, templateUsage
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        modifiedAt = try c.decodeIfPresent(Date.self, forKey: .modifiedAt) ?? .distantPast
        people = try c.decodeIfPresent([Person].self, forKey: .people) ?? []
        events = try c.decodeIfPresent([GreetingEvent].self, forKey: .events) ?? []
        templates = try c.decodeIfPresent([GreetingTemplate].self, forKey: .templates) ?? []
        groups = try c.decodeIfPresent([TemplateGroup].self, forKey: .groups)
            ?? (try c.decodeIfPresent([TemplateGroup].self, forKey: .templateGroups)) ?? []
        revisions = try c.decodeIfPresent([TemplateRevision].self, forKey: .revisions)
            ?? (try c.decodeIfPresent([TemplateRevision].self, forKey: .templateRevisions)) ?? []
        usage = try c.decodeIfPresent([TemplateUsageRecord].self, forKey: .usage)
            ?? (try c.decodeIfPresent([TemplateUsageRecord].self, forKey: .templateUsage)) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(version, forKey: .version); try c.encode(modifiedAt, forKey: .modifiedAt)
        try c.encode(people, forKey: .people)
        try c.encode(events, forKey: .events); try c.encode(templates, forKey: .templates)
        try c.encode(groups, forKey: .groups); try c.encode(revisions, forKey: .revisions)
        try c.encode(usage, forKey: .usage)
        // Keep the explicit local names in the archive as well; this allows older
        // CloudKit/export clients to consume a complete payload without adapters.
        try c.encode(groups, forKey: .templateGroups)
        try c.encode(revisions, forKey: .templateRevisions)
        try c.encode(usage, forKey: .templateUsage)
    }
}

typealias DataSnapshot = AppDataSnapshot
typealias AppArchive = AppDataSnapshot

extension AppStore {
    var dataSnapshot: AppDataSnapshot {
        AppDataSnapshot(modifiedAt: lastModifiedAt, people: people, events: events, templates: templates,
                        groups: templateGroups, revisions: templateRevisions, usage: templateUsage)
    }

    func exportSnapshot() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(dataSnapshot)
    }

    func exportArchive() throws -> Data { try exportSnapshot() }
    func exportData() throws -> Data { try exportSnapshot() }

    /// Replaces the complete store only after decoding and validating the payload.
    /// On a persistence failure all in-memory values are restored.
    @discardableResult
    func importSnapshot(_ data: Data, preservingModifiedAt: Bool = false) -> Bool {
        do {
            guard data.count <= Self.maximumArchiveBytes else { throw AppPersistenceError.archiveTooLarge }
            let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
            let snapshot = try decoder.decode(AppDataSnapshot.self, from: data)
            guard (1...Self.currentPersistenceVersion).contains(snapshot.version) else {
                throw AppPersistenceError.unsupportedVersion(snapshot.version)
            }
            try Self.validate(snapshot)
            let previous = mutableState
            people = snapshot.people; events = snapshot.events; templates = snapshot.templates
            templateGroups = snapshot.groups; templateRevisions = snapshot.revisions; templateUsage = snapshot.usage
            if snapshot.version < Self.currentPersistenceVersion { upgradeTemplateLibraryIfNeeded() }
            lastModifiedAt = snapshot.modifiedAt
            let canPreserveTimestamp = preservingModifiedAt
                && snapshot.version == Self.currentPersistenceVersion
                && snapshot.modifiedAt != .distantPast
            guard save(preservingModifiedAt: canPreserveTimestamp) else {
                restore(previous)
                return false
            }
            return true
        } catch {
            persistenceError = "This backup could not be imported. \(error.localizedDescription)"
            return false
        }
    }

    @discardableResult
    func importArchive(_ data: Data, preservingModifiedAt: Bool = false) -> Bool {
        importSnapshot(data, preservingModifiedAt: preservingModifiedAt)
    }
    @discardableResult
    func importData(_ data: Data) -> Bool { importSnapshot(data) }

    private static func validate(_ snapshot: AppDataSnapshot) throws {
        func requireUnique(_ ids: [UUID], label: String) throws {
            guard Set(ids).count == ids.count else {
                throw AppPersistenceError.invalidArchive("duplicate \(label) identifiers")
            }
        }
        try requireUnique(snapshot.people.map(\.id), label: "person")
        try requireUnique(snapshot.events.map(\.id), label: "greeting")
        try requireUnique(snapshot.templates.map(\.id), label: "template")
        try requireUnique(snapshot.groups.map(\.id), label: "collection")
        try requireUnique(snapshot.revisions.map(\.id), label: "revision")
        try requireUnique(snapshot.usage.map(\.id), label: "usage")

        let personIDs = Set(snapshot.people.map(\.id))
        guard snapshot.events.allSatisfy({ personIDs.contains($0.personID) }) else {
            throw AppPersistenceError.invalidArchive("a greeting refers to a missing person")
        }
        guard snapshot.people.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw AppPersistenceError.invalidArchive("a person has no name")
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        for date in snapshot.people.flatMap(\.importantDates) {
            var components = DateComponents()
            components.calendar = calendar
            components.timeZone = calendar.timeZone
            components.year = 2000
            components.month = date.month
            components.day = date.day
            guard let resolved = calendar.date(from: components),
                  calendar.component(.month, from: resolved) == date.month,
                  calendar.component(.day, from: resolved) == date.day else {
                throw AppPersistenceError.invalidArchive("an important date is invalid")
            }
            if date.occasion == .custom,
               date.customName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                throw AppPersistenceError.invalidArchive("a custom important date has no name")
            }
        }
        guard snapshot.events.allSatisfy({ event in
            event.occasion != .custom
                || event.customName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        }) else {
            throw AppPersistenceError.invalidArchive("a custom greeting has no name")
        }

        let groupIDs = Set(snapshot.groups.map(\.id))
        guard snapshot.templates.allSatisfy({ template in
            template.groupID.map(groupIDs.contains) ?? true
        }) else {
            throw AppPersistenceError.invalidArchive("a template refers to a missing collection")
        }
        let templateIDs = Set(snapshot.templates.map(\.id))
        guard snapshot.revisions.allSatisfy({ templateIDs.contains($0.templateID) }) else {
            throw AppPersistenceError.invalidArchive("a revision refers to a missing template")
        }
        guard snapshot.usage.allSatisfy({ templateIDs.contains($0.templateID) }) else {
            throw AppPersistenceError.invalidArchive("usage refers to a missing template")
        }
    }

    /// Reads a recoverable corrupt payload without changing the active store.
    func recoverableSnapshotData() -> Data? {
        guard let url = corruptSnapshotBackupURL else { return nil }
        return try? Data(contentsOf: url)
    }

    /// Explicitly retries a previously backed-up payload. The active state changes only
    /// if decoding and persistence both succeed.
    @discardableResult
    func restoreCorruptSnapshot() -> Bool {
        guard let data = recoverableSnapshotData() else { return false }
        guard importSnapshot(data) else { return false }
        corruptSnapshotBackupURL = nil
        UserDefaults.standard.removeObject(forKey: Self.recoveryBackupPathKey)
        return true
    }
}

private struct MutableState {
    let people: [Person]
    let events: [GreetingEvent]
    let templates: [GreetingTemplate]
    let groups: [TemplateGroup]
    let revisions: [TemplateRevision]
    let usage: [TemplateUsageRecord]
    let lastModifiedAt: Date
}
