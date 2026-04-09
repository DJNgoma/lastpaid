import AVFoundation
import Foundation

enum CameraAuthorizationStatus: Equatable {
    case notDetermined
    case denied
    case restricted
    case authorized
    case unsupported
}

enum ScannerError: LocalizedError, Equatable {
    case cameraUnavailable
    case permissionDenied
    case permissionRestricted
    case invalidBarcode
    case unsupportedDevice
    case simulatorUnavailable

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable:
            return "This device does not have a usable camera."
        case .permissionDenied:
            return "Camera access is denied. You can still enter a barcode manually."
        case .permissionRestricted:
            return "Camera access is restricted on this device."
        case .invalidBarcode:
            return "The scanned barcode could not be read."
        case .unsupportedDevice:
            return "Barcode scanning is not supported on this device."
        case .simulatorUnavailable:
            return "The iOS simulator cannot access the barcode camera feed."
        }
    }
}

protocol CameraPermissionProviding: Sendable {
    func authorizationStatus() -> CameraAuthorizationStatus
    func requestAccess() async -> CameraAuthorizationStatus
}

@MainActor
protocol BarcodeScannerServicing: AnyObject {
    var captureSession: AVCaptureSession { get }
    var onBarcodeDetected: ((Result<ScannedBarcode, ScannerError>) -> Void)? { get set }

    func configureIfNeeded() throws
    func startRunning()
    func stopRunning()
    func resumeScanning()
}
