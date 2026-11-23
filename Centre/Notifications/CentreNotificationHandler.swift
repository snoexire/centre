import UIKit
import UserNotifications
import Combine

// Remembers which expense a notification asks us to open.

@MainActor
final class CentreNotificationRouter: ObservableObject {
    static let shared = CentreNotificationRouter()

    @Published var pendingExpenseID: String?

    private init() {}
}

// Receives notification events.

@MainActor
final class CentreAppDelegate: NSObject,
    UIApplicationDelegate,
    UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions:
            [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
            @escaping @Sendable (
                UNNotificationPresentationOptions
            ) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler:
            @escaping @Sendable () -> Void
    ) {
        guard response.actionIdentifier
            == UNNotificationDefaultActionIdentifier else {
            completionHandler()
            return
        }

        guard let expenseID =
            response.notification.request.content
                .userInfo["expenseID"] as? String else {
            completionHandler()
            return
        }

        Task { @MainActor in
            CentreNotificationRouter.shared.pendingExpenseID =
                expenseID

            completionHandler()
        }
    }
}
