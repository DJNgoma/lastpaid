import Foundation

enum BarcodeType: String, CaseIterable, Codable, Sendable, Hashable, Identifiable {
    case ean13 = "EAN-13"
    case ean8 = "EAN-8"
    case upca = "UPC-A"
    case upce = "UPC-E"
    case code128 = "Code 128"
    case code39 = "Code 39"
    case qr = "QR"
    case unknown = "Unknown"

    var id: String { rawValue }

    static var userSelectableCases: [BarcodeType] {
        allCases.filter { $0 != .unknown }
    }

    var isNumericRetailCode: Bool {
        switch self {
        case .ean13, .ean8, .upca, .upce:
            return true
        case .code128, .code39, .qr, .unknown:
            return false
        }
    }
}
