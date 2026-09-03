import Foundation
import Observation

@Observable
final class AppStore {
    var people: [Person]
    var events: [GreetingEvent]
    var templates: [GreetingTemplate]

    init(people: [Person], events: [GreetingEvent], templates: [GreetingTemplate]) {
        self.people = people
        self.events = events
        self.templates = templates
    }

    func person(for event: GreetingEvent) -> Person? {
        people.first { $0.id == event.personID }
    }

    func addPerson(_ person: Person) {
        people.append(person)
    }

    func addTemplate(_ template: GreetingTemplate) {
        templates.append(template)
    }

    func event(id: UUID) -> GreetingEvent? {
        events.first { $0.id == id }
    }

    func completeGreeting(id: UUID) {
        guard let index = events.firstIndex(where: { $0.id == id }) else { return }
        events[index].status = .completed
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
        method: ContactMethod
    ) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let selectedPeople = people.filter { personIDs.contains($0.id) }
        var created = 0

        for person in selectedPeople {
            for occasion in occasions {
                guard let date = nextDate(for: occasion, person: person, after: start) else { continue }
                let alreadyScheduled = events.contains {
                    $0.personID == person.id &&
                    $0.occasion == occasion &&
                    calendar.isDate($0.date, inSameDayAs: date)
                }
                guard !alreadyScheduled else { continue }

                events.append(
                    GreetingEvent(
                        personID: person.id,
                        occasion: occasion,
                        date: date,
                        method: method,
                        status: .planned,
                        message: "Wishing you a wonderful \(occasion.rawValue.lowercased()), \(person.name.split(separator: " ").first.map(String.init) ?? person.name)!"
                    )
                )
                created += 1
            }
        }

        return created
    }

    private func nextDate(for occasion: Occasion, person: Person, after start: Date) -> Date? {
        let calendar = Calendar.current
        let components: DateComponents?

        switch occasion {
        case .christmas:
            components = DateComponents(month: 12, day: 25)
        case .thanksgiving:
            components = thanksgivingComponents(after: start)
        case .clientAppreciation:
            components = DateComponents(month: 11, day: 5)
        case .birthday, .homeAnniversary, .weddingAnniversary:
            guard let saved = person.importantDates.first(where: { $0.occasion == occasion }) else { return nil }
            components = DateComponents(month: saved.month, day: saved.day)
        }

        guard let components else { return nil }
        let year = calendar.component(.year, from: start)
        var datedComponents = components
        datedComponents.year = year
        datedComponents.hour = 9
        guard var candidate = calendar.date(from: datedComponents) else { return nil }

        if candidate < start {
            datedComponents.year = year + 1
            guard let nextYear = calendar.date(from: datedComponents) else { return nil }
            candidate = nextYear
        }

        return candidate
    }

    private func thanksgivingComponents(after start: Date) -> DateComponents? {
        let calendar = Calendar.current
        let startYear = calendar.component(.year, from: start)

        for year in startYear...(startYear + 1) {
            var components = DateComponents()
            components.year = year
            components.month = 11
            components.weekday = 5
            components.weekdayOrdinal = 4
            components.hour = 9
            guard let date = calendar.date(from: components) else { continue }
            if date >= start {
                return calendar.dateComponents([.month, .day], from: date)
            }
        }

        return nil
    }
}

extension AppStore {
    static var preview: AppStore {
        let people = [
            Person(name: "Anna Smith", email: "anna@example.com", phone: "+1 415 555 0136", relationship: .client, importantDates: [.init(occasion: .birthday, month: 9, day: 2), .init(occasion: .homeAnniversary, month: 10, day: 3)]),
            Person(name: "Marcus Lee", email: "marcus@example.com", phone: "+1 206 555 0174", relationship: .friend, timeZoneIdentifier: "America/Denver", importantDates: [.init(occasion: .birthday, month: 10, day: 18), .init(occasion: .homeAnniversary, month: 9, day: 4)]),
            Person(name: "Sofia Ramirez", email: "sofia@example.com", phone: "+1 512 555 0191", relationship: .client, preferredLanguage: "Spanish", timeZoneIdentifier: "America/Chicago", importantDates: [.init(occasion: .birthday, month: 9, day: 7)]),
            Person(name: "Daniel Kim", email: "daniel@example.com", phone: "+1 917 555 0128", relationship: .colleague, timeZoneIdentifier: "America/New_York", importantDates: [.init(occasion: .birthday, month: 12, day: 8)]),
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
