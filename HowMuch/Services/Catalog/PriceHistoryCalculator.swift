import Foundation

struct PriceHistorySnapshot: Equatable, Sendable {
    let latest: PriceEntryRecord?
    let previous: PriceEntryRecord?

    var difference: Decimal? {
        guard let latest, let previous else {
            return nil
        }
        return latest.amount - previous.amount
    }
}

enum PriceHistoryCalculator {
    static func snapshot(for entries: [PriceEntryRecord]) -> PriceHistorySnapshot {
        PriceHistorySnapshot(
            latest: entries.first,
            previous: entries.dropFirst().first
        )
    }
}
