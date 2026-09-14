import Foundation
import Observation

private final class WeakPreferencesBox: @unchecked Sendable {
    weak var value: AppPreferences?
    init(_ value: AppPreferences) { self.value = value }
}

@Observable
final class AppPreferences {
    private enum Key {
        static let reminderLeadTimes = "TouchPoint.ReminderLeadTimes"
        static let reminderHour = "TouchPoint.ReminderHour"
        static let reminderMinute = "TouchPoint.ReminderMinute"
        static let hideReminderNames = "TouchPoint.HideReminderNames"
        static let senderName = "TouchPoint.SenderName"
        static let preferredLanguage = "TouchPoint.PreferredLanguage"
        static let disabledOccasionCategories = "TouchPoint.DisabledOccasionCategories"
    }

    private let defaults: UserDefaults
    private let cloudDefaults: NSUbiquitousKeyValueStore
    @ObservationIgnored private var cloudObserver: NSObjectProtocol?

    /// Days before the recipient date when a local reminder should be delivered.
    /// Zero means the configured reminder time on the recipient date.
    var reminderLeadTimes: Set<Int> {
        didSet {
            let normalized = Set(reminderLeadTimes.filter { (0...30).contains($0) })
            // @Observable routes assignment through the setter again. Only write
            // back when normalization changes the value, or didSet recurses forever.
            if normalized != reminderLeadTimes {
                reminderLeadTimes = normalized
                return
            }
            defaults.set(Array(reminderLeadTimes).sorted(), forKey: Key.reminderLeadTimes)
            cloudDefaults.set(Array(reminderLeadTimes).sorted(), forKey: Key.reminderLeadTimes)
        }
    }

    var reminderHour: Int {
        didSet {
            let value = min(max(reminderHour, 0), 23)
            defaults.set(value, forKey: Key.reminderHour)
            cloudDefaults.set(value, forKey: Key.reminderHour)
        }
    }

    var reminderMinute: Int {
        didSet {
            let value = min(max(reminderMinute, 0), 59)
            defaults.set(value, forKey: Key.reminderMinute)
            cloudDefaults.set(value, forKey: Key.reminderMinute)
        }
    }

    var hideReminderNames: Bool {
        didSet {
            defaults.set(hideReminderNames, forKey: Key.hideReminderNames)
            cloudDefaults.set(hideReminderNames, forKey: Key.hideReminderNames)
        }
    }

    /// The app user's name, used by `{{sender_name}}` and as generation context.
    var senderName: String {
        didSet {
            defaults.set(senderName, forKey: Key.senderName)
            cloudDefaults.set(senderName, forKey: Key.senderName)
        }
    }

    /// Default language for newly created templates and language-aware generation.
    var preferredLanguage: String {
        didSet {
            let value = TouchPointLanguage.resolved(preferredLanguage)
            if value != preferredLanguage {
                preferredLanguage = value
                return
            }
            defaults.set(value, forKey: Key.preferredLanguage)
            cloudDefaults.set(value, forKey: Key.preferredLanguage)
        }
    }

    /// Occasion categories hidden from selection lists. Personal moments are
    /// always available because they contain recipient-specific dates.
    var disabledOccasionCategories: Set<OccasionCategory> {
        didSet {
            let normalized = disabledOccasionCategories.subtracting([.personal])
            if normalized != disabledOccasionCategories {
                disabledOccasionCategories = normalized
                return
            }
            let values = normalized.map(\.rawValue).sorted()
            defaults.set(values, forKey: Key.disabledOccasionCategories)
            cloudDefaults.set(values, forKey: Key.disabledOccasionCategories)
        }
    }

    func isOccasionCategoryEnabled(_ category: OccasionCategory) -> Bool {
        category == .personal || !disabledOccasionCategories.contains(category)
    }

    func isOccasionEnabled(_ occasion: Occasion) -> Bool {
        isOccasionCategoryEnabled(occasion.category)
    }

