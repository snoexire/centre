import AppIntents
import CoreLocation
import Foundation

struct RecordOctopusNotificationIntent: AppIntent {
    static var title: LocalizedStringResource =
        "Record Payment in Centre"

    static var description = IntentDescription(
        "Records supported Wallet payment notifications in Centre."
    )

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Notification Title")
    var notificationTitle: String

    @Parameter(title: "Notification Subtitle")
    var notificationSubtitle: String

    @Parameter(title: "Notification Body")
    var notificationBody: String

    @Parameter(title: "Notification Date")
    var notificationDate: Date

    @Parameter(title: "Location")
    var location: CLPlacemark?

    @MainActor
    func perform() async throws
        -> some IntentResult & ProvidesDialog {
        let lat = location?.location?.coordinate.latitude
        let lon = location?.location?.coordinate.longitude
        let accuracy = location?.location?.horizontalAccuracy

        let message = try PaymentImportService.record(
            title: notificationTitle,
            subtitle: notificationSubtitle,
            body: notificationBody,
            date: notificationDate,
            source: "unknown",
            latitude: lat,
            longitude: lon,
            accuracy: accuracy
        )

        return .result(
            dialog: IntentDialog(
                stringLiteral: message
            )
        )
    }
}
