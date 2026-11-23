import SwiftUI
import Foundation

// MARK: - Monthly budget editor

struct MonthlyBudgetEditor: View {
    @Environment(\.dismiss) private var dismiss

    let currentBudgetInCents: Int
    let onSave: (Int) -> Void
    @State private var amount: String

    init(
        currentBudgetInCents: Int,
        onSave: @escaping (Int) -> Void
    ) {
        self.currentBudgetInCents = currentBudgetInCents
        self.onSave = onSave

        _amount = State(
            initialValue: currentBudgetInCents > 0
                ? String(
                    format: "%.2f",
                    Double(currentBudgetInCents) / 100
                )
                : ""
        )
    }

    private var parsedBudgetInCents: Int? {
        let normalized = amount
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")

        guard normalized.range(
            of: #"^[0-9]+(?:\.[0-9]{0,2})?$"#,
            options: .regularExpression
        ) != nil,
        let value = Decimal(
            string: normalized,
            locale: Locale(identifier: "en_US_POSIX")
        ) else {
            return nil
        }

        let cents = value * 100

        guard cents > 0,
              cents <= Decimal(999_999_999) else {
            return nil
        }

        return NSDecimalNumber(decimal: cents).intValue
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("HK$")
                            .foregroundStyle(.secondary)

                        TextField("2,000", text: $amount)
                            .keyboardType(.decimalPad)
                            .font(.title2)
                            .monospacedDigit()
                    }
                } header: {
                    Text("Monthly spending limit")
                } footer: {
                    Text(
                        "Enter an amount without thousands separators, "
                        + "for example 2000 or 2000.50. "
                        + "This limit applies to every month until you change it."
                    )
                }

                if currentBudgetInCents > 0 {
                    Section {
                        Button("Remove budget", role: .destructive) {
                            onSave(0)
                            dismiss()
                        }
                    } footer: {
                        Text(
                            "Removing the budget does not delete any purchases."
                        )
                    }
                }
            }
            .navigationTitle("Monthly budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let cents = parsedBudgetInCents else {
                            return
                        }

                        onSave(cents)
                        dismiss()
                    }
                    .disabled(parsedBudgetInCents == nil)
                }
            }
        }
    }
}
