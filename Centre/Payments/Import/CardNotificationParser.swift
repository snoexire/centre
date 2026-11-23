import Foundation

enum CardNotificationParser {
    static func parse(
        title: String,
        subtitle: String,
        body: String,
        date: Date,
        paymentMethod: String
    ) -> WalletNotificationRouter.Payment? {
        let label = title.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let merchant = subtitle.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let amountText = body.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        // Octopus must continue through its existing parser.
        guard label.caseInsensitiveCompare("Octopus")
                != .orderedSame else {
            return nil
        }

        guard !label.isEmpty,
              label.count <= 100,
              !label.contains("\n"),
              !label.contains("\r"),
              !merchant.isEmpty else {
            return nil
        }

        guard let amountInCents = parseHKDAmount(
            amountText
        ) else {
            return nil
        }

        return WalletNotificationRouter.Payment(
            amountInCents: amountInCents,
            currencyCode: "HKD",
            merchant: merchant,
            category: "Needs details",
            paymentMethod: paymentMethod,
            date: date,
            needsDetails: true,
            parserID: "card.hkd.title-subtitle-amount.v1"
        )
    }

    private static func parseHKDAmount(
        _ text: String
    ) -> Int? {
        let pattern =
            #"^HK\$[ \t]*(?:[0-9]+|[0-9]{1,3}(?:,[0-9]{3})+)\.[0-9]{2}$"#

        guard text.range(
            of: pattern,
            options: .regularExpression
        ) != nil else {
            return nil
        }

        let number = String(text.dropFirst(3))
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: "")

        let parts = number.split(
            separator: ".",
            omittingEmptySubsequences: false
        )

        guard parts.count == 2,
              let whole = Int(parts[0]),
              let fraction = Int(parts[1]) else {
            return nil
        }

        let multiplication =
            whole.multipliedReportingOverflow(by: 100)

        guard !multiplication.overflow else {
            return nil
        }

        let addition =
            multiplication.partialValue
                .addingReportingOverflow(fraction)

        guard !addition.overflow,
              addition.partialValue > 0 else {
            return nil
        }

        return addition.partialValue
    }
}
