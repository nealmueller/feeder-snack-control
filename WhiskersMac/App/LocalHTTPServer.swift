import Foundation
import Network

struct LocalHTTPRequest {
    let method: String
    let path: String
}

struct LocalHTTPResponse {
    let statusCode: Int
    var headers: [String: String] = [:]
    var body: String = ""
    var bodyData: Data?

    init(statusCode: Int, headers: [String: String] = [:], body: String) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
        self.bodyData = body.data(using: .utf8)
    }

    init(statusCode: Int, headers: [String: String] = [:], bodyData: Data) {
        self.statusCode = statusCode
        self.headers = headers
        self.bodyData = bodyData
    }
}

actor LocalHTTPServer {
    private let port: UInt16
    private let handler: @Sendable (LocalHTTPRequest) async -> LocalHTTPResponse
    private var listener: NWListener?

    init(port: UInt16, handler: @escaping @Sendable (LocalHTTPRequest) async -> LocalHTTPResponse) {
        self.port = port
        self.handler = handler
    }

    func start() async throws {
        let params = NWParameters.tcp
        let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        listener.newConnectionHandler = { [weak self] connection in
            connection.start(queue: .global(qos: .utility))
            self?.receive(on: connection)
        }
        self.listener = listener
        listener.start(queue: .global(qos: .utility))
    }

    nonisolated private func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8_192) { [weak self] data, _, _, _ in
            guard let self, let data, !data.isEmpty else {
                connection.cancel()
                return
            }

            Task {
                let request = self.parseRequest(data)
                let response = await self.handler(request)
                connection.send(content: self.serialize(response: response), completion: .contentProcessed { _ in
                    connection.cancel()
                })
            }
        }
    }

    nonisolated private func parseRequest(_ data: Data) -> LocalHTTPRequest {
        let text = String(decoding: data, as: UTF8.self)
        let line = text.split(separator: "\r\n").first ?? ""
        let parts = line.split(separator: " ")
        let method = parts.first.map(String.init) ?? "GET"
        let path = parts.dropFirst().first.map(String.init) ?? "/"
        return LocalHTTPRequest(method: method, path: path)
    }

    nonisolated private func serialize(response: LocalHTTPResponse) -> Data {
        let body = response.bodyData ?? Data()
        var headers = response.headers
        headers["Content-Length"] = String(body.count)
        headers["Connection"] = "close"
        let statusLine = "HTTP/1.1 \(response.statusCode) \(reasonPhrase(for: response.statusCode))\r\n"
        let headerLines = headers.map { "\($0): \($1)\r\n" }.joined()
        var data = Data((statusLine + headerLines + "\r\n").utf8)
        data.append(body)
        return data
    }

    nonisolated private func reasonPhrase(for code: Int) -> String {
        switch code {
        case 200: return "OK"
        case 404: return "Not Found"
        case 500: return "Internal Server Error"
        default: return "OK"
        }
    }
}
