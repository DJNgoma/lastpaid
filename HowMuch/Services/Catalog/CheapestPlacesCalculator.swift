import Foundation

struct CheapestPlaceSummary: Identifiable, Equatable, Sendable {
    enum SourceKind: Equatable, Sendable {
        case store
        case taggedPlace

        var systemImage: String {
            switch self {
            case .store:
                "bag"
            case .taggedPlace:
                "location"
            }
        }
    }

    let label: String
    let amount: Decimal
    let currencyCode: String
    let purchasedAt: Date
    let quantityText: String?
    let sourceKind: SourceKind

    var id: String {
        "\(currencyCode)|\(label.lowercased())"
    }
}

struct CheapestPlacesSnapshot: Equatable, Sendable {
    let comparedCurrencyCode: String?
    let places: [CheapestPlaceSummary]
    let usesEnteredQuantities: Bool

    static let empty = CheapestPlacesSnapshot(
        comparedCurrencyCode: nil,
        places: [],
        usesEnteredQuantities: false
    )
}

enum CheapestPlacesCalculator {
    static func snapshot(
        for entries: [PriceEntryRecord],
        limit: Int = 3
    ) -> CheapestPlacesSnapshot {
        guard limit > 0, let latest = entries.first else {
            return .empty
        }

        let bestByLabel = entries.reduce(into: [String: PriceEntryRecord]()) { partialResult, entry in
            guard entry.currencyCode == latest.currencyCode,
                  let label = bestLabel(for: entry) else {
                return
            }

            guard let current = partialResult[label] else {
                partialResult[label] = entry
                return
            }

            if isBetterCandidate(entry, than: current) {
                partialResult[label] = entry
            }
        }

        let places = bestByLabel
            .map { key, value in
                makeSummary(label: key, entry: value)
            }
            .sorted(by: compare)

        let displayedPlaces = Array(places.prefix(limit))

        return CheapestPlacesSnapshot(
            comparedCurrencyCode: latest.currencyCode,
            places: displayedPlaces,
            usesEnteredQuantities: displayedPlaces.contains(where: { $0.quantityText != nil })
        )
    }

    private static func bestLabel(for entry: PriceEntryRecord) -> String? {
        entry.storeName ?? entry.placeName
    }

    private static func makeSummary(label: String, entry: PriceEntryRecord) -> CheapestPlaceSummary {
        CheapestPlaceSummary(
            label: label,
            amount: entry.amount,
            currencyCode: entry.currencyCode,
            purchasedAt: entry.purchasedAt,
            quantityText: entry.quantityText,
            sourceKind: entry.storeName != nil ? .store : .taggedPlace
        )
    }

    private static func isBetterCandidate(_ lhs: PriceEntryRecord, than rhs: PriceEntryRecord) -> Bool {
        if lhs.amount != rhs.amount {
            return lhs.amount < rhs.amount
        }

        if lhs.purchasedAt != rhs.purchasedAt {
            return lhs.purchasedAt > rhs.purchasedAt
        }

        return (bestLabel(for: lhs) ?? "").localizedCaseInsensitiveCompare(bestLabel(for: rhs) ?? "") == .orderedAscending
    }

    private static func compare(_ lhs: CheapestPlaceSummary, _ rhs: CheapestPlaceSummary) -> Bool {
        if lhs.amount != rhs.amount {
            return lhs.amount < rhs.amount
        }

        if lhs.purchasedAt != rhs.purchasedAt {
            return lhs.purchasedAt > rhs.purchasedAt
        }

        return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
    }
}
