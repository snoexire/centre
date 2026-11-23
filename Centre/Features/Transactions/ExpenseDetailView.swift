import SwiftUI
import SwiftData
import Foundation
import CoreLocation
import MapKit

struct ExpenseDetailView: View {
    @Environment(\.modelContext)
    private var context

    @Environment(\.dismiss)
    private var dismiss

    let expense: CentreExpense

    @State private var showingEdit = false
    @State private var showingDelete = false
    @State private var errorMessage: String?

    @State private var selectedGroup: CentrePlaceGroup?
    @State private var choosingLocation = false
    @State private var showingAllServices = false
    @State private var districtName: String?

    private struct ServiceChoice: Identifiable {
        let service: CentrePlaceService
        let place: CentrePlace

        var id: String {
            service.id
        }
    }

    private struct AliasSuggestion {
        let group: CentrePlaceGroup
        let isTentative: Bool
    }

    private let generalCategories = [
        "Food", "Shopping", "Transport", "Other"
    ]

    // MARK: - Names shown to the user

    private func displayName(
        for group: CentrePlaceGroup
    ) -> String {
        switch group {
        case .mc:
            return "Morningside College"
        case .shho:
            return "SHHO"
        case .cc:
            return "Chung Chi College"
        case .cwc:
            return "CWC"
        case .lws:
            return "Lee Woo Sing College"
        case .wys:
            return "Wu Yee Sun College"
        case .uc:
            return "United College"
        case .na:
            return "New Asia College"
        case .shaw:
            return "Shaw College"
        case .cuhk:
            return "YIA - CUHK"
        }
    }

    // MARK: - Suggestions

    private var needsDetails: Bool {
        expense.category == "Needs details"
    }

    private var isOctopus: Bool {
        expense.paymentMethod == "Octopus"
    }

    // A saved location that is accurate enough to trust.
    private var usableLocation: CLLocation? {
        guard let latitude = expense.latitude,
              let longitude = expense.longitude,
              let accuracy = expense.locationAccuracy,
              latitude.isFinite,
              longitude.isFinite,
              accuracy.isFinite,
              abs(latitude) <= 90,
              abs(longitude) <= 180,
              accuracy > 0,
              accuracy <= 100 else {
            return nil
        }

        return CLLocation(
            latitude: latitude,
            longitude: longitude
        )
    }

    // Already sorted closest first.
    private var nearbyMatches: [CentrePlaceMatcher.Match] {
        CentrePlaceMatcher.matches(
            latitude: expense.latitude,
            longitude: expense.longitude,
            accuracy: expense.locationAccuracy
        )
    }

    // Card payments: a known merchant alias (for example FOTD)
    // suggests a college. Location confirms or rejects it.
    private var aliasSuggestion: AliasSuggestion? {
        guard !isOctopus,
              let group = CampusMerchantAliases.group(
                for: expense.merchant
              ) else {
            return nil
        }

        // No usable location: show the alias as a tentative guess.
        guard usableLocation != nil else {
            return AliasSuggestion(group: group, isTentative: true)
        }

        // Location present but no campus pin nearby: far away.
        guard !nearbyMatches.isEmpty else {
            return nil
        }

        if nearbyMatches.contains(where: { $0.place.group == group }) {
            return AliasSuggestion(group: group, isTentative: false)
        }

        return AliasSuggestion(group: group, isTentative: true)
    }

    private var isTentativeSuggestion: Bool {
        guard let alias = aliasSuggestion else {
            return false
        }

        return alias.isTentative && selectedGroup == alias.group
    }

    // Octopus uses location only. Cards use the merchant alias.
    // The nearest group, plus any other group whose closest pin
    // is within 10 m of the nearest pin.
    private var nearbyGroups: [CentrePlaceGroup] {
        if let alias = aliasSuggestion {
            return [alias.group]
        }

        guard isOctopus,
              let nearest = nearbyMatches.first else {
            return []
        }

        let closePlaces = nearbyMatches.filter {
            $0.distance <= nearest.distance + 10
        }

        return uniqueGroups(
            from: closePlaces.map(\.place)
        )
    }

    private var visibleGroups: [CentrePlaceGroup] {
        nearbyGroups
    }

    private var hasCollegeSuggestion: Bool {
        !nearbyGroups.isEmpty || selectedGroup != nil
    }

    private func uniqueGroups(
        from places: [CentrePlace]
    ) -> [CentrePlaceGroup] {
        var result: [CentrePlaceGroup] = []

        for place in places {
            if !result.contains(place.group) {
                result.append(place.group)
            }
        }

        return result
    }

