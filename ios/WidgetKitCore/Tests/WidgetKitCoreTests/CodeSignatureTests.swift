import Foundation
import Testing
@testable import WidgetKitCore

/// Builds minimal Mach-O files with a code signature to test `CodeSignature`.
private enum MachO {
    static func be32(_ value: UInt32) -> [UInt8] { (0..<4).map { UInt8(truncatingIfNeeded: value >> (24 - 8 * $0)) } }
    static func le32(_ value: UInt32) -> [UInt8] { be32(value).reversed() }

    static func codeDirectory(identifier: String, team: String?, adHoc: Bool) -> [UInt8] {
        let header = 52
        let identBytes: [UInt8] = Array(identifier.utf8) + [0]
        let teamBytes: [UInt8] = team.map { Array($0.utf8) + [UInt8(0)] } ?? []
        var blob = be32(0xFADE_0C02) + be32(UInt32(header + identBytes.count + teamBytes.count))
        blob += be32(0x20200)                       // version
        blob += be32(adHoc ? 0x2 : 0)               // flags
        blob += be32(0)                             // hashOffset
        blob += be32(UInt32(header))                // identOffset
        blob += be32(0) + be32(0) + be32(0)         // nSpecialSlots, nCodeSlots, codeLimit
        blob += [0, 0, 0, 0] + be32(0)              // hashSize/type/platform/pageSize, spare2
        blob += be32(0)                             // scatterOffset
        blob += be32(team == nil ? 0 : UInt32(header + identBytes.count)) // teamOffset
        return blob + identBytes + teamBytes
    }

    static func entitlements(_ plist: [String: Any]) -> [UInt8] {
        let xml = (try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)) ?? Data()
        return be32(0xFADE_7171) + be32(UInt32(8 + xml.count)) + [UInt8](xml)
    }

    static func binary(identifier: String, team: String?, adHoc: Bool = false, entitlements plist: [String: Any]) -> Data {
        let directory = codeDirectory(identifier: identifier, team: team, adHoc: adHoc)
        let ents = entitlements(plist)
        let superHeader = 12 + 2 * 8
        var superBlob = be32(0xFADE_0CC0) + be32(UInt32(superHeader + directory.count + ents.count)) + be32(2)
        superBlob += be32(0) + be32(UInt32(superHeader))
        superBlob += be32(5) + be32(UInt32(superHeader + directory.count))
        superBlob += directory + ents
        let signatureOffset = 32 + 16
        var file = le32(0xFEED_FACF) + le32(0x0100_000C) + le32(0) + le32(2) + le32(1) + le32(16) + le32(0) + le32(0)
        file += le32(0x1D) + le32(16) + le32(UInt32(signatureOffset)) + le32(UInt32(superBlob.count))
        return Data(file + superBlob)
    }
}

struct CodeSignatureTests {
    @Test func readsTeamIdentifierAndEntitlements() throws {
        let data = MachO.binary(identifier: "com.store.widgetstudio.widgets", team: "STORE12345", entitlements: [
            "application-identifier": "STORE12345.com.store.widgetstudio.widgets",
            "com.apple.security.application-groups": ["group.com.store.widgetstudio"],
            "get-task-allow": false,
        ])
        let info = try #require(CodeSignature.parse(data))
        #expect(info.identifier == "com.store.widgetstudio.widgets")
        #expect(info.teamID == "STORE12345")
        #expect(!info.isAdHoc)
        #expect(info.appGroups == ["group.com.store.widgetstudio"])
        #expect(info.applicationIdentifier == "STORE12345.com.store.widgetstudio.widgets")
        #expect(info.entitlementKeys == ["application-identifier", "com.apple.security.application-groups", "get-task-allow"])
    }

    @Test func adHocSignatureHasNoTeam() throws {
        let info = try #require(CodeSignature.parse(MachO.binary(identifier: "com.khaled.widgetstudio", team: nil, adHoc: true,
                                                                 entitlements: [:])))
        #expect(info.isAdHoc)
        #expect(info.teamID == nil)
        #expect(info.entitlementKeys.isEmpty)
    }

    @Test func readsTheFirstSliceOfAFatBinary() throws {
        let thin = [UInt8](MachO.binary(identifier: "fat.test", team: "TEAMFAT001", entitlements: [:]))
        let header = 8 + 20
        var fat = MachO.be32(0xCAFE_BABE) + MachO.be32(1)
        fat += MachO.be32(0x0100_000C) + MachO.be32(0) + MachO.be32(UInt32(header)) + MachO.be32(UInt32(thin.count)) + MachO.be32(0)
        let info = try #require(CodeSignature.parse(Data(fat + thin)))
        #expect(info.teamID == "TEAMFAT001")
    }

    @Test func rejectsUnsignedOrGarbage() {
        #expect(CodeSignature.parse(Data("not a binary".utf8)) == nil)
        var unsigned = MachO.le32(0xFEED_FACF) + MachO.le32(0) + MachO.le32(0) + MachO.le32(2) + MachO.le32(0) + MachO.le32(0)
        unsigned += MachO.le32(0) + MachO.le32(0)
        #expect(CodeSignature.parse(Data(unsigned)) == nil)
    }
}
