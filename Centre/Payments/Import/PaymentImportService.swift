import Foundation
import SwiftData
import CryptoKit

@MainActor
enum PaymentImportService {
    static func record(
        title: String,
        subtitle: String,
        body: String,
        date: Date,
        source: String = "unknown",
        latitude: Double? = nil,
        longitude: Double? = nil,
        accuracy: Double? = nil
    ) throws -> String {
        let context = ModelContext(
            CentreDataStore.container
        )
        context.autosaveEnabled = false
        
        // Card payments join the existing save path only when enabled.
        var parsedCardPayment: WalletNotificationRouter.Payment?

        let cleanTitle = title.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let isOctopus =
            cleanTitle.caseInsensitiveCompare("Octopus")
            == .orderedSame

        if !isOctopus,
           CardNotificationParser.parse(
               title: title,
               subtitle: subtitle,
               body: body,
               date: date,
               paymentMethod: "Other"
           ) != nil {
            let normalizedLabel =
                PaymentSourceSettings.normalize(cleanTitle)

            var request = FetchDescriptor<PaymentSourceSettings>(
                predicate: #Predicate { settings in
                    settings.normalizedLabel == normalizedLabel
                }
            )

            request.fetchLimit = 1

            if let settings = try context.fetch(request).first {
                guard !settings.isRemoved else {
                    return """
                    \(settings.notificationLabel) is not being tracked. \
                    No expense recorded.
                    """
                }

                guard settings.recordingEnabled else {
                    if !settings.hasEverEnabledRecording {
                        guard let payment = CardNotificationParser.parse(
                            title: title,
                            subtitle: subtitle,
                            body: body,
                            date: date,
                            paymentMethod: settings.paymentType
                        ) else {
                            return "Unsupported payment. No expense recorded."
                        }

                        return try retainLatestWaitingPayment(
                            payment,
                            settings: settings,
                            title: title,
                            subtitle: subtitle,
                            body: body,
                            source: source,
                            context: context
                        )
                    }

                    return """
                    \(settings.notificationLabel) is switched off. \
                    No expense recorded.
                    """
                }

                parsedCardPayment = CardNotificationParser.parse(
                    title: title,
                    subtitle: subtitle,
                    body: body,
                    date: date,
                    paymentMethod: settings.paymentType
                )

                guard parsedCardPayment != nil else {
                    return """
                    Payment format not supported yet. \
                    No expense recorded.
                    """
                }

                settings.hasEverEnabledRecording = true
                settings.hasReviewedDiscovery = true
            } else {
                let settings = PaymentSourceSettings(
                    notificationLabel: cleanTitle,
                    paymentType: "Other",
                    recordingEnabled: false
                )

                context.insert(settings)

                guard let payment = CardNotificationParser.parse(
                    title: title,
                    subtitle: subtitle,
                    body: body,
                    date: date,
                    paymentMethod: settings.paymentType
                ) else {
                    context.rollback()
                    return "Unsupported payment. No expense recorded."
                }

                return try retainLatestWaitingPayment(
                    payment,
                    settings: settings,
                    title: title,
                    subtitle: subtitle,
                    body: body,
                    source: source,
                    context: context
                )
            }
        }
        

        let fingerprint = try makeFingerprint(
            title: title,
            subtitle: subtitle,
            body: body,
            date: date
        )

