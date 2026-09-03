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
    var subject: String?

    init(
        id: UUID = UUID(),
        personID: UUID,
        occasion: Occasion,
        date: Date,
        method: ContactMethod,
        status: GreetingStatus,
        message: String = "",
        subject: String? = nil
    ) {
        self.id = id
        self.personID = personID
        self.occasion = occasion
        self.date = date
        self.method = method
        self.status = status
        self.message = message
        self.subject = subject
    }
}

/// A user-manageable collection for organizing templates.
struct TemplateGroup: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var iconSemantic: String
    var iconID: String
    var colorToken: String
    var sortOrder: Int
    var isBuiltIn: Bool
    var isArchived: Bool
    let createdAt: Date
    var updatedAt: Date

    var title: String {
        get { name }
        set { name = newValue }
    }

    var icon: String {
        get { iconID }
        set { iconID = newValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        iconSemantic: String = "folder",
        iconID: String = "folder",
        colorToken: String = "teal",
        sortOrder: Int = 0,
        isBuiltIn: Bool = false,
        isArchived: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.iconSemantic = iconSemantic
        self.iconID = iconID
        self.colorToken = colorToken
        self.sortOrder = sortOrder
        self.isBuiltIn = isBuiltIn
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct GreetingTemplate: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    /// The occasions this template can be used for. `occasion` remains available for the current UI.
    var occasions: [Occasion]
    var body: String
    var isFavorite: Bool
    var iconSemantic: String
    var iconID: String
    var colorToken: String
    var groupID: UUID?
    var relationships: [Relationship]
    var channels: [ContactMethod]
    var languages: [String]
    var emailSubject: String?
    var isDefault: Bool
    var isBuiltIn: Bool
    var isArchived: Bool
    let createdAt: Date
    var updatedAt: Date
    var usageCount: Int
    var lastUsedAt: Date?

    /// The legacy single-occasion API used by the existing views.
    var occasion: Occasion {
        get { occasions.first ?? .birthday }
        set {
            occasions = [newValue] + occasions.filter { $0 != newValue }
        }
    }

    /// The legacy message API used by the existing views and v1/v2 data.
    var message: String {
        get { body }
        set { body = newValue }
    }

    var icon: String {
        get { iconID }
        set { iconID = newValue }
    }

    /// Descriptive aliases for clients that prefer the audience terminology.
    var relationshipAudiences: [Relationship] {
        get { relationships }
        set { relationships = newValue }
    }

    var channelAudiences: [ContactMethod] {
        get { channels }
        set { channels = newValue }
    }

    init(
        id: UUID = UUID(),
        title: String,
        occasion: Occasion,
        message: String,
        isFavorite: Bool = false
    ) {
        self.init(
            id: id,
            title: title,
            occasions: [occasion],
            body: message,
            isFavorite: isFavorite,
            iconSemantic: "occasion",
            iconID: occasion.icon,
            colorToken: occasion.defaultColorToken
        )
    }

    init(
        id: UUID = UUID(),
        title: String,
        occasion: Occasion,
        body: String,
        isFavorite: Bool = false
    ) {
        self.init(id: id, title: title, occasion: occasion, message: body, isFavorite: isFavorite)
    }

    init(
        id: UUID = UUID(),
        title: String,
        occasions: [Occasion],
        body: String,
        isFavorite: Bool = false,
        iconSemantic: String = "occasion",
        iconID: String? = nil,
        colorToken: String? = nil,
        groupID: UUID? = nil,
        relationships: [Relationship] = [],
        channels: [ContactMethod] = [],
        languages: [String] = [],
        emailSubject: String? = nil,
        isDefault: Bool = false,
        isBuiltIn: Bool = false,
        isArchived: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        usageCount: Int = 0,
        lastUsedAt: Date? = nil
    ) {
        var normalizedOccasions: [Occasion] = []
        for occasion in occasions where !normalizedOccasions.contains(occasion) {
            normalizedOccasions.append(occasion)
        }
        if normalizedOccasions.isEmpty { normalizedOccasions = [.birthday] }
        self.id = id
        self.title = title
        self.occasions = normalizedOccasions
        self.body = body
        self.isFavorite = isFavorite
        self.iconSemantic = iconSemantic
        self.iconID = iconID ?? normalizedOccasions.first?.icon ?? "text.quote"
        self.colorToken = colorToken ?? normalizedOccasions.first?.defaultColorToken ?? "teal"
        self.groupID = groupID
        self.relationships = relationships
        self.channels = channels
        self.languages = languages
        self.emailSubject = emailSubject
        self.isDefault = isDefault
        self.isBuiltIn = isBuiltIn
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.usageCount = max(0, usageCount)
        self.lastUsedAt = lastUsedAt
    }

    /// The supported interpolation tokens, without braces.
    static let supportedTokens: Set<String> = ["first_name", "name", "organization", "occasion", "date"]

    var validationErrors: [String] {
        var errors: [String] = []
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errors.append("A title is required.") }
        if body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errors.append("A body is required.") }
        if occasions.isEmpty { errors.append("At least one occasion is required.") }
        let tokenPattern = #"\{\{([A-Za-z0-9_]+)\}\}"#
        for source in [body, emailSubject ?? ""] where !source.isEmpty {
            let openingCount = source.components(separatedBy: "{{").count - 1
            let closingCount = source.components(separatedBy: "}}").count - 1
            if openingCount != closingCount {
                errors.append("A template variable has unmatched braces.")
            }
            if let regex = try? NSRegularExpression(pattern: tokenPattern) {
                let range = NSRange(source.startIndex..., in: source)
                for match in regex.matches(in: source, range: range) {
                    guard let tokenRange = Range(match.range(at: 1), in: source) else { continue }
                    let token = String(source[tokenRange])
                    if !Self.supportedTokens.contains(token) {
                        errors.append("Unsupported token: {{\(token)}}.")
                    }
                }
            }
        }
        return Array(Set(errors)).sorted()
    }

    func validate() -> [String] { validationErrors }

    enum CodingKeys: String, CodingKey {
        case id, title, occasion, occasions, body, message, isFavorite
        case iconSemantic, iconID, icon, colorToken, groupID
        case relationships, relationshipAudiences, channels, channelAudiences, languages
        case emailSubject, isDefault, isBuiltIn, isArchived, createdAt, updatedAt, usageCount, lastUsedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Untitled template"
        let legacyOccasion = try container.decodeIfPresent(Occasion.self, forKey: .occasion)
        let decodedOccasions = try container.decodeIfPresent([Occasion].self, forKey: .occasions) ?? []
        occasions = decodedOccasions.isEmpty ? [legacyOccasion ?? .birthday] : decodedOccasions
        body = try container.decodeIfPresent(String.self, forKey: .body)
            ?? container.decodeIfPresent(String.self, forKey: .message)
            ?? ""
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        iconSemantic = try container.decodeIfPresent(String.self, forKey: .iconSemantic) ?? "occasion"
        iconID = try container.decodeIfPresent(String.self, forKey: .iconID)
            ?? container.decodeIfPresent(String.self, forKey: .icon)
            ?? occasions.first?.icon
            ?? "text.quote"
        colorToken = try container.decodeIfPresent(String.self, forKey: .colorToken)
            ?? occasions.first?.defaultColorToken
            ?? "teal"
        groupID = try container.decodeIfPresent(UUID.self, forKey: .groupID)
        relationships = try container.decodeIfPresent([Relationship].self, forKey: .relationships)
            ?? container.decodeIfPresent([Relationship].self, forKey: .relationshipAudiences)
            ?? []
        channels = try container.decodeIfPresent([ContactMethod].self, forKey: .channels)
            ?? container.decodeIfPresent([ContactMethod].self, forKey: .channelAudiences)
            ?? []
        languages = try container.decodeIfPresent([String].self, forKey: .languages) ?? []
        emailSubject = try container.decodeIfPresent(String.self, forKey: .emailSubject)
        isDefault = try container.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false
        isBuiltIn = try container.decodeIfPresent(Bool.self, forKey: .isBuiltIn) ?? false
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        usageCount = max(0, try container.decodeIfPresent(Int.self, forKey: .usageCount) ?? 0)
        lastUsedAt = try container.decodeIfPresent(Date.self, forKey: .lastUsedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(occasion, forKey: .occasion)
        try container.encode(occasions, forKey: .occasions)
        try container.encode(body, forKey: .body)
        // Keep writing `message` so an older build can still read newly saved data.
        try container.encode(body, forKey: .message)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encode(iconSemantic, forKey: .iconSemantic)
        try container.encode(iconID, forKey: .iconID)
        try container.encode(colorToken, forKey: .colorToken)
        try container.encodeIfPresent(groupID, forKey: .groupID)
        try container.encode(relationships, forKey: .relationships)
        try container.encode(channels, forKey: .channels)
        try container.encode(languages, forKey: .languages)
        try container.encodeIfPresent(emailSubject, forKey: .emailSubject)
        try container.encode(isDefault, forKey: .isDefault)
        try container.encode(isBuiltIn, forKey: .isBuiltIn)
        try container.encode(isArchived, forKey: .isArchived)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(usageCount, forKey: .usageCount)
        try container.encodeIfPresent(lastUsedAt, forKey: .lastUsedAt)
    }
}

extension Occasion {
    var defaultColorToken: String {
        switch self {
        case .birthday: "coral"
        case .homeAnniversary: "blue"
        case .weddingAnniversary: "rose"
        case .thanksgiving: "amber"
        case .christmas: "forest"
        case .clientAppreciation: "teal"
        }
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
