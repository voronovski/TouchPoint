import Foundation
import Observation

@Observable
final class AppStore {
    private static let currentPersistenceVersion = 5

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
    private let persistenceURL: URL?

    init(
        people: [Person],
        events: [GreetingEvent],
        templates: [GreetingTemplate],
        templateGroups: [TemplateGroup] = [],
        templateRevisions: [TemplateRevision] = [],
        templateUsage: [TemplateUsageRecord] = [],
        persistenceURL: URL? = nil,
        persistenceError: String? = nil
    ) {
        self.people = people
        self.events = events
        self.templates = templates
        self.templateGroups = templateGroups
        self.templateRevisions = templateRevisions
        self.templateUsage = templateUsage
        self.persistenceURL = persistenceURL
        self.persistenceError = persistenceError
    }

    func person(for event: GreetingEvent) -> Person? {
        people.first { $0.id == event.personID }
    }

    func addPerson(_ person: Person) {
        people.append(person)
        save()
    }

    func updatePerson(_ person: Person) {
        guard let index = people.firstIndex(where: { $0.id == person.id }) else { return }
        people[index] = person
        save()
    }

    func addTemplate(_ template: GreetingTemplate) {
        var inserted = template
        if inserted.isBuiltIn {
            inserted.isApproved = true
            inserted.approvedAt = inserted.approvedAt ?? inserted.createdAt
            inserted.isLocked = true
        }
        inserted.revisionNumber = max(1, inserted.revisionNumber)
        templates.append(inserted)
        save()
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
        save()
        return true
    }

    @discardableResult
    func duplicateTemplate(id: UUID, title: String? = nil) -> GreetingTemplate? {
        guard let source = templates.first(where: { $0.id == id }) else { return nil }
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
        save()
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
        templates.remove(at: index)
        templateRevisions.removeAll { $0.templateID == id }
        templateUsage.removeAll { $0.templateID == id }
        save()
        return true
    }

    @discardableResult
    func archiveTemplate(id: UUID, archived: Bool = true) -> Bool {
        guard let index = templates.firstIndex(where: { $0.id == id }) else { return false }
        templates[index].isArchived = archived
        templates[index].updatedAt = .now
        save()
        return true
    }

    @discardableResult
    func setTemplateFavorite(id: UUID, isFavorite: Bool) -> Bool {
        guard let index = templates.firstIndex(where: { $0.id == id }) else { return false }
        templates[index].isFavorite = isFavorite
        templates[index].updatedAt = .now
        save()
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
        templates[index].isApproved = approved
        templates[index].approvedAt = approved ? date : nil
        templates[index].updatedAt = date
        save()
        return true
    }

    /// Locks or unlocks local editing. Built-in templates remain immutable and locked.
    @discardableResult
    func setTemplateLock(id: UUID, locked: Bool) -> Bool {
        guard let index = templates.firstIndex(where: { $0.id == id }) else { return false }
        if templates[index].isBuiltIn && !locked { return false }
        templates[index].isLocked = locked
        templates[index].updatedAt = .now
        save()
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
        save()
        return true
    }

    // MARK: Template groups

    func addTemplateGroup(_ group: TemplateGroup) {
        templateGroups.append(group)
        normalizeGroupOrder()
        save()
    }

    func addGroup(_ group: TemplateGroup) { addTemplateGroup(group) }

    func updateTemplateGroup(_ group: TemplateGroup) {
        guard let index = templateGroups.firstIndex(where: { $0.id == group.id }) else { return }
        var updated = group
        updated.updatedAt = .now
        templateGroups[index] = updated
        save()
    }

    func updateGroup(_ group: TemplateGroup) { updateTemplateGroup(group) }

    @discardableResult
    func deleteTemplateGroup(id: UUID) -> Bool {
        guard let index = templateGroups.firstIndex(where: { $0.id == id }), !templateGroups[index].isBuiltIn else {
            return false
        }
        templateGroups.remove(at: index)
        for templateIndex in templates.indices where templates[templateIndex].groupID == id {
            templates[templateIndex].groupID = nil
            templates[templateIndex].updatedAt = .now
        }
        normalizeGroupOrder()
        save()
        return true
    }

    @discardableResult
    func deleteGroup(id: UUID) -> Bool { deleteTemplateGroup(id: id) }

    @discardableResult
    func reorderTemplateGroups(ids: [UUID]) -> Bool {
        let currentIDs = Set(templateGroups.map(\.id))
        guard currentIDs == Set(ids), ids.count == templateGroups.count else { return false }
        for (order, id) in ids.enumerated() {
            guard let index = templateGroups.firstIndex(where: { $0.id == id }) else { continue }
            templateGroups[index].sortOrder = order
            templateGroups[index].updatedAt = .now
        }
        templateGroups.sort { $0.sortOrder < $1.sortOrder }
        save()
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
        date: Date? = nil
    ) -> String {
        let source = template?.body
            ?? "Wishing you a wonderful \(occasion.title.lowercased()), {{first_name}}!"
        return renderTokens(source, person: person, occasion: occasion, date: date)
    }

