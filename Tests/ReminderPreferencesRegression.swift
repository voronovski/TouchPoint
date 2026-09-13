import Foundation

// Keep these tests independent of the user's iCloud preferences.
private final class MemoryCloudStore: NSUbiquitousKeyValueStore {
    private var values: [String: Any] = [:]

    override func object(forKey key: String) -> Any? { values[key] }
    override func string(forKey key: String) -> String? { values[key] as? String }
    override func array(forKey key: String) -> [Any]? { values[key] as? [Any] }
    override func bool(forKey key: String) -> Bool { values[key] as? Bool ?? false }
    override func set(_ value: Any?, forKey key: String) { values[key] = value }
    override func set(_ value: String?, forKey key: String) { values[key] = value }
    override func set(_ value: [Any]?, forKey key: String) { values[key] = value }
    override func set(_ value: Bool, forKey key: String) { values[key] = value }
    override func set(_ value: Int64, forKey key: String) { values[key] = NSNumber(value: value) }
    override func synchronize() -> Bool { true }
}

// Run with bash scripts/test-reminder-preferences.sh.
@main
struct ReminderPreferencesRegression {
    static func main() {
        let suite = "TouchPoint.ReminderRegression.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let cloud = MemoryCloudStore()
        let preferences = AppPreferences(defaults: defaults, cloudDefaults: cloud)

        func expectDays(_ expected: Set<Int>) {
            precondition(preferences.reminderLeadTimes == expected)
            precondition(defaults.array(forKey: "TouchPoint.ReminderLeadTimes") as? [Int] == expected.sorted())
            precondition(cloud.array(forKey: "TouchPoint.ReminderLeadTimes") as? [Int] == expected.sorted())
        }

        // Match the insert/remove mutations used by the Reminders buttons.
        for day in [1, 3, 7] {
            preferences.reminderLeadTimes.insert(day)
        }
        expectDays([0, 1, 3, 7])
        preferences.reminderLeadTimes.remove(0)
        expectDays([1, 3, 7])
        preferences.reminderLeadTimes.insert(0)
        for day in [1, 3, 7] {
            preferences.reminderLeadTimes.remove(day)
        }
        expectDays([0])

        // An unchanged assignment and invalid imported values must also terminate.
        preferences.reminderLeadTimes = [0]
        expectDays([0])
        preferences.reminderLeadTimes = [-1, 0, 7, 31]
        expectDays([0, 7])

        preferences.reminderHour = 18
        preferences.reminderMinute = 45
        preferences.hideReminderNames.toggle()
        precondition(defaults.integer(forKey: "TouchPoint.ReminderHour") == 18)
        precondition(defaults.integer(forKey: "TouchPoint.ReminderMinute") == 45)
        precondition(defaults.bool(forKey: "TouchPoint.HideReminderNames"))

        // Opening Settings again must keep all saved choices.
        let restored = AppPreferences(defaults: defaults, cloudDefaults: cloud)
        precondition(restored.reminderLeadTimes == [0, 7])
        precondition(restored.reminderHour == 18 && restored.reminderMinute == 45)
        precondition(restored.hideReminderNames)
        print("PASS: reminder day mutations, normalization, time, privacy, and persistence")
    }
}
