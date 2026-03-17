import Foundation

@MainActor
final class SettingsStore {
    private enum Keys {
        static let email = "email"
        static let selectedFeederSerial = "selectedFeederSerial"
        static let selectedFeederName = "selectedFeederName"
    }

    private let defaults = UserDefaults.standard

    var email: String? {
        get { defaults.string(forKey: Keys.email) }
        set { defaults.set(newValue, forKey: Keys.email) }
    }

    var selectedFeederSerial: String? {
        get { defaults.string(forKey: Keys.selectedFeederSerial) }
        set { defaults.set(newValue, forKey: Keys.selectedFeederSerial) }
    }

    var selectedFeederName: String? {
        get { defaults.string(forKey: Keys.selectedFeederName) }
        set { defaults.set(newValue, forKey: Keys.selectedFeederName) }
    }

    func clear() {
        defaults.removeObject(forKey: Keys.email)
        defaults.removeObject(forKey: Keys.selectedFeederSerial)
        defaults.removeObject(forKey: Keys.selectedFeederName)
    }
}