    func renderedEmailSubject(
        for template: GreetingTemplate,
        person: Person,
        occasion: Occasion,
        date: Date? = nil
    ) -> String? {
        guard let subject = template.emailSubject, !subject.isEmpty else { return nil }
        return renderTokens(subject, person: person, occasion: occasion, date: date)
    }

    private func renderTokens(_ source: String, person: Person, occasion: Occasion, date: Date?) -> String {
        let firstName = person.name.split(separator: " ").first.map(String.init) ?? person.name
        let dateText = (date ?? .now).formatted(date: .long, time: .omitted)
        return source
            .replacingOccurrences(of: "{{first_name}}", with: firstName)
            .replacingOccurrences(of: "{{name}}", with: person.name)
            .replacingOccurrences(of: "{{organization}}", with: person.organization)
            .replacingOccurrences(of: "{{occasion}}", with: occasion.title)
            .replacingOccurrences(of: "{{date}}", with: dateText)
    }

    @discardableResult
    func recordTemplateUsage(id: UUID, at date: Date = .now) -> Bool {
        guard templates.contains(where: { $0.id == id }) else { return false }
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
        save()
        return true
    }

    /// Records that a composer was opened for a scheduled event. This is intentionally
    /// separate from completion because opening a composer is not evidence of delivery.
    @discardableResult
    func recordComposerOpened(eventID: UUID, at date: Date = .now) -> Bool {
        guard let event = events.first(where: { $0.id == eventID }),
              let templateID = event.sourceTemplateID else { return false }
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
        save()
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

    @discardableResult
    func completeGreeting(id: UUID) -> Bool {
        guard let index = events.firstIndex(where: { $0.id == id }) else { return false }
        guard events[index].status != .completed else { return true }
        events[index].status = .completed
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
        save()
        return true
    }

    @discardableResult
    func skipGreeting(id: UUID) -> Bool {
        guard let index = events.firstIndex(where: { $0.id == id }) else { return false }
        guard events[index].status != .skipped else { return true }
        events[index].status = .skipped
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
        save()
        return true
    }

    @discardableResult
    func restoreGreeting(id: UUID) -> Bool {
        guard let index = events.firstIndex(where: { $0.id == id }), events[index].status == .skipped else { return false }
        events[index].status = .planned
        save()
        return true
    }

    @discardableResult
    func updateGreetingMessage(id: UUID, message: String) -> Bool {
        guard let index = events.firstIndex(where: { $0.id == id }) else { return false }
        guard events[index].message != message else { return true }
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
        save()
        return true
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
        usePreferredContactMethods: Bool = false
    ) -> Int {
        let referenceDate = Date.now
        let selectedPeople = people.filter { personIDs.contains($0.id) }
        var created = 0

        for person in selectedPeople {
            let calendar = calendar(for: person)
            for occasion in occasions {
                guard let date = nextDate(
                    for: occasion,
                    person: person,
                    after: referenceDate,
                    calendar: calendar
                ) else {
                    continue
                }
                guard !isAlreadyScheduled(personID: person.id, occasion: occasion, date: date, calendar: calendar) else {
                    continue
                }

                let resolvedMethod = usePreferredContactMethods ? person.preferredContactMethod : method
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
                        message: renderedBody(for: template, person: person, occasion: occasion, date: date),
                        subject: template.flatMap {
                            renderedEmailSubject(for: $0, person: person, occasion: occasion, date: date)
                        },
                        sourceTemplateID: template?.id,
                        sourceTemplateRevision: template?.revisionNumber
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

        if created > 0 {
            save()
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
                    guard let date = nextDate(
                            for: occasion,
                            person: person,
                            after: referenceDate,
                            calendar: calendar
                          ),
                          !isAlreadyScheduled(
                            personID: person.id,
                            occasion: occasion,
                            date: date,
                            calendar: calendar
                          ) else {
                        continue
                    }
                    count += 1
                }
            }
    }

    private func isAlreadyScheduled(
        personID: UUID,
        occasion: Occasion,
        date: Date,
        calendar: Calendar
    ) -> Bool {
        events.contains {
            $0.personID == personID
                && $0.occasion == occasion
                && calendar.isDate($0.date, inSameDayAs: date)
        }
    }

    private func nextDate(
        for occasion: Occasion,
        person: Person,
        after referenceDate: Date,
        calendar: Calendar
    ) -> Date? {
        let startOfRecipientDay = calendar.startOfDay(for: referenceDate)
        let currentYear = calendar.component(.year, from: referenceDate)

        for year in currentYear...(currentYear + 1) {
            guard let candidate = occurrenceDate(
                for: occasion,
                person: person,
                year: year,
                calendar: calendar
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
        calendar: Calendar
    ) -> Date? {
        if occasion == .thanksgiving {
            var components = DateComponents()
            components.timeZone = calendar.timeZone
            components.year = year
            components.month = 11
            components.weekday = 5
            components.weekdayOrdinal = 4
            components.hour = 9
            return calendar.date(from: components)
        }

        let monthAndDay: (month: Int, day: Int)?
        switch occasion {
        case .christmas:
            monthAndDay = (12, 25)
        case .clientAppreciation:
            monthAndDay = (11, 5)
        case .birthday, .homeAnniversary, .weddingAnniversary:
            guard let saved = person.importantDates.first(where: { $0.occasion == occasion }) else {
                return nil
            }
            monthAndDay = (saved.month, saved.day)
        case .thanksgiving:
            monthAndDay = nil
        }

        guard let monthAndDay else { return nil }
        let day = validDay(
            month: monthAndDay.month,
            requestedDay: monthAndDay.day,
            year: year,
            calendar: calendar
        )
        var components = DateComponents()
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = monthAndDay.month
        components.day = day
        components.hour = 9
        return calendar.date(from: components)
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

    private func save() {
        guard let persistenceURL else { return }

        do {
            try FileManager.default.createDirectory(
                at: persistenceURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let snapshot = StoredAppData(
                version: Self.currentPersistenceVersion,
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
            try encoder.encode(snapshot).write(to: persistenceURL, options: .atomic)
            persistenceError = nil
        } catch {
            persistenceError = "Changes could not be saved on this device. \(error.localizedDescription)"
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
        let seed = preview
        guard let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return AppStore(
                people: seed.people,
                events: seed.events,
                templates: seed.templates,
                templateGroups: seed.templateGroups,
                persistenceError: "Local storage is unavailable on this device."
            )
        }

        let url = applicationSupport
            .appendingPathComponent("TouchPoint", isDirectory: true)
            .appendingPathComponent("touchpoint-data.json")

        guard FileManager.default.fileExists(atPath: url.path) else {
            let store = AppStore(
                people: seed.people,
                events: seed.events,
                templates: seed.templates,
                templateGroups: seed.templateGroups,
                persistenceURL: url
            )
            store.save()
            return store
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let snapshot = try decoder.decode(StoredAppData.self, from: Data(contentsOf: url))
            guard (1...Self.currentPersistenceVersion).contains(snapshot.version) else {
                throw AppPersistenceError.unsupportedVersion(snapshot.version)
            }
            let store = AppStore(
                people: snapshot.people,
                events: snapshot.events,
                templates: snapshot.templates,
                templateGroups: snapshot.templateGroups,
                templateRevisions: snapshot.templateRevisions,
                templateUsage: snapshot.templateUsage,
                persistenceURL: url
            )
            if snapshot.version < Self.currentPersistenceVersion {
                store.upgradeTemplateLibraryIfNeeded()
                store.save()
            }
            return store
        } catch {
            return AppStore(
                people: seed.people,
                events: seed.events,
                templates: seed.templates,
                templateGroups: seed.templateGroups,
                persistenceError: "Saved data could not be loaded. The sample workspace is shown, and changes will not be saved."
            )
        }
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
    let people: [Person]
    let events: [GreetingEvent]
    let templates: [GreetingTemplate]
    let templateGroups: [TemplateGroup]
    let templateRevisions: [TemplateRevision]
    let templateUsage: [TemplateUsageRecord]

    init(
        version: Int,
        people: [Person],
        events: [GreetingEvent],
        templates: [GreetingTemplate],
        templateGroups: [TemplateGroup] = [],
        templateRevisions: [TemplateRevision] = [],
        templateUsage: [TemplateUsageRecord] = []
    ) {
        self.version = version
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
        people = try container.decodeIfPresent([Person].self, forKey: .people) ?? []
        events = try container.decodeIfPresent([GreetingEvent].self, forKey: .events) ?? []
        templates = try container.decodeIfPresent([GreetingTemplate].self, forKey: .templates) ?? []
        templateGroups = try container.decodeIfPresent([TemplateGroup].self, forKey: .templateGroups) ?? []
        templateRevisions = try container.decodeIfPresent([TemplateRevision].self, forKey: .templateRevisions) ?? []
        templateUsage = try container.decodeIfPresent([TemplateUsageRecord].self, forKey: .templateUsage) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case version, people, events, templates, templateGroups, templateRevisions, templateUsage
    }
}

private enum AppPersistenceError: LocalizedError {
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            "TouchPoint data version \(version) is not supported by this build."
        }
    }
}
