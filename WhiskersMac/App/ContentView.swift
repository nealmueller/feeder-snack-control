import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Feeder Snack Control")
                .font(.largeTitle.bold())

            GroupBox("Feeder Account") {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Email", text: $appModel.email)
                        .textFieldStyle(.roundedBorder)
                    SecureField("Password", text: $appModel.password)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button("Save Credentials") {
                            Task { await appModel.saveCredentials() }
                        }
                        Button("Refresh Feeders") {
                            Task { await appModel.refreshFeeders() }
                        }
                        Button("Clear Local Data") {
                            Task { await appModel.clearLocalData() }
                        }
                    }
                }
                .padding(.top, 4)
            }

            GroupBox("Feeder") {
                VStack(alignment: .leading, spacing: 12) {
                    if appModel.feederOptions.isEmpty {
                        Text("No feeder loaded yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Selected Feeder", selection: Binding(
                            get: { appModel.selectedFeederSerial },
                            set: { appModel.updateSelectedFeeder(serial: $0) }
                        )) {
                            ForEach(appModel.feederOptions) { feeder in
                                Text(feeder.name).tag(feeder.serial)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    Button {
                        Task { await appModel.sendSnack() }
                    } label: {
                        Label("Give Snack", systemImage: "pawprint.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(appModel.selectedFeederSerial.isEmpty || appModel.isWorking)
                }
                .padding(.top, 4)
            }

            GroupBox("Status") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(appModel.statusText)
                    if let last = appModel.lastSnackResponse {
                        Text("Last result: \(last.message)")
                            .foregroundStyle(.secondary)
                        Text(last.timestamp.formatted(date: .numeric, time: .standard))
                            .foregroundStyle(.secondary)
                    }
                    Text("Control Center uses the same local bridge while the app is running.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
            }

            Spacer()
        }
        .padding(24)
    }
}

struct MenuBarContentView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(appModel.selectedFeederName.isEmpty ? "No feeder selected" : appModel.selectedFeederName)
                .font(.headline)
            Text(appModel.statusText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Give Snack") {
                Task { await appModel.sendSnack() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(appModel.selectedFeederSerial.isEmpty || appModel.isWorking)
        }
        .padding()
    }
}
