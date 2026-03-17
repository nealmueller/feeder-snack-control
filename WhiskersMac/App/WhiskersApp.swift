import SwiftUI

@main
struct WhiskersApp: App {
    @StateObject private var appModel = AppModel()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(appModel)
                .frame(minWidth: 620, minHeight: 460)
                .task {
                    await appModel.start()
                }
                .onOpenURL { url in
                    guard url.scheme == "feedersnackcontrol", url.host == "settings" else { return }
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .handlesExternalEvents(matching: ["settings"])
        .defaultLaunchBehavior(.suppressed)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appVisibility) {}
        }
        .defaultSize(width: 620, height: 460)
    }
}
