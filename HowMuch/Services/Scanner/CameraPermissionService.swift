import AVFoundation
import Foundation

struct CameraPermissionService: CameraPermissionProviding {
    func authorizationStatus() -> CameraAuthorizationStatus {
        guard AVCaptureDevice.default(for: .video) != nil else {
            return .unsupported
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .authorized:
            return .authorized
        @unknown default:
            return .unsupported
        }
    }

    func requestAccess() async -> CameraAuthorizationStatus {
        guard AVCaptureDevice.default(for: .video) != nil else {
            return .unsupported
        }

        let granted = await AVCaptureDevice.requestAccess(for: .video)
        if granted {
            return .authorized
        }

        return authorizationStatus()
    }
}
