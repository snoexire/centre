import Foundation
import SwiftData

@Model
final class PaymentSourceSettings {
    var id: String = UUID().uuidString
    var notificationLabel: String = ""
    var normalizedLabel: String = ""
    var paymentType: String = "Credit card"
    var recordingEnabled: Bool = false
    var createdAt: Date = Date()
    // Whether the user has reviewed this label in Cards to record.
    var hasReviewedDiscovery: Bool = false

    // Prevent repeated discovery-notification attempts.
    var discoveryNotificationAttempted: Bool = false

    // Distinguishes a new label from one deliberately switched off.
    var hasEverEnabledRecording: Bool = false
    
    // Identifies the latest payment waiting for this label's approval.
    var pendingPaymentEventID: String?
    
    // Hidden from the main list until the user restores it.
    var isRemoved: Bool = false

    init(
        notificationLabel: String,
        paymentType: String,
        recordingEnabled: Bool = false
    ) {
        let trimmed = notificationLabel.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        self.notificationLabel = trimmed
        self.normalizedLabel = Self.normalize(trimmed)
        self.paymentType = paymentType
        self.recordingEnabled = recordingEnabled
    }

    static func normalize(_ label: String) -> String {
        label
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .lowercased()
    }
}
