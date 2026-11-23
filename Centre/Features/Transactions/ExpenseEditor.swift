import SwiftUI
import SwiftData
import Foundation

// MARK: - Add / edit expense
    
    struct ExpenseEditor: View {
        @Environment(\.modelContext)
        private var context
        
        @Environment(\.dismiss)
        private var dismiss
        
        private let expense: CentreExpense?
        
        @State private var amount: String
        @State private var merchant: String
        @State private var category: String
        @State private var paymentMethod: String
        @State private var date: Date
        @State private var errorMessage: String?
        
        init(expense: CentreExpense? = nil) {
            self.expense = expense
            
            _amount = State(
                initialValue: expense.map {
                    String(
                        format: "%.2f",
                        Double($0.amountInCents) / 100
                    )
                } ?? ""
            )
            
            _merchant = State(
                initialValue: expense?.merchant ?? ""
            )
            
            _category = State(
                initialValue: expense?.category ?? "Other"
            )
            
            _paymentMethod = State(
                initialValue: expense?.paymentMethod ?? "Octopus"
            )
            
            _date = State(
                initialValue: expense?.date ?? Date()
            )
        }
        
        private var amountInCents: Int? {
            let normalized = amount
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .replacingOccurrences(
                    of: ",",
                    with: "."
                )
            
            guard normalized.range(
                of: #"^[0-9]+(?:\.[0-9]{0,2})?$"#,
                options: .regularExpression
            ) != nil,
                  let decimal = Decimal(
                    string: normalized,
                    locale: Locale(identifier: "en_US_POSIX")
                  ) else {
                return nil
            }
            
            let cents = decimal * 100
            
            guard cents > 0,
                  cents <= Decimal(999_999_999) else {
                return nil
            }
            
            return NSDecimalNumber(decimal: cents).intValue
        }
        
        private var trimmedMerchant: String {
            merchant.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        }
        
        var body: some View {
            NavigationStack {
                Form {
                    Section("Amount") {
                        HStack {
                            Text("HK$")
                                .foregroundStyle(.secondary)
                            
                            TextField("0.00", text: $amount)
                                .keyboardType(.decimalPad)
                                .font(.title2)
                                .monospacedDigit()
                        }
                    }
                    
                    if expense != nil {
                        Section("Change service") {
                            Button("Canteen") {
                                merchant = "Canteen"
                                category = "Food"
                            }
                            
                            Button("Laundry") {
                                merchant = "Laundry"
                                category = "Bills"
                            }
                            
                            Button("Air conditioning") {
                                merchant = "Air conditioning"
                                category = "Bills"
                            }
                            
                            Button("Vending machine") {
                                merchant = "Vending machine"
                                category = "Food"
                            }
                        }
                    }
                    
                    Section("Details") {
                        TextField(
                            "Merchant or description",
                            text: $merchant
                        )
                        
                        Picker(
                            "Category",
                            selection: $category
                        ) {
                            if category == "Needs details" {
                                Text("Needs details")
                                    .tag("Needs details")
                            }
                            
                            ForEach(
                                CentreOptions.categories,
                                id: \.self
                            ) { option in
                                Text(option)
                                    .tag(option)
                            }
                        }
                        
                        Picker(
                            "Payment method",
                            selection: $paymentMethod
                        ) {
                            ForEach(
                                CentreOptions.paymentMethods,
                                id: \.self
                            ) { method in
                                Text(method)
                                    .tag(method)
                            }
                        }
                        
                        DatePicker(
                            "Date and time",
                            selection: $date,
                            displayedComponents: [
                                .date,
                                .hourAndMinute
                            ]
                        )
                    }
                }
                .navigationTitle(
                    expense == nil
                    ? "Add expense"
                    : "Edit expense"
                )
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(
                        placement: .cancellationAction
                    ) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                    
                    ToolbarItem(
                        placement: .confirmationAction
                    ) {
                        Button("Save") {
                            saveExpense()
                        }
                        .disabled(
                            amountInCents == nil
                            || trimmedMerchant.isEmpty
                        )
                    }
                }
                .alert(
                    "Couldn't save expense",
                    isPresented: Binding(
                        get: {
                            errorMessage != nil
                        },
                        set: { isPresented in
                            if !isPresented {
                                errorMessage = nil
                            }
                        }
                    )
                ) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(errorMessage ?? "")
                }
            }
            .tint(.indigo)
        }
        
        private func saveExpense() {
            guard let cents = amountInCents,
                  !trimmedMerchant.isEmpty else {
                return
            }

            if let expense {
                expense.amountInCents = cents
                expense.merchant = trimmedMerchant
                expense.category = category
                expense.paymentMethod = paymentMethod
                expense.date = date
            } else {
                let newExpense = CentreExpense(
                    amountInCents: cents,
                    merchant: trimmedMerchant,
                    category: category,
                    paymentMethod: paymentMethod,
                    date: date
                )

                context.insert(newExpense)
            }

            do {
                try context.save()
                dismiss()
            } catch {
                context.rollback()
                errorMessage = error.localizedDescription
            }
        }
    }
