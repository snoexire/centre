import SwiftUI
import SwiftData
import Foundation
import CoreLocation
import UserNotifications

// MARK: - Monthly breakdown

private enum BreakdownMode: String, CaseIterable {
    case category = "Category"
    case payment = "Payment method"
}

private struct SpendingGroup: Identifiable {
    let name: String
    let amountInCents: Int
    let count: Int

    var id: String {
        name
    }
}

struct MonthlyBreakdownView: View {
    let month: Date

    @Query(sort: \CentreExpense.date, order: .reverse)
    private var expenses: [CentreExpense]

    @State private var mode: BreakdownMode = .category

    private var monthlyExpenses: [CentreExpense] {
        expenses.filter {
            sameMonth($0.date, as: month)
        }
    }

    private var total: Int {
        monthlyExpenses.reduce(0) {
            $0 + $1.amountInCents
        }
    }

    private var groups: [SpendingGroup] {
        let grouped = Dictionary(grouping: monthlyExpenses) {
            mode == .category
                ? $0.category
                : $0.paymentMethod
        }

        return grouped.map { name, records in
            SpendingGroup(
                name: name,
                amountInCents: records.reduce(0) {
                    $0 + $1.amountInCents
                },
                count: records.count
            )
        }
        .sorted {
            if $0.amountInCents == $1.amountInCents {
                return $0.name < $1.name
            }

            return $0.amountInCents > $1.amountInCents
        }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(
                        month,
                        format: .dateTime.month(.wide).year()
                    )
                    .foregroundStyle(.secondary)

                    Text(hkd(total))
                        .font(
                            .system(
                                size: 36,
                                weight: .semibold,
                                design: .rounded
                            )
                        )
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .monospacedDigit()

                    Text("\(monthlyExpenses.count) transactions")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 10)
            }

            Section {
                Picker("Group by", selection: $mode) {
                    ForEach(
                        BreakdownMode.allCases,
                        id: \.self
                    ) { option in
                        Text(option.rawValue)
                            .tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(
                mode == .category
                    ? "By category"
                    : "By payment method"
            ) {
                if groups.isEmpty {
                    Text("No expenses for this month.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(groups) { group in
                        NavigationLink {
                            TransactionListView(
                                month: month,
                                title: group.name,
                                category: mode == .category
                                    ? group.name
                                    : nil,
                                paymentMethod: mode == .payment
                                    ? group.name
                                    : nil
                            )
                        } label: {
                            groupRow(group)
                        }
                    }
                }
            }

            if !monthlyExpenses.isEmpty {
                Section {
                    NavigationLink("View all transactions") {
                        TransactionListView(
                            month: month,
                            title: "Transactions"
                        )
                    }
                }
            }
        }
        .navigationTitle("Breakdown")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func groupRow(
        _ group: SpendingGroup
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(group.name)
                    .fontWeight(.medium)

                Spacer()

                Text(hkd(group.amountInCents))
                    .monospacedDigit()
            }

            ProgressView(
                value: Double(group.amountInCents),
                total: Double(max(total, 1))
            )
            .tint(.indigo)

            HStack {
                Text("\(group.count) transactions")

                Spacer()

                Text(percentage(for: group.amountInCents))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }

    private func percentage(for cents: Int) -> String {
        guard total > 0 else {
            return "0%"
        }

        return (
            Double(cents) / Double(total)
        ).formatted(
            .percent.precision(.fractionLength(0))
        )
    }
}
