import Foundation
import Network

struct BridgeConfiguration {
    let email: String
    let password: String
    let feederSerial: String?

    var isConfigured: Bool {
        !email.isEmpty && !password.isEmpty
    }
}

actor WhiskersBridge {
    private let configurationProvider: @MainActor @Sendable () -> BridgeConfiguration?
    private let stateReporter: @Sendable (SnackResponse) -> Void
    private let bridgeRunner = PythonBridgeRunner()
    private var lastSnackResponse: SnackResponse?
    private var server: LocalHTTPServer?

    init(
        configurationProvider: @escaping @MainActor @Sendable () -> BridgeConfiguration?,
        stateReporter: @escaping @Sendable (SnackResponse) -> Void
    ) {
        self.configurationProvider = configurationProvider
        self.stateReporter = stateReporter
    }

    func start() async {
        guard server == nil else { return }
        let server = LocalHTTPServer(port: AppConstants.bridgePort) { [weak self] request in
            guard let self else { return LocalHTTPResponse(statusCode: 500, body: "Bridge unavailable") }
            return await self.handle(request: request)
        }
        self.server = server
        do {
            try await server.start()
        } catch {
            print("Failed to start bridge: \(error)")
        }
    }

    func listFeeders(email: String, password: String, selectedSerial: String?) async throws -> [FeederOption] {
        try await bridgeRunner.listFeeders(email: email, password: password, selectedSerial: selectedSerial)
    }

    private func handle(request: LocalHTTPRequest) async -> LocalHTTPResponse {
        switch (request.method, request.path) {
        case ("GET", "/status"):
            let configuration = await MainActor.run {
                configurationProvider()
            }
            let payload = StatusResponse(
                configured: configuration?.isConfigured ?? false,
                selectedFeederName: configuration?.feederSerial,
                lastResult: lastSnackResponse
            )
            return jsonResponse(payload)
        case ("POST", "/snack"):
            do {
                let response = try await giveSnack()
                return jsonResponse(response)
            } catch {
                let failure = SnackResponse(
                    ok: false,
                    message: error.localizedDescription,
                    feederName: nil,
                    timestamp: Date()
                )
                return jsonResponse(failure, statusCode: 500)
            }
        default:
            return LocalHTTPResponse(statusCode: 404, body: "Not found")
        }
    }

    private func giveSnack() async throws -> SnackResponse {
        let configuration = await MainActor.run {
            configurationProvider()
        }
        guard let configuration, configuration.isConfigured else {
            throw BridgeError.server("Configure credentials in the app first.")
        }
        let response = try await bridgeRunner.giveSnack(
            email: configuration.email,
            password: configuration.password,
            selectedSerial: configuration.feederSerial
        )
        lastSnackResponse = response
        stateReporter(response)
        return response
    }

    private func jsonResponse<T: Encodable>(_ value: T, statusCode: Int = 200) -> LocalHTTPResponse {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = (try? encoder.encode(value)) ?? Data()
        return LocalHTTPResponse(
            statusCode: statusCode,
            headers: ["Content-Type": "application/json"],
            bodyData: data
        )
    }
}
