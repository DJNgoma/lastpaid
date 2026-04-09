import Foundation

enum ProductSortOption: String, CaseIterable, Codable, Sendable, Identifiable {
    case recentlyUpdated
    case recentlyScanned
    case alphabetical

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recentlyUpdated:
            return "Recently Updated"
        case .recentlyScanned:
            return "Recently Scanned"
        case .alphabetical:
            return "Alphabetical"
        }
    }
}
