import Foundation
import Observation

@Observable
final class AppStore {
    private static let currentPersistenceVersion = 2

    var people: [Person]
    var events: [GreetingEvent]
    var templates: [GreetingTemplate]
    var persistenceError: String?
    private let persistenceURL: URL?

    init(
        people: [Person],
        events: [GreetingEvent],
        templates: [GreetingTemplate],
        persistenceURL: URL? = nil,
        persistenceError: String? = nil
    ) {
        self.people = people
        self.events = events
        self.templates = templates
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
        templates.append(template)
        save()
    }

    func event(id: UUID) -> GreetingEvent? {
        events.first { $0.id == id }
    }

    func completeGreeting(id: UUID) {
        guard let index = events.firstIndex(where: { $0.id == id }) else { return }
        events[index].status = .completed
        save()
    }

    func updateGreetingMessage(id: UUID, message: String) {
        guard let index = events.firstIndex(where: { $0.id == id }) else { return }
        events[index].message = message
        save()
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
        templateIDsByOccasion: [Occasion: UUID] = [:]
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

                let template = templateIDsByOccasion[occasion].flatMap { templateID in
                    templates.first { $0.id == templateID }
                }

                events.append(
                    GreetingEvent(
                        personID: person.id,
                        occasion: occasion,
                        date: date,
                        method: method,
                        status: .planned,
                        message: renderedMessage(template: template, for: person, occasion: occasion)
                    )
                )
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

    private func renderedMessage(
        template: GreetingTemplate?,
        for person: Person,
        occasion: Occasion
    ) -> String {
        let firstName = person.name.split(separator: " ").first.map(String.init) ?? person.name
        let source = template?.message
            ?? "Wishing you a wonderful \(occasion.title.lowercased()), {{first_name}}!"

        return source
            .replacingOccurrences(of: "{{first_name}}", with: firstName)
            .replacingOccurrences(of: "{{name}}", with: person.name)
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
                templates: templates
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
                persistenceURL: url
            )
            if snapshot.version < Self.currentPersistenceVersion {
                store.save()
            }
            return store
        } catch {
            return AppStore(
                people: seed.people,
                events: seed.events,
                templates: seed.templates,
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

        let templates = [
            GreetingTemplate(title: "Warm and simple", occasion: .birthday, message: "Happy birthday, {{first_name}}! Wishing you a wonderful day and a bright year ahead.", isFavorite: true),
            GreetingTemplate(title: "A year at home", occasion: .homeAnniversary, message: "Happy home anniversary, {{first_name}}! I hope your home is still your favorite place to be.", isFavorite: true),
            GreetingTemplate(title: "Client thank you", occasion: .clientAppreciation, message: "Thinking of you today, {{first_name}}. Thank you for trusting me to be part of your journey.", isFavorite: false),
            GreetingTemplate(title: "Celebrate together", occasion: .weddingAnniversary, message: "Happy anniversary! Wishing you both another year full of great memories.", isFavorite: false)
        ]

        return AppStore(people: people, events: events, templates: templates)
    }
}

private struct StoredAppData: Codable {
    let version: Int
    let people: [Person]
    let events: [GreetingEvent]
    let templates: [GreetingTemplate]
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
