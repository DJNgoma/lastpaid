import Foundation

enum CatalogError: LocalizedError, Equatable {
    case invalidBarcode
    case missingProductName
    case missingPriceInput
    case invalidPriceInput(String)
    case invalidCurrencyCode(String)
    case duplicateBarcode(String)
    case productNotFound
    case priceEntryNotFound
    case corruptedPriceData
    case persistenceFailure(String)

    var errorDescription: String? {
        switch self {
        case .invalidBarcode:
            return "Enter a valid barcode value before saving."
        case .missingProductName:
            return "Enter a product name before saving."
        case .missingPriceInput:
            return "Enter the price you paid."
        case .invalidPriceInput(let value):
            return "“\(value)” is not a valid price."
        case .invalidCurrencyCode(let value):
            return "“\(value)” is not a valid 3-letter currency code."
        case .duplicateBarcode(let barcode):
            return "A product with barcode \(barcode) already exists."
        case .productNotFound:
            return "The selected product could not be found."
        case .priceEntryNotFound:
            return "The selected price entry could not be found."
        case .corruptedPriceData:
            return "A saved price could not be read. Please edit or remove the corrupted entry."
        case .persistenceFailure(let message):
            return message
        }
    }
}
