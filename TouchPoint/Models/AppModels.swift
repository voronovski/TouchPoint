import Foundation
import SwiftUI

protocol StableStringCodable: RawRepresentable, Codable where RawValue == String {
    static var legacyRawValues: [String: Self] { get }
}

extension StableStringCodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        guard let decoded = Self(rawValue: value) ?? Self.legacyRawValues[value] else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported \(Self.self) value: \(value)"
            )
        }
        self = decoded
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum Relationship: String, CaseIterable, Identifiable, StableStringCodable {
    case client
    case family
    case friend
    case colleague

    var id: Self { self }

    static let legacyRawValues: [String: Relationship] = [
        "Client": .client,
        "Family": .family,
        "Friend": .friend,
        "Colleague": .colleague
    ]

    var title: String {
        switch self {
        case .client: "Client"
        case .family: "Family"
        case .friend: "Friend"
        case .colleague: "Colleague"
        }
    }
}

enum Occasion: String, CaseIterable, Identifiable, StableStringCodable {
    case birthday
    case homeAnniversary = "home_anniversary"
    case weddingAnniversary = "wedding_anniversary"
    case thanksgiving
    case christmas
    case clientAppreciation = "client_appreciation"

    var id: Self { self }

    static let legacyRawValues: [String: Occasion] = [
        "Birthday": .birthday,
        "Home anniversary": .homeAnniversary,
        "Wedding anniversary": .weddingAnniversary,
        "Thanksgiving": .thanksgiving,
        "Christmas": .christmas,
        "Client appreciation": .clientAppreciation
    ]

    var title: String {
        switch self {
        case .birthday: "Birthday"
        case .homeAnniversary: "Home anniversary"
        case .weddingAnniversary: "Wedding anniversary"
        case .thanksgiving: "Thanksgiving"
        case .christmas: "Christmas"
        case .clientAppreciation: "Client appreciation"
        }
    }

    static let contactSpecificCases: [Occasion] = [
        .birthday,
        .homeAnniversary,
        .weddingAnniversary,
        .clientAppreciation
    ]

    var icon: String {
        switch self {
        case .birthday: "birthday.cake"
        case .homeAnniversary: "house"
        case .weddingAnniversary: "heart"
        case .thanksgiving: "leaf"
        case .christmas: "gift"
        case .clientAppreciation: "hands.sparkles"
        }
    }

    var tint: Color {
        switch self {
        case .birthday: TouchPointColor.coral
        case .homeAnniversary: .accentColor
        case .weddingAnniversary: TouchPointColor.rose
        case .thanksgiving: TouchPointColor.amber
        case .christmas: TouchPointColor.forest
        case .clientAppreciation: TouchPointColor.teal
        }
    }
}

enum ContactMethod: String, CaseIterable, Identifiable, StableStringCodable {
    case sms
    case email
    case reminder

    var id: Self { self }

    static let legacyRawValues: [String: ContactMethod] = [
        "Text message": .sms,
        "Email": .email,
        "Reminder only": .reminder
    ]

    var title: String {
        switch self {
        case .sms: "Text message"
        case .email: "Email"
        case .reminder: "Reminder only"
        }
    }

    var icon: String {
        switch self {
        case .sms: "message"
        case .email: "envelope"
        case .reminder: "bell"
        }
    }
}

enum GreetingStatus: String, CaseIterable, Identifiable, StableStringCodable {
    case planned
    case ready
    case completed
    case skipped

    var id: Self { self }

    static let legacyRawValues: [String: GreetingStatus] = [
        "Planned": .planned,
        "Ready": .ready,
        "Completed": .completed,
        "Skipped": .skipped
    ]

    var title: String {
        switch self {
        case .planned: "Planned"
        case .ready: "Ready"
        case .completed: "Completed"
        case .skipped: "Skipped"
        }
    }
}

struct Person: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var email: String
    var phone: String
    var organization: String
    var relationship: Relationship
    var preferredContactMethod: ContactMethod
    var preferredLanguage: String
    var timeZoneIdentifier: String
    var importantDates: [ImportantDate]

    init(
        id: UUID = UUID(),
        name: String,
        email: String = "",
        phone: String = "",
        organization: String = "",
        relationship: Relationship,
        preferredContactMethod: ContactMethod = .sms,
        preferredLanguage: String = "English",
        timeZoneIdentifier: String = "America/Los_Angeles",
        importantDates: [ImportantDate] = []
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.phone = phone
        self.organization = organization
        self.relationship = relationship
        self.preferredContactMethod = preferredContactMethod
        self.preferredLanguage = preferredLanguage
        self.timeZoneIdentifier = timeZoneIdentifier
        self.importantDates = importantDates
    }

    var initials: String {
        name.split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }
}

struct ImportantDate: Identifiable, Hashable, Codable {
    let id: UUID
    var occasion: Occasion
    var month: Int
    var day: Int

    init(id: UUID = UUID(), occasion: Occasion, month: Int, day: Int) {
        self.id = id
        self.occasion = occasion
        self.month = month
        self.day = day
    }

    var formatted: String {
        var components = DateComponents()
        components.calendar = .current
        components.year = 2000
        components.month = month
        components.day = day
        guard let date = components.date else { return "Date unavailable" }
        return date.formatted(.dateTime.month(.wide).day())
    }
}

struct GreetingEvent: Identifiable, Hashable, Codable {
    let id: UUID
    var personID: UUID
    var occasion: Occasion
    var date: Date
    var method: ContactMethod
    var status: GreetingStatus
    var message: String

    init(
        id: UUID = UUID(),
        personID: UUID,
        occasion: Occasion,
        date: Date,
        method: ContactMethod,
        status: GreetingStatus,
        message: String = ""
    ) {
        self.id = id
        self.personID = personID
        self.occasion = occasion
        self.date = date
        self.method = method
        self.status = status
        self.message = message
    }
}

struct GreetingTemplate: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var occasion: Occasion
    var message: String
    var isFavorite: Bool

    init(id: UUID = UUID(), title: String, occasion: Occasion, message: String, isFavorite: Bool) {
        self.id = id
        self.title = title
        self.occasion = occasion
        self.message = message
        self.isFavorite = isFavorite
    }
}

enum PlanningHorizon: String, CaseIterable, Identifiable {
    case today = "Today"
    case week = "7 days"
    case month = "30 days"

    var id: Self { self }

    var days: Int {
        switch self {
        case .today: 1
        case .week: 7
        case .month: 30
        }
    }
}
