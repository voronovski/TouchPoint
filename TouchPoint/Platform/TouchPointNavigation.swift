import Foundation
import Observation
import UserNotifications

enum TouchPointDestination: Identifiable, Hashable {
    case greeting(UUID)
    case plan
    case addPerson

    var id: String {
        switch self {
        case .greeting(let id): "greeting-\(id.uuidString)"
        case .plan: "plan"
        case .addPerson: "add-person"
        }
    }
}

@Observable
@MainActor
final class TouchPointNavigation {
    static let shared = TouchPointNavigation()
    var destination: TouchPointDestination?

    func openGreeting(_ id: UUID) { destination = .greeting(id) }
    func openPlan() { destination = .plan }
    func openAddPerson() { destination = .addPerson }
}

final class TouchPointNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = TouchPointNotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        guard let rawID = userInfo["greetingID"] as? String, let id = UUID(uuidString: rawID) else {
            completionHandler()
            return
        }
        Task { @MainActor in
            TouchPointNavigation.shared.openGreeting(id)
            completionHandler()
        }
    }
}
