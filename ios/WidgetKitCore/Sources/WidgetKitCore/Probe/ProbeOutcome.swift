import Foundation

/// Result of one capability check in Diagnostics (ADR-005).
public enum ProbeOutcome: Codable, Sendable, Equatable {
    /// Worked; the detail is shown as is ("87%", "31.2, 29.9").
    case ok(String)
    /// Didn't work; the reason comes from the system or the probe.
    case failed(String)
    case notRun

    public var isOK: Bool {
        if case .ok = self { return true }
        return false
    }

    /// Plain text for the shareable report (not localized, so the owner can paste it to Claude).
    public var reportText: String {
        switch self {
        case .ok(let detail): "OK (\(detail))"
        case .failed(let reason): "FAILED (\(reason))"
        case .notRun: "not run"
        }
    }
}
