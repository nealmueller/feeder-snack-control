import Foundation
import Observation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var selectedFeederSerial: String = ""
    @Published var selectedFeederName: String = ""
    @Published var feederOptions: [FeederOption] = []
    @Published var statusText: String = "Not configured"
    @Published var isWorking = false
    @Published var lastSnackResponse: SnackResponse?

    private let settings = SettingsStore()
    private let keychain = KeychainStore()
    private lazy var bridge = WhiskersBridge(
        configurationProvider: { [weak self] in
            guard let self else { return nil }
            return BridgeConfiguration(
                email: self.email,
                password: self.password,
                feederSerial: self.selectedFeederSerial.isEmpty ? nil : self.selectedFeederSerial
            )
        },
        stateReporter: { [weak self] response in
            Task { @MainActor in
                self?.lastSnackResponse = response
                self?.statusText = response.message
            }
        }
    )

    func start() async {
        email = settings.email ?? ""
        selectedFeederSerial = settings.selectedFeederSerial ?? ""
        selectedFeederName = settings.selectedFeederName ?? ""
        password = (try? keychain.password()) ?? ""
        LaunchAtLoginManager.enable()
        await bridge.start()
        await refreshFeeders()
        await refreshStatus()
        if !feederOptions.isEmpty {
            closeVisibleWindows()
        }
    }

    func saveCredentials() async {
        isWorking = true
        defer { isWorking = false }

        do {
            settings.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
            try keychain.save(password: password)
            await refreshFeeders()
            statusText = "Credentials saved"
        } catch {
            statusText = error.localizedDescription
        }
    }

    func refreshFeeders() async {
        guard !email.isEmpty, !password.isEmpty else { return }
        isWorking = true
        defer { isWorking = false }

        do {
            let feeders = try await bridge.listFeeders(
                email: email,
                password: password,
                selectedSerial: selectedFeederSerial
            )
            feederOptions = feeders
            if selectedFeederSerial.isEmpty, let first = feeders.first {
                selectedFeederSerial = first.serial
                selectedFeederName = first.name
                settings.selectedFeederSerial = first.serial
                settings.selectedFeederName = first.name
            } else if let current = feeders.first(where: { $0.serial == selectedFeederSerial }) {
                selectedFeederName = current.name
                settings.selectedFeederName = current.name
            }
            statusText = feeders.isEmpty ? "No feeders found on this account" : "Feeder list refreshed"
        } catch {
            statusText = error.localizedDescription
        }
    }

    func updateSelectedFeeder(serial: String) {
        selectedFeederSerial = serial
        if let feeder = feederOptions.first(where: { $0.serial == serial }) {
            selectedFeederName = feeder.name
            settings.selectedFeederName = feeder.name
        }
        settings.selectedFeederSerial = serial
    }

    func sendSnack() async {
        isWorking = true
        defer { isWorking = false }

        do {
            let response = try await BridgeClient().snack()
            lastSnackResponse = response
            statusText = response.message
        } catch {
            statusText = error.localizedDescription
        }
    }

    func refreshStatus() async {
        do {
            let response = try await BridgeClient().status()
            lastSnackResponse = response.lastResult
            if response.configured {
                statusText = response.lastResult?.message ?? "Ready"
            } else {
                statusText = "Configure credentials to enable snacks"
            }
        } catch {
            statusText = "Bridge offline"
        }
    }

    func clearLocalData() async {
        isWorking = true
        defer { isWorking = false }

        settings.clear()
        keychain.deletePassword()
        PythonBridgeRunner.clearCachedData()

        email = ""
        password = ""
        selectedFeederSerial = ""
        selectedFeederName = ""
        feederOptions = []
        lastSnackResponse = nil
        statusText = "Local data cleared"
    }

    private func closeVisibleWindows() {
        for window in NSApplication.shared.windows where window.isVisible {
            window.close()
        }
    }
}
