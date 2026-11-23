import SwiftUI
import SwiftData
import Foundation
import CoreLocation
import UserNotifications

func hkd(_ cents: Int) -> String {
    (Double(cents) / 100).formatted(
        .currency(code: "HKD")
            .locale(Locale(identifier: "en_HK"))
    )
}

func categorySymbol(_ category: String) -> String {
    switch category {
    case "Food":
        return "fork.knife"
    case "Transport":
        return "tram.fill"
    case "Shopping":
        return "bag.fill"
    case "Entertainment":
        return "ticket.fill"
    case "Bills":
        return "doc.text.fill"
    case "Health":
        return "cross.case.fill"
    default:
        return "square.grid.2x2.fill"
    }
}

func sameMonth(_ date: Date, as month: Date) -> Bool {
    Calendar.current.isDate(
        date,
        equalTo: month,
        toGranularity: .month
    )
}
