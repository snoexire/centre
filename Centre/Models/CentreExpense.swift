import Foundation
import SwiftData

@Model
final class CentreExpense {
    var notificationID: String = UUID().uuidString
    var amountInCents: Int
    var merchant: String
    var category: String
    var paymentMethod: String
    var date: Date

    var latitude: Double? = nil
    var longitude: Double? = nil
    var locationAccuracy: Double? = nil
    var locationCapturedAt: Date? = nil

    init(
        amountInCents: Int,
        merchant: String,
        category: String,
        paymentMethod: String,
        date: Date
    ) {
        self.amountInCents = amountInCents
        self.merchant = merchant
        self.category = category
        self.paymentMethod = paymentMethod
        self.date = date
    }
}
