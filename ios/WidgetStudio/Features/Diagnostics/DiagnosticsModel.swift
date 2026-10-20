import CoreLocation
import HealthKit
import Observation
import UIKit
import WidgetKit
import WidgetKitCore

/// Collects what actually works on this install (ADR-004, ADR-005): signing profile, App Group,
/// the widget's own report (location + battery inside the extension), location permission,
/// HealthKit and battery.
@MainActor
@Observable
final class DiagnosticsModel {
    private(set) var profileStatus: ProvisioningProfile.Status = .missing
    private(set) var store = AppGroupResolver.resolve()
    /// Every group ID the resolver tried, in order (ADR-004).
    private(set) var candidates: [AppGroupResolver.Candidate] = []
    private(set) var appGroupTest: ProbeOutcome = .notRun
    private(set) var testValue: Int?
    private(set) var widgetReport: WidgetReport?
    private(set) var locationStatus: CLAuthorizationStatus = .notDetermined
    private(set) var health: ProbeOutcome = .notRun
    private(set) var healthRunning = false
    private(set) var battery: ProbeOutcome = .notRun
    private(set) var widgetReloadedAt: Date?

    private let location = LocationPermission()

    init() {
        location.onChange = { [weak self] status in self?.locationStatus = status }
    }

    var profile: ProvisioningProfile? { profileStatus.profile }

    /// Re-reads everything, refreshes the app heartbeat and asks the widget to reload.
    func refresh() {
        profileStatus = ProvisioningProfile.inspect()
        store = AppGroupResolver.resolve()
        candidates = AppGroupResolver.candidates()
        let probeStore = ProbeStore(location: store)
        appGroupTest = probeStore.readWriteTest()
        if AppInfo.writeHeartbeat(changeValue: 0) == nil { widgetReloadedAt = .now }
        testValue = probeStore.readAppHeartbeat()?.testValue
        widgetReport = probeStore.readWidgetReport()
        locationStatus = location.status
        battery = Self.measureBattery()
    }

    /// Increments the value the widget displays, so the owner can watch it change there.
    func writeTestValue() {
        if let error = AppInfo.writeHeartbeat(changeValue: 1) {
            appGroupTest = .failed(error.localizedDescription)
        } else {
            widgetReloadedAt = .now
        }
        testValue = ProbeStore(location: store).readAppHeartbeat()?.testValue
    }

    func requestLocation() {
        location.request()
    }

    func runHealthKit() async {
        healthRunning = true
        health = await HealthProbe.run()
        healthRunning = false
    }

    var healthAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Whether the signing profile grants HealthKit (nil without a readable profile).
    var profileGrantsHealthKit: Bool? {
        profile.map { $0.entitlementKeys.contains("com.apple.developer.healthkit") }
    }

    var locationAllowed: Bool {
        locationStatus == .authorizedWhenInUse || locationStatus == .authorizedAlways
    }

    static func measureBattery() -> ProbeOutcome {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        let level = device.batteryLevel
        guard level >= 0 else { return .failed("batteryLevel = -1") }
        return .ok("\(Int((level * 100).rounded()))%")
    }

