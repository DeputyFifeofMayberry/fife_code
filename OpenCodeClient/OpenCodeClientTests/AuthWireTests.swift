//
//  AuthWireTests.swift
//  OpenCodeClientTests
//
//  Wire-level auth coverage (LOC-86 Stage C, item C5): Basic Auth header
//  construction, credential omission when no usable credential exists,
//  export omission of Basic Auth secrets, and the Keychain fail-closed
//  path when a stored credential cannot be loaded. Reuses the offline
//  V2HTTPStubSupport machinery (real APIClient, no server) and the
//  isolated HostCredentialAccess pattern from ConnectionTests. No real
//  Keychain, no network.
//

import Foundation
import Testing
@testable import OpenCodeClient

@Suite(.serialized)
struct AuthWireTests {
    private func cleanup(_ host: String) {
        V2StubRegistry.remove(host: host)
        V2StubRegistry.resetRequests()
    }

    private func stubHealthHost() -> String {
        let host = makeV2StubHost()
        V2StubRegistry.set(host: host, routes: [
            V2StubRoute(path: "/global/health", status: 200, body: #"{"healthy":true,"version":"auth-wire-test"}"#)
        ])
        return host
    }

    // MARK: - Basic Auth header construction

    @Test func basicAuthHeaderIsBase64OfUsernameColonPassword() async throws {
        let host = stubHealthHost()
        defer { cleanup(host) }
        let api = APIClient(
            baseURL: "http://\(host)",
            username: "ops",
            password: "s3cret",
            session: makeV2StubSession()
        )

        _ = try await api.health()

        let request = V2StubRegistry.recordedRequests(host: host).first
        let expected = "Basic " + Data("ops:s3cret".utf8).base64EncodedString()
        #expect(request?.headers["Authorization"] == expected)
    }

    // MARK: - Credential omission on the wire (fail-closed)

    @Test func usernameWithoutPasswordOmitsAuthorizationHeader() async throws {
        // Fail-closed: a half-configured credential must never reach the
        // wire as a partial or empty Basic value.
        let host = stubHealthHost()
        defer { cleanup(host) }
        let api = APIClient(
            baseURL: "http://\(host)",
            username: "ops",
            password: nil,
            session: makeV2StubSession()
        )

        _ = try await api.health()

        let request = V2StubRegistry.recordedRequests(host: host).first
        #expect(request?.headers["Authorization"] == nil)
    }

    @Test func noCredentialsOmitAuthorizationHeader() async throws {
        let host = stubHealthHost()
        defer { cleanup(host) }
        let api = APIClient(
            baseURL: "http://\(host)",
            session: makeV2StubSession()
        )

        _ = try await api.health()

        let request = V2StubRegistry.recordedRequests(host: host).first
        #expect(request?.headers["Authorization"] == nil)
    }

    // MARK: - Credential omission on host-config export

    @Test @MainActor func directProfileExportOmitsBasicAuthCredentials() throws {
        // The export payload carries transport basics only; the Basic Auth
        // username and its Keychain reference must never appear (same
        // contract as the SSH export case in ConnectionTests).
        let state = makeIsolatedAppState(apiClient: MockAPIClient(), sseClient: MockSSEClient())
        let profile = HostProfile(
            name: "Direct Lab",
            transport: .direct,
            serverURL: "https://direct.example.invalid",
            basicAuth: BasicAuthConfig(username: "admin", keychainPasswordID: "secret-password-id"),
            ssh: nil
        )

        let json = try state.hostConfigJSON(for: profile)

        #expect(json.contains("\"transport\" : \"direct\""))
        #expect(json.contains("direct.example.invalid"))
        #expect(!json.contains("basicAuth"))
        #expect(!json.contains("admin"))
        #expect(!json.contains("secret-password-id"))
    }

    // MARK: - Keychain fail-closed path

    @Test @MainActor func duplicateProfileDropsBasicAuthWhenKeychainLoadThrows() {
        // If the stored credential cannot be loaded, duplication fails
        // closed: the copy carries no Basic Auth reference instead of a
        // dangling Keychain ID, and the failure is surfaced.
        let recorder = FailingCredentialRecorder()
        let state = makeIsolatedAppState(
            apiClient: MockAPIClient(),
            sseClient: MockSSEClient(),
            hostCredentialAccess: recorder.access()
        )
        let profile = HostProfile(
            name: "Locked Lab",
            transport: .direct,
            serverURL: APIClient.defaultServer,
            basicAuth: BasicAuthConfig(username: "admin", keychainPasswordID: "unreachable-password-id"),
            ssh: nil
        )
        state.hostProfiles = [profile]
        state.currentHostProfileID = profile.id

        state.duplicateHostProfile(profile)

        #expect(state.hostProfiles.count == 2)
        let copy = state.hostProfiles.first { $0.id != profile.id }
        #expect(copy?.basicAuth == nil)
        #expect(state.hostCredentialError != nil)
        #expect(recorder.loads == ["unreachable-password-id"])
        #expect(recorder.saves.isEmpty)
    }
}

/// Credential access whose loads always throw: models an unavailable
/// Keychain so the fail-closed path is deterministic offline.
@MainActor
private final class FailingCredentialRecorder {
    private(set) var loads: [String] = []
    private(set) var saves: [(value: String, key: String)] = []

    func access() -> HostCredentialAccess {
        HostCredentialAccess(
            save: { [weak self] value, key in
                self?.saves.append((value, key))
            },
            load: { [weak self] key in
                self?.loads.append(key)
                throw KeychainUnavailableError(key: key)
            },
            delete: { _ in }
        )
    }
}

private struct KeychainUnavailableError: Error {
    let key: String
}
