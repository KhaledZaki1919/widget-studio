import Foundation

/// Where the app and the widget extension keep their files.
public struct StoreLocation: Sendable, Equatable {
    public let directory: URL
    /// The App Group in use, or nil when falling back to the app's own container.
    public let appGroupID: String?
    /// Where `appGroupID` came from; nil with the fallback container.
    public let source: AppGroupSource?

    public init(directory: URL, appGroupID: String?, source: AppGroupSource?) {
        self.directory = directory
        self.appGroupID = appGroupID
        self.source = source
    }

    public var isShared: Bool { appGroupID != nil }
}

/// Where a candidate App Group ID was found, in resolution order.
public enum AppGroupSource: String, Sendable, Equatable, CaseIterable {
    /// `ALTAppGroups` in Info.plist. AltStore and SideStore register these groups and rewrite
    /// the key to the real IDs when they sign the app.
    case altAppGroups
    /// `com.apple.security.application-groups` in `embedded.mobileprovision`.
    case profile
    /// The compiled default (`WSAppGroup` in Info.plist).
    case compiled
}

/// Resolves the shared container at runtime (ADR-004):
/// 1. `ALTAppGroups` from Info.plist (as rewritten by AltStore / SideStore),
/// 2. App Groups in the embedded provisioning profile (as rewritten by the signer),
/// 3. the compiled default from Info.plist (`WSAppGroup`),
/// 4. the target's own Application Support directory (not shared).
public enum AppGroupResolver {
    public static let infoPlistKey = "WSAppGroup"
    public static let altStoreKey = "ALTAppGroups"

    public struct Candidate: Sendable, Equatable {
        public let id: String
        public let source: AppGroupSource
    }

    public static func resolve(bundle: Bundle = .main) -> StoreLocation {
        resolve(
            candidates: candidates(bundle: bundle),
            containerURL: { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0) },
            fallback: defaultFallbackDirectory()
        )
    }

    /// Every group ID worth trying, in order, without duplicates (also shown in Diagnostics).
    public static func candidates(bundle: Bundle = .main) -> [Candidate] {
        candidates(
            altGroups: bundle.object(forInfoDictionaryKey: altStoreKey) as? [String] ?? [],
            profileGroups: ProvisioningProfile.load(from: bundle)?.appGroups ?? [],
            compiled: bundle.object(forInfoDictionaryKey: infoPlistKey) as? String
        )
    }

    static func candidates(altGroups: [String], profileGroups: [String], compiled: String?) -> [Candidate] {
        var seen = Set<String>()
        let all = altGroups.map { Candidate(id: $0, source: .altAppGroups) }
            + profileGroups.map { Candidate(id: $0, source: .profile) }
            + [compiled].compactMap { $0 }.map { Candidate(id: $0, source: .compiled) }
        return all.filter { !$0.id.isEmpty && seen.insert($0.id).inserted }
    }

    static func resolve(candidates: [Candidate], containerURL: (String) -> URL?, fallback: URL) -> StoreLocation {
        for candidate in candidates {
            if let url = containerURL(candidate.id), isWritable(url) {
                return StoreLocation(directory: url, appGroupID: candidate.id, source: candidate.source)
            }
        }
        return StoreLocation(directory: fallback, appGroupID: nil, source: nil)
    }

    /// `containerURL` can return a path even when the entitlement is missing, so write to it.
    static func isWritable(_ directory: URL) -> Bool {
        let probe = directory.appendingPathComponent(".ws-write-probe")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data().write(to: probe)
            try FileManager.default.removeItem(at: probe)
            return true
        } catch {
            return false
        }
    }

    static func defaultFallbackDirectory() -> URL {
        let fileManager = FileManager.default
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let directory = base.appendingPathComponent("WidgetStudio", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
