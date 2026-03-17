import Foundation

actor PythonBridgeRunner {
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    func listFeeders(email: String, password: String, selectedSerial: String?) async throws -> [FeederOption] {
        let data = try await run(command: "list-feeders", email: email, password: password, selectedSerial: selectedSerial)
        return try decoder.decode([FeederOption].self, from: data)
    }

    func giveSnack(email: String, password: String, selectedSerial: String?) async throws -> SnackResponse {
        let data = try await run(command: "give-snack", email: email, password: password, selectedSerial: selectedSerial)
        return try decoder.decode(SnackResponse.self, from: data)
    }

    private func run(command: String, email: String, password: String, selectedSerial: String?) async throws -> Data {
        let process = Process()
        process.executableURL = pythonExecutableURL()
        process.arguments = [pythonScriptURL().path(), command]
        process.environment = pythonEnvironment(email: email, password: password, selectedSerial: selectedSerial)

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorData = stderr.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            throw BridgeError.server(String(decoding: errorData, as: UTF8.self))
        }

        return data
    }

    private func pythonExecutableURL() -> URL {
        let bundled = Bundle.main.bundleURL
            .appending(path: "Contents")
            .appending(path: "Frameworks")
            .appending(path: "Python.framework")
            .appending(path: "Versions")
            .appending(path: "Current")
            .appending(path: "bin")
            .appending(path: "python3")
        if FileManager.default.fileExists(atPath: bundled.path()) {
            return bundled
        }
        return URL(filePath: "/opt/homebrew/bin/python3")
    }

    private func pythonScriptURL() -> URL {
        guard let url = Bundle.main.url(forResource: "bridge", withExtension: "py", subdirectory: "Python") else {
            fatalError("Missing bundled bridge.py")
        }
        return url
    }

    private func pythonEnvironment(email: String, password: String, selectedSerial: String?) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let resources = Bundle.main.resourceURL!
        let bundledSitePackages = resources.appending(path: "VendorPython/site-packages").path()
        if FileManager.default.fileExists(atPath: bundledSitePackages) {
            environment["PYTHONPATH"] = bundledSitePackages
        }
        environment["WHISKERS_EMAIL"] = email
        environment["WHISKERS_PASSWORD"] = password
        environment["WHISKERS_FEEDER_SERIAL"] = selectedSerial ?? ""
        environment["WHISKERS_TOKEN_CACHE"] = tokenCacheURL().path()
        return environment
    }

    private func tokenCacheURL() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = support.appending(path: "Feeder Snack Control", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appending(path: "tokens.json")
    }

    static func clearCachedData() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = support.appending(path: "Feeder Snack Control", directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: folder)
    }
}
