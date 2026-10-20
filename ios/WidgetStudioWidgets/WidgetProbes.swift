import CoreLocation
import UIKit
import WidgetKitCore

/// Capability checks that must run inside the widget extension process (ADR-005).
@MainActor
enum WidgetProbes {
    /// One location fix from the extension, plus `isAuthorizedForWidgetUpdates`.
    static func location(timeout: TimeInterval = 10) async -> (authorized: Bool, outcome: ProbeOutcome) {
        await withCheckedContinuation { continuation in
            OneShotLocation().start(timeout: timeout) { authorized, outcome in
                continuation.resume(returning: (authorized, outcome))
            }
        }
    }

    static func battery() -> ProbeOutcome {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        let level = device.batteryLevel
        guard level >= 0 else { return .failed("batteryLevel = -1 (unknown in this process)") }
        return .ok("\(Int((level * 100).rounded()))%, \(describe(device.batteryState))")
    }

    private static func describe(_ state: UIDevice.BatteryState) -> String {
        switch state {
        case .charging: "charging"
        case .full: "full"
        case .unplugged: "unplugged"
        case .unknown: "state unknown"
        @unknown default: "state \(state.rawValue)"
        }
    }
}

/// Requests a single location and reports once: on a fix, an error or the timeout.
/// Created and used on the main thread, so delegate callbacks arrive there too.
private final class OneShotLocation: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var finish: ((Bool, ProbeOutcome) -> Void)?
    /// Keeps the probe alive until it reports (nobody else holds it).
    private var retainedSelf: OneShotLocation?

    func start(timeout: TimeInterval, finish: @escaping (Bool, ProbeOutcome) -> Void) {
        self.finish = finish
        retainedSelf = self
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.requestLocation()
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
            self?.complete(.failed("no fix within \(Int(timeout)) s"))
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let fix = locations.last else { return }
        complete(.ok(String(
            format: "%.2f, %.2f ±%.0f m", fix.coordinate.latitude, fix.coordinate.longitude, fix.horizontalAccuracy
        )))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let status = manager.authorizationStatus.rawValue
        complete(.failed("\(error.localizedDescription) (authorization status \(status))"))
    }

    private func complete(_ outcome: ProbeOutcome) {
        guard let finish else { return }
        self.finish = nil
        let authorized = manager.isAuthorizedForWidgetUpdates
        manager.delegate = nil
        retainedSelf = nil
        finish(authorized, outcome)
    }
}
