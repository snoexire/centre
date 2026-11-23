import Foundation

enum CampusMerchantAliases {
    // Add new card merchant keywords here, one line each.
    private static let entries: [(keyword: String, group: CentrePlaceGroup)] = [
        ("FOTD", .mc)
    ]

    static func group(for merchant: String) -> CentrePlaceGroup? {
        let text = merchant.uppercased()
        return entries.first { text.contains($0.keyword.uppercased()) }?.group
    }
}
