import SwiftUI
import SwiftData

struct PaymentSourcesView: View {
    @Environment(\.modelContext)
    private var context

    @Query(sort: \PaymentSourceSettings.createdAt)
    private var sources: [PaymentSourceSettings]

    @Query(
        filter: #Predicate<PaymentImportEvent> { event in
            event.status == "awaitingSourceApproval"
        }
    )
    private var waitingEvents: [PaymentImportEvent]

    @State private var errorMessage: String?
    @State private var sourceToRemove: PaymentSourceSettings?
    @State private var showingRemoveConfirmation = false
    @State private var showingAvailableLabels = false
    @State private var sourceToAdd: PaymentSourceSettings?
    @State private var showingAddConfirmation = false

    private let paymentTypes = [
        "Credit card",
        "Debit card",
        "Other"
    ]

    private var trackedSources: [PaymentSourceSettings] {
        sources.filter {
            !$0.isRemoved
                && (
                    $0.hasReviewedDiscovery
                    || $0.hasEverEnabledRecording
                    || $0.recordingEnabled
                )
        }
    }

    private var availableSources: [PaymentSourceSettings] {
        let available = sources.filter {
            $0.isRemoved
                || (
                    !$0.hasReviewedDiscovery
                    && !$0.hasEverEnabledRecording
                    && !$0.recordingEnabled
                )
        }

        let newlyDetected = available.filter { !$0.isRemoved }
        let previouslyRemoved = available.filter { $0.isRemoved }

        return newlyDetected + previouslyRemoved
    }

    var body: some View {
        Form {
            Section {
                Text(
                    "Centre detects cards from supported Wallet payments "
                    + "it receives. Use + to choose which cards to add. "
                    + "You’ll be notified when a new card is detected."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Section {
                if trackedSources.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No cards added")
                            .font(.headline)

                        Text(
                            "After Wallet is connected, Centre can detect "
                            + "cards from supported payments. Tap + to "
                            + "review detected cards."
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } else {
                    ForEach(trackedSources) { source in
                        sourceRow(source)
                            .swipeActions(
                                edge: .trailing,
                                allowsFullSwipe: false
                            ) {
                                Button(role: .destructive) {
                                    sourceToRemove = source
                                    showingRemoveConfirmation = true
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
                Text("Cards to record")
            } footer: {
                Text(
                    "Cards are identified by the name in the payment "
                    + "notification, such as HSBC. If multiple cards "
                    + "share that name, this setting applies to all "
                    + "of them. Deleting a card here preserves "
                    + "existing expenses."
                )
            }
        }
        .navigationTitle("Cards to record")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAvailableLabels = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add detected card")
            }
        }
        .sheet(isPresented: $showingAvailableLabels) {
            availableLabelsSheet
        }
        .confirmationDialog(
            "Delete this card?",
            isPresented: $showingRemoveConfirmation,
            titleVisibility: .visible,
            presenting: sourceToRemove
        ) { source in
            Button(
                "Delete \(source.notificationLabel)",
                role: .destructive
            ) {
                remove(source)
            }

            Button("Cancel", role: .cancel) {}
        } message: { source in
            Text(
                "Stop recording payments for \(source.notificationLabel)? "
                + "Existing expenses will remain. Any payment waiting "
                + "for review will be discarded. You can add this card "
                + "again using +."
            )
        }
        .alert(
            "Could not complete action",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { presented in
                    if !presented {
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

    private var availableLabelsSheet: some View {
        NavigationStack {
            List {
                Section {
                    if availableSources.isEmpty {
                        Text("No other detected cards")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(availableSources) { source in
                            Button {
                                sourceToAdd = source
                                showingAddConfirmation = true
                            } label: {
                                VStack(
                                    alignment: .leading,
                                    spacing: 10
                                ) {
                                    Text(source.notificationLabel)
                                        .font(.headline)
                                        .foregroundStyle(.primary)

                                    if source.isRemoved {
                                        Text("Previously deleted")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        waitingPaymentDetails(
                                            for: source
                                        )
                                    }
                                }
                                .frame(
                                    maxWidth: .infinity,
                                    alignment: .leading
                                )
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } footer: {
                    Text(
                        "Tap a card to add it. Adding enables future "
                        + "recording. Payments already waiting for review "
                        + "are not automatically added to spending."
                    )
                }
            }
            .navigationTitle("Detected cards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingAvailableLabels = false
                    }
                }
            }
            .alert(
                "Add this card?",
                isPresented: $showingAddConfirmation,
                presenting: sourceToAdd
            ) { source in
                Button("Yes, add") {
                    add(source)
                }

                Button("Cancel", role: .cancel) {}
            } message: { source in
                Text(
                    "Enable future payment recording for "
                    + "\(source.notificationLabel)? "
                    + "Previously skipped payments will not be added."
                )
            }
        }
    }

    private func sourceRow(
        _ source: PaymentSourceSettings
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(
                isOn: Binding(
                    get: { source.recordingEnabled },
                    set: { enabled in
                        source.recordingEnabled = enabled
                        source.hasReviewedDiscovery = true

                        if enabled {
                            source.hasEverEnabledRecording = true
                        }

                        saveChanges()
                    }
                )
            ) {
                Text(source.notificationLabel)
            }

            Picker(
                "Payment type",
                selection: Binding(
                    get: { source.paymentType },
                    set: { type in
                        source.paymentType = type
                        saveChanges()
                    }
                )
            ) {
                ForEach(paymentTypes, id: \.self) { type in
                    Text(type).tag(type)
                }
            }

            waitingPaymentDetails(for: source)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func waitingPaymentDetails(
        for source: PaymentSourceSettings
    ) -> some View {
        if let event = waitingEvents.first(where: {
            $0.id == source.pendingPaymentEventID
        }) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Latest payment waiting for review")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let cents = event.parsedAmountInCents {
                    Text(
                        (Double(cents) / 100).formatted(
                            .currency(
                                code: event.parsedCurrencyCode ?? "HKD"
                            )
                        )
                    )
                    .font(.headline)
                }

                if let merchant = event.parsedMerchant {
                    Text(merchant)
                        .font(.subheadline)
                }

                Text(
                    event.notificationDate,
                    format: .dateTime
                        .year()
                        .month()
                        .day()
                        .hour()
                        .minute()
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Text("Not included in spending.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @MainActor
    private func add(_ source: PaymentSourceSettings) {
        source.isRemoved = false
        source.recordingEnabled = true
        source.hasReviewedDiscovery = true
        source.hasEverEnabledRecording = true
        source.discoveryNotificationAttempted = true

        do {
            try context.save()

            CardDiscoveryNotifications.clear(
                sourceID: source.id
            )

            showingAvailableLabels = false
        } catch {
            context.rollback()
            errorMessage = error.localizedDescription
            showingAvailableLabels = false
        }
    }

    @MainActor
    private func remove(_ source: PaymentSourceSettings) {
        do {
            try PaymentImportService.removeSource(
                source,
                context: context
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        sourceToRemove = nil
    }

    @MainActor
    private func saveChanges() {
        do {
            try context.save()
        } catch {
            context.rollback()
            errorMessage = error.localizedDescription
        }
    }
}