    /// Rendering performed by AppStore can happen outside a view, so it reads the
    /// current production preference through this narrow accessor by default.
    static var storedSenderName: String {
        UserDefaults.standard.string(forKey: Key.senderName)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    /// Last reconciliation error is transient and is shown in Settings.
    var notificationSyncError: String?

    init(
        defaults: UserDefaults = .standard,
        cloudDefaults: NSUbiquitousKeyValueStore = .default
    ) {
        self.defaults = defaults
        self.cloudDefaults = cloudDefaults
        let savedLeadTimes = ((cloudDefaults.array(forKey: Key.reminderLeadTimes) ?? defaults.array(forKey: Key.reminderLeadTimes)) as? [NSNumber])?.map(\.intValue) ?? [0]
        let normalizedLeadTimes = Set(savedLeadTimes.filter { (0...30).contains($0) })
        reminderLeadTimes = normalizedLeadTimes.isEmpty ? [0] : normalizedLeadTimes
        reminderHour = min(max((cloudDefaults.object(forKey: Key.reminderHour) as? NSNumber)?.intValue ?? defaults.object(forKey: Key.reminderHour) as? Int ?? 9, 0), 23)
        reminderMinute = min(max((cloudDefaults.object(forKey: Key.reminderMinute) as? NSNumber)?.intValue ?? defaults.object(forKey: Key.reminderMinute) as? Int ?? 0, 0), 59)
        hideReminderNames = cloudDefaults.object(forKey: Key.hideReminderNames) == nil
            ? defaults.bool(forKey: Key.hideReminderNames)
            : cloudDefaults.bool(forKey: Key.hideReminderNames)
        senderName = cloudDefaults.string(forKey: Key.senderName)
            ?? defaults.string(forKey: Key.senderName)
            ?? ""
        preferredLanguage = TouchPointLanguage.resolved(
            cloudDefaults.string(forKey: Key.preferredLanguage)
                ?? defaults.string(forKey: Key.preferredLanguage)
        )
        let savedDisabledOccasionCategories = ((cloudDefaults.array(forKey: Key.disabledOccasionCategories)
            ?? defaults.array(forKey: Key.disabledOccasionCategories)) as? [String]) ?? []
        let knownOccasionCategories = Set(OccasionCategory.allCases.map(\.rawValue))
        disabledOccasionCategories = Set(
            savedDisabledOccasionCategories
                .filter { knownOccasionCategories.contains($0) }
                .compactMap(OccasionCategory.init(rawValue:))
        ).subtracting([.personal])
        notificationSyncError = nil
        defaults.set(senderName, forKey: Key.senderName)
        defaults.set(preferredLanguage, forKey: Key.preferredLanguage)
        if cloudDefaults.object(forKey: Key.reminderLeadTimes) == nil { cloudDefaults.set(Array(reminderLeadTimes).sorted(), forKey: Key.reminderLeadTimes) }
        if cloudDefaults.object(forKey: Key.reminderHour) == nil { cloudDefaults.set(reminderHour, forKey: Key.reminderHour) }
        if cloudDefaults.object(forKey: Key.reminderMinute) == nil { cloudDefaults.set(reminderMinute, forKey: Key.reminderMinute) }
        if cloudDefaults.object(forKey: Key.hideReminderNames) == nil { cloudDefaults.set(hideReminderNames, forKey: Key.hideReminderNames) }
        if cloudDefaults.object(forKey: Key.senderName) == nil { cloudDefaults.set(senderName, forKey: Key.senderName) }
        if cloudDefaults.object(forKey: Key.preferredLanguage) == nil { cloudDefaults.set(preferredLanguage, forKey: Key.preferredLanguage) }
        defaults.set(disabledOccasionCategories.map(\.rawValue).sorted(), forKey: Key.disabledOccasionCategories)
        if cloudDefaults.object(forKey: Key.disabledOccasionCategories) == nil {
            cloudDefaults.set(disabledOccasionCategories.map(\.rawValue).sorted(), forKey: Key.disabledOccasionCategories)
        }
        let observerTarget = WeakPreferencesBox(self)
        cloudObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloudDefaults,
            queue: .main
        ) { _ in
            Task { @MainActor in observerTarget.value?.applyCloudPreferences() }
        }
        // Apple recommends requesting KVS synchronization sparingly, typically once
        // at launch, after registering for external-change notifications. Local writes
        // are propagated automatically after a short delay.
        cloudDefaults.synchronize()
    }

    private func applyCloudPreferences() {
        if let numbers = cloudDefaults.array(forKey: Key.reminderLeadTimes) as? [NSNumber] {
            let value = Set(numbers.map(\.intValue).filter { (0...30).contains($0) })
            if !value.isEmpty, value != reminderLeadTimes { reminderLeadTimes = value }
        }
        if let number = cloudDefaults.object(forKey: Key.reminderHour) as? NSNumber {
            let value = min(max(number.intValue, 0), 23)
            if value != reminderHour { reminderHour = value }
        }
        if let number = cloudDefaults.object(forKey: Key.reminderMinute) as? NSNumber {
            let value = min(max(number.intValue, 0), 59)
            if value != reminderMinute { reminderMinute = value }
        }
        if cloudDefaults.object(forKey: Key.hideReminderNames) != nil {
            let value = cloudDefaults.bool(forKey: Key.hideReminderNames)
            if value != hideReminderNames { hideReminderNames = value }
        }
        if let value = cloudDefaults.string(forKey: Key.senderName), value != senderName {
            senderName = value
        }
        if let value = cloudDefaults.string(forKey: Key.preferredLanguage) {
            let resolved = TouchPointLanguage.resolved(value)
            if resolved != preferredLanguage { preferredLanguage = resolved }
        }
        if let values = cloudDefaults.array(forKey: Key.disabledOccasionCategories) as? [String] {
            let known = Set(OccasionCategory.allCases.map(\.rawValue))
            let resolved = Set(values.filter { known.contains($0) }.compactMap(OccasionCategory.init(rawValue:)))
                .subtracting([.personal])
            if resolved != disabledOccasionCategories { disabledOccasionCategories = resolved }
        }
    }
}
