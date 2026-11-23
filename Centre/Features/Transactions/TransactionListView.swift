import SwiftUI
import SwiftData
import Foundation
import CoreLocation
import UserNotifications

// MARK: - Filtered transactions

struct TransactionListView: View {
    @Environment(\.modelContext)
    private var context

    @Environment(\.editMode)
    private var editMode

    let month: Date
    let title: String

    var category: String? = nil
    var paymentMethod: String? = nil

    @Query(sort: \CentreExpense.date, order: .reverse)
    private var expenses: [CentreExpense]

    @State private var deleteError: String?
    @State private var recordsPendingDeletion: [CentreExpense] = []
    @State private var showingDeleteConfirmation = false

    private var filtered: [CentreExpense] {
        expenses.filter { expense in
            sameMonth(expense.date, as: month)
                && (
                    category == nil
                    || expense.category == category
                )
                && (
                    paymentMethod == nil
                    || expense.paymentMethod == paymentMethod
                )
        }
    }

    private var total: Int {
        filtered.reduce(0) {
            $0 + $1.amountInCents
        }
    }

    var body: some View {
        List {
            Section {
                LabeledContent(
                    month.formatted(
                        .dateTime.month(.wide).year()
                    ),
                    value: hkd(total)
                )
            }

            Section {
                if filtered.isEmpty {
                    Text("No matching transactions.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filtered) { expense in
                        NavigationLink {
                            ExpenseDetailView(expense: expense)
                        } label: {
                            ExpenseRow(expense: expense)
                        }
                        .swipeActions(
                            edge: .trailing,
                            allowsFullSwipe: false
                        ) {
                            Button {
                                requestDeletion([expense])
                            } label: {
                                Label(
                                    "Delete",
                                    systemImage: "trash"
                                )
                            }
                            .tint(.red)
                        }
                    }
                    .onDelete { offsets in
                        let records = filtered

                        requestDeletion(
                            offsets.map { records[$0] }
                        )
                    }
                }
            }
        }
        .navigationLinkIndicatorVisibility(.hidden)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !filtered.isEmpty {
                    EditButton()
                }
            }
        }
        .alert(
            recordsPendingDeletion.count == 1
                ? "Permanently delete this transaction?"
                : "Permanently delete these transactions?",
            isPresented: $showingDeleteConfirmation,

        ) {
            Button(
                "Delete permanently",
                role: .destructive
            ) {
                deletePendingExpenses()
            }

            Button("Cancel", role: .cancel) {
                recordsPendingDeletion = []
            }
        } message: {
            if recordsPendingDeletion.count == 1,
               let expense = recordsPendingDeletion.first {
                Text(
                    "\(expense.merchant) — "
                    + "\(hkd(expense.amountInCents))\n\n"
                    + "This cannot be undone. Its amount will "
                    + "also be removed from your spending total."
                )
            } else {
                Text(
                    "This cannot be undone. Deleted amounts "
                    + "will also be removed from your spending total."
                )
            }
        }
        .alert(
            "Couldn't delete transaction",
            isPresented: Binding(
                get: {
                    deleteError != nil
                },
                set: { isPresented in
                    if !isPresented {
                        deleteError = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteError ?? "")
        }
    }

    private func requestDeletion(
        _ records: [CentreExpense]
    ) {
        recordsPendingDeletion = records
        showingDeleteConfirmation = true
    }

    private func deletePendingExpenses() {
        let recordsToDelete = recordsPendingDeletion

        let expenseIDs = recordsToDelete.map {
            $0.notificationID
        }

        do {
            for expense in recordsToDelete {
                context.delete(expense)
            }

            try context.save()
        } catch {
            context.rollback()
            recordsPendingDeletion = []
            deleteError = error.localizedDescription
            return
        }

        recordsPendingDeletion = []

        removePurchaseNotifications(
            expenseIDs: expenseIDs
        )
    }
}
