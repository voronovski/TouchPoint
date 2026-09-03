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
        case .client: String(localized: "Client")
        case .family: String(localized: "Family")
        case .friend: String(localized: "Friend")
        case .colleague: String(localized: "Colleague")
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
    case custom

    var id: Self { self }

    static let legacyRawValues: [String: Occasion] = [
        "Birthday": .birthday,
        "Home anniversary": .homeAnniversary,
        "Wedding anniversary": .weddingAnniversary,
        "Thanksgiving": .thanksgiving,
        "Christmas": .christmas,
        "Client appreciation": .clientAppreciation,
        "Custom occasion": .custom
    ]

    var title: String {
        switch self {
        case .birthday: String(localized: "Birthday")
        case .homeAnniversary: String(localized: "Home anniversary")
        case .weddingAnniversary: String(localized: "Wedding anniversary")
        case .thanksgiving: String(localized: "Thanksgiving")
        case .christmas: String(localized: "Christmas")
        case .clientAppreciation: String(localized: "Client appreciation")
        case .custom: String(localized: "Custom occasion")
        }
    }

    static let contactSpecificCases: [Occasion] = [
        .birthday,
        .homeAnniversary,
        .weddingAnniversary,
        .clientAppreciation,
        .custom
    ]

    var icon: String {
        switch self {
        case .birthday: "birthday.cake"
        case .homeAnniversary: "house"
        case .weddingAnniversary: "heart"
        case .thanksgiving: "leaf"
        case .christmas: "gift"
        case .clientAppreciation: "hands.sparkles"
        case .custom: "star"
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
        case .custom: .accentColor
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
        case .sms: String(localized: "Text message")
        case .email: String(localized: "Email")
        case .reminder: String(localized: "Reminder only")
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
        case .planned: String(localized: "Planned")
        case .ready: String(localized: "Ready")
        case .completed: String(localized: "Completed")
        case .skipped: String(localized: "Skipped")
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
    /// Free-form context kept with a person. Missing fields decode as empty for legacy data.
    var notes: String
    var tags: [String]

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
        importantDates: [ImportantDate] = [],
        notes: String = "",
        tags: [String] = []
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
        self.notes = notes
        self.tags = tags
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, email, phone, organization, relationship, preferredContactMethod
        case preferredLanguage, timeZoneIdentifier, importantDates, notes, tags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
        phone = try container.decodeIfPresent(String.self, forKey: .phone) ?? ""
        organization = try container.decodeIfPresent(String.self, forKey: .organization) ?? ""
        relationship = try container.decodeIfPresent(Relationship.self, forKey: .relationship) ?? .friend
        preferredContactMethod = try container.decodeIfPresent(ContactMethod.self, forKey: .preferredContactMethod) ?? .sms
        preferredLanguage = try container.decodeIfPresent(String.self, forKey: .preferredLanguage) ?? "English"
        timeZoneIdentifier = try container.decodeIfPresent(String.self, forKey: .timeZoneIdentifier) ?? "America/Los_Angeles"
        importantDates = try container.decodeIfPresent([ImportantDate].self, forKey: .importantDates) ?? []
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        tags = (try container.decodeIfPresent([String].self, forKey: .tags) ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id); try container.encode(name, forKey: .name)
        try container.encode(email, forKey: .email); try container.encode(phone, forKey: .phone)
        try container.encode(organization, forKey: .organization); try container.encode(relationship, forKey: .relationship)
        try container.encode(preferredContactMethod, forKey: .preferredContactMethod)
        try container.encode(preferredLanguage, forKey: .preferredLanguage)
        try container.encode(timeZoneIdentifier, forKey: .timeZoneIdentifier)
        try container.encode(importantDates, forKey: .importantDates)
        try container.encode(notes, forKey: .notes); try container.encode(tags, forKey: .tags)
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
    /// Optional label for a custom event represented by this date.
    var customName: String?

    init(id: UUID = UUID(), occasion: Occasion, month: Int, day: Int, customName: String? = nil) {
        self.id = id
        self.occasion = occasion
        self.month = month
        self.day = day
        self.customName = customName
    }

    private enum CodingKeys: String, CodingKey { case id, occasion, month, day, customName }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        occasion = try c.decodeIfPresent(Occasion.self, forKey: .occasion) ?? .birthday
        month = try c.decodeIfPresent(Int.self, forKey: .month) ?? 1
        day = try c.decodeIfPresent(Int.self, forKey: .day) ?? 1
        customName = try c.decodeIfPresent(String.self, forKey: .customName)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(occasion, forKey: .occasion)
        try c.encode(month, forKey: .month); try c.encode(day, forKey: .day)
        try c.encodeIfPresent(customName, forKey: .customName)
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

    var displayName: String {
        guard let customName else { return occasion.title }
        let trimmed = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? occasion.title : trimmed
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
    /// The template snapshot used when this greeting was planned. Optional for legacy events.
    var sourceTemplateID: UUID?
    var sourceTemplateRevision: Int?
    /// Optional user-facing name for an event that does not fit the built-in occasions.
    var customName: String?
    var recurrence: EventRecurrence

    init(
        id: UUID = UUID(),
        personID: UUID,
        occasion: Occasion,
        date: Date,
        method: ContactMethod,
        status: GreetingStatus,
        message: String = "",
        subject: String? = nil,
        sourceTemplateID: UUID? = nil,
        sourceTemplateRevision: Int? = nil,
        customName: String? = nil,
        recurrence: EventRecurrence = .annual
    ) {
        self.id = id
        self.personID = personID
        self.occasion = occasion
        self.date = date
        self.method = method
        self.status = status
        self.message = message
        self.subject = subject
        self.sourceTemplateID = sourceTemplateID
        self.sourceTemplateRevision = sourceTemplateRevision
        self.customName = customName
        self.recurrence = recurrence
    }

    private enum CodingKeys: String, CodingKey {
        case id, personID, occasion, date, method, status, message, subject
        case sourceTemplateID, sourceTemplateRevision, customName, recurrence
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        personID = try c.decodeIfPresent(UUID.self, forKey: .personID) ?? UUID()
        occasion = try c.decodeIfPresent(Occasion.self, forKey: .occasion) ?? .birthday
        date = try c.decodeIfPresent(Date.self, forKey: .date) ?? .now
        method = try c.decodeIfPresent(ContactMethod.self, forKey: .method) ?? .reminder
        status = try c.decodeIfPresent(GreetingStatus.self, forKey: .status) ?? .planned
        message = try c.decodeIfPresent(String.self, forKey: .message) ?? ""
        subject = try c.decodeIfPresent(String.self, forKey: .subject)
        sourceTemplateID = try c.decodeIfPresent(UUID.self, forKey: .sourceTemplateID)
        sourceTemplateRevision = try c.decodeIfPresent(Int.self, forKey: .sourceTemplateRevision)
        customName = try c.decodeIfPresent(String.self, forKey: .customName)
        recurrence = try c.decodeIfPresent(EventRecurrence.self, forKey: .recurrence) ?? .annual
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(personID, forKey: .personID)
        try c.encode(occasion, forKey: .occasion); try c.encode(date, forKey: .date)
        try c.encode(method, forKey: .method); try c.encode(status, forKey: .status)
        try c.encode(message, forKey: .message); try c.encodeIfPresent(subject, forKey: .subject)
        try c.encodeIfPresent(sourceTemplateID, forKey: .sourceTemplateID)
        try c.encodeIfPresent(sourceTemplateRevision, forKey: .sourceTemplateRevision)
        try c.encodeIfPresent(customName, forKey: .customName)
        try c.encode(recurrence, forKey: .recurrence)
    }

    var displayName: String {
        guard let customName else { return occasion.title }
        let trimmed = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? occasion.title : trimmed
    }
}

enum EventRecurrence: String, CaseIterable, Codable, Identifiable, StableStringCodable {
    case annual
    case oneTime = "one_time"

    var id: Self { self }

    static let legacyRawValues: [String: EventRecurrence] = [
        "Annual": .annual, "One-time": .oneTime, "one-time": .oneTime
    ]

    var title: String {
        switch self {
        case .annual: String(localized: "Annual")
        case .oneTime: String(localized: "One-time")
        }
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
    /// Monotonically increasing local content revision. Starts at one for legacy templates.
    var revisionNumber: Int
    /// Approval and locking are local, single-user library controls, not team permissions.
    var isApproved: Bool
    var approvedAt: Date?
    var isLocked: Bool

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
        lastUsedAt: Date? = nil,
        revisionNumber: Int = 1,
        isApproved: Bool? = nil,
        approvedAt: Date? = nil,
        isLocked: Bool? = nil
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
        self.revisionNumber = max(1, revisionNumber)
        self.isApproved = isApproved ?? isBuiltIn
        self.approvedAt = approvedAt ?? (isBuiltIn ? createdAt : nil)
        self.isLocked = isLocked ?? isBuiltIn
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
        case revisionNumber, isApproved, approvedAt, isLocked
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
        revisionNumber = max(1, try container.decodeIfPresent(Int.self, forKey: .revisionNumber) ?? 1)
        isApproved = try container.decodeIfPresent(Bool.self, forKey: .isApproved) ?? isBuiltIn
        approvedAt = try container.decodeIfPresent(Date.self, forKey: .approvedAt)
            ?? (isApproved && isBuiltIn ? createdAt : nil)
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? isBuiltIn
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
        try container.encode(revisionNumber, forKey: .revisionNumber)
        try container.encode(isApproved, forKey: .isApproved)
        try container.encodeIfPresent(approvedAt, forKey: .approvedAt)
        try container.encode(isLocked, forKey: .isLocked)
    }
}

/// The user-editable portion of a template, kept separate from usage and governance state.
struct TemplateContentSnapshot: Codable, Hashable {
    var title: String
    var occasions: [Occasion]
    var body: String
    var iconSemantic: String
    var iconID: String
    var colorToken: String
    var groupID: UUID?
    var relationships: [Relationship]
    var channels: [ContactMethod]
    var languages: [String]
    var emailSubject: String?

    init(template: GreetingTemplate) {
        title = template.title
        occasions = template.occasions
        body = template.body
        iconSemantic = template.iconSemantic
        iconID = template.iconID
        colorToken = template.colorToken
        groupID = template.groupID
        relationships = template.relationships
        channels = template.channels
        languages = template.languages
        emailSubject = template.emailSubject
    }
}

struct TemplateRevision: Identifiable, Codable, Hashable {
    let id: UUID
    let templateID: UUID
    let number: Int
    let createdAt: Date
    let snapshot: TemplateContentSnapshot

    init(
        id: UUID = UUID(),
        templateID: UUID,
        number: Int,
        createdAt: Date = .now,
        snapshot: TemplateContentSnapshot
    ) {
        self.id = id
        self.templateID = templateID
        self.number = max(1, number)
        self.createdAt = createdAt
        self.snapshot = snapshot
    }
}

enum TemplateUsageKind: String, CaseIterable, Codable, Hashable, Identifiable {
    case scheduled
    case composerOpened
    case completed
    case skipped
    case messageEdited

    var id: Self { self }
}

/// Metadata-only usage event. Deliberately contains no person or message content.
struct TemplateUsageRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let templateID: UUID
    let templateRevision: Int?
    let eventID: UUID?
    let occurredAt: Date
    let kind: TemplateUsageKind
    let occasion: Occasion?
    let channel: ContactMethod?

    init(
        id: UUID = UUID(),
        templateID: UUID,
        templateRevision: Int? = nil,
        eventID: UUID? = nil,
        occurredAt: Date = .now,
        kind: TemplateUsageKind,
        occasion: Occasion? = nil,
        channel: ContactMethod? = nil
    ) {
        self.id = id
        self.templateID = templateID
        self.templateRevision = templateRevision
        self.eventID = eventID
        self.occurredAt = occurredAt
        self.kind = kind
        self.occasion = occasion
        self.channel = channel
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
        case .custom: "indigo"
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
