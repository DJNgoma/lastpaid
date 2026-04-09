import CoreLocation
import Foundation

struct CapturedLocation: Equatable, Sendable {
    let latitude: Double
    let longitude: Double
    let placeName: String?
}

@MainActor
protocol LocationServicing: AnyObject {
    var authorizationStatus: CLAuthorizationStatus { get }
    func captureCurrent() async -> CapturedLocation?
}

@MainActor
final class LocationService: NSObject, LocationServicing, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var pendingContinuations: [CheckedContinuation<CLLocation?, Never>] = []

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    func captureCurrent() async -> CapturedLocation? {
        let status = await ensureAuthorization()
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            return nil
        }

        guard let location = await requestOneShotLocation() else {
            return nil
        }

        let placeName = await reverseGeocode(location: location)

        return CapturedLocation(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            placeName: placeName
        )
    }

    // MARK: - Authorization

    private var authContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?

    private func ensureAuthorization() async -> CLAuthorizationStatus {
        let status = manager.authorizationStatus
        if status != .notDetermined {
            return status
        }

        return await withCheckedContinuation { continuation in
            authContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            if let continuation = authContinuation {
                authContinuation = nil
                continuation.resume(returning: status)
            }
        }
    }

    // MARK: - One-shot location

    private func requestOneShotLocation() async -> CLLocation? {
        await withCheckedContinuation { (continuation: CheckedContinuation<CLLocation?, Never>) in
            pendingContinuations.append(continuation)
            manager.requestLocation()

            // Safety timeout — if no fix in 8 seconds, return nil.
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                self.resumePending(with: nil)
            }
        }
    }

    private func resumePending(with location: CLLocation?) {
        guard pendingContinuations.isEmpty == false else { return }
        let pending = pendingContinuations
        pendingContinuations.removeAll()
        for continuation in pending {
            continuation.resume(returning: location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations.last
        Task { @MainActor in
            self.resumePending(with: location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.resumePending(with: nil)
        }
    }

    // MARK: - Reverse geocoding

    private func reverseGeocode(location: CLLocation) async -> String? {
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let mark = placemarks.first else { return nil }
            return Self.formatPlacemark(mark)
        } catch {
            return nil
        }
    }

    static func formatPlacemark(_ placemark: CLPlacemark) -> String? {
        // Prefer "Pick n Pay, Sandton" style: name (POI) + locality.
        let name = placemark.name
        let locality = placemark.locality ?? placemark.subLocality

        // Skip when `name` is just the street address (it equals thoroughfare + subThoroughfare).
        let nameIsAddress: Bool = {
            guard let name, let street = placemark.thoroughfare else { return false }
            return name.contains(street)
        }()

        let primary = (nameIsAddress ? nil : name) ?? placemark.areasOfInterest?.first

        switch (primary, locality) {
        case (let primary?, let locality?):
            return "\(primary), \(locality)"
        case (let primary?, nil):
            return primary
        case (nil, let locality?):
            return locality
        case (nil, nil):
            return placemark.thoroughfare
        }
    }
}
