//
//  V2APIWireTests.swift
//  OpenCodeClientTests
//
//  Wire-level tests for the v2 APIClient branches: method, path, query, body,
//  and exact status handling per docs/v2_server_compatibility.md. Real
//  APIClient against an offline URLProtocol stub, no server.
//

import Foundation
import Testing
@testable import OpenCodeClient

@Suite(.serialized)
struct V2APIWireTests {
    /// The caller sets stub routes on `host` before calling this; the helper
    /// only builds the client so it never overwrites the routes.
    private func client(
        host: String,
        username: String? = nil,
        password: String? = nil
    ) -> APIClient {
        APIClient(baseURL: "http://\(host)", username: username, password: password, session: makeV2StubSession())
    }

    private func cleanup(_ host: String) {
        V2StubRegistry.remove(host: host)
        V2StubRegistry.resetRequests()
    }

    // MARK: - Sessions

    @Test func v2SessionListUsesAPIRouteWithDirectoryAndLimit() async throws {
        let host = makeV2StubHost()
        V2StubRegistry.set(host: host, routes: [
            V2StubRoute(path: "/api/session", status: 200, body: #"{"data":[{"id":"ses_1","location":{"directory":"/repo"},"time":{"created":1,"updated":2}}],"cursor":null}"#)
        ])
        defer { cleanup(host) }
        let api = client(host: host)
        await api.setGeneration(.v2)
        let sessions = try await api.sessions(directory: "/repo", limit: 37)
        #expect(sessions.map(\.id) == ["ses_1"])
        let request = V2StubRegistry.recordedRequests(host: host).first
        #expect(request?.path == "/api/session")
        #expect(request?.method == "GET")
    }

    @Test func v2CreateSessionSendsLocationDirectoryNotQuery() async throws {
        let host = makeV2StubHost()
        V2StubRegistry.set(host: host, routes: [
            V2StubRoute(path: "/api/session", method: "POST", status: 200, body: #"{"data":{"id":"new_1","location":{"directory":"/repo"},"time":{"created":1,"updated":2}}}"#)
        ])
        defer { cleanup(host) }
        let api = client(host: host)
        await api.setGeneration(.v2)
        let session = try await api.createSession(title: "Hi", directory: "/repo")
        #expect(session.id == "new_1")
        let request = V2StubRegistry.recordedRequests(host: host).first
        #expect(request?.path == "/api/session")
        #expect(request?.method == "POST")
        let body = try JSONSerialization.jsonObject(with: request?.body ?? Data()) as? [String: Any]
        #expect(body?["title"] as? String == "Hi")
        #expect((body?["location"] as? [String: Any])?["directory"] as? String == "/repo")
    }

    @Test func v2UpdateSessionRequiresEmpty204ThenGETs() async throws {
        let host = makeV2StubHost()
        V2StubRegistry.set(host: host, routes: [
            V2StubRoute(path: "/api/session/s1", method: "PATCH", status: 204, body: ""),
            V2StubRoute(path: "/api/session/s1", method: "GET", status: 200, body: #"{"data":{"id":"s1","location":{"directory":"/repo"},"title":"Renamed","time":{"created":1,"updated":3}}}"#)
        ])
        defer { cleanup(host) }
        let api = client(host: host)
        await api.setGeneration(.v2)
        let session = try await api.updateSession(sessionID: "s1", title: "Renamed")
        #expect(session.title == "Renamed")
        let requests = V2StubRegistry.recordedRequests(host: host)
        #expect(requests.count == 2)
        #expect(requests[0].method == "PATCH")
        #expect(requests[1].method == "GET")
    }

    @Test func v2UpdateSessionRejectsNonEmpty204() async throws {
        let host = makeV2StubHost()
        V2StubRegistry.set(host: host, routes: [
            V2StubRoute(path: "/api/session/s1", method: "PATCH", status: 204, body: "unexpected")
        ])
        defer { cleanup(host) }
        let api = client(host: host)
        await api.setGeneration(.v2)
        await #expect(throws: APIError.self) {
            try await api.updateSession(sessionID: "s1", title: "X")
        }
    }

    @Test func v2ArchiveWriteThrows404WithoutNetwork() async throws {
        let host = makeV2StubHost()
        V2StubRegistry.set(host: host, routes: [])
        defer { cleanup(host) }
        let api = client(host: host)
        await api.setGeneration(.v2)
        await #expect(throws: APIError.self) {
            try await api.updateSessionArchived(sessionID: "s1", archived: 5)
        }
        #expect(V2StubRegistry.recordedRequests(host: host).isEmpty)
    }

    @Test func v2ForkSendsBeforeField() async throws {
        let host = makeV2StubHost()
        V2StubRegistry.set(host: host, routes: [
            V2StubRoute(path: "/api/session/s1/fork", method: "POST", status: 200, body: #"{"data":{"id":"fork_1","location":{"directory":"/repo"},"time":{"created":1,"updated":2}}}"#)
        ])
        defer { cleanup(host) }
        let api = client(host: host)
        await api.setGeneration(.v2)
        let forked = try await api.forkSession(sessionID: "s1", messageID: "msg_9")
        #expect(forked.id == "fork_1")
        let body = try JSONSerialization.jsonObject(with: V2StubRegistry.recordedRequests(host: host).first?.body ?? Data()) as? [String: Any]
        #expect(body?["before"] as? String == "msg_9")
        #expect(body?["messageID"] == nil)
    }

    @Test func v2RevertStagesThenGETs() async throws {
        let host = makeV2StubHost()
        V2StubRegistry.set(host: host, routes: [
            V2StubRoute(path: "/api/session/s1/revert/stage", method: "POST", status: 200, body: #"{"data":{"messageID":"m1","files":[]}}"#),
            V2StubRoute(path: "/api/session/s1", method: "GET", status: 200, body: #"{"data":{"id":"s1","location":{"directory":"/repo"},"revert":{"messageID":"m1"},"time":{"created":1,"updated":4}}}"#)
        ])
        defer { cleanup(host) }
        let api = client(host: host)
        await api.setGeneration(.v2)
        let session = try await api.revertSession(sessionID: "s1", messageID: "m1", partID: "ignored")
        #expect(session.revert?.messageID == "m1")
        let requests = V2StubRegistry.recordedRequests(host: host)
        #expect(requests.map(\.path) == ["/api/session/s1/revert/stage", "/api/session/s1"])
    }

    @Test func v2SessionTodosReturnsEmptyWithoutRequest() async throws {
        let host = makeV2StubHost()
        V2StubRegistry.set(host: host, routes: [])
        defer { cleanup(host) }
        let api = client(host: host)
        await api.setGeneration(.v2)
        let todos = try await api.sessionTodos(sessionID: "s1")
        #expect(todos.isEmpty)
        #expect(V2StubRegistry.recordedRequests(host: host).isEmpty)
    }

    // MARK: - Send

    @Test func v2PromptSwitchesAgentAndModelThenSendsTextBody() async throws {
        let host = makeV2StubHost()
        V2StubRegistry.set(host: host, routes: [
            V2StubRoute(path: "/api/session/s1/agent", method: "POST", status: 204, body: ""),
            V2StubRoute(path: "/api/session/s1/model", method: "POST", status: 204, body: ""),
            V2StubRoute(path: "/api/session/s1/prompt", method: "POST", status: 200, body: #"{"data":{"id":"msg_1"}}"#)
        ])
        defer { cleanup(host) }
        let api = client(host: host)
        await api.setGeneration(.v2)
        let attachment = ComposerImageAttachment(
            id: UUID(), filename: "a.png", mime: "image/png",
            dataURL: "data:image/png;base64,aGVsbG8=", thumbnailData: Data(), byteSize: 5
        )
        try await api.promptAsync(
            sessionID: "s1", messageID: "msg_1", text: " hi ",
            attachments: [attachment],
            agent: "build",
            model: Message.ModelInfo(providerID: "openai", modelID: "gpt-5"),
            directory: "/repo"
        )
        let requests = V2StubRegistry.recordedRequests(host: host)
        #expect(requests.map(\.path) == ["/api/session/s1/agent", "/api/session/s1/model", "/api/session/s1/prompt"])
        let agentBody = try JSONSerialization.jsonObject(with: requests[0].body) as? [String: Any]
        #expect(agentBody?["agent"] as? String == "build")
        let modelBody = try JSONSerialization.jsonObject(with: requests[1].body) as? [String: Any]
        #expect((modelBody?["model"] as? [String: Any])?["id"] as? String == "gpt-5")
        let promptBody = try JSONSerialization.jsonObject(with: requests[2].body) as? [String: Any]
        #expect(promptBody?["text"] as? String == "hi")
        #expect(promptBody?["id"] as? String == "msg_1")
        #expect((promptBody?["files"] as? [[String: String]])?.first?["uri"] == "data:image/png;base64,aGVsbG8=")
        #expect(promptBody?["parts"] == nil)
        #expect(promptBody?["format"] == nil)
        #expect(promptBody?["agent"] == nil)
        #expect(promptBody?["model"] == nil)
    }

    @Test func v2Prompt204Throws() async throws {
        let host = makeV2StubHost()
        V2StubRegistry.set(host: host, routes: [
            V2StubRoute(path: "/api/session/s1/prompt", method: "POST", status: 204, body: "")
        ])
        defer { cleanup(host) }
        let api = client(host: host)
        await api.setGeneration(.v2)
        await #expect(throws: APIError.self) {
            try await api.promptAsync(sessionID: "s1", messageID: "", text: "x", attachments: [], agent: "", model: nil, directory: nil)
        }
    }

    @Test func v2InterruptSendsEmptyObjectAndRequires200() async throws {
        let host = makeV2StubHost()
        V2StubRegistry.set(host: host, routes: [
            V2StubRoute(path: "/api/session/s1/interrupt", method: "POST", status: 200, body: #"{"interrupted":false}"#)
        ])
        defer { cleanup(host) }
        let api = client(host: host)
        await api.setGeneration(.v2)
        try await api.abort(sessionID: "s1")
        let body = String(data: V2StubRegistry.recordedRequests(host: host).first?.body ?? Data(), encoding: .utf8)
        #expect(body == "{}")
    }

    @Test func v2StructuredSendPollsAndParsesEnvelope() async throws {
        let host = makeV2StubHost()
        let envelope = #"{"version":1,"status":"completed","speech":"Done","confirmation":null,"clientActions":[]}"#
        V2StubRegistry.set(host: host, routes: [
            V2StubRoute(path: "/api/session/s1/agent", method: "POST", status: 204, body: ""),
            V2StubRoute(path: "/api/session/s1/model", method: "POST", status: 204, body: ""),
            V2StubRoute(path: "/api/session/s1/prompt", method: "POST", status: 200, body: #"{"data":{"id":"msg_u"}}"#),
            V2StubRoute(path: "/api/session/s1/message", method: "GET", status: 200, body: #"{"data":[{"id":"msg_u","type":"user","text":"q","time":{"created":1}},{"id":"msg_a","type":"assistant","parentID":"msg_u","content":[{"type":"text","text":\#(jsonEscape(envelope))}],"time":{"created":2}}]}"#)
        ])
        defer { cleanup(host) }
        let api = client(host: host)
        await api.setGeneration(.v2)
        await api.setV2IdleProbe { true }
        let format = StructuredOutputFormat(schema: ["type": "object"])
        let result = try await api.promptStructured(
            sessionID: "s1", messageID: "msg_u", text: "q",
            system: "sys", format: format,
            agent: "build",
            model: Message.ModelInfo(providerID: "openai", modelID: "gpt-5")
        )
        #expect(result.info.structured != nil)
        #expect(result.info.time.completed == result.info.time.created)
        let envelopeDecoded = try result.info.carResponseEnvelope
        #expect(envelopeDecoded?.speech == "Done")
    }

    @Test func v2StructuredSend409ToleratesAdmittedID() async throws {
        let host = makeV2StubHost()
        let envelope = #"{"version":1,"status":"completed","speech":"Ok","confirmation":null,"clientActions":[]}"#
        V2StubRegistry.set(host: host, routes: [
            V2StubRoute(path: "/api/session/s1/agent", method: "POST", status: 204, body: ""),
            V2StubRoute(path: "/api/session/s1/model", method: "POST", status: 204, body: ""),
            V2StubRoute(path: "/api/session/s1/prompt", method: "POST", status: 409, body: "already admitted"),
            V2StubRoute(path: "/api/session/s1/message", method: "GET", status: 200, body: #"{"data":[{"id":"msg_u","type":"user","text":"q","time":{"created":1}},{"id":"msg_a","type":"assistant","parentID":"msg_u","content":[{"type":"text","text":\#(jsonEscape(envelope))}],"time":{"created":2}}]}"#)
        ])
        defer { cleanup(host) }
        let api = client(host: host)
        await api.setGeneration(.v2)
        await api.setV2IdleProbe { true }
        let format = StructuredOutputFormat(schema: ["type": "object"])
        let result = try await api.promptStructured(
            sessionID: "s1", messageID: "msg_u", text: "q",
            system: "sys", format: format,
            agent: "build",
            model: Message.ModelInfo(providerID: "openai", modelID: "gpt-5")
        )
        #expect(result.info.structured != nil)
    }

    @Test func v2StructuredSend409WithoutAdmissionThrows() async throws {
        let host = makeV2StubHost()
        V2StubRegistry.set(host: host, routes: [
            V2StubRoute(path: "/api/session/s1/agent", method: "POST", status: 204, body: ""),
            V2StubRoute(path: "/api/session/s1/model", method: "POST", status: 204, body: ""),
            V2StubRoute(path: "/api/session/s1/prompt", method: "POST", status: 409, body: "already admitted"),
            V2StubRoute(path: "/api/session/s1/message", method: "GET", status: 200, body: #"{"data":[]}"#)
        ])
        defer { cleanup(host) }
        let api = client(host: host)
        await api.setGeneration(.v2)
        let format = StructuredOutputFormat(schema: ["type": "object"])
        await #expect(throws: CarModeError.self) {
            try await api.promptStructured(
                sessionID: "s1", messageID: "msg_u", text: "q",
                system: "sys", format: format,
                agent: "build",
                model: Message.ModelInfo(providerID: "openai", modelID: "gpt-5")
            )
        }
    }

    // MARK: - Status, permissions, questions

    @Test func v2SessionStatusUsesActiveRoute() async throws {
        let host = makeV2StubHost()
        V2StubRegistry.set(host: host, routes: [
            V2StubRoute(path: "/api/session/active", status: 200, body: #"{"data":{"ses_1":{"type":"running"}}}"#)
        ])
        defer { cleanup(host) }
        let api = client(host: host)
        await api.setGeneration(.v2)
        let statuses = try await api.sessionStatus()
        #expect(statuses["ses_1"]?.type == "busy")
    }

    @Test func v2PendingPermissionsScopedAndEmptyWithoutSession() async throws {
        let host = makeV2StubHost()
        V2StubRegistry.set(host: host, routes: [
            V2StubRoute(path: "/api/session/s1/permission", status: 200, body: #"{"data":[{"id":"per_1","sessionID":"s1","action":"read","resources":["*.env"]}]}"#)
        ])
        defer { cleanup(host) }
        let api = client(host: host)
        await api.setGeneration(.v2)

        #expect(try await api.pendingPermissions(sessionID: nil).isEmpty)
        #expect(V2StubRegistry.recordedRequests(host: host).isEmpty)

        let permissions = try await api.pendingPermissions(sessionID: "s1")
        #expect(permissions.first?.permission == "read")
        #expect(V2StubRegistry.recordedRequests(host: host).first?.path == "/api/session/s1/permission")
    }

    @Test func v2PermissionReplySendsDecision204() async throws {
        let host = makeV2StubHost()
        V2StubRegistry.set(host: host, routes: [
            V2StubRoute(path: "/api/session/s1/permission/per_1/reply", method: "POST", status: 204, body: "")
        ])
        defer { cleanup(host) }
        let api = client(host: host)
        await api.setGeneration(.v2)
        try await api.respondPermission(sessionID: "s1", permissionID: "per_1", response: .always)
        let body = try JSONSerialization.jsonObject(with: V2StubRegistry.recordedRequests(host: host).first?.body ?? Data()) as? [String: String]
        #expect(body?["decision"] == "always")
    }

    @Test func v2FormTableFillsFromPendingQuestionsAndDrivesReply() async throws {
        let host = makeV2StubHost()
        V2StubRegistry.set(host: host, routes: [
            V2StubRoute(path: "/api/session/s1/form", method: "GET", status: 200, body: #"{"data":[{"id":"frm_1","sessionID":"s1","fields":[{"key":"color","type":"string","options":[{"value":"red","label":"Red"}]}]}]}"#),
            V2StubRoute(path: "/api/session/s1/form/frm_1/reply", method: "POST", status: 204, body: "")
        ])
        defer { cleanup(host) }
        let api = client(host: host)
        await api.setGeneration(.v2)

        let questions = try await api.pendingQuestions(sessionID: "s1")
        #expect(questions.first?.id == "frm_1")

        try await api.replyQuestion(requestID: "frm_1", answers: [["Red"]])
        let replyRequest = V2StubRegistry.recordedRequests(host: host).last
        #expect(replyRequest?.path == "/api/session/s1/form/frm_1/reply")
        let body = try JSONSerialization.jsonObject(with: replyRequest?.body ?? Data()) as? [String: Any]
        #expect((body?["answer"] as? [String: Any])?["color"] as? String == "red")
    }

    @Test func v2FormReplyAndRejectWithoutTableEntryThrow404() async throws {
        let host = makeV2StubHost()
        V2StubRegistry.set(host: host, routes: [])
        defer { cleanup(host) }
        let api = client(host: host)
        await api.setGeneration(.v2)
        await #expect(throws: APIError.self) {
            try await api.replyQuestion(requestID: "missing", answers: [["a"]])
        }
        await #expect(throws: APIError.self) {
            try await api.rejectQuestion(requestID: "missing")
        }
        #expect(V2StubRegistry.recordedRequests(host: host).isEmpty)
    }

    // MARK: - Files, diff, projects

    @Test func v2FileRoutesAndLocationQueries() async throws {
        let host = makeV2StubHost()
        V2StubRegistry.set(host: host, routes: [
            V2StubRoute(path: "/api/fs/list", status: 200, body: #"{"data":[{"path":"/repo/a.swift","type":"file"}]}"#),
            V2StubRoute(path: "/api/fs/find", status: 200, body: #"{"data":[{"path":"a.swift"}]}"#),
            V2StubRoute(path: "/api/fs/read/a.swift", status: 200, body: "let x = 1"),
            V2StubRoute(path: "/api/vcs/status", status: 200, body: #"{"data":[{"file":"a.swift","additions":1,"deletions":0,"status":"modified"}]}"#)
        ])
        defer { cleanup(host) }
        let api = client(host: host)
        await api.setGeneration(.v2)

        let nodes = try await api.fileList(path: "", directory: "/repo")
        #expect(nodes.first?.path == "/repo/a.swift")
        let paths = try await api.findFile(query: "sw", limit: 10, directory: "/repo")
        #expect(paths == ["a.swift"])
        let content = try await api.fileContent(path: "a.swift", directory: "/repo")
        #expect(content.text == "let x = 1")
        let status = try await api.fileStatus()
        #expect(status.first?.path == "a.swift")

        let requests = V2StubRegistry.recordedRequests(host: host)
        #expect(requests[0].path == "/api/fs/list")
        #expect(requests[1].path == "/api/fs/find")
        #expect(requests[2].path == "/api/fs/read/a.swift")
        #expect(requests[3].path == "/api/vcs/status")
    }

    @Test func v2DiffUsesAPIRoute() async throws {
        let host = makeV2StubHost()
        V2StubRegistry.set(host: host, routes: [
            V2StubRoute(path: "/api/session/s1/diff", status: 200, body: #"{"data":[{"file":"a.swift","patch":"+x","additions":1,"deletions":0,"status":"added"}]}"#)
        ])
        defer { cleanup(host) }
        let api = client(host: host)
        await api.setGeneration(.v2)
        let diffs = try await api.sessionDiff(sessionID: "s1")
        #expect(diffs.first?.after == "+x")
    }

    @Test func v2ProvidersCallsAllThreeRoutes() async throws {
        let host = makeV2StubHost()
        V2StubRegistry.set(host: host, routes: [
            V2StubRoute(path: "/api/model", status: 200, body: #"{"data":[{"id":"gpt-5","providerID":"openai","name":"GPT"}]}"#),
            V2StubRoute(path: "/api/provider", status: 200, body: #"{"data":[{"id":"openai","name":"OpenAI"}]}"#),
            V2StubRoute(path: "/api/model/default", status: 200, body: #"{"location":"x","data":{"providerID":"openai","id":"gpt-5"}}"#)
        ])
        defer { cleanup(host) }
        let api = client(host: host)
        await api.setGeneration(.v2)
        let response = try await api.providers()
        #expect(response.default?.modelID == "gpt-5")
        #expect(response.providers.first?.id == "openai")
        let paths = V2StubRegistry.recordedRequests(host: host).map(\.path)
        #expect(paths.contains("/api/model/default"))
    }

    @Test func v2ProjectsAndCurrentLocation() async throws {
        let host = makeV2StubHost()
        V2StubRegistry.set(host: host, routes: [
            V2StubRoute(path: "/api/project", status: 200, body: #"[{"id":"prj_1","canonical":"/repo","sandboxes":[]}]"#),
            V2StubRoute(path: "/api/location", status: 200, body: #"{"project":{"id":"prj_1","directory":"/repo"}}"#)
        ])
        defer { cleanup(host) }
        let api = client(host: host)
        await api.setGeneration(.v2)
        let projects = try await api.projects()
        #expect(projects.first?.worktree == "/repo")
        let current = try await api.projectCurrent()
        #expect(current?.id == "prj_1")
    }

    // MARK: - V1 paths untouched

    @Test func v1GenerationKeepsLegacyRoutes() async throws {
        let host = makeV2StubHost()
        V2StubRegistry.set(host: host, routes: [
            V2StubRoute(path: "/session", status: 200, body: "[]"),
            V2StubRoute(path: "/global/health", status: 200, body: #"{"healthy":true,"version":"1"}"#)
        ])
        defer { cleanup(host) }
        let api = client(host: host)
        // generation stays .auto → v1 wire paths
        let sessions = try await api.sessions()
        #expect(sessions.isEmpty)
        let detection = try await api.detectGeneration()
        #expect(detection == .v1(version: "1"))
        let paths = V2StubRegistry.recordedRequests(host: host).map(\.path)
        #expect(paths == ["/session", "/global/health"])
    }
}

private func jsonEscape(_ json: String) -> String {
    let data = try? JSONSerialization.data(withJSONObject: [json])
    let array = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String] }
    return array?.first ?? ""
}
