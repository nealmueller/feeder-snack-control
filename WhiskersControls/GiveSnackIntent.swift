import AppIntents

struct GiveSnackIntent: AppIntent {
    static var title: LocalizedStringResource { "Give Snack" }
    static var openAppWhenRun: Bool { false }

    func perform() async throws -> some IntentResult {
        let response = try await BridgeClient().snack()
        return .result(dialog: IntentDialog(stringLiteral: response.message))
    }
}
