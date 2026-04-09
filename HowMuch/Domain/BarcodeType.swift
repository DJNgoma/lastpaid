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
}
