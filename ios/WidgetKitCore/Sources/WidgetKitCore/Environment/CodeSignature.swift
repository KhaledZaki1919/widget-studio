import Foundation

/// What the signer actually put into an executable's code signature (Diagnostics → Signing,
/// ADR-012): the signing identifier and team from the CodeDirectory, and the entitlements blob.
/// Re-signing stores (Fast Store) can change all of these, and unlike `embedded.mobileprovision`
/// they are always present in a signed binary.
public struct CodeSignatureInfo: Sendable, Equatable {
    /// CodeDirectory identifier (usually the bundle ID the signer used).
    public let identifier: String?
    /// CodeDirectory team ID; nil for ad-hoc signatures.
    public let teamID: String?
    public let isAdHoc: Bool
    /// Keys of the signed entitlements, sorted.
    public let entitlementKeys: [String]
    /// `com.apple.security.application-groups` from the signed entitlements.
    public let appGroups: [String]
    /// `application-identifier` from the signed entitlements.
    public let applicationIdentifier: String?
}

public enum CodeSignature {
    /// Reads the code signature of a Mach-O executable (thin or fat); nil if unsigned or unreadable.
    public static func inspect(executable url: URL) -> CodeSignatureInfo? {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
        return parse(data)
    }

    static let fatMagic: UInt32 = 0xCAFE_BABE
    static let machO64Magic: UInt32 = 0xFEED_FACF
    static let lcCodeSignature: UInt32 = 0x1D
    static let superBlobMagic: UInt32 = 0xFADE_0CC0
    static let codeDirectoryMagic: UInt32 = 0xFADE_0C02
    static let entitlementsMagic: UInt32 = 0xFADE_7171

    static func parse(_ data: Data) -> CodeSignatureInfo? {
        let bytes = [UInt8](data)
        // Fat binary: use the first slice.
        if readBE32(bytes, 0) == fatMagic, let count = readBE32(bytes, 4), count > 0,
           let offset = readBE32(bytes, 8 + 8), let size = readBE32(bytes, 8 + 12) {
            let start = Int(offset)
            let end = start + Int(size)
            guard end <= bytes.count else { return nil }
            return parseThin(Array(bytes[start..<end]))
        }
        return parseThin(bytes)
    }

    static func parseThin(_ bytes: [UInt8]) -> CodeSignatureInfo? {
        guard readLE32(bytes, 0) == machO64Magic, let commandCount = readLE32(bytes, 16) else { return nil }
        var cursor = 32
        for _ in 0..<commandCount {
            guard let command = readLE32(bytes, cursor), let size = readLE32(bytes, cursor + 4), size >= 8 else { return nil }
            if command == lcCodeSignature, let dataOffset = readLE32(bytes, cursor + 8) {
                return parseSuperBlob(bytes, at: Int(dataOffset))
            }
            cursor += Int(size)
        }
        return nil
    }

    static func parseSuperBlob(_ bytes: [UInt8], at start: Int) -> CodeSignatureInfo? {
        guard readBE32(bytes, start) == superBlobMagic, let count = readBE32(bytes, start + 8) else { return nil }
        var directory: (identifier: String?, team: String?, adHoc: Bool)?
        var entitlements: [String: Any] = [:]
        for index in 0..<Int(count) {
            guard let offset = readBE32(bytes, start + 12 + index * 8 + 4) else { continue }
            let blob = start + Int(offset)
            switch readBE32(bytes, blob) {
            case codeDirectoryMagic?:
                // The first CodeDirectory is the primary one; alternates repeat its identity.
                if directory == nil { directory = parseCodeDirectory(bytes, at: blob) }
            case entitlementsMagic?:
                if let length = readBE32(bytes, blob + 4), length > 8, blob + Int(length) <= bytes.count {
                    let xml = Data(bytes[(blob + 8)..<(blob + Int(length))])
                    entitlements = (try? PropertyListSerialization.propertyList(from: xml, format: nil) as? [String: Any]) ?? [:]
                }
            default:
                break
            }
        }
        guard let directory else { return nil }
        return CodeSignatureInfo(
            identifier: directory.identifier,
            teamID: directory.team,
            isAdHoc: directory.adHoc,
            entitlementKeys: entitlements.keys.sorted(),
            appGroups: entitlements["com.apple.security.application-groups"] as? [String] ?? [],
            applicationIdentifier: entitlements["application-identifier"] as? String
        )
    }

    /// CodeDirectory: version at +8, flags at +12 (0x2 = ad hoc), identifier offset at +20,
    /// team offset at +48 from version 0x20200 on.
    static func parseCodeDirectory(_ bytes: [UInt8], at start: Int) -> (identifier: String?, team: String?, adHoc: Bool)? {
        guard let version = readBE32(bytes, start + 8), let flags = readBE32(bytes, start + 12),
              let identOffset = readBE32(bytes, start + 20) else { return nil }
        let identifier = cString(bytes, at: start + Int(identOffset))
        var team: String?
        if version >= 0x20200, let teamOffset = readBE32(bytes, start + 48), teamOffset > 0 {
            team = cString(bytes, at: start + Int(teamOffset))
        }
        return (identifier, team, flags & 0x2 != 0)
    }

    static func cString(_ bytes: [UInt8], at start: Int) -> String? {
        guard start >= 0, start < bytes.count else { return nil }
        guard let end = bytes[start...].firstIndex(of: 0) else { return nil }
        return String(bytes: bytes[start..<end], encoding: .utf8)
    }

    static func readBE32(_ bytes: [UInt8], _ offset: Int) -> UInt32? {
        guard offset >= 0, offset + 4 <= bytes.count else { return nil }
        return bytes[offset..<offset + 4].reduce(0) { $0 << 8 | UInt32($1) }
    }

    static func readLE32(_ bytes: [UInt8], _ offset: Int) -> UInt32? {
        guard offset >= 0, offset + 4 <= bytes.count else { return nil }
        return bytes[offset..<offset + 4].reversed().reduce(0) { $0 << 8 | UInt32($1) }
    }
}

/// Signing facts for one bundle inside the app (the app itself or an extension).
public struct BundleSigning: Sendable, Equatable {
    public let name: String
    public let bundleID: String?
    public let signature: CodeSignatureInfo?
    public let profile: ProvisioningProfile.Status

    /// The app and every extension in its PlugIns folder.
    public static func all(main: Bundle = .main) -> [BundleSigning] {
        var bundles = [main]
        if let plugIns = main.builtInPlugInsURL,
           let items = try? FileManager.default.contentsOfDirectory(at: plugIns, includingPropertiesForKeys: nil) {
            bundles += items.filter { $0.pathExtension == "appex" }.sorted { $0.path < $1.path }.compactMap(Bundle.init(url:))
        }
        return bundles.map(inspect)
    }

    public static func inspect(_ bundle: Bundle) -> BundleSigning {
        BundleSigning(
            name: bundle.bundleURL.lastPathComponent,
            bundleID: bundle.bundleIdentifier,
            signature: bundle.executableURL.flatMap(CodeSignature.inspect(executable:)),
            profile: ProvisioningProfile.inspect(bundle: bundle)
        )
    }
}
