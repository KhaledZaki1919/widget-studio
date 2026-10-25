import SwiftUI
import WidgetKit
import WidgetKitCore

@main
struct WidgetStudioWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SmallTemplateWidget()
        MediumTemplateWidget()
        LargeTemplateWidget()
        // Kept for install checks (Diagnostics, ADR-005); large shows the template widgets' log.
        ProbeWidget()
        // Diagnostics for the gray template widget (ADR-012); remove once it is solved.
        FontTestWidget()
        StaticTemplateTestWidget()
    }
}
