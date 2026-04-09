import Foundation

enum BarcodeNormalizer {
    static func normalize(_ rawValue: String) -> String {
        rawValue
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func validated(_ rawValue: String) throws -> String {
        let normalized = normalize(rawValue)
        guard normalized.isEmpty == false else {
            throw CatalogError.invalidBarcode
        }
        return normalized
    }
}
