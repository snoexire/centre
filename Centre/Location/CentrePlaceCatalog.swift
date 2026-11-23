import Foundation
import CoreLocation

// MARK: - Available services

enum CentrePlaceService: String, CaseIterable, Identifiable {
    case canteen = "Canteen"
    case cafe = "Café"
    case airConditioning = "Air conditioning"
    case laundry = "Laundry"
    case vendingMachine = "Vending machine"
    case bookstore = "Bookstore"

    var id: String {
        rawValue
    }

    var category: String {
        switch self {
        case .canteen, .cafe, .vendingMachine:
            return "Food"

        case .airConditioning, .laundry:
            return "Bills"

        case .bookstore:
            return "Shopping"
        }
    }
}

// MARK: - College / campus grouping

enum CentrePlaceGroup: String, CaseIterable, Identifiable {
    case mc = "MC"
    case shho = "SHHO"
    case cc = "CC"
    case cwc = "CWC"
    case lws = "LWS"
    case wys = "WYS"
    case uc = "UC"
    case na = "NA"
    case shaw = "SHAW"

    // Campus buildings that do not belong to a college.
    case cuhk = "CUHK"

    var id: String {
        rawValue
    }
}

// MARK: - Place definition

struct CentrePlace: Identifiable {
    // Keep this ID unchanged after adding the place.
    let id: String

    let name: String
    let group: CentrePlaceGroup

    let latitude: Double
    let longitude: Double

    // Suggestion distance, not a verified building boundary.
    let matchingRadius: CLLocationDistance

    // Only these services should be offered for this place.
    let services: [CentrePlaceService]

    init(
        id: String,
        name: String,
        group: CentrePlaceGroup,
        latitude: Double,
        longitude: Double,
        matchingRadius: CLLocationDistance = 40,
        services: [CentrePlaceService]
    ) {
        self.id = id
        self.name = name
        self.group = group
        self.latitude = latitude
        self.longitude = longitude
        self.matchingRadius = matchingRadius
        self.services = services
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: latitude,
            longitude: longitude
        )
    }
}

// MARK: - Location catalog

enum CentrePlaceCatalog {
    // Add new places to this list.
    //
    // Coordinates come from the supplied location list.
    // The default 40 m radius is an initial testing value.
    // Nearby places may overlap and must remain user-confirmed.

    static let places: [CentrePlace] = [

        // MARK: Chung Chi

        CentrePlace(
            id: "cc-canteen",
            name: "CC Canteen",
            group: .cc,
            latitude: 22.41677,
            longitude: 114.20974,
            services: [.canteen]
        ),

        // MARK: Morningside

        CentrePlace(
            id: "mc-canteen",
            name: "Morningside Canteen",
            group: .mc,
            latitude: 22.41913,
            longitude: 114.21049,
            services: [.canteen]
        ),

        CentrePlace(
            id: "mc-cafe",
            name: "Morningside Café",
            group: .mc,
            latitude: 22.41887,
            longitude: 114.21038,
            services: [.cafe]
        ),

        CentrePlace(
            id: "mc-vending-1",
            name: "Morningside Vending Machine",
            group: .mc,
            latitude: 22.41890,
            longitude: 114.21040,
            services: [.vendingMachine]
        ),

        CentrePlace(
            id: "mc-vending-2",
            name: "Morningside Vending Machine",
            group: .mc,
            latitude: 22.41907,
            longitude: 114.21044,
            services: [.vendingMachine]
        ),

        CentrePlace(
            id: "mc-residential-services",
            name: "Morningside College",
            group: .mc,
            latitude: 22.41894,
            longitude: 114.21030,
            services: [
                .airConditioning,
                .laundry
            ]
        ),

        // MARK: S.H. Ho

        CentrePlace(
            id: "shho-canteen",
            name: "SHHO Canteen",
            group: .shho,
            latitude: 22.41819,
            longitude: 114.21024,
            services: [.canteen]
        ),

        CentrePlace(
            id: "shho-cafe",
            name: "SHHO Café",
            group: .shho,
            latitude: 22.41815,
            longitude: 114.21035,
            services: [.cafe]
        ),

        // MARK: CUHK campus buildings

        CentrePlace(
            id: "cuhk-yia",
            name: "YIA",
            group: .cuhk,
            latitude: 22.41643,
            longitude: 114.21089,
            services: [
                .cafe,
                .bookstore,
                .vendingMachine
            ]
        )
    ]

    // MARK: - Lookup helpers

    static func place(withID id: String) -> CentrePlace? {
        places.first { $0.id == id }
    }

    static func places(
        in group: CentrePlaceGroup
    ) -> [CentrePlace] {
        places.filter { $0.group == group }
    }
}
