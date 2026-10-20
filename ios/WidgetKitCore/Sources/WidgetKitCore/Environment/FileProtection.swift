import Foundation

/// Applies iOS Data Protection per file, which needs no entitlement (ADR-004), and excludes
/// the file from iCloud/iTunes device backups (D8: data stays on this device).
/// `completeUntilFirstUserAuthentication` keeps files readable by widgets and background
/// work after the first unlock.
public enum FileProtection {
    public static func apply(to url: URL) {
        #if os(iOS)
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
        #endif
        excludeFromBackup(url)
    }

    /// Marks a file or directory so it isn't copied into device backups.
    public static func excludeFromBackup(_ url: URL) {
        var target = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? target.setResourceValues(values)
    }

    /// Writes atomically, then applies the protection class.
    public static func write(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
        apply(to: url)
    }
}
