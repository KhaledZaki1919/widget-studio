import Foundation

/// The live Qibla compass in the app (the widget can't read the compass, so it opens this).
/// Angles are degrees clockwise from north.
public enum QiblaCompass {
    /// Within this many degrees of the Qibla counts as aligned...
    public static let alignTolerance = 4.0
    /// ...and it stays aligned until it drifts past this, so the haptic doesn't stutter at the edge.
    public static let releaseTolerance = 8.0
    /// Heading accuracy worse than this (or unknown, < 0) shows the calibration hint.
    public static let calibrationAccuracy = 25.0

    /// Where the needle points on screen: the Qibla relative to the phone's heading, -180…180.
    public static func needleAngle(qibla: Double, heading: Double) -> Double {
        normalized(qibla - heading)
    }

    public static func isAligned(needle: Double, wasAligned: Bool) -> Bool {
        abs(needle) <= (wasAligned ? releaseTolerance : alignTolerance)
    }

    public static func needsCalibration(accuracy: Double) -> Bool {
        accuracy < 0 || accuracy > calibrationAccuracy
    }

    /// An angle in -180…180.
    public static func normalized(_ angle: Double) -> Double {
        let wrapped = angle.truncatingRemainder(dividingBy: 360)
        if wrapped > 180 { return wrapped - 360 }
        if wrapped <= -180 { return wrapped + 360 }
        return wrapped
    }
}
