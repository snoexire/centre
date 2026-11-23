import SwiftUI
import SwiftData
import Foundation
import CoreLocation
import UserNotifications

// MARK: - Notification cleanup

@MainActor
func removePurchaseNotifications(
    expenseIDs: [String]
) {
    let requestIDs = expenseIDs.map {
        "centre.purchase.\($0)"
    }

    let center = UNUserNotificationCenter.current()

    center.removePendingNotificationRequests(
        withIdentifiers: requestIDs
    )

    center.removeDeliveredNotifications(
        withIdentifiers: requestIDs
    )

    let router = CentreNotificationRouter.shared

    if let pendingID = router.pendingExpenseID,
       expenseIDs.contains(pendingID) {
        router.pendingExpenseID = nil
    }
}
