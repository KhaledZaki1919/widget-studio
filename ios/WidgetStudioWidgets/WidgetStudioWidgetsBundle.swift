import SwiftUI
import WidgetKit
import WidgetKitCore

/// One widget per template (ADR-013), grouped by category in library order, then the check
/// widget. Category bundles keep each block within the 10-widget limit of the builder.
@main
struct WidgetStudioWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TimeTemplateWidgets().body
        WeatherTemplateWidgets().body
        HealthTemplateWidgets().body
        PrayerTemplateWidgets().body
        CountdownTemplateWidgets().body
        PhotoTemplateWidgets().body
        TilesTemplateWidgets().body
        CounterTemplateWidgets().body
        // Kept for install checks (Diagnostics, ADR-005); large shows the template widgets' log.
        ProbeWidget()
    }
}
