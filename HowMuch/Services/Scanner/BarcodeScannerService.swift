import AVFoundation
import Foundation

@MainActor
final class BarcodeScannerService: NSObject, BarcodeScannerServicing {
    let captureSession = AVCaptureSession()
    var onBarcodeDetected: ((Result<ScannedBarcode, ScannerError>) -> Void)?

    private let duplicateSuppressionInterval: TimeInterval
    private let sessionQueue = DispatchQueue(label: "com.djngoma.howmuch.scanner-session")
    private var isConfigured = false
    private var isPaused = false
    private var lastDetectedPayload = ""
    private var lastDetectedAt = Date.distantPast

    init(duplicateSuppressionInterval: TimeInterval = 1.5) {
        self.duplicateSuppressionInterval = duplicateSuppressionInterval
        super.init()
    }

    func configureIfNeeded() throws {
        guard isConfigured == false else {
            return
        }

        #if targetEnvironment(simulator)
        throw ScannerError.simulatorUnavailable
        #else
        guard let videoDevice = AVCaptureDevice.default(for: .video) else {
            throw ScannerError.cameraUnavailable
        }

        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: videoDevice)
        } catch {
            throw ScannerError.unsupportedDevice
        }

        let metadataOutput = AVCaptureMetadataOutput()

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high

        guard captureSession.canAddInput(input),
              captureSession.canAddOutput(metadataOutput) else {
            captureSession.commitConfiguration()
            throw ScannerError.unsupportedDevice
        }

        captureSession.addInput(input)
        captureSession.addOutput(metadataOutput)
        metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
        metadataOutput.metadataObjectTypes = [
            .ean13,
            .ean8,
            .upce,
            .code128,
            .code39,
            .qr
        ]
        captureSession.commitConfiguration()

        isConfigured = true
        #endif
    }

    func startRunning() {
        guard isConfigured, isPaused == false else {
            return
        }

        sessionQueue.async { [captureSession] in
            if captureSession.isRunning == false {
                captureSession.startRunning()
            }
        }
    }

    func stopRunning() {
        sessionQueue.async { [captureSession] in
            if captureSession.isRunning {
                captureSession.stopRunning()
            }
        }
    }

    func resumeScanning() {
        isPaused = false
        startRunning()
    }

    private func shouldEmit(payload: String, at date: Date) -> Bool {
        if payload == lastDetectedPayload, date.timeIntervalSince(lastDetectedAt) < duplicateSuppressionInterval {
            return false
        }

        lastDetectedPayload = payload
        lastDetectedAt = date
        return true
    }

    nonisolated private static func mappedBarcodeType(
        for metadataType: AVMetadataObject.ObjectType,
        payload: String
    ) -> BarcodeType {
        switch metadataType {
        case .ean13:
            if payload.count == 12 || (payload.count == 13 && payload.hasPrefix("0")) {
                return .upca
            }
            return .ean13
        case .ean8:
            return .ean8
        case .upce:
            return .upce
        case .code128:
            return .code128
        case .code39:
            return .code39
        case .qr:
            return .qr
        default:
            return .unknown
        }
    }
}

extension BarcodeScannerService: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let readableCode = metadataObjects.compactMap({ $0 as? AVMetadataMachineReadableCodeObject }).first,
              let rawValue = readableCode.stringValue else {
            Task { @MainActor [weak self] in
                self?.emitFailure(.invalidBarcode)
            }
            return
        }

        let normalizedPayload = BarcodeNormalizer.normalize(rawValue)
        guard normalizedPayload.isEmpty == false else {
            Task { @MainActor [weak self] in
                self?.emitFailure(.invalidBarcode)
            }
            return
        }

        let now = Date.now
        let symbology = Self.mappedBarcodeType(for: readableCode.type, payload: normalizedPayload)

        Task { @MainActor [weak self] in
            self?.handleDetectedPayload(normalizedPayload, symbology: symbology, at: now)
        }
    }

    private func handleDetectedPayload(_ normalizedPayload: String, symbology: BarcodeType, at now: Date) {
        guard isPaused == false else {
            return
        }

        guard shouldEmit(payload: normalizedPayload, at: now) else {
            return
        }

        isPaused = true
        stopRunning()

        onBarcodeDetected?(
            .success(
                ScannedBarcode(payload: normalizedPayload, symbology: symbology, scannedAt: now)
            )
        )
    }

    private func emitFailure(_ error: ScannerError) {
        onBarcodeDetected?(.failure(error))
    }
}
