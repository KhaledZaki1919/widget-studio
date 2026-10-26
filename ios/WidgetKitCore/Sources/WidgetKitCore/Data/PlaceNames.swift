import CoreLocation
import Foundation

/// Reverse-geocoded place names in Arabic and English, for `weather.city` (ADR-016). Used by the
/// app and the widget extension; failures (offline, rate limits) just mean no name.
public enum PlaceNames {
    public static func city(for location: CLLocation) async -> LocalizedText? {
        func name(_ locale: String) async -> String? {
            let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location, preferredLocale: Locale(identifier: locale))
            return placemarks?.first.flatMap { $0.locality ?? $0.subAdministrativeArea ?? $0.administrativeArea }
        }
        let english = await name("en_US")
        let arabic = await name("ar_EG")
        guard let any = english ?? arabic else { return nil }
        return .localized(en: english ?? any, ar: arabic ?? any)
    }

    /// A new stored location from a fix, keeping the cached name unless the device moved > 5 km.
    public static func store(_ fix: CLLocation, previous: StoredLocation?, now: Date = .now) async -> StoredLocation {
        var location = StoredLocation(latitude: fix.coordinate.latitude, longitude: fix.coordinate.longitude,
                                      altitude: fix.verticalAccuracy >= 0 ? fix.altitude : nil, city: previous?.city, updated: now)
        let moved = previous.map { $0.distance(toLatitude: location.latitude, longitude: location.longitude) > 5 } ?? true
        if moved || location.city == nil {
            location.city = await city(for: fix) ?? (moved ? nil : previous?.city)
        }
        return location
    }
}
