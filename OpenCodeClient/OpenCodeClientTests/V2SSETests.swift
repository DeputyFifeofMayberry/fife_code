//
//  V2SSETests.swift
//  OpenCodeClientTests
//
//  Tests for v2 SSE handling: frame discrimination in SSEClient and the
//  AppState v2 dispatch (docs/v2_server_compatibility.md, SSE section).
//

import Foundation
import Testing
@testable import OpenCodeClient

@Suite(.serialized)
struct V2SSEFrameTests {
    @Test func v2TypedFrameNormalizesIntoV1EventShape() {
        let frame = SSEClient.decodeFrame(Data(#"{"id":"evt_1","type":"server.connected","data":{}}"#.utf8))
        #expect(frame?.payload.type == "server.connected")
        #expect(frame?.payload.properties?.isEmpty == true)
        #expect(frame?.directory == nil)
    }

    @Test func v2TypedFrameCarriesDataAsProperties() {
        let frame = SSEClient.decodeFrame(Data(#"{"id":"e","type":"session.idle","data":{"sessionID":"ses_1"}}"#.utf8))
        #expect(frame?.payload.type == "session.idle")
        #expect(frame?.payload.properties?["sessionID"]?.value as? String == "ses_1")
    }

    @Test func v1EnvelopeFrameStillDecodesAsV1() {
        let frame = SSEClient.decodeFrame(Data(#"{"directory":"/repo","payload":{"type":"session.status","properties":{"sessionID":"s"}}}"#.utf8))
        #expect(frame?.payload.type == "session.status")
        #expect(frame?.directory == "/repo")
    }

    @Test func garbageFrameReturnsNil() {
        #expect(SSEClient.decodeFrame(Data("not json".utf8)) == nil)
        #expect(SSEClient.decodeFrame(Data(#"{"neither":true}"#.utf8)) == nil)
    }
}

@Suite(.serialized)
@MainActor
struct V2SSEDispatchTests {
    private func makeV2State(mock: MockAPIClient = MockAPIClient()) async -> AppState {
        let state = await makeIsolatedAppState(apiClient: mock)
        state.serverGeneration = .v2
        return state
    }

    private func event(_ type: String, _ properties: [String: Any] = [:]) -> SSEEvent {
        SSEEvent(directory: nil, payload: SSEPayload(type: type, properties: properties.mapValues { AnyCodable($0) }))
    }

    private func assistantFixture(sessionID: String, messageID: String, partID: String, text: String) -> MessageWithParts {
        MessageWithParts(
            info: Message(
                id: messageID,
                sessionID: sessionID,
                role: "assistant",
                parentID: nil,
                providerID: nil,
                modelID: nil,
                model: nil,
                error: nil,
                time: .init(created: 1, completed: nil),
                finish: nil,
                tokens: nil,
                cost: nil
            ),
            parts: [
                Part(
                    id: partID,
                    messageID: messageID,
                    sessionID: sessionID,
                    type: "text",
                    text: text,
                    tool: nil,
                    callID: nil,
                    state: nil,
                    metadata: nil,
                    files: nil
                )
            ]
        )
    }

    private func userFixture(sessionID: String, messageID: String) -> MessageWithParts {
        MessageWithParts(
            info: Message(
                id: messageID,
                sessionID: sessionID,
                role: "user",
                parentID: nil,
                providerID: nil,
                modelID: nil,
                model: nil,
                error: nil,
                time: .init(created: 1, completed: nil),
                finish: nil,
                tokens: nil,
                cost: nil
            ),
            parts: []
        )
    }

    @Test func sessionIdleFrameUpdatesStatusMap() async {
        let state = await makeV2State()
        await state.applySSEEventForTesting(event("session.idle", ["sessionID": "ses_1"]))
        #expect(state.sessionStatuses["ses_1"]?.type == "idle")
    }

    @Test func sessionStatusFramePassesThrough() async {
        let state = await makeV2State()
        await state.applySSEEventForTesting(event("session.status", ["sessionID": "ses_1", "status": ["type": "busy", "attempt": 1]]))
        #expect(state.sessionStatuses["ses_1"]?.type == "busy")
        #expect(state.sessionStatuses["ses_1"]?.attempt == 1)
    }

    @Test func renamedFrameReloadsAndUpsertsSession() async {
        let mock = MockAPIClient()
        let known = Session(
            id: "ses_1", slug: "ses_1", projectID: "p", directory: "/repo",
            parentID: nil, title: "Old", version: "2",
            time: .init(created: 1, updated: 2, archived: nil), share: nil, summary: nil
        )
        await mock.setSessionResult(Session(
            id: "ses_1", slug: "ses_1", projectID: "p", directory: "/repo",
            parentID: nil, title: "New", version: "2",
            time: .init(created: 1, updated: 3, archived: nil), share: nil, summary: nil
        ))
        let state = await makeV2State(mock: mock)
        state.sessions = [known]
        await state.applySSEEventForTesting(event("session.renamed", ["sessionID": "ses_1"]))
        #expect(state.sessions.first?.title == "New")
    }

    @Test func textStartedDeltaEndedConvergeThroughMessageStore() async {
        let mock = MockAPIClient()
        await mock.setMessagesResult([
            assistantFixture(sessionID: "ses_1", messageID: "msg_1", partID: "msg_1-text-0", text: "")
        ])
        let state = await makeV2State(mock: mock)
        state.currentSessionID = "ses_1"
        state.messages = await mock.messagesResult

        await state.applySSEEventForTesting(event(
            "session.text.started",
            ["sessionID": "ses_1", "assistantMessageID": "msg_1", "ordinal": 0]
        ))
        // Start frame opened the step-timing window and registered the part.
        #expect(state.messageStore.stepTimings["msg_1"] != nil)
        #expect(state.messageStore.partType(for: "msg_1-text-0", inSession: "ses_1") == "text")

        await state.applySSEEventForTesting(event(
            "session.text.delta",
            ["sessionID": "ses_1", "assistantMessageID": "msg_1", "ordinal": 0, "delta": "hi"]
        ))
        #expect(state.partsByMessage["msg_1"]?.first?.text == "hi")

        // The finalizer reload replaces the window with server truth, so the
        // mock's transcript must carry the full text before the end frame.
        await mock.setMessagesResult([
            assistantFixture(sessionID: "ses_1", messageID: "msg_1", partID: "msg_1-text-0", text: "hi there")
        ])
        await state.applySSEEventForTesting(event(
            "session.text.ended",
            ["sessionID": "ses_1", "assistantMessageID": "msg_1", "ordinal": 0, "text": "hi there"]
        ))
        #expect(state.partsByMessage["msg_1"]?.first?.text == "hi there")
        // The reloads ran: one for the start-frame fallback, one finalizer.
        let calls = await mock.messagesCallCount
        #expect(calls >= 2)
    }

    @Test func reasoningDeltaIsDropped() async {
        let mock = MockAPIClient()
        let state = await makeV2State(mock: mock)
        state.currentSessionID = "ses_1"
        await state.applySSEEventForTesting(event(
            "session.reasoning.delta",
            ["sessionID": "ses_1", "assistantMessageID": "msg_1", "ordinal": 0, "delta": "thinking"]
        ))
        let calls = await mock.messagesCallCount
        #expect(calls == 0)
        #expect(state.messageStore.stepTimings.isEmpty)
    }

    @Test func contentUpdatedReloadsMessages() async {
        let mock = MockAPIClient()
        let state = await makeV2State(mock: mock)
        state.currentSessionID = "ses_1"
        await state.applySSEEventForTesting(event("session.message.content.updated", ["sessionID": "ses_1"]))
        let calls = await mock.messagesCallCount
        #expect(calls == 1)
    }

    @Test func executionFailedMarksPendingSendFailed() async {
        let mock = MockAPIClient()
        let state = await makeV2State(mock: mock)
        state.currentSessionID = "ses_1"
        let row = userFixture(sessionID: "ses_1", messageID: "msg_u")
        state.messageStore.rememberOutboundSend(
            hostProfileID: state.currentHostProfileID,
            sessionID: "ses_1",
            row: row
        )
        await state.applySSEEventForTesting(event(
            "session.execution.failed",
            ["sessionID": "ses_1", "error": ["type": "provider_error", "message": "boom"]]
        ))
        #expect(state.messageStore.failedSendReasonsByID["msg_u"]?.contains("boom") == true)
    }

    @Test func formCreatedAppendsCardAndCancelledRemovesIt() async {
        let state = await makeV2State()
        state.currentSessionID = "ses_1"
        await state.applySSEEventForTesting(event(
            "form.created",
            ["form": [
                "id": "frm_1",
                "sessionID": "ses_1",
                "fields": [
                    ["key": "color", "type": "string", "options": [["value": "red", "label": "Red"]]]
                ],
            ]]
        ))
        #expect(state.pendingQuestions.count == 1)
        #expect(state.pendingQuestions.first?.id == "frm_1")
        #expect(state.pendingQuestions.first?.questions.first?.header == "color")

        await state.applySSEEventForTesting(event("form.cancelled", ["id": "frm_1"]))
        #expect(state.pendingQuestions.isEmpty)
    }

    @Test func permissionAskedAndRepliedFlow() async {
        let state = await makeV2State()
        await state.applySSEEventForTesting(event(
            "permission.asked",
            ["id": "per_1", "sessionID": "ses_1", "action": "read", "resources": ["*.env"], "save": ["*.env"]]
        ))
        #expect(state.pendingPermissions.count == 1)
        #expect(state.pendingPermissions.first?.permissionID == "per_1")
        #expect(state.pendingPermissions.first?.allowAlways == true)

        await state.applySSEEventForTesting(event(
            "permission.replied",
            ["sessionID": "ses_1", "requestID": "per_1"]
        ))
        #expect(state.pendingPermissions.isEmpty)
    }

    @Test func deletedFrameRemovesSession() async {
        let state = await makeV2State()
        let known = Session(
            id: "ses_9", slug: "ses_9", projectID: "p", directory: "/repo",
            parentID: nil, title: "Doomed", version: "2",
            time: .init(created: 1, updated: 2, archived: nil), share: nil, summary: nil
        )
        state.sessions = [known]
        await state.applySSEEventForTesting(event("session.deleted", ["sessionID": "ses_9"]))
        #expect(state.sessions.isEmpty)
    }
}
