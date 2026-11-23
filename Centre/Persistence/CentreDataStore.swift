import SwiftData

@MainActor
enum CentreDataStore {
    static let container: ModelContainer = {
        do {
            return try ModelContainer(
                for: CentreExpense.self,
                PaymentImportEvent.self,
                PaymentSourceSettings.self
            )
        } catch {
            fatalError(
                "Could not open Centre database: \(error)"
            )
        }
    }()
}
