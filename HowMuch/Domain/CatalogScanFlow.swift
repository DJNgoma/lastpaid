import Foundation

enum KnownProductQuickAddOrigin: String, Equatable, Sendable {
    case scanner
    case manualEntry
}

enum CatalogScanDestination: Equatable, Sendable {
    case capture(ProductDraft)
    case quickAdd(ProductDetail, origin: KnownProductQuickAddOrigin)
}

enum QuickAddSaveFollowUp: Equatable, Sendable {
    case none
    case reopenScanner
}

enum CatalogScanFlow {
    static func destination(
        for resolution: ScanResolution,
        knownProductOrigin: KnownProductQuickAddOrigin
    ) -> CatalogScanDestination {
        switch resolution {
        case .existing(let product):
            .quickAdd(product, origin: knownProductOrigin)
        case .newDraft(let draft):
            .capture(draft)
        }
    }

    static func saveFollowUp(for origin: KnownProductQuickAddOrigin) -> QuickAddSaveFollowUp {
        switch origin {
        case .scanner:
            .reopenScanner
        case .manualEntry:
            .none
        }
    }
}
