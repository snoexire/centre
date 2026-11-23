import SwiftUI
import SwiftData
import Foundation
import CoreLocation
import UserNotifications

// MARK: - Overview

struct ContentView: View {
    @AppStorage("centre.monthlyBudgetInCents")
    private var monthlyBudgetInCents = 0

    @State private var showingBudgetEditor = false
    @Environment(\.modelContext)
    private var context

    @Query(sort: \CentreExpense.date, order: .reverse)
    private var expenses: [CentreExpense]

    @State private var selectedMonth = Date()
    @State private var showingAddExpense = false
    @State private var showingLocationTest = false

    @State private var showingTestSaveError = false
    @State private var testSaveError = ""

    @StateObject private var notificationRouter =
        CentreNotificationRouter.shared

    @State private var notificationExpense: CentreExpense?

    @StateObject private var purchaseLocationTester =
        CentreLocationTester()

    @State private var locationExpenseID: String?
    @State private var arrivingExpenseID: String? = nil

    @State private var expensePendingDeletion: CentreExpense?
    @State private var showingDeleteConfirmation = false

    private var monthlyExpenses: [CentreExpense] {
        expenses.filter {
            sameMonth($0.date, as: selectedMonth)
        }
    }

    private var monthlyTotal: Int {
        monthlyExpenses.reduce(0) {
            $0 + $1.amountInCents
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 24) {
                        monthSelector
                        spendingCard

                        Button {
                            showingBudgetEditor = true
                        } label: {
                            CentreBudgetSemicircle(
                                spentInCents: monthlyTotal,
                                budgetInCents: monthlyBudgetInCents
                            )
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Edit your monthly budget")


                    }
                    .padding(.vertical, 4)
                }
                .listRowInsets(
                    EdgeInsets(
                        top: 0,
                        leading: 0,
                        bottom: 0,
                        trailing: 0
                    )
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                recentTransactions
            }
            .listStyle(.insetGrouped)
            .navigationLinkIndicatorVisibility(.hidden)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Centre")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingLocationTest = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("Control panel")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddExpense = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add expense")
                }
            }
            .sheet(isPresented: $showingAddExpense) {
                ExpenseEditor()
            }
            .sheet(isPresented: $showingBudgetEditor) {
                MonthlyBudgetEditor(
                    currentBudgetInCents: monthlyBudgetInCents
                ) { newBudgetInCents in
                    monthlyBudgetInCents = newBudgetInCents
                }
            }
            .sheet(isPresented: $showingLocationTest) {
                LocationTestView(
                    purchaseLocationTester: purchaseLocationTester,
                    createTestPurchase: {
                        createTestPurchase()
                    }
                )
            }            .sheet(item: $notificationExpense) { expense in
                NavigationStack {
                    ExpenseDetailView(expense: expense)
                        .toolbar {
                            ToolbarItem(
                                placement: .confirmationAction
                            ) {
                                Button("Done") {
                                    notificationExpense = nil
                                }
                            }
                        }
                }
            }
            .onChange(
                of: notificationRouter.pendingExpenseID,
                initial: true
            ) {
                openNotificationExpense()
            }
            .onChange(of: expenses.count) {
                openNotificationExpense()
            }
            .onChange(of: expenses.map(\.notificationID)) { oldIDs, newIDs in
                let oldSet = Set(oldIDs)

                guard let newID = newIDs.first(where: {
                    !oldSet.contains($0)
                }) else {
                    return
                }

                arrivingExpenseID = newID

                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1))

                    if arrivingExpenseID == newID {
                        arrivingExpenseID = nil
                    }
                }
            }
            .onChange(
                of: purchaseLocationTester.location?.timestamp
            ) {
                savePurchaseLocation()
            }
            .alert(
                "Centre issue",
                isPresented: $showingTestSaveError
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(testSaveError)
            }
            .alert(
                "Permanently delete this transaction?",
                isPresented: $showingDeleteConfirmation,
            ) {
                Button(
                    "Delete permanently",
                    role: .destructive
                ) {
                    if let expense = expensePendingDeletion {
                        deletePreviewExpense(expense)
                    }

                    expensePendingDeletion = nil
                }

                Button("Cancel", role: .cancel) {
                    expensePendingDeletion = nil
                }
            } message: {
                if let expense = expensePendingDeletion {
                    Text(
                        "\(expense.merchant) — "
                        + "\(hkd(expense.amountInCents))\n\n"
                        + "This cannot be undone. Its amount will "
                        + "also be removed from your spending total."
                    )
                } else {
                    Text("This cannot be undone.")
                }
            }
        }
        .tint(.indigo)
    }
    
    // MARK: Budget setup

    private var budgetSetupRow: some View {
        Button {
            showingBudgetEditor = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "chart.pie")
                    .font(.title3)
                    .foregroundStyle(.green)

                VStack(alignment: .leading, spacing: 4) {
                    Text(
                        monthlyBudgetInCents > 0
                            ? "Monthly budget"
                            : "Set monthly budget"
                    )
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                    Text(
                        monthlyBudgetInCents > 0
                            ? "\(hkd(monthlyBudgetInCents)) per month"
                            : "Choose a monthly spending limit"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Text(monthlyBudgetInCents > 0 ? "Edit" : "Set")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.green)
            }
            .padding(16)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 18)
            )
            .contentShape(
                RoundedRectangle(cornerRadius: 18)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Month selector

    private var monthSelector: some View {
        HStack {
            Button {
                changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Previous month")

            Spacer()

            Text(
                selectedMonth,
                format: .dateTime.month(.wide).year()
            )
            .font(.headline)

            Spacer()

            Button {
                changeMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Next month")
        }
    }

    // MARK: Spending card

    private var spendingCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Spent this month")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(hkd(monthlyTotal))
                    .font(
                        .system(
                            size: 40,
                            weight: .semibold,
                            design: .rounded
                        )
                    )
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }

            Divider()

            HStack {
                Text(
                    "\(monthlyExpenses.count) "
                    + (
                        monthlyExpenses.count == 1
                            ? "transaction"
                            : "transactions"
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()

                NavigationLink {
                    MonthlyBreakdownView(
                        month: selectedMonth
                    )
                } label: {
                    HStack(spacing: 5) {
                        Text("View breakdown")

                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                    }
                    .font(.caption)
                    .foregroundStyle(.indigo)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(22)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 24)
        )
    }

    // MARK: Recent transactions

    private var recentTransactions: some View {
        Section {
            if monthlyExpenses.isEmpty {
                emptyState
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(
                    Array(monthlyExpenses.prefix(5))
                ) { expense in
                    NavigationLink {
                        ExpenseDetailView(expense: expense)
                    } label: {
                        ExpenseRow(
                            expense: expense,
                            animateArrival: arrivingExpenseID == expense.notificationID
                        )
                    }
                    .swipeActions(
                        edge: .trailing,
                        allowsFullSwipe: false
                    ) {
                        Button {
                            expensePendingDeletion = expense
                            showingDeleteConfirmation = true
                        } label: {
                            Label(
                                "Delete",
                                systemImage: "trash"
                            )
                        }
                        .tint(.red)
                    }
                }
            }
        } header: {
            HStack {
                Text("Recent transactions")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                if !monthlyExpenses.isEmpty {
                    NavigationLink("See all") {
                        TransactionListView(
                            month: selectedMonth,
                            title: "Transactions"
                        )
                    }
                    .font(.subheadline)
                    .foregroundStyle(.indigo)
                }
            }
            .textCase(nil)
            .padding(.bottom, 6)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("No expenses this month")
                .font(.headline)

            Text("Add an expense to start your breakdown.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Add expense") {
                showingAddExpense = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 20)
        )
    }

    // MARK: Notification navigation

    private func openNotificationExpense() {
        guard let expenseID =
            notificationRouter.pendingExpenseID else {
            return
        }

        guard let expense = expenses.first(where: {
            $0.notificationID == expenseID
        }) else {
            return
        }

        notificationExpense = expense
        notificationRouter.pendingExpenseID = nil
    }

    // MARK: Purchase location

    private func savePurchaseLocation() {
        guard let expenseID = locationExpenseID,
              let location = purchaseLocationTester.location else {
            return
        }

        guard let expense = expenses.first(where: {
            $0.notificationID == expenseID
        }) else {
            locationExpenseID = nil
            return
        }

        expense.latitude = location.coordinate.latitude
        expense.longitude = location.coordinate.longitude
        expense.locationAccuracy = location.horizontalAccuracy
        expense.locationCapturedAt = location.timestamp

        do {
            try context.save()
        } catch {
            context.rollback()
            testSaveError = """
            The purchase was saved, but its location \
            could not be saved.

            \(error.localizedDescription)
            """
            showingTestSaveError = true
        }

        locationExpenseID = nil
    }

    // MARK: Test purchase

    private func createTestPurchase() {
        let now = Date()

        let expense = CentreExpense(
            amountInCents: 1200,
            merchant: "Test Octopus purchase",
            category: "Needs details",
            paymentMethod: "Octopus",
            date: now
        )

        context.insert(expense)

        do {
            try context.save()
            selectedMonth = now
        } catch {
            context.rollback()
            testSaveError = error.localizedDescription
            showingTestSaveError = true
            return
        }

        let expenseID = expense.notificationID

        locationExpenseID = expenseID
        purchaseLocationTester.requestLocation()

        Task { @MainActor in
            await sendPurchaseNotification(
                expenseID: expenseID
            )
        }
    }

    @MainActor
    private func sendPurchaseNotification(
        expenseID: String
    ) async {
        let center = UNUserNotificationCenter.current()

        do {
            let allowed = try await center.requestAuthorization(
                options: [.alert, .sound]
            )

            guard expenses.contains(where: {
                $0.notificationID == expenseID
            }) else {
                return
            }

            guard allowed else {
                testSaveError = """
                The purchase was saved, but notifications \
                are not allowed. Enable them for Centre \
                in Settings.
                """
                showingTestSaveError = true
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "HK$12.00 Octopus purchase"
            content.body = "What was this payment for?"
            content.sound = .default
            content.userInfo = [
                "expenseID": expenseID
            ]

            let request = UNNotificationRequest(
                identifier: "centre.purchase.\(expenseID)",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(
                    timeInterval: 5,
                    repeats: false
                )
            )

            try await center.add(request)

            if !expenses.contains(where: {
                $0.notificationID == expenseID
            }) {
                removePurchaseNotifications(
                    expenseIDs: [expenseID]
                )
            }
        } catch {
            testSaveError = """
            The purchase was saved, but its notification \
            could not be scheduled.

            \(error.localizedDescription)
            """
            showingTestSaveError = true
        }
    }

    // MARK: Preview deletion

    private func deletePreviewExpense(
        _ expense: CentreExpense
    ) {
        let expenseID = expense.notificationID

        context.delete(expense)

        do {
            try context.save()
        } catch {
            context.rollback()
            testSaveError = """
            The transaction could not be deleted.

            \(error.localizedDescription)
            """
            showingTestSaveError = true
            return
        }

        if locationExpenseID == expenseID {
            locationExpenseID = nil
        }

        removePurchaseNotifications(
            expenseIDs: [expenseID]
        )
    }

    // MARK: Month navigation

    private func changeMonth(by amount: Int) {
        let calendar = Calendar.current

        let start = calendar.dateInterval(
            of: .month,
            for: selectedMonth
        )?.start ?? selectedMonth

        if let date = calendar.date(
            byAdding: .month,
            value: amount,
            to: start
        ) {
            selectedMonth = date
        }
    }
}