    // Nearby pins first; other pins retain catalog order.
    private func orderedPlaces(
        in group: CentrePlaceGroup,
        includeAll: Bool
    ) -> [CentrePlace] {
        let nearby = nearbyMatches
            .map(\.place)
            .filter { $0.group == group }

        guard includeAll else {
            return nearby
        }

        let nearbyIDs = Set(nearby.map(\.id))

        let remaining = CentrePlaceCatalog.places.filter {
            $0.group == group
                && !nearbyIDs.contains($0.id)
        }

        return nearby + remaining
    }

    private func serviceChoices(
        in group: CentrePlaceGroup,
        includeAll: Bool
    ) -> [ServiceChoice] {
        var result: [ServiceChoice] = []
        var seen = Set<String>()

        for place in orderedPlaces(
            in: group,
            includeAll: includeAll
        ) {
            for service in place.services {
                if seen.insert(service.id).inserted {
                    result.append(
                        ServiceChoice(
                            service: service,
                            place: place
                        )
                    )
                }
            }
        }

        return result
    }

    // With no nearby pin (for example a tentative alias with
    // no location), fall back to every service in the group.
    private func effectiveIncludeAll(
        for group: CentrePlaceGroup
    ) -> Bool {
        showingAllServices
            || serviceChoices(
                in: group,
                includeAll: false
            ).isEmpty
    }

    private var visibleServices: [ServiceChoice] {
        guard let selectedGroup else {
            return []
        }

        return serviceChoices(
            in: selectedGroup,
            includeAll: effectiveIncludeAll(for: selectedGroup)
        )
    }

    private var hasMoreServices: Bool {
        guard let selectedGroup,
              !effectiveIncludeAll(for: selectedGroup) else {
            return false
        }

        let nearbyIDs = Set(
            serviceChoices(
                in: selectedGroup,
                includeAll: false
            )
            .map(\.id)
        )

        let allIDs = Set(
            serviceChoices(
                in: selectedGroup,
                includeAll: true
            )
            .map(\.id)
        )

        return !allIDs.subtracting(nearbyIDs).isEmpty
    }

    // MARK: - Screen

