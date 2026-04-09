import Foundation

struct ScannedBarcode: Equatable, Sendable {
    let payload: String
    let symbology: BarcodeType
    let scannedAt: Date

    init(payload: String, symbology: BarcodeType, scannedAt: Date = .now) {
        self.payload = payload
        self.symbology = symbology
        self.scannedAt = scannedAt
    }
}
