import Foundation
import ServiceManagement

enum LaunchAtLoginManager {
    @MainActor
    static func enable() {
        do {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            }
        } catch {
            print("Launch at login registration failed: \(error)")
        }
    }
}