    static func describe(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: "not determined"
        case .restricted: "restricted"
        case .denied: "denied"
        case .authorizedAlways: "always"
        case .authorizedWhenInUse: "when in use"
        @unknown default: "status \(status.rawValue)"
        }
    }

    static func describe(_ status: ProvisioningProfile.Status) -> String {
        switch status {
        case .missing: "missing"
        case .unreadable(let byteCount): "unreadable (\(byteCount) B)"
        case .parsed(let profile): "parsed" + (profile.name.map { " · \($0)" } ?? "")
        }
    }

    /// "group.a (altAppGroups), group.b (compiled)"
    var candidatesText: String {
        candidates.isEmpty ? "none" : candidates.map { "\($0.id) (\($0.source.rawValue))" }.joined(separator: ", ")
    }

    private static func stamp(_ date: Date?) -> String {
        date.map { $0.formatted(.iso8601) } ?? "never"
    }

    /// Plain English text for the share sheet, to paste back to Claude (not localized on purpose).
    var reportText: String {
        let report = widgetReport
        let lines: [String] = [
            "Widget Studio diagnostics \(AppInfo.versionText) · \(Date.now.formatted(.iso8601))",
            "iOS \(UIDevice.current.systemVersion) · \(UIDevice.current.model)",
            "",
            "[Build]",
            "Bundle ID: \(Bundle.main.bundleIdentifier ?? "?")",
            "Profile: \(Self.describe(profileStatus))",
            "Team: \(profile?.teamIdentifiers.joined(separator: ", ") ?? "?")",
            "Profile App Groups: \(profile.map { $0.appGroups.isEmpty ? "none" : $0.appGroups.joined(separator: ", ") } ?? "no profile")",
            "Profile entitlements: \(profile?.entitlementKeys.joined(separator: ", ") ?? "?")",
            "",
            "[App Group]",
            "Resolved group: \(store.appGroupID ?? "none (app's own container)")"
                + (store.source.map { " via \($0.rawValue)" } ?? ""),
            "Candidates tried: \(candidatesText)",
            "Shared: \(store.isShared)",
            "Read/write: \(appGroupTest.reportText)",
            "Test value: \(testValue.map { "\($0)" } ?? "none")",
            "",
            "[Widget]",
            "Last widget report: \(Self.stamp(report?.date))",
            "Widget resolved group: \(report.map { $0.appGroupID ?? "none" } ?? "?")",
            "Widget saw app value: \(report?.appHeartbeat.map { "\($0.testValue) (written \(Self.stamp($0.date)))" } ?? "no")",
            "Location authorized for widget: \(report.map { "\($0.locationAuthorizedForWidget)" } ?? "?")",
            "Location in widget: \(report?.location.reportText ?? "?")",
            "Battery in widget: \(report?.battery.reportText ?? "?")",
            "",
            "[Location]",
            "Permission: \(Self.describe(locationStatus))",
            "",
            "[HealthKit]",
            "Health data available: \(healthAvailable)",
            "Profile grants HealthKit: \(profileGrantsHealthKit.map { "\($0)" } ?? "?")",
            "Steps query: \(health.reportText)",
            "",
            "[Battery]",
            "App: \(battery.reportText)",
        ]
        return lines.joined(separator: "\n")
    }
}

/// Wraps `CLLocationManager` authorization for the app (the widget uses the app's permission).
final class LocationPermission: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    var onChange: (@MainActor (CLAuthorizationStatus) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
    }

    var status: CLAuthorizationStatus { manager.authorizationStatus }

    func request() {
        manager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            self?.onChange?(status)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}

/// Requests read access to steps and sleep (brief §4.5 bindings), then queries today's steps.
enum HealthProbe {
    private static let store = HKHealthStore()

    static func run() async -> ProbeOutcome {
        guard HKHealthStore.isHealthDataAvailable() else { return .failed("health data not available") }
        guard let steps = HKQuantityType.quantityType(forIdentifier: .stepCount),
              let sleep = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)
        else { return .failed("types unavailable") }
        do {
            try await store.requestAuthorization(toShare: [], read: [steps, sleep])
        } catch {
            return .failed(error.localizedDescription)
        }
        let predicate = HKQuery.predicateForSamples(withStart: Calendar.current.startOfDay(for: .now), end: .now)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: steps, quantitySamplePredicate: predicate, options: .cumulativeSum
            ) { _, statistics, error in
                if let error = error as? HKError, error.code == .errorNoData {
                    // iOS hides read denials: "no data" can also mean access was denied.
                    continuation.resume(returning: .ok("authorized; no steps today (or read access denied)"))
                } else if let error {
                    continuation.resume(returning: .failed(error.localizedDescription))
                } else {
                    let count = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                    continuation.resume(returning: .ok("\(Int(count)) steps today"))
                }
            }
            store.execute(query)
        }
    }
}
