import Foundation

struct BridgeClient {
    private let baseURL = URL(string: "http://127.0.0.1:\(AppConstants.bridgePort)")!

    func snack() async throws -> SnackResponse {
        var request = URLRequest(url: baseURL.appending(path: "snack"))
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        return try await execute(request)
    }

    func status() async throws -> StatusResponse {
        var request = URLRequest(url: baseURL.appending(path: "status"))
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        return try await execute(request)
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BridgeError.invalidResponse
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if 200 ..< 300 ~= http.statusCode {
            return try decoder.decode(T.self, from: data)
        }

        if let error = try? decoder.decode(SnackResponse.self, from: data) {
            throw BridgeError.server(error.message)
        }

        throw BridgeError.server(String(decoding: data, as: UTF8.self))
    }
}
