import Foundation
import Observation

enum Focus: String, CaseIterable, Identifiable {
    case work
    case personal
    case all

    var id: Self { self }

    var title: String {
        switch self {
        case .work: "Work"
        case .personal: "Personal"
        case .all: "All"
        }
    }

    var subtitle: String {
        switch self {
        case .work: "Clients and colleagues"
        case .personal: "Family and friends"
        case .all: "Every relationship"
        }
    }

    var detail: String {
        switch self {
        case .work: "Prioritize work relationships when reviewing upcoming greetings."
        case .personal: "Prioritize personal relationships when reviewing upcoming greetings."
        case .all: "Keep every relationship in view. You can change this focus anytime."
        }
    }

    var icon: String {
        switch self {
        case .work: "briefcase"
        case .personal: "heart"
        case .all: "person.2"
        }
    }

    var defaultRelationship: Relationship {
        switch self {
        case .work: .client
        case .personal: .family
        case .all: .friend
        }
    }

    var relationshipPriority: [Relationship] {
        switch self {
        case .work: [.client, .colleague, .friend, .family]
        case .personal: [.family, .friend, .colleague, .client]
        case .all: [.friend, .family, .client, .colleague]
        }
    }

    var occasionPriority: [Occasion] {
        switch self {
        case .work:
            [.clientAppreciation, .homeAnniversary, .birthday, .christmas, .thanksgiving, .weddingAnniversary]
        case .personal:
            [.birthday, .weddingAnniversary, .christmas, .thanksgiving, .homeAnniversary, .clientAppreciation]
        case .all:
            [.birthday, .clientAppreciation, .weddingAnniversary, .homeAnniversary, .christmas, .thanksgiving]
        }
    }

    var relationships: Set<Relationship> {
        switch self {
        case .work: [.client, .colleague]
        case .personal: [.family, .friend]
        case .all: Set(Relationship.allCases)
        }
    }

    func includes(_ relationship: Relationship) -> Bool {
        relationships.contains(relationship)
    }

    func relationshipRank(_ relationship: Relationship) -> Int {
        relationshipPriority.firstIndex(of: relationship) ?? relationshipPriority.count
    }

    func occasionRank(_ occasion: Occasion) -> Int {
        occasionPriority.firstIndex(of: occasion) ?? occasionPriority.count
    }
}

@Observable
final class AppPreferences {
    private enum Key {
        static let focus = "TouchPoint.Focus"
        static let legacyMode = "TouchPoint.AppMode"
        static let completedOnboarding = "TouchPoint.CompletedOnboarding"
    }

    private let defaults: UserDefaults

    var focus: Focus {
        didSet {
            defaults.set(focus.rawValue, forKey: Key.focus)
        }
    }

    var hasCompletedOnboarding: Bool {
        didSet {
            defaults.set(hasCompletedOnboarding, forKey: Key.completedOnboarding)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let resolvedFocus: Focus
        let shouldPersistMigration: Bool
        if let savedFocus = defaults.string(forKey: Key.focus).flatMap(Focus.init(rawValue:)) {
            resolvedFocus = savedFocus
            shouldPersistMigration = false
        } else if let legacyMode = defaults.string(forKey: Key.legacyMode) {
            switch legacyMode {
            case "professional":
                resolvedFocus = .work
            case "personal":
                resolvedFocus = .personal
            default:
                resolvedFocus = .all
            }
            shouldPersistMigration = true
        } else {
            resolvedFocus = .all
            shouldPersistMigration = false
        }
        focus = resolvedFocus
        hasCompletedOnboarding = defaults.bool(forKey: Key.completedOnboarding)
        if shouldPersistMigration {
            defaults.set(resolvedFocus.rawValue, forKey: Key.focus)
        }
    }

    func completeOnboarding(with focus: Focus) {
        self.focus = focus
        hasCompletedOnboarding = true
    }
}
