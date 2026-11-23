import SwiftUI
import Combine
import CoreLocation
import MapKit
import SwiftData

// MARK: - Location manager

@MainActor
final class CentreLocationTester: NSObject,
    ObservableObject,
    CLLocationManagerDelegate {

    @Published private(set) var location: CLLocation?
    @Published private(set) var isRequesting = false
    @Published private(set) var status =
        "Tap the button to test your location."

    private let manager = CLLocationManager()
    private var waitingForPermission = false
    private var timeoutTask: Task<Void, Never>?

    override init() {
        super.init()

        manager.delegate = self
        manager.desiredAccuracy =
            kCLLocationAccuracyNearestTenMeters
    }

    func requestLocation() {
        guard !isRequesting else {
            return
        }

        switch manager.authorizationStatus {
        case .notDetermined:
            waitingForPermission = true
            status = "Please allow location access."
            manager.requestWhenInUseAuthorization()

        case .authorizedWhenInUse, .authorizedAlways:
            startRequest()

        case .denied:
            status = """
            Location access is denied. Enable it in \
            Settings → Apps → Centre → Location.
            """

        case .restricted:
            status = "Location access is restricted."

        @unknown default:
            status = "Unknown location permission status."
        }
    }

    private func startRequest() {
        guard !isRequesting else {
            return
        }

        isRequesting = true
        location = nil
        status = "Getting your location…"

        manager.requestLocation()

        timeoutTask?.cancel()

        timeoutTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(20))
            } catch {
                return
            }

            guard let self,
                  self.isRequesting else {
                return
            }

            self.manager.stopUpdatingLocation()
            self.isRequesting = false
            self.status =
                "Location request timed out. Try again."
        }
    }

    func locationManagerDidChangeAuthorization(
        _ manager: CLLocationManager
    ) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if waitingForPermission {
                waitingForPermission = false
                startRequest()
            }

        case .denied, .restricted:
            waitingForPermission = false
            finish()
            status = "Location access is unavailable."

        case .notDetermined:
            break

        @unknown default:
            break
        }
    }

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard isRequesting else {
            return
        }

        guard let result = locations
            .filter({ $0.horizontalAccuracy >= 0 })
            .max(by: { $0.timestamp < $1.timestamp }) else {
            finish()
            status = "No valid location was returned."
            return
        }

        let age = abs(
            result.timestamp.timeIntervalSinceNow
        )

        guard age <= 60 else {
            finish()
            location = nil
            status = """
            Only an old location was returned. \
            It was not attached to the purchase. Try again.
            """
            return
        }

        finish()
        location = result

        if result.horizontalAccuracy > 100 {
            status = """
            Recent location received, but its accuracy is \
            too broad for a confident college suggestion.
            """
        } else {
            status = """
            Recent location received. College \
            identification is not connected yet.
            """
        }
    }

    func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        guard isRequesting else {
            return
        }

        finish()

        let details = error as NSError

        status = """
        Location failed.
        Domain: \(details.domain)
        Code: \(details.code)
        Message: \(details.localizedDescription)
        """
    }

    private func finish() {
        timeoutTask?.cancel()
        timeoutTask = nil
        isRequesting = false
    }
}

// MARK: - Location test screen

struct LocationTestView: View {
    @ObservedObject var purchaseLocationTester: CentreLocationTester
    let createTestPurchase: () -> Void

    @Environment(\.dismiss)
    private var dismiss

    @Environment(\.modelContext)
    private var context

    @StateObject
    private var tester = CentreLocationTester()

    var body: some View {
        NavigationStack {
            List {
                Section("Payment setup") {
                    NavigationLink {
                        PaymentSourcesView()
                    } label: {
                        Label(
                            "Cards to record",
                            systemImage: "creditcard"
                        )
                    }
                }

                AdminTransactionCleanupView()
                    .disabled(purchaseLocationTester.isRequesting)

                Section("Demo Purchases") {
                    Button {
                        createPresetPurchase(
                            title: "Demo MC Canteen",
                            amountInCents: 3800,
                            lat: 22.41887,
                            lon: 114.21038,
                            accuracy: 10
                        )
                    } label: {
                        Label(
                            "Simulate Morningside (MC)",
                            systemImage: "building.2.crop.circle"
                        )
                    }

                    Button {
                        createPresetPurchase(
                            title: "Demo Outside CUHK",
                            amountInCents: 5000,
                            lat: 22.31930,
                            lon: 114.16940,
                            accuracy: 10
                        )
                    } label: {
                        Label(
                            "Simulate Outside CUHK",
                            systemImage: "xmark.circle"
                        )
                    }

                    Button {
                        createTestPurchase()
                    } label: {
                        Label(
                            "Record at Current Location",
                            systemImage: "location.circle"
                        )
                    }
                    .disabled(purchaseLocationTester.isRequesting)

                    Text(
                        "Simulates payments in different areas to demonstrate college matching and fallback behavior."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Section("Location") {
                    Button {
                        tester.requestLocation()
                    } label: {
                        HStack {
                            Label(
                                "Get current location",
                                systemImage: "location.fill"
                            )

                            Spacer()

                            if tester.isRequesting {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(tester.isRequesting)

                    Text(tester.status)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let location = tester.location {
                    Section("Position") {
                        locationMap(location)

                        LabeledContent(
                            "Latitude",
                            value: String(
                                format: "%.6f",
                                location.coordinate.latitude
                            )
                        )

                        LabeledContent(
                            "Longitude",
                            value: String(
                                format: "%.6f",
                                location.coordinate.longitude
                            )
                        )

                        LabeledContent(
                            "Reported accuracy",
                            value: String(
                                format: "±%.0f metres",
                                location.horizontalAccuracy
                            )
                        )

                        LabeledContent(
                            "Captured",
                            value: location.timestamp.formatted(
                                date: .abbreviated,
                                time: .standard
                            )
                        )

                        Text(
                            """
                            The accuracy circle is an estimate, \
                            not proof of a payment location.
                            """
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Control panel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(
                    placement: .confirmationAction
                ) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .tint(.indigo)
    }

    private func createPresetPurchase(
        title: String,
        amountInCents: Int,
        lat: Double,
        lon: Double,
        accuracy: Double
    ) {
        let now = Date()
        let expense = CentreExpense(
            amountInCents: amountInCents,
            merchant: title,
            category: "Needs details",
            paymentMethod: "Octopus",
            date: now
        )
        expense.latitude = lat
        expense.longitude = lon
        expense.locationAccuracy = accuracy
        expense.locationCapturedAt = now

        context.insert(expense)
        try? context.save()
    }

    private func locationMap(
        _ location: CLLocation
    ) -> some View {
        Map(
            initialPosition: .region(
                MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(
                        latitudeDelta: 0.004,
                        longitudeDelta: 0.004
                    )
                )
            )
        ) {
            Annotation(
                "Captured location",
                coordinate: location.coordinate
            ) {
                Image(
                    systemName: "location.circle.fill"
                )
                .font(.title)
                .foregroundStyle(.indigo)
                .padding(6)
                .background(
                    .background,
                    in: Circle()
                )
            }

            MapCircle(
                center: location.coordinate,
                radius: location.horizontalAccuracy
            )
            .foregroundStyle(
                .indigo.opacity(0.15)
            )
        }
        .frame(height: 250)
        .id(location.timestamp)
    }
}