    var body: some View {
        List {
            summarySection

            if needsDetails {
                if hasCollegeSuggestion {
                    locationSection

                    if selectedGroup != nil,
                       !choosingLocation {
                        servicesSection
                    }
                } else {
                    generalSection
                }
            }

            detailsSection
            actionsSection
        }
        .onAppear {
            suggestInitialLocation()
        }
        .onChange(of: nearbyMatches.map(\.id)) {
            suggestInitialLocation()
        }
        .task {
            await lookupDistrict()
        }
        .navigationTitle("Transaction")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEdit) {
            ExpenseEditor(expense: expense)
        }
        .alert(
            "Permanently delete this transaction?",
            isPresented: $showingDelete
        ) {
            Button("Cancel", role: .cancel) {}

            Button(
                "Delete permanently",
                role: .destructive
            ) {
                deleteExpense()
            }
        } message: {
            Text(
                "This cannot be undone. Its amount will also "
                + "be removed from your spending total."
            )
        }
        .alert(
            "Couldn't save changes",
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

    // MARK: - Purchase summary

    private var summarySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(expense.merchant)
                    .font(.headline)

                Text(hkd(expense.amountInCents))
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

                Text(
                    "\(expense.paymentMethod) · "
                    + expense.date.formatted(
                        date: .abbreviated,
                        time: .shortened
                    )
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 12)
        }
    }

    // MARK: - College / building selection

    private var locationHeader: String {
        if choosingLocation {
            return "Change location"
        }

        if isTentativeSuggestion {
            return "\(expense.merchant) is usually at…"
        }

        if hasCollegeSuggestion {
            return "Looks like you made a purchase at…"
        }

        return "Where was this purchase?"
    }

    private var locationSection: some View {
        Section {
            if let group = selectedGroup,
               !choosingLocation {
                Button {
                    choosingLocation = true
                } label: {
                    HStack {
                        Text(displayName(for: group))
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(
                        maxWidth: .infinity,
                        minHeight: 36,
                        alignment: .leading
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    "\(displayName(for: group)), change location"
                )

                Text("Not here? Tap the location to change it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                if visibleGroups.isEmpty {
                    Text("No nearby location could be suggested.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(visibleGroups) { group in
                        Button {
                            selectGroup(group)
                        } label: {
                            HStack {
                                Text(displayName(for: group))
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                Spacer()

                                Image(
                                    systemName: selectedGroup == group
                                        ? "checkmark"
                                        : "chevron.right"
                                )
                                .font(.subheadline)
                                .foregroundStyle(.indigo)
                                .accessibilityHidden(true)
                            }
                            .frame(
                                maxWidth: .infinity,
                                minHeight: 36,
                                alignment: .leading
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Second-last action while changing location.
                Button("Somewhere else / enter details") {
                    showingEdit = true
                }

                // Always the last action while changing location.
                if choosingLocation {
                    Button("Cancel", role: .cancel) {
                        choosingLocation = false

                        if selectedGroup == nil {
                            suggestInitialLocation()
                        }
                    }
                }
            }
        } header: {
            Text(locationHeader)
        }
    }

    // MARK: - Service selection

    private var servicesSection: some View {
        Section {
            ForEach(visibleServices) { choice in
                Button(choice.service.rawValue) {
                    classify(choice)
                }
            }

            if hasMoreServices {
                Button("Show all options at this location") {
                    showingAllServices = true
                }
            }

            Button("Other / enter details") {
                showingEdit = true
            }
        } header: {
            Text("What was it for?")
        } footer: {
            Text(
                showingAllServices
                    ? "Showing all configured services at this location."
                    : "Nearby options are shown closest first. "
                        + "Location is only a suggestion."
            )
        }
    }

    // MARK: - General categories (no college suggestion)

    private var generalSection: some View {
        Section {
            if isOctopus,
               let districtName {
                Label(
                    "Near \(districtName)",
                    systemImage: "mappin.and.ellipse"
                )
                .foregroundStyle(.secondary)
            }

            ForEach(generalCategories, id: \.self) { category in
                Button(category) {
                    classifyGeneral(category)
                }
            }

            // Second-last action.
            Button("Somewhere else / enter details") {
                showingEdit = true
            }
        } header: {
            Text("What was it for?")
        } footer: {
            Text(
                isOctopus
                    ? "Octopus does not show a merchant. "
                        + "The area is only a hint."
                    : "The merchant name from your card is kept."
            )
        }
    }

    // MARK: - Saved expense details

    private var detailsSection: some View {
        Section("Details") {
            LabeledContent(
                "Category",
                value: expense.category
            )

            LabeledContent(
                "Payment method",
                value: expense.paymentMethod
            )

            LabeledContent(
                "Date",
                value: expense.date.formatted(
                    date: .abbreviated,
                    time: .shortened
                )
            )
        }
    }

    private var actionsSection: some View {
        Section {
            Button("Edit expense") {
                showingEdit = true
            }

            Button(
                "Delete expense",
                role: .destructive
            ) {
                showingDelete = true
            }
        }
    }

    // MARK: - Selection actions

    private func suggestInitialLocation() {
        guard selectedGroup == nil,
              !choosingLocation,
              let nearestGroup = nearbyGroups.first else {
            return
        }

        selectedGroup = nearestGroup
        showingAllServices = false
    }

    private func selectGroup(
        _ group: CentrePlaceGroup
    ) {
        selectedGroup = group
        showingAllServices = false
        choosingLocation = false
    }

    // MARK: - District lookup (Octopus, off campus)

    private func lookupDistrict() async {
        guard needsDetails,
              isOctopus,
              nearbyGroups.isEmpty,
              districtName == nil,
              let location = usableLocation,
              let request = MKReverseGeocodingRequest(
                location: location
              ) else {
            return
        }

        do {
            let items = try await request.mapItems

            guard let item = items.first else {
                return
            }

            if let short = item.address?.shortAddress,
               !short.isEmpty {
                districtName = short
            } else if let name = item.name,
                      !name.isEmpty {
                districtName = name
            }
        } catch {
            // No hint is shown if the lookup fails or is offline.
        }
    }

    // MARK: - Save classification

    private func classify(
        _ choice: ServiceChoice
    ) {
        guard let selectedGroup,
              choice.place.group == selectedGroup,
              choice.place.services.contains(choice.service)
        else {
            return
        }

        expense.merchant =
            "\(displayName(for: selectedGroup))"
            + " — \(choice.service.rawValue)"

        expense.category = choice.service.category

        do {
            try context.save()

            removePurchaseNotifications(
                expenseIDs: [expense.notificationID]
            )
        } catch {
            context.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func classifyGeneral(
        _ category: String
    ) {
        // Card payments keep their merchant name.
        if isOctopus {
            expense.merchant =
                "\(districtName ?? "Octopus") — \(category)"
        }

        expense.category = category

        do {
            try context.save()

            removePurchaseNotifications(
                expenseIDs: [expense.notificationID]
            )
        } catch {
            context.rollback()
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Delete expense

    private func deleteExpense() {
        let expenseID = expense.notificationID

        context.delete(expense)

        do {
            try context.save()

            removePurchaseNotifications(
                expenseIDs: [expenseID]
            )

            dismiss()
        } catch {
            context.rollback()
            errorMessage = error.localizedDescription
        }
    }
}
