//
//  ServerGenerationTests.swift
//  OpenCodeClientTests
//
//  Saved-body tests for the generation probe (docs/v2_server_compatibility.md,
//  Detection + Unit-tests row 1) and the HostProfile generation binding.
//

import Foundation
import Testing
@testable import OpenCodeClient

@Suite(.serialized)
struct GenerationProbeTests {
    private func probe(
        health: V2StubRoute? = nil,
        info: V2StubRoute? = nil,
        failing: Bool = false
    ) async -> GenerationDetection {
        let host = makeV2StubHost()
        var routes: [V2StubRoute] = []
        if let health { routes.append(health) }
        if let info { routes.append(info) }
        V2StubRegistry.set(host: host, routes: routes)
        if failing { V2StubRegistry.setFailing(host: host) }
        defer {
            V2StubRegistry.remove(host: host)
            V2StubRegistry.resetRequests()
        }
        return await GenerationProbe.detect(
            baseURL: "http://\(host)",
            username: "opencode",
            password: "pw",
            session: makeV2StubSession()
        )
    }

    @Test func healthyV1HealthJSONIsV1WithoutProbingInfo() async {
        let detection = await probe(health: V2StubRoute(path: "/global/health", status: 200, body: #"{"version":"1.0.5","healthy":true}"#))
        #expect(detection == .v1(version: "1.0.5"))
    }

    @Test func unhealthyHealthIsV1AndNotConnected() async {
        let detection = await probe(health: V2StubRoute(path: "/global/health", status: 200, body: #"{"version":"1.0.5","healthy":false}"#))
        #expect(detection == .v1Unhealthy(version: "1.0.5"))
    }

    @Test func htmlHealthContinuesToInfoAndDetectsV2() async {
        let detection = await probe(
            health: V2StubRoute(path: "/global/health", status: 200, body: "<html>hello</html>", headers: ["Content-Type": "text/html"]),
            info: V2StubRoute(path: "/api/info", status: 200, body: #"{"version":"2.0.26"}"#)
        )
        #expect(detection == .v2(version: "2.0.26"))
    }

    @Test func empty500HealthContinuesToInfo() async {
        let detection = await probe(
            health: V2StubRoute(path: "/global/health", status: 500, body: ""),
            info: V2StubRoute(path: "/api/info", status: 404, body: "missing")
        )
        #expect(detection == .unrecognized(healthStatus: 500, infoStatus: 404))
    }

    @Test func missingHealthRouteFallsThroughToV2Info() async {
        let detection = await probe(
            health: V2StubRoute(path: "/global/health", status: 404, body: "no route"),
            info: V2StubRoute(path: "/api/info", status: 200, body: #"{"version":"2.0.26"}"#)
        )
        #expect(detection == .v2(version: "2.0.26"))
    }

    @Test func health200WithoutStringVersionKeepsProbing() async {
        let detection = await probe(
            health: V2StubRoute(path: "/global/health", status: 200, body: #"{"healthy":true}"#),
            info: V2StubRoute(path: "/api/info", status: 404, body: "missing")
        )
        #expect(detection == .unrecognized(healthStatus: 200, infoStatus: 404))
    }

    @Test func auth401OnHealthDoesNotContinueIntoInfo() async {
        let detection = await probe(health: V2StubRoute(path: "/global/health", status: 401, body: "denied"))
        #expect(detection == .authFailure(healthStatus: 401, infoStatus: nil))
    }

    @Test func auth403OnInfoReportsBothStatuses() async {
        let detection = await probe(
            health: V2StubRoute(path: "/global/health", status: 200, body: "<html></html>", headers: ["Content-Type": "text/html"]),
            info: V2StubRoute(path: "/api/info", status: 403, body: "forbidden")
        )
        #expect(detection == .authFailure(healthStatus: 200, infoStatus: 403))
    }

    @Test func transportFailureDoesNotContinueIntoInfo() async {
        let detection = await probe(health: V2StubRoute(path: "/global/health", status: 200, body: #"{"healthy":true,"version":"1"}"#), failing: true)
        guard case .transportFailure = detection else {
            Issue.record("expected transport failure, got \(detection)")
            return
        }
    }

    @Test func bodyBeyond8KBCapFailsToParseAndKeepsProbing() async {
        let pad = String(repeating: "x", count: 9000)
        let detection = await probe(
            health: V2StubRoute(path: "/global/health", status: 200, body: #"{"version":"1","healthy":true,"pad":"\#(pad)"}"#),
            info: V2StubRoute(path: "/api/info", status: 200, body: #"{"version":"2.0.26"}"#)
        )
        #expect(detection == .v2(version: "2.0.26"))
    }

    @Test func v1DetectionStopsAfterFirstProbe() async {
        let host = makeV2StubHost()
        V2StubRegistry.set(host: host, routes: [
            V2StubRoute(path: "/global/health", status: 200, body: #"{"version":"1.0.5","healthy":true}"#)
        ])
        defer {
            V2StubRegistry.remove(host: host)
            V2StubRegistry.resetRequests()
        }
        _ = await GenerationProbe.detect(
            baseURL: "http://\(host)",
            username: nil,
            password: nil,
            session: makeV2StubSession()
        )
        let paths = V2StubRegistry.recordedRequests(host: host).map(\.path)
        #expect(paths == ["/global/health"])
    }

    @Test func probeSendsBasicAuthHeader() async {
        let host = makeV2StubHost()
        V2StubRegistry.set(host: host, routes: [
            V2StubRoute(path: "/global/health", status: 200, body: #"{"version":"1","healthy":true}"#)
        ])
        defer {
            V2StubRegistry.remove(host: host)
            V2StubRegistry.resetRequests()
        }
        _ = await GenerationProbe.detect(
            baseURL: "http://\(host)",
            username: "opencode",
            password: "secret",
            session: makeV2StubSession()
        )
        let expected = Data("opencode:secret".utf8).base64EncodedString()
        let requests = V2StubRegistry.recordedRequests(host: host)
        #expect(requests.count == 1)
        #expect(requests.first?.headers["Authorization"] == "Basic \(expected)")
    }
}

@Suite(.serialized)
struct HostProfileGenerationTests {
    @Test func missingAPIGenerationDecodesAsNil() throws {
        let json = """
        {"id":"\(UUID().uuidString)","name":"Local","transport":"direct","serverURL":"127.0.0.1:4096","lastUsedAt":1700000000}
        """
        let profile = try JSONDecoder().decode(HostProfile.self, from: Data(json.utf8))
        #expect(profile.apiGeneration == nil)
    }

    @Test func apiGenerationRoundTrips() throws {
        let profile = HostProfile(name: "Local", transport: .direct, serverURL: "127.0.0.1:4096", basicAuth: nil, ssh: nil, lastUsedAt: nil, apiGeneration: .v2)
        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(HostProfile.self, from: data)
        #expect(decoded.apiGeneration == .v2)
    }

    @Test @MainActor func urlChangeClearsStoredGeneration() {
        let state = makeIsolatedAppState()
        state.hostProfiles[0].apiGeneration = .v2
        state.serverURL = "http://127.0.0.1:5099"
        state.persistRuntimeToCurrentHostProfile()
        #expect(state.hostProfiles[0].apiGeneration == nil)
        #expect(state.hostProfiles[0].serverURL == "http://127.0.0.1:5099")
    }

    @Test @MainActor func sameURLEditKeepsStoredGeneration() {
        let state = makeIsolatedAppState()
        state.hostProfiles[0].apiGeneration = .v2
        state.persistRuntimeToCurrentHostProfile()
        #expect(state.hostProfiles[0].apiGeneration == .v2)
    }
}

@Suite(.serialized)
struct GenerationConnectFlowTests {
    @Test @MainActor func v2DetectionConnectsAndStoresGeneration() async {
        let mock = MockAPIClient()
        await mock.setGenerationDetectionOverride(.v2(version: "2.0.26"))
        let state = makeIsolatedAppState(apiClient: mock)
        state.configure(serverURL: "127.0.0.1:4096")
        await state.testConnection()

        #expect(state.isConnected)
        #expect(state.serverGeneration == .v2)
        #expect(state.serverVersion == "2.0.26")
        let stored = await mock.configuredGeneration
        #expect(stored == .v2)
        #expect(state.hostProfiles[0].apiGeneration == .v2)
    }

    @Test @MainActor func v1DetectionKeepsLegacyConnectBehavior() async {
        let mock = MockAPIClient()
        let state = makeIsolatedAppState(apiClient: mock)
        state.configure(serverURL: "127.0.0.1:4096")
        await state.testConnection()

        #expect(state.isConnected)
        #expect(state.serverGeneration == .v1)
        #expect(state.serverVersion == "test-version")
        let stored = await mock.configuredGeneration
        #expect(stored == .v1)
    }

    @Test @MainActor func v1UnhealthyDetectionDoesNotConnect() async {
        let mock = MockAPIClient()
        await mock.setGenerationDetectionOverride(.v1Unhealthy(version: "1.0.5"))
        let state = makeIsolatedAppState(apiClient: mock)
        state.configure(serverURL: "127.0.0.1:4096")
        await state.testConnection()

        #expect(!state.isConnected)
        #expect(state.serverGeneration == .v1)
        #expect(state.serverVersion == "1.0.5")
        #expect(state.connectionError != nil)
    }

    @Test @MainActor func unrecognizedDetectionReportsBothStatuses() async {
        let mock = MockAPIClient()
        await mock.setGenerationDetectionOverride(.unrecognized(healthStatus: 200, infoStatus: 404))
        let state = makeIsolatedAppState(apiClient: mock)
        state.configure(serverURL: "127.0.0.1:4096")
        await state.testConnection()

        #expect(!state.isConnected)
        #expect(state.serverGeneration == .auto)
        #expect(state.connectionError?.contains("200") == true)
        #expect(state.connectionError?.contains("404") == true)
    }

    @Test @MainActor func authFailureSurfacesInfoLegRejectionNotHealthStatus() async {
        // Live finding (2026-10-12, 2.0.26 server): the health leg answers
        // 200 HTML even for bad credentials, so the probe reports
        // authFailure(200, 401). The user-facing error must name the 401
        // ("Basic Auth rejected"), not the meaningless health 200.
        let mock = MockAPIClient()
        await mock.setGenerationDetectionOverride(.authFailure(healthStatus: 200, infoStatus: 401))
        let state = makeIsolatedAppState(apiClient: mock)
        state.configure(serverURL: "127.0.0.1:4096")
        await state.testConnection()

        #expect(!state.isConnected)
        #expect(state.connectionError?.contains("Basic Auth") == true)
        #expect(state.connectionError?.contains("200") == false)
    }

    @Test @MainActor func gatewayStatusesReportProxyUnreachable() async {
        // Live finding (2026-10-13): 502 on both legs means the reverse proxy
        // is alive but the OpenCode process behind it is down — that deserves
        // a proxy-specific message, not "not a recognizable API".
        let mock = MockAPIClient()
        await mock.setGenerationDetectionOverride(.unrecognized(healthStatus: 502, infoStatus: 502))
        let state = makeIsolatedAppState(apiClient: mock)
        state.configure(serverURL: "127.0.0.1:4096")
        await state.testConnection()

        #expect(!state.isConnected)
        #expect(state.serverGeneration == .auto)
        #expect(state.connectionError?.contains("502") == true)
        #expect(state.connectionError?.localizedLowercase.contains("proxy") == true)
        #expect(state.connectionError?.contains("recognizable") == false)
    }

    @Test @MainActor func mixedUnrecognizedStatusesKeepUnrecognizedMessage() async {
        let mock = MockAPIClient()
        await mock.setGenerationDetectionOverride(.unrecognized(healthStatus: 502, infoStatus: 404))
        let state = makeIsolatedAppState(apiClient: mock)
        state.configure(serverURL: "127.0.0.1:4096")
        await state.testConnection()

        #expect(!state.isConnected)
        #expect(state.connectionError?.contains("recognizable") == true)
        #expect(state.connectionError?.contains("404") == true)
    }

    @Test @MainActor func hostSwitchResetsGeneration() async {
        let mock = MockAPIClient()
        await mock.setGenerationDetectionOverride(.v2(version: "2.0.26"))
        let state = makeIsolatedAppState(apiClient: mock)
        state.configure(serverURL: "127.0.0.1:4096")
        await state.testConnection()
        #expect(state.serverGeneration == .v2)

        state.resetConnectionRuntimeForHostSwitch()
        #expect(state.serverGeneration == .auto)
        #expect(state.serverVersion == nil)
    }
}
