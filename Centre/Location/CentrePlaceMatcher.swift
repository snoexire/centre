import Foundation
import CoreLocation

enum CentrePlaceMatcher {
    struct Match: Identifiable {
        let place: CentrePlace
        let distance: CLLocationDistance

        var id: String {
            place.id
        }
    }

    static func matches(
        latitude: Double?,
        longitude: Double?,
        accuracy: Double?
    ) -> [Match] {
        guard let latitude,
              let longitude,
              let accuracy,
              latitude.isFinite,
              longitude.isFinite,
              accuracy.isFinite,
              (-90.0...90.0).contains(latitude),
              (-180.0...180.0).contains(longitude),
              accuracy >= 0,
              accuracy <= 100 else {
            return []
        }

        let location = CLLocation(
            latitude: latitude,
            longitude: longitude
        )

        return CentrePlaceCatalog.places.compactMap { place in
            let placeLocation = CLLocation(
                latitude: place.latitude,
                longitude: place.longitude
            )

            let distance = location.distance(
                from: placeLocation
            )

            // Include places within the configured radius
            // plus the saved location's accuracy estimate.
            let suggestionDistance =
                place.matchingRadius + accuracy

            guard distance <= suggestionDistance else {
                return nil
            }

            return Match(
                place: place,
                distance: distance
            )
        }
        .sorted { first, second in
            if first.distance == second.distance {
                return first.place.id < second.place.id
            }

            return first.distance < second.distance
        }
    }
}
