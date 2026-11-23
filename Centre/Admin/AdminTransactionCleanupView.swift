import SwiftUI
import SwiftData
import UserNotifications

struct AdminTransactionCleanupView: View {
    @Environment(\.modelContext)
    private var context

    @State private var showingConfirmation = false
    @State private var isDeleting = false
    @State private var resultMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        Section {
            Button(role: .destructive) {
                showingConfirmation = true
            } label: {
                Label(
                    "Clear all transactions",
                    systemImage: "trash"
                )
            }
            .disabled(isDeleting)

            if let resultMessage {
                Text(resultMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Data cleanup")
        } footer: {
            Text(
                "Deletes all transactions across all months, "
                + "including real purchases. Your budget setting "
                + "and import history are kept."
            )
        }
        .alert(
            "Delete all transactions?",
            isPresented: $showingConfirmation
        ) {
            Button("Cancel", role: .cancel) {}

            Button("Delete all transactions", role: .destructive) {
                clearTransactions()
            }
        } message: {
            Text(
                "This permanently deletes every saved transaction "
                + "and removes their purchase notifications. "
                + "This cannot be undone."
            )
        }
        .alert(
            "Could not clear transactions",
            isPresented: Binding(
                get: { errorMessage != nil },
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

    @MainActor
    private func clearTransactions() {
        isDeleting = true
        resultMessage = nil

        defer {
            isDeleting = false
        }

        do {
            let expenses = try context.fetch(
                FetchDescriptor<CentreExpense>()
            )

            let expenseIDs = expenses.map(\.notificationID)
            let count = expenses.count

            for expense in expenses {
                context.delete(expense)
            }

            try context.save()

            let requestIDs = expenseIDs.map {
                "centre.purchase.\($0)"
            }

            let center = UNUserNotificationCenter.current()

            center.removePendingNotificationRequests(
                withIdentifiers: requestIDs
            )

            center.removeDeliveredNotifications(
                withIdentifiers: requestIDs
            )

            let router = CentreNotificationRouter.shared

            if let pendingID = router.pendingExpenseID,
               expenseIDs.contains(pendingID) {
                router.pendingExpenseID = nil
            }

            resultMessage = count == 1
                ? "Deleted 1 transaction."
                : "Deleted \(count) transactions."
        } catch {
            context.rollback()
            errorMessage = error.localizedDescription
        }
    }
}
