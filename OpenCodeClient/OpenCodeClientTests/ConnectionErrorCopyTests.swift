import Foundation
import Testing
@testable import OpenCodeClient

/// Clipboard text for the connection-error copy button: the message plus the
/// connection context an admin (or agent) needs to debug it remotely
/// (host URL, transport, phase, recovery hint, timestamp).
@Suite
struct ConnectionErrorCopyTests {
    @Test func copyTextIncludesMessageHostTransportPhaseHintAndTime() {
        let timestamp = Date(timeIntervalSince1970: 1_791_945_000)
        let text = ConnectionDiagnostic.copyText(
            message: "Server is not a recognizable OpenCode v1 or v2 API (health: HTTP 502, info: HTTP 502).",
            hostURL: "https://barneyfife.tailfb50d8.ts.net",
            transportLabel: "Direct",
            phaseLabel: "Health check",
            recoveryHint: "Verify the host configuration.",
            timestamp: timestamp
        )

        #expect(text.contains("Server is not a recognizable OpenCode v1 or v2 API"))
        #expect(text.contains("https://barneyfife.tailfb50d8.ts.net"))
        #expect(text.contains("Direct"))
        #expect(text.contains("Health check"))
        #expect(text.contains("Verify the host configuration."))
        #expect(text.contains(ISO8601DateFormatter().string(from: timestamp)))
    }

    @Test func copyTextOmitsAbsentPieces() {
        let text = ConnectionDiagnostic.copyText(
            message: "Could not connect to OpenCode.",
            hostURL: nil,
            transportLabel: nil,
            phaseLabel: nil,
            recoveryHint: nil,
            timestamp: nil
        )

        #expect(text == "Could not connect to OpenCode.")
        #expect(!text.contains("Host:"))
        #expect(!text.contains("Phase:"))
        #expect(!text.contains("Hint:"))
        #expect(!text.contains("Time:"))
    }
}
