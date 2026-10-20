import Foundation
import Testing
@testable import WidgetKitCore

private func makeTempDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("WidgetKitCoreTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

struct ProvisioningProfileTests {
    private static let plist = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>Name</key><string>Widget Studio Free</string>
        <key>TeamIdentifier</key><array><string>ABCDE12345</string></array>
        <key>ExpirationDate</key><date>2026-10-18T12:00:00Z</date>
        <key>Entitlements</key>
        <dict>
            <key>application-identifier</key><string>ABCDE12345.com.khaled.widgetstudio</string>
            <key>com.apple.security.application-groups</key>
            <array><string>group.com.khaled.widgetstudio.ABCDE12345</string></array>
        </dict>
    </dict>
    </plist>
    """

    @Test func parsesPlistInsideBinaryEnvelope() throws {
        var data = Data([0x30, 0x82, 0x0F, 0x00, 0xFF])   // CMS-like noise before
        data.append(Data(Self.plist.utf8))
        data.append(Data([0x00, 0xA0, 0x82]))              // signature noise after

        let profile = try #require(ProvisioningProfile.parse(data))
        #expect(profile.name == "Widget Studio Free")
        #expect(profile.teamIdentifiers == ["ABCDE12345"])
        #expect(profile.appGroups == ["group.com.khaled.widgetstudio.ABCDE12345"])
        #expect(profile.applicationIdentifier == "ABCDE12345.com.khaled.widgetstudio")
        #expect(profile.expirationDate != nil)
    }

    @Test func returnsNilWithoutPlist() {
        #expect(ProvisioningProfile.parse(Data("not a profile".utf8)) == nil)
    }
}

struct AppGroupResolverTests {
    @Test func candidatesOrderAltStoreThenProfileThenCompiledWithoutDuplicates() {
        let candidates = AppGroupResolver.candidates(
            altGroups: ["group.com.khaled.widgetstudio.TEAM123"],
            profileGroups: ["group.rewritten", "group.com.khaled.widgetstudio.TEAM123"],
            compiled: "group.com.khaled.widgetstudio"
        )
        #expect(candidates.map(\.id) == [
            "group.com.khaled.widgetstudio.TEAM123", "group.rewritten", "group.com.khaled.widgetstudio",
        ])
        #expect(candidates.map(\.source) == [.altAppGroups, .profile, .compiled])
    }

    @Test func dropsEmptyIDs() {
        let candidates = AppGroupResolver.candidates(altGroups: [""], profileGroups: [], compiled: nil)
        #expect(candidates.isEmpty)
    }

    @Test func usesFirstWritableContainer() throws {
        let shared = try makeTempDirectory()
        let fallback = try makeTempDirectory()
        let location = AppGroupResolver.resolve(
            candidates: [
                .init(id: "group.missing", source: .altAppGroups),
                .init(id: "group.ok", source: .compiled),
            ],
            containerURL: { $0 == "group.ok" ? shared : nil },
            fallback: fallback
        )
        #expect(location == StoreLocation(directory: shared, appGroupID: "group.ok", source: .compiled))
        #expect(location.isShared)
    }

    @Test func fallsBackWhenNoGroupIsUsable() throws {
        let fallback = try makeTempDirectory()
        let location = AppGroupResolver.resolve(
            candidates: [.init(id: "group.a", source: .profile)], containerURL: { _ in nil }, fallback: fallback
        )
        #expect(location.directory == fallback)
        #expect(location.appGroupID == nil)
        #expect(location.source == nil)
        #expect(!location.isShared)
    }
}

struct ProbeStoreTests {
    @Test func roundTripsAppHeartbeatAndWidgetReport() throws {
        let store = ProbeStore(directory: try makeTempDirectory())
        #expect(store.readAppHeartbeat() == nil)
        #expect(store.readWidgetReport() == nil)

        let date = Date(timeIntervalSince1970: 1_760_000_000)
        let heartbeat = AppHeartbeat(date: date, bundleID: "app", appGroupID: "g", testValue: 3)
        try store.writeAppHeartbeat(heartbeat)
        let report = WidgetReport(
            date: date, bundleID: "widget", appGroupID: "g", appHeartbeat: heartbeat,
            locationAuthorizedForWidget: true, location: .ok("30.0, 31.2"), battery: .failed("unknown")
        )
        try store.writeWidgetReport(report)

        #expect(store.readAppHeartbeat() == heartbeat)
        #expect(store.readWidgetReport() == report)
    }

    @Test func readWriteTestSucceedsInWritableDirectory() throws {
        let store = ProbeStore(directory: try makeTempDirectory())
        #expect(store.readWriteTest().isOK)
        // The test file is removed again.
        #expect(try FileManager.default.contentsOfDirectory(atPath: store.directory.path).isEmpty)
    }

    @Test func outcomeReportText() {
        #expect(ProbeOutcome.ok("87%").reportText == "OK (87%)")
        #expect(ProbeOutcome.failed("denied").reportText == "FAILED (denied)")
        #expect(ProbeOutcome.notRun.reportText == "not run")
    }
}
