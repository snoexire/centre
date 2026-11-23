import Foundation
import UserNotifications

enum CardDiscoveryNotifications {
    static func identifier(for sourceID: String) -> String {
        "card-discovery-\(sourceID)"
    }

    static func requestPermission() async throws -> Bool {
        try await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
    }

    static func schedule(
        sourceID: String,
        label: String
    ) {
        let content = UNMutableNotificationContent()
        content.title = "New payment label detected"
        content.body =
            "Centre detected “\(label)”. "
            + "Review it in Control panel → Cards to record."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: identifier(for: sourceID),
            content: content,
            trigger: nil
        )

        let center = UNUserNotificationCenter.current()

        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized
                    || settings.authorizationStatus == .provisional
            else {
                return
            }

            center.add(request) { error in
                if let error {
                    print(
                        "Card discovery notification failed: "
                        + error.localizedDescription
                    )
                }
            }
        }
    }

    static func clear(sourceID: String) {
        let ids = [identifier(for: sourceID)]
        let center = UNUserNotificationCenter.current()

        center.removePendingNotificationRequests(
            withIdentifiers: ids
        )
        center.removeDeliveredNotifications(
            withIdentifiers: ids
        )
    }
}
