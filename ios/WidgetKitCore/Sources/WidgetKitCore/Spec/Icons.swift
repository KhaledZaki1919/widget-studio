/// SF Symbols a spec may use (brief §4.4), each with the Material Symbols name the Android
/// renderer will use later (M7). Keep entries sorted by area.
public enum Icons {
    public static let whitelist: [String: String] = [
        // Weather
        "sun.max.fill": "sunny", "moon.fill": "dark_mode", "moon.stars.fill": "bedtime",
        "cloud.fill": "cloud", "cloud.sun.fill": "partly_cloudy_day", "cloud.moon.fill": "partly_cloudy_night",
        "cloud.rain.fill": "rainy", "cloud.drizzle.fill": "rainy_light", "cloud.heavyrain.fill": "rainy_heavy",
        "cloud.bolt.rain.fill": "thunderstorm", "cloud.snow.fill": "weather_snowy", "cloud.fog.fill": "foggy",
        "wind": "air", "sunrise.fill": "wb_twilight", "sunset.fill": "wb_twilight", "thermometer.medium": "thermostat",
        "humidity.fill": "humidity_percentage", "sun.haze.fill": "wb_sunny",
        // Time
        "clock": "schedule", "clock.fill": "schedule", "alarm.fill": "alarm", "timer": "timer",
        "stopwatch": "timer", "hourglass": "hourglass_empty", "calendar": "calendar_today", "globe": "public",
        // Health and focus
        "figure.walk": "directions_walk", "figure.run": "directions_run", "heart.fill": "favorite",
        "bed.double.fill": "bed", "flame.fill": "local_fire_department", "brain.head.profile": "psychology",
        "drop.fill": "water_drop",
        // Prayer and location
        "location.fill": "location_on", "location.north.fill": "navigation", "safari.fill": "explore",
        "moon.haze.fill": "nights_stay", "building.columns.fill": "mosque", "map.fill": "map",
        // Device and tiles
        "battery.100": "battery_full", "battery.75": "battery_5_bar", "battery.50": "battery_3_bar",
        "battery.25": "battery_2_bar", "bolt.fill": "bolt", "wifi": "wifi", "antenna.radiowaves.left.and.right": "cell_tower",
        "airplane": "flight", "flashlight.on.fill": "flashlight_on", "moon.circle.fill": "dark_mode",
        "bluetooth": "bluetooth", "qrcode": "qr_code", "camera.fill": "photo_camera", "mic.fill": "mic",
        "mic.slash.fill": "mic_off", "record.circle": "radio_button_checked", "rotate.right": "screen_rotation",
        "house.fill": "home", "music.note": "music_note", "play.fill": "play_arrow", "pause.fill": "pause",
        "headphones": "headphones", "phone.fill": "call", "message.fill": "chat", "link": "link",
        "app.fill": "apps", "square.grid.2x2.fill": "grid_view", "bolt.horizontal.fill": "electric_bolt",
        // Counters and actions
        "plus": "add", "minus": "remove", "plus.circle.fill": "add_circle", "arrow.counterclockwise": "replay",
        "checkmark": "check", "checkmark.circle.fill": "check_circle", "star.fill": "star", "circle.fill": "circle",
        "circle": "radio_button_unchecked", "hand.tap.fill": "touch_app", "sparkles": "auto_awesome",
    ]

    public static func isAllowed(_ symbol: String) -> Bool {
        whitelist[symbol] != nil
    }
}
