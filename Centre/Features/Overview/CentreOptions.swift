import SwiftUI
import SwiftData
import Foundation
import CoreLocation
import UserNotifications

// MARK: - Shared values

enum CentreOptions {
    static let categories = [
        "Food",
        "Transport",
        "Shopping",
        "Entertainment",
        "Bills",
        "Health",
        "Other"
    ]

    static let paymentMethods = [
        "Octopus",
        "Credit card",
        "Debit card",
        "Cash",
        "Bank transfer",
        "Other"
    ]
}
