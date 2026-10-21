import SwiftUI
import WidgetKit
import WidgetKitCore

@main
struct WidgetStudioWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SpecWidget()
        // Kept for sideloading checks (Diagnostics, ADR-005).
        ProbeWidget()
    }
}
