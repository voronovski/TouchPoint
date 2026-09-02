import Foundation
import SwiftUI

enum Relationship: String, CaseIterable, Identifiable, Codable {
    case client = "Client"
    case family = "Family"
    case friend = "Friend"
    case colleague = "Colleague"

    var id: Self { self }
}

enum Occasion: String, CaseIterable, Identifiable, Codable {
    case birthday = "Birthday"
    case homeAnniversary = "Home anniversary"
    case weddingAnniversary = "Wedding anniversary"
    case thanksgiving = "Thanksgiving"
    case christmas = "Christmas"
    case clientAppreciation = "Client appreciation"

    var id: Self { self }

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

enum DeliveryMethod: String, CaseIterable, Identifiable, Codable {
    case sms = "Text message"
    case email = "Email"
    case reminder = "Reminder only"

    var id: Self { self }

    var icon: String {
        switch self {
        case .sms: "message"
        case .email: "envelope"
        case .reminder: "bell"
        }
    }
}

enum GreetingStatus: String, CaseIterable, Identifiable, Codable {
    case scheduled = "Scheduled"
    case approval = "Needs approval"
    case sent = "Sent"
    case opened = "Opened"
    case failed = "Failed"

    var id: Self { self }
}

struct Person: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var email: String
    var phone: String
    var relationship: Relationship
    var preferredLanguage: String
    var timeZoneIdentifier: String
    var importantDates: [ImportantDate]

    init(
        id: UUID = UUID(),
        name: String,
        email: String = "",
        phone: String = "",
        relationship: Relationship,
        preferredLanguage: String = "English",
        timeZoneIdentifier: String = "America/Los_Angeles",
        importantDates: [ImportantDate] = []
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.phone = phone
        self.relationship = relationship
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
}

struct GreetingEvent: Identifiable, Hashable, Codable {
    let id: UUID
    var personID: UUID
    var occasion: Occasion
    var date: Date
    var delivery: DeliveryMethod
    var status: GreetingStatus
    var message: String

    init(
        id: UUID = UUID(),
        personID: UUID,
        occasion: Occasion,
        date: Date,
        delivery: DeliveryMethod,
        status: GreetingStatus,
        message: String = ""
    ) {
        self.id = id
        self.personID = personID
        self.occasion = occasion
        self.date = date
        self.delivery = delivery
        self.status = status
        self.message = message
    }
}

struct GreetingTemplate: Identifiable, Hashable {
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
