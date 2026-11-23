import Foundation
import SwiftData

@Model
final class PaymentImportEvent {
    var id: String = UUID().uuidString

    var fingerprint: String = ""
    var notificationDate: Date = Date()
    var receivedAt: Date = Date()

    // unknown, manualTest, walletAutomation, adminTest
    var source: String = "unknown"

    // pending, awaitingSourceApproval, superseded,
    // recorded, ignored, needsReview, failed
    var status: String = "pending"

    var parserID: String?
    var linkedExpenseID: String?
    var processingNote: String?

    // Optional so raw notification text can be removed later.
    var rawTitle: String?
    var rawSubtitle: String?
    var rawBody: String?
    var rawTextExpiresAt: Date?
    // Parsed payment details for review without keeping raw text.
    var paymentSourceNormalizedLabel: String?
    var parsedAmountInCents: Int?
    var parsedCurrencyCode: String?
    var parsedMerchant: String?
    var parsedCategory: String?
    var parsedPaymentMethod: String?

    init(
        fingerprint: String,
        notificationDate: Date,
        source: String,
        title: String,
        subtitle: String,
        body: String
    ) {
        self.fingerprint = fingerprint
        self.notificationDate = notificationDate
        self.source = source

        let now = Date()
        self.receivedAt = now

        self.rawTitle = title
        self.rawSubtitle = subtitle
        self.rawBody = body

        self.rawTextExpiresAt = Calendar.current.date(
            byAdding: .day,
            value: 30,
            to: now
        )
    }
}
