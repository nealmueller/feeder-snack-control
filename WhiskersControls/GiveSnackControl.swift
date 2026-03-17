import SwiftUI
import WidgetKit

struct GiveSnackControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: AppConstants.widgetKind) {
            ControlWidgetButton(action: GiveSnackIntent()) {
                Label("Give Snack", systemImage: "pawprint.fill")
                    .controlWidgetActionHint("Send a snack")
            } actionLabel: { isActive in
                if isActive {
                    Text("Sending…")
                }
            }
        }
        .displayName("Give Snack")
        .description("Send a snack to the selected feeder.")
    }
}
