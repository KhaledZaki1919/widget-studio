import Testing
@testable import WidgetKitCore

struct QiblaCompassTests {
    @Test func needleIsTheQiblaRelativeToTheHeading() {
        #expect(QiblaCompass.needleAngle(qibla: 136, heading: 0) == 136)
        #expect(QiblaCompass.needleAngle(qibla: 136, heading: 136) == 0)
        #expect(QiblaCompass.needleAngle(qibla: 136, heading: 350) == 146)
        #expect(QiblaCompass.needleAngle(qibla: 10, heading: 200) == 170)
        #expect(QiblaCompass.needleAngle(qibla: 10, heading: 190) == 180)
        #expect(QiblaCompass.needleAngle(qibla: 350, heading: 10) == -20)
    }

    @Test func alignmentHasHysteresis() {
        #expect(QiblaCompass.isAligned(needle: 3, wasAligned: false))
        #expect(!QiblaCompass.isAligned(needle: 6, wasAligned: false))
        #expect(QiblaCompass.isAligned(needle: -6, wasAligned: true))
        #expect(!QiblaCompass.isAligned(needle: 9, wasAligned: true))
    }

    @Test func calibrationHint() {
        #expect(QiblaCompass.needsCalibration(accuracy: -1))
        #expect(QiblaCompass.needsCalibration(accuracy: 40))
        #expect(!QiblaCompass.needsCalibration(accuracy: 10))
    }

    @Test func onlyTheQiblaTemplateOpensTheCompass() throws {
        #expect(DataRequirements.showsQibla(try TemplateLibrary.load(id: "mono.qibla").get()))
        #expect(!DataRequirements.showsQibla(try TemplateLibrary.load(id: "mono.clock.digital").get()))
    }
}
