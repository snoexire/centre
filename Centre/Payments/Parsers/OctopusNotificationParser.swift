import Foundation

enum OctopusNotificationParser {
    struct Payment: Equatable {
        let amountInCents: Int
        let merchant: String
        let category: String
        let paymentMethod: String
        let date: Date
        let needsDetails: Bool
    }

    enum Result: Equatable {
        case payment(Payment)
        case journeyInProgress
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

        let cleanSubtitle = subtitle
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{202F}", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleanTitle.caseInsensitiveCompare("Octopus")
                == .orderedSame else {
            return .unsupported
        }

        if cleanSubtitle.caseInsensitiveCompare(
            "Trip in Progress"
        ) == .orderedSame {
            return .journeyInProgress
        }

        let pattern =
            #"^HK\$\s*([0-9]+(?:,[0-9]{3})*)\.([0-9]{2})\s+(Purchase|for Train)$"#

        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive]
        ) else {
            return .unsupported
        }

        let source = cleanSubtitle as NSString
        let fullRange = NSRange(
            location: 0,
            length: source.length
        )

        guard let match = expression.firstMatch(
            in: cleanSubtitle,
            range: fullRange
        ) else {
            return .unsupported
        }

        let dollarsText = source.substring(
            with: match.range(at: 1)
        )
        .replacingOccurrences(of: ",", with: "")

        let centsText = source.substring(
            with: match.range(at: 2)
        )

        guard
            let dollars = Int(dollarsText),
            let cents = Int(centsText),
            dollars <= (Int.max - cents) / 100
        else {
            return .unsupported
        }

        let amount = dollars * 100 + cents

        guard amount > 0 else {
            return .unsupported
        }

        let kind = source.substring(
            with: match.range(at: 3)
        )

        let isTrain = kind.caseInsensitiveCompare(
            "for Train"
        ) == .orderedSame

        return .payment(
            Payment(
                amountInCents: amount,
                merchant: isTrain ? "MTR" : "Octopus purchase",
                category: isTrain ? "Transport" : "Needs details",
                paymentMethod: "Octopus",
                date: date,
                needsDetails: !isTrain
            )
        )
    }
}