        var eventRequest = FetchDescriptor<PaymentImportEvent>(
            predicate: #Predicate { event in
                event.fingerprint == fingerprint
            }
        )
        eventRequest.fetchLimit = 1

        if let existing = try context.fetch(eventRequest).first {
            switch existing.status {
            case "recorded":
                return "This notification was already recorded."

            case "ignored":
                return "This notification was already ignored."

            case "needsReview":
                return "This notification is already awaiting review."

            default:
                return "This notification was already received."
            }
        }

        let event = PaymentImportEvent(
            fingerprint: fingerprint,
            notificationDate: date,
            source: source,
            title: title,
            subtitle: subtitle,
            body: body
        )

        let result: WalletNotificationRouter.Result

        if let payment = parsedCardPayment {
            result = .payment(payment)
        } else {
            result = WalletNotificationRouter.parse(
                title: title,
                subtitle: subtitle,
                body: body,
                date: date
            )
        }

        let message: String

        switch result {
        case .ignored(.journeyInProgress):
            event.status = "ignored"
            event.parserID = "octopus.en.v1"
            event.processingNote = "Journey in progress; no charge recorded."

            message = "Journey in progress. No expense recorded."

        case .unsupported:
            event.status = "needsReview"
            event.processingNote = "Unsupported notification format."

            message = "Payment format not supported yet. No expense recorded."

        case .payment(let payment):
            guard payment.currencyCode == "HKD" else {
                event.status = "needsReview"
                event.parserID = payment.parserID
                event.processingNote = "Currency is not supported yet."

                context.insert(event)

                do {
                    try context.save()
                } catch {
                    context.rollback()
                    throw error
                }

                return "Currency not supported yet. No expense recorded."
            }

            // Compatibility with imports saved before
            // PaymentImportEvent was introduced.
            var legacyRequest = FetchDescriptor<CentreExpense>(
                predicate: #Predicate { expense in
                    expense.notificationID == fingerprint
                }
            )
            legacyRequest.fetchLimit = 1

            if let existing = try context.fetch(legacyRequest).first {
                event.status = "recorded"
                event.parserID = payment.parserID
                event.linkedExpenseID = existing.notificationID
                event.processingNote = "Linked to an earlier import."

                message = "This notification was already recorded."
            } else {
                let expense = CentreExpense(
                    amountInCents: payment.amountInCents,
                    merchant: payment.merchant,
                    category: payment.category,
                    paymentMethod: payment.paymentMethod,
                    date: payment.date
                )
                if let latitude, let longitude {
                    expense.latitude = latitude
                    expense.longitude = longitude
                    expense.locationAccuracy = accuracy
                    expense.locationCapturedAt = Date()
                }
                context.insert(expense)

                event.status = "recorded"
                event.parserID = payment.parserID
                event.linkedExpenseID = expense.notificationID
                event.processingNote = "Expense saved."

                message = "Payment saved in Centre."
            }
        }

        context.insert(event)

        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }

        return message
    }
    
    private static func retainLatestWaitingPayment(
        _ payment: WalletNotificationRouter.Payment,
        settings: PaymentSourceSettings,
        title: String,
        subtitle: String,
        body: String,
        source: String,
        context: ModelContext
    ) throws -> String {
        do {
            let fingerprint = try makeFingerprint(
                title: title,
                subtitle: subtitle,
                body: body,
                date: payment.date
            )

            var duplicateRequest =
                FetchDescriptor<PaymentImportEvent>(
                    predicate: #Predicate { event in
                        event.fingerprint == fingerprint
                    }
                )

            duplicateRequest.fetchLimit = 1

            if let existing = try context.fetch(
                duplicateRequest
            ).first {
                if existing.status == "recorded" {
                    return "This notification was already recorded."
                }

                if existing.status == "awaitingSourceApproval" {
                    return """
                    This payment is already waiting for review. \
                    No expense recorded.
                    """
                }

                return """
                This notification was already received. \
                No expense recorded.
                """
            }

            if let pendingID = settings.pendingPaymentEventID {
                var pendingRequest =
                    FetchDescriptor<PaymentImportEvent>(
                        predicate: #Predicate { event in
                            event.id == pendingID
                        }
                    )

                pendingRequest.fetchLimit = 1

                if let previous = try context.fetch(
                    pendingRequest
                ).first,
                   previous.status == "awaitingSourceApproval" {
                    // An older, delayed input must not replace
                    // a more recent waiting payment.
                    if previous.notificationDate > payment.date {
                        return """
                        A newer payment is already waiting for review. \
                        No expense recorded.
                        """
                    }

                    previous.status = "superseded"
                    previous.processingNote =
                        "Replaced by a newer waiting payment."

                    previous.parsedAmountInCents = nil
                    previous.parsedCurrencyCode = nil
                    previous.parsedMerchant = nil
                    previous.parsedCategory = nil
                    previous.parsedPaymentMethod = nil

                    previous.rawTitle = nil
                    previous.rawSubtitle = nil
                    previous.rawBody = nil
                    previous.rawTextExpiresAt = nil
                }
            }

            // Raw text is not needed for waiting-payment review.
            let event = PaymentImportEvent(
                fingerprint: fingerprint,
                notificationDate: payment.date,
                source: source,
                title: "",
                subtitle: "",
                body: ""
            )

            event.status = "awaitingSourceApproval"
            event.parserID = payment.parserID
            event.processingNote =
                "Latest payment waiting for card-label approval."

            event.paymentSourceNormalizedLabel =
                settings.normalizedLabel

            event.parsedAmountInCents = payment.amountInCents
            event.parsedCurrencyCode = payment.currencyCode
            event.parsedMerchant = payment.merchant
            event.parsedCategory = payment.category
            event.parsedPaymentMethod = payment.paymentMethod

            event.rawTitle = nil
            event.rawSubtitle = nil
            event.rawBody = nil
            event.rawTextExpiresAt = nil

            context.insert(event)
            settings.pendingPaymentEventID = event.id

            let shouldNotify =
                !settings.discoveryNotificationAttempted
                && !settings.hasReviewedDiscovery
                && !settings.isRemoved

            if shouldNotify {
                settings.discoveryNotificationAttempted = true
            }

            // Save the label, waiting payment, and notification-attempt flag
            // before asking the notification system to schedule anything.
            try context.save()

            if shouldNotify {
                CardDiscoveryNotifications.schedule(
                    sourceID: settings.id,
                    label: settings.notificationLabel
                )
            }

            return """
            Latest \(settings.notificationLabel) payment saved for review. \
            No expense added to spending.
            """
        } catch {
            context.rollback()
            throw error
        }
    }

    static func removeSource(
        _ settings: PaymentSourceSettings,
        context: ModelContext
    ) throws {
        do {
            if let pendingID = settings.pendingPaymentEventID {
                var request = FetchDescriptor<PaymentImportEvent>(
                    predicate: #Predicate { event in
                        event.id == pendingID
                    }
                )
                request.fetchLimit = 1

                if let event = try context.fetch(request).first,
                   event.status == "awaitingSourceApproval" {
                    event.status = "ignored"
                    event.processingNote =
                        "Waiting payment discarded when label was removed."

                    event.parsedAmountInCents = nil
                    event.parsedCurrencyCode = nil
                    event.parsedMerchant = nil
                    event.parsedCategory = nil
                    event.parsedPaymentMethod = nil

                    event.rawTitle = nil
                    event.rawSubtitle = nil
                    event.rawBody = nil
                    event.rawTextExpiresAt = nil
                }
            }

            settings.pendingPaymentEventID = nil
            settings.recordingEnabled = false
            settings.isRemoved = true
            settings.hasReviewedDiscovery = true
            settings.discoveryNotificationAttempted = true

            try context.save()
        } catch {
            context.rollback()
            throw error
        }

        CardDiscoveryNotifications.clear(sourceID: settings.id)
    }
    
    private static func makeFingerprint(
        title: String,
        subtitle: String,
        body: String,
        date: Date
    ) throws -> String {
        let fields = [
            title,
            subtitle,
            body,
            String(date.timeIntervalSince1970)
        ]

        let encoded = try JSONEncoder().encode(fields)
        let digest = SHA256.hash(data: encoded)

        return "octopus-" + digest.map {
            String(format: "%02x", $0)
        }
        .joined()
    }
}
