import Foundation

struct SnackResponse: Codable {
    let ok: Bool
    let message: String
    let feederName: String?
    let timestamp: Date
}

struct StatusResponse: Codable {
    let configured: Bool
    let selectedFeederName: String?
    let lastResult: SnackResponse?
}

enum BridgeError: Error, LocalizedError {
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The bridge returned an invalid response."
        case let .server(message):
            return message
        }
    }
}
