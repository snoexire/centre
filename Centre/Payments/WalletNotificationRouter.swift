import Foundation

enum WalletNotificationRouter {
    struct Payment: Equatable {
        let amountInCents: Int
        let currencyCode: String
        let merchant: String
        let category: String
        let paymentMethod: String
        let date: Date
        let needsDetails: Bool
        let parserID: String
    }

    enum IgnoreReason: Equatable {
        case journeyInProgress
    }

    enum Result: Equatable {
        case payment(Payment)
        case ignored(IgnoreReason)
        case unsupported
    }

    static func parse(
        title: String,
        subtitle: String,
        body: String,
        date: Date
    ) -> Result {
        let cleanTitle = title.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        if cleanTitle.caseInsensitiveCompare("Octopus")
            == .orderedSame {
            return parseOctopus(
                title: cleanTitle,
                subtitle: subtitle,
                body: body,
                date: date
            )
        }

        // Add supported card parsers here once their
        // notification formats have been verified.
        return .unsupported
    }

    private static func parseOctopus(
        title: String,
        subtitle: String,
        body: String,
        date: Date
    ) -> Result {
        let result = OctopusNotificationParser.parse(
            title: title,
            subtitle: subtitle,
            body: body,
            date: date
        )

        switch result {
        case .payment(let payment):
            return .payment(
                Payment(
                    amountInCents: payment.amountInCents,
                    currencyCode: "HKD",
                    merchant: payment.merchant,
                    category: payment.category,
                    paymentMethod: payment.paymentMethod,
                    date: payment.date,
                    needsDetails: payment.needsDetails,
                    parserID: "octopus.en.v1"
                )
            )

        case .journeyInProgress:
            return .ignored(.journeyInProgress)

        case .unsupported:
            return .unsupported
        }
    }
}
