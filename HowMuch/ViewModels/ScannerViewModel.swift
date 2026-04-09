import AVFoundation
import Foundation
import Observation

@Observable
@MainActor
final class ScannerViewModel {
    private let catalogService: any CatalogServicing
    private let permissionService: any CameraPermissionProviding
    private let scannerService: any BarcodeScannerServicing

    var permissionStatus: CameraAuthorizationStatus
    var errorMessage: String?
    var resolution: ScanResolution?
    var isManualEntryPresented = false
    var manualBarcodeValue = ""
    var manualBarcodeType: BarcodeType = BarcodeType.userSelectableCases.first ?? .ean13

    var captureSession: AVCaptureSession {
        scannerService.captureSession
    }

    init(
        catalogService: any CatalogServicing,
        permissionService: any CameraPermissionProviding,
        scannerService: any BarcodeScannerServicing
    ) {
        self.catalogService = catalogService
        self.permissionService = permissionService
        self.scannerService = scannerService
        self.permissionStatus = permissionService.authorizationStatus()

        self.scannerService.onBarcodeDetected = { [weak self] result in
            self?.handleScan(result)
        }
    }

    func requestAccessIfNeeded() async {
        refreshPermissionStatus()

        switch permissionStatus {
        case .notDetermined:
            permissionStatus = await permissionService.requestAccess()
            handlePermissionUpdate()
        case .authorized:
            prepareScanner()
        case .denied:
            errorMessage = ScannerError.permissionDenied.localizedDescription
        case .restricted:
            errorMessage = ScannerError.permissionRestricted.localizedDescription
        case .unsupported:
            errorMessage = ScannerError.cameraUnavailable.localizedDescription
        }
    }

    func handleAppDidBecomeActive() async {
        refreshPermissionStatus()
        handlePermissionUpdate()
    }

    func refreshPermissionStatus() {
        permissionStatus = permissionService.authorizationStatus()
    }

    func stopScanning() {
        scannerService.stopRunning()
    }

    func beginManualEntry() {
        stopScanning()
        isManualEntryPresented = true
    }

    func endManualEntry() {
        isManualEntryPresented = false
        if permissionStatus == .authorized {
            resumeScanning()
        }
    }

    func resumeScanning() {
        errorMessage = nil
        scannerService.resumeScanning()
    }

    @discardableResult
    func submitManualBarcode() -> Bool {
        do {
            let normalized = try BarcodeNormalizer.validated(
                manualBarcodeValue,
                symbology: manualBarcodeType
            )
            resolution = try catalogService.resolveScan(
                ScannedBarcode(payload: normalized, symbology: manualBarcodeType)
            )
            manualBarcodeValue = ""
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func consumeResolution() {
        resolution = nil
    }

    func clearError() {
        errorMessage = nil
    }

    private func handlePermissionUpdate() {
        switch permissionStatus {
        case .authorized:
            prepareScanner()
        case .denied:
            errorMessage = ScannerError.permissionDenied.localizedDescription
        case .restricted:
            errorMessage = ScannerError.permissionRestricted.localizedDescription
        case .unsupported:
            errorMessage = ScannerError.cameraUnavailable.localizedDescription
        case .notDetermined:
            break
        }
    }

    private func prepareScanner() {
        do {
            try scannerService.configureIfNeeded()
            scannerService.startRunning()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleScan(_ result: Result<ScannedBarcode, ScannerError>) {
        switch result {
        case .success(let barcode):
            do {
                resolution = try catalogService.resolveScan(barcode)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
                scannerService.resumeScanning()
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            scannerService.resumeScanning()
        }
    }
}
