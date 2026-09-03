import Foundation
import Observation

enum AppMode: String, CaseIterable, Identifiable {
    case professional
    case personal

    var id: Self { self }

    var title: String {
        switch self {
        case .professional: "Professional"
        case .personal: "Personal"
        }
    }

    var subtitle: String {
        switch self {
        case .professional: "Clients and business relationships"
        case .personal: "Family, friends, and people close to you"
        }
    }

    var detail: String {
        switch self {
        case .professional: "Client-first planning, weekly workload, and repeatable outreach."
        case .personal: "Warm reminders and simple planning for the moments that matter."
        }
    }

    var icon: String {
        switch self {
        case .professional: "briefcase"
        case .personal: "heart"
        }
    }

    var defaultRelationship: Relationship {
        switch self {
        case .professional: .client
        case .personal: .family
        }
    }

    var relationshipPriority: [Relationship] {
        switch self {
        case .professional: [.client, .colleague, .friend, .family]
        case .personal: [.family, .friend, .colleague, .client]
        }
    }

    var occasionPriority: [Occasion] {
        switch self {
        case .professional:
            [.clientAppreciation, .homeAnniversary, .birthday, .christmas, .thanksgiving, .weddingAnniversary]
        case .personal:
            [.birthday, .weddingAnniversary, .christmas, .thanksgiving, .homeAnniversary, .clientAppreciation]
        }
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
        static let mode = "TouchPoint.AppMode"
        static let completedOnboarding = "TouchPoint.CompletedOnboarding"
    }

    private let defaults: UserDefaults

    var mode: AppMode {
        didSet {
            defaults.set(mode.rawValue, forKey: Key.mode)
        }
    }

    var hasCompletedOnboarding: Bool {
        didSet {
            defaults.set(hasCompletedOnboarding, forKey: Key.completedOnboarding)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        mode = defaults.string(forKey: Key.mode).flatMap(AppMode.init(rawValue:)) ?? .professional
        hasCompletedOnboarding = defaults.bool(forKey: Key.completedOnboarding)
    }

    func completeOnboarding(with mode: AppMode) {
        self.mode = mode
        hasCompletedOnboarding = true
    }
}
