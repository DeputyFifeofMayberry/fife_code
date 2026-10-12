//
//  V2MapperTests.swift
//  OpenCodeClientTests
//
//  Saved-body tests for the v2 mappings, one per row of the spec's
//  Unit-tests section (docs/v2_server_compatibility.md). No server.
//

import Foundation
import Testing
@testable import OpenCodeClient

@Suite
struct V2MapperTests {
    // MARK: - Session map

    @Test func sessionFixtureMapsToUIShape() throws {
        let json = #"{"id":"ses_1","projectID":"prj_1","location":{"directory":"/repo"},"time":{"created":1,"updated":2}}"#
        let session = try V2Mapper.session(fromJSON: json)
        #expect(session.slug == "ses_1")
        #expect(session.directory == "/repo")
        #expect(session.title == "Untitled")
        #expect(session.version == "2")
        #expect(session.projectID == "prj_1")
        #expect(!session.isArchived)
    }

    @Test func serverArchiveFlagMapsToArchived() throws {
        let archived = try V2Mapper.session(fromJSON: #"{"id":"s","location":{"directory":"/r"},"time":{"created":1,"updated":2,"archived":5}}"#)
        #expect(archived.isArchived)
        #expect(archived.time.archived == 5)

        let notArchived = try V2Mapper.session(fromJSON: #"{"id":"s","location":{"directory":"/r"},"time":{"created":1,"updated":2}}"#)
        #expect(!notArchived.isArchived)
    }

    @Test func sessionMissingRequiredFieldsThrows() {
        #expect(throws: (any Error).self) {
            try V2Mapper.session(fromJSON: #"{"location":{"directory":"/r"},"time":{"created":1,"updated":2}}"#)
        }
        #expect(throws: (any Error).self) {
            try V2Mapper.session(fromJSON: #"{"id":"s","time":{"created":1,"updated":2}}"#)
        }
        #expect(throws: (any Error).self) {
            try V2Mapper.session(fromJSON: #"{"id":"s","location":{"directory":"/r"}}"#)
        }
    }

    @Test func sessionListSkipsInvalidElements() throws {
        let json = #"{"data":[{"id":"a","location":{"directory":"/r"},"time":{"created":1,"updated":2}},{"id":"b"},{"type":"idle"}]}"#
        let sessions = try V2Mapper.sessionList(Data(json.utf8))
        #expect(sessions.map(\.id) == ["a"])
    }

    @Test func sessionCopiesTokensAndCostAggregates() throws {
        let json = #"{"id":"s","location":{"directory":"/r"},"time":{"created":1,"updated":2},"tokens":{"input":10,"output":4,"reasoning":2,"cache":{"read":3,"write":1}},"cost":0.5}"#
        let session = try V2Mapper.session(fromJSON: json)
        #expect(session.tokens?.total == 20)
        #expect(session.cost == 0.5)
    }

    // MARK: - Message map

    @Test func emptyDataIsAnEmptyTranscript() throws {
        let messages = try V2Mapper.messages(sessionID: "ses_1", data: Data(#"{"data":[]}"#.utf8))
        #expect(messages.isEmpty)
    }

    @Test func userItemBecomesOneTextPart() throws {
        let json = #"{"data":[{"id":"msg_1","type":"user","text":"hi","time":{"created":1}}]}"#
        let messages = try V2Mapper.messages(sessionID: "ses_1", data: Data(json.utf8))
        #expect(messages.count == 1)
        #expect(messages[0].info.role == "user")
        #expect(messages[0].info.isUser)
        #expect(messages[0].parts.count == 1)
        #expect(messages[0].parts[0].type == "text")
        #expect(messages[0].parts[0].text == "hi")
        #expect(messages[0].parts[0].id == "msg_1-0")
        #expect(messages[0].parts[0].messageID == "msg_1")
        #expect(messages[0].parts[0].sessionID == "ses_1")
    }

    @Test func userPayloadTextAndFilesMap() throws {
        let json = #"{"data":[{"id":"msg_2","type":"user","payload":{"text":"look","files":[{"data":"aGk=","mime":"image/png","name":"x.png"}]},"time":{"created":1}}]}"#
        let messages = try V2Mapper.messages(sessionID: "ses_1", data: Data(json.utf8))
        #expect(messages[0].parts.count == 2)
        #expect(messages[0].parts[0].text == "look")
        let file = messages[0].parts[1]
        #expect(file.type == "file")
        #expect(file.url == "data:image/png;base64,aGk=")
        #expect(file.filename == "x.png")
    }

    @Test func assistantItemBecomesOneTextPart() throws {
        let json = #"{"data":[{"id":"m1","type":"user","text":"hi","time":{"created":1}},{"id":"msg_2","type":"assistant","content":[{"type":"text","text":"ok"}],"time":{"created":2}}]}"#
        let messages = try V2Mapper.messages(sessionID: "ses_1", data: Data(json.utf8))
        let assistant = messages[1]
        #expect(assistant.info.role == "assistant")
        #expect(assistant.parts.count == 1)
        #expect(assistant.parts[0].type == "text")
        #expect(assistant.parts[0].text == "ok")
        #expect(assistant.info.parentID == "m1")
    }

    @Test func assistantToolEntriesMapToToolParts() throws {
        let json = #"{"data":[{"id":"m1","type":"user","text":"go","time":{"created":1}},{"id":"a1","type":"assistant","content":[{"type":"tool","id":"call_1","tool":"bash","state":{"status":"completed","output":"done"}},{"type":"text","text":"ran"}],"time":{"created":2}}]}"#
        let messages = try V2Mapper.messages(sessionID: "ses_1", data: Data(json.utf8))
        let assistant = messages[1]
        #expect(assistant.parts.count == 2)
        let tool = assistant.parts[0]
        #expect(tool.type == "tool")
        #expect(tool.tool == "bash")
        #expect(tool.callID == "call_1")
        #expect(tool.state?.displayString == "completed")
        #expect(tool.id == "a1-0")
        #expect(assistant.parts[1].id == "a1-1")
    }

    @Test func assistantModelTokensCostErrorFinishMap() throws {
        let json = #"{"data":[{"id":"m1","type":"user","text":"go","time":{"created":1}},{"id":"a1","type":"assistant","content":[{"type":"text","text":"x"}],"model":{"providerID":"openai","id":"gpt-5"},"tokens":{"input":1,"output":2,"reasoning":0,"cache":{"read":3,"write":4}},"cost":0.25,"finish":"stop","error":{"type":"provider_error","message":"boom"},"time":{"created":2,"completed":9}}]}"#
        let messages = try V2Mapper.messages(sessionID: "ses_1", data: Data(json.utf8))
        let info = messages[1].info
        #expect(info.providerID == "openai")
        #expect(info.modelID == "gpt-5")
        #expect(info.model?.modelID == "gpt-5")
        #expect(info.tokens?.total == 10)
        #expect(info.cost == 0.25)
        #expect(info.finish == "stop")
        #expect(info.error?.name == "provider_error")
        #expect(info.error?.message == "boom")
        #expect(info.time.completed == 9)
    }

    @Test func idleItemsAreSkipped() throws {
        let json = #"{"data":[{"id":"msg_9","type":"idle","time":{"created":1}}]}"#
        let messages = try V2Mapper.messages(sessionID: "ses_1", data: Data(json.utf8))
        #expect(messages.isEmpty)
    }

    @Test func rowsMissingIDOrCreatedAreSkippedAndMalformedEnvelopeThrows() {
        #expect((try? V2Mapper.messages(sessionID: "s", data: Data(#"{"data":[{"type":"user","text":"x","time":{"created":1}}]}"#.utf8)))?.isEmpty == true)
        #expect((try? V2Mapper.messages(sessionID: "s", data: Data(#"{"data":[{"id":"a","type":"user","text":"x"}]}"#.utf8)))?.isEmpty == true)
        #expect(throws: (any Error).self) {
            try V2Mapper.messages(sessionID: "s", data: Data(#"{"nope":true}"#.utf8))
        }
    }

    @Test func syntheticItemMapsToReceiptRow() throws {
        // Resolved open question: v2 delivers the task receipt as a
        // type:"synthetic" message; map it so the card renders. Both bodies
        // below were captured live from the 2.0.26 server (2026-10-12 scan:
        // 297 synthetic rows, all carrying top-level `text`; the richer
        // shape's `description`/`metadata` extras are not read by the
        // mapper). The receipt card itself is parsed client-side from the
        // text, so mapping only needs the row to arrive user-like.
        let json = #"{"data":[{"id":"msg_12e179521001oykjD7tWtzzVQl","metadata":{"instruction":{"paths":["Y:\\opencode_fife\\packages\\cli\\AGENTS.md"]}},"time":{"created":1791774659873},"text":"Instructions from: Y:\\opencode_fife\\packages\\cli\\AGENTS.md\n# CLI and TUI development guide\r\n\r\n- Use `@opencode/client` and the location-scoped data in packages/tui/src/context/data.tsx instead of adding dependencies on legacy sync state.\r\n- Preserve established TUI behavior unless the task intentionally changes it.\r\n","description":"Loaded packages\\cli\\AGENTS.md","type":"synthetic"},{"id":"msg_131260b0e001xYx6Ikns1XreOq","time":{"created":1791825939260},"text":"<system-reminder>\nYou are NO LONGER in Plan mode. The previous Plan restrictions no longer apply. Any Plan mode instructions from earlier in this conversation are no longer active.\n</system-reminder>","type":"synthetic"}]}"#
        let messages = try V2Mapper.messages(sessionID: "ses_1", data: Data(json.utf8))
        #expect(messages.count == 2)
        #expect(messages[0].info.role == "user")
        #expect(messages[0].parts[0].synthetic == true)
        #expect(messages[0].parts[0].text?.hasPrefix("Instructions from: Y:\\opencode_fife") == true)
        #expect(messages[0].parts[0].text?.contains("Preserve established TUI behavior") == true)
        #expect(messages[1].parts[0].synthetic == true)
        #expect(messages[1].parts[0].text?.hasPrefix("<system-reminder>") == true)
    }

    // MARK: - Prompt encodes

    @Test func v2PromptEncodeText() {
        let body = V2Mapper.promptBody(text: "hi", files: [], messageID: nil)
        #expect(body.count == 1)
        #expect(body["text"] as? String == "hi")
        #expect(body["parts"] == nil)
        #expect(body["format"] == nil)
    }

    @Test func v2PromptEncodeImage() {
        let body = V2Mapper.promptBody(
            text: "hi",
            files: [(uri: "data:image/png;base64,aGVsbG8=", name: "a.png")],
            messageID: nil
        )
        let files = body["files"] as? [[String: String]]
        #expect(files == [["uri": "data:image/png;base64,aGVsbG8=", "name": "a.png"]])
        #expect(body["mime"] == nil)
        #expect(body["source"] == nil)
    }

    @Test func v2PromptEncodeCarriesIDOnlyWhenPresent() {
        #expect(V2Mapper.promptBody(text: "x", files: [], messageID: "msg_1")["id"] as? String == "msg_1")
        #expect(V2Mapper.promptBody(text: "x", files: [], messageID: "")["id"] == nil)
    }

    // MARK: - Permissions

    @Test func permissionFixtureMaps() throws {
        let json = #"{"data":[{"id":"per_1","sessionID":"ses_1","action":"read","resources":["*.env"],"source":{"type":"tool","messageID":"msg_1","id":"call_1"}}]}"#
        let permissions = V2Mapper.permissions(data: Data(json.utf8))
        #expect(permissions.count == 1)
        let permission = permissions[0]
        #expect(permission.permission == "read")
        #expect(permission.patterns == ["*.env"])
        #expect(permission.tool?.callID == "call_1")
        #expect(permission.tool?.messageID == "msg_1")
        #expect(permission.always == nil)
    }

    @Test func permissionReplyEncode() {
        let body = V2Mapper.permissionReplyBody(.once)
        #expect((body["decision"] as? String) == "once")
        #expect(body["response"] == nil)
    }

    // MARK: - Forms

    @Test func formFixtureMapsAndRepliesWithStoredValue() throws {
        let json = #"{"data":[{"id":"frm_1","sessionID":"ses_1","title":"Pick","fields":[{"key":"color","type":"string","options":[{"value":"red","label":"Red"}]}]}]}"#
        let forms = V2Mapper.forms(data: Data(json.utf8))
        #expect(forms.count == 1)
        let (request, record) = forms[0]
        #expect(request.id == "frm_1")
        #expect(request.sessionID == "ses_1")
        #expect(request.tool == nil)
        #expect(request.questions.count == 1)
        #expect(request.questions[0].header == "color")
        #expect(request.questions[0].question == "color")
        #expect(request.questions[0].options.first?.label == "Red")

        let body = try V2Mapper.replyBody(for: [["Red"]], record: record)
        let answer = body["answer"] as? [String: Any]
        #expect(answer?["color"] as? String == "red")
    }

    @Test func formCustomAnswerAndMultiselectAndTypes() throws {
        let json = #"{"data":[{"id":"frm_2","sessionID":"ses_1","fields":[{"key":"note","type":"string"},{"key":"tags","type":"multiselect","options":[{"value":"a","label":"Alpha"},{"value":"b","label":"Beta"}]},{"key":"count","type":"integer"},{"key":"flag","type":"boolean"}]}]}"#
        let (_, record) = V2Mapper.forms(data: Data(json.utf8))[0]

        let custom = try V2Mapper.replyBody(for: [["freeform"], [], [], []], record: record)
        let answer = custom["answer"] as? [String: Any]
        #expect(answer?["note"] as? String == "freeform")

        let multi = try V2Mapper.replyBody(for: [[], ["Alpha", "custom-tag"], [], []], record: record)
        #expect((multi["answer"] as? [String: Any])?["tags"] as? [String] == ["a", "custom-tag"])

        let number = try V2Mapper.replyBody(for: [[], [], ["42"], []], record: record)
        #expect((number["answer"] as? [String: Any])?["count"] as? Int == 42)

        let boolean = try V2Mapper.replyBody(for: [[], [], [], ["true"]], record: record)
        #expect((boolean["answer"] as? [String: Any])?["flag"] as? Bool == true)

        #expect(throws: APIError.self) {
            try V2Mapper.replyBody(for: [[], [], ["not-a-number"], []], record: record)
        }
    }

    @Test func formExternalFieldsSkippedAndDuplicateLabelsDeduped() throws {
        let json = #"{"data":[{"id":"frm_3","sessionID":"s","fields":[{"key":"hidden","type":"external"},{"key":"color","type":"string","options":[{"value":"red","label":"Red"},{"value":"crimson","label":"Red"}]}]}]}"#
        let forms = V2Mapper.forms(data: Data(json.utf8))
        let (request, record) = forms[0]
        #expect(request.questions.count == 1)
        #expect(request.questions[0].header == "color")
        #expect(request.questions[0].options.count == 1)
        #expect(record.fields.count == 1)
        #expect(record.fields[0].options.count == 1)
    }

    // MARK: - Models

    @Test func modelCapabilitiesMap() throws {
        let json = #"{"data":[{"id":"gpt-5","providerID":"openai","name":"GPT","capabilities":{"tools":true,"input":["text","image"],"output":["text"]},"limit":{"context":8,"output":2}}]}"#
        let providerJSON = #"{"data":[{"id":"openai","name":"OpenAI"}]}"#
        let response = V2Mapper.providers(
            modelData: Data(json.utf8),
            providerData: Data(providerJSON.utf8),
            defaultData: nil
        )
        #expect(response.providers.count == 1)
        let provider = response.providers[0]
        #expect(provider.id == "openai")
        #expect(provider.name == "OpenAI")
        let model = provider.models["gpt-5"]
        #expect(model?.capabilities?.toolCall == true)
        #expect(model?.capabilities?.attachment == true)
        #expect(model?.limit?.context == 8)
        #expect(model?.limit?.output == 2)
        #expect(response.default == nil)
    }

    @Test func providerListAndDefaultModelMap() throws {
        let models = #"{"data":[{"id":"m1","providerID":"p1"},{"id":"m2","providerID":"orphan"}]}"#
        let providersJSON = #"{"data":[{"id":"p1","name":"Provider One","activation":"enabled"},{"id":"p2","name":"Disabled","activation":"disabled"}]}"#
        let registry = V2Mapper.providerRegistry(modelData: Data(models.utf8), providerData: Data(providersJSON.utf8))
        #expect(registry.providers.map(\.id) == ["orphan", "p1", "p2"])
        // Connected ids come from the provider list's non-disabled entries;
        // the model-list fallback applies only when the list is empty.
        #expect(registry.connectedProviderIDs == ["p1"])

        let fallback = V2Mapper.providerRegistry(modelData: Data(models.utf8), providerData: Data(#"{"data":[]}"#.utf8))
        #expect(fallback.connectedProviderIDs == ["orphan", "p1"])

        let providers = V2Mapper.providers(
            modelData: Data(models.utf8),
            providerData: Data(providersJSON.utf8),
            defaultData: Data(#"{"location":"x","data":{"providerID":"p1","id":"m1"}}"#.utf8)
        )
        #expect(providers.default?.providerID == "p1")
        #expect(providers.default?.modelID == "m1")
        #expect(providers.providers.first { $0.id == "orphan" }?.name == "orphan")

        let nullDefault = V2Mapper.providers(
            modelData: Data(models.utf8),
            providerData: Data(providersJSON.utf8),
            defaultData: Data(#"{"location":"x","data":null}"#.utf8)
        )
        #expect(nullDefault.default == nil)
    }

    // MARK: - Agents

    @Test func agentsMapNameFromNameElseID() throws {
        let json = #"{"data":[{"id":"build","name":"Build","description":"d","mode":"primary","hidden":false},{"id":"plan","description":"p"}]}"#
        let agents = V2Mapper.agents(data: Data(json.utf8))
        #expect(agents.count == 2)
        #expect(agents[0].name == "Build")
        #expect(agents[1].name == "plan")
        #expect(agents[1].native == nil)
    }

    // MARK: - Diff, files, status

    @Test func diffFixtureMaps() throws {
        let json = #"{"data":[{"file":"a.swift","patch":"+let x","additions":1,"deletions":0,"status":"added"}]}"#
        let diffs = V2Mapper.fileDiffs(data: Data(json.utf8))
        #expect(diffs[0].file == "a.swift")
        #expect(diffs[0].after == "+let x")
        #expect(diffs[0].before == "")
        #expect(diffs[0].additions == 1)
    }

    @Test func fileStatusFixtureMaps() throws {
        let json = #"{"data":[{"file":"a.swift","additions":1,"deletions":0,"status":"modified"}]}"#
        let entries = V2Mapper.fileStatusEntries(data: Data(json.utf8))
        #expect(entries[0].path == "a.swift")
        #expect(entries[0].status == "modified")
    }

    @Test func fileNodesAndFindAndContentMap() throws {
        let nodes = V2Mapper.fileNodes(data: Data(#"{"data":[{"path":"/repo/sub/file.ts","type":"file"}]}"#.utf8))
        #expect(nodes[0].name == "file.ts")
        #expect(nodes[0].path == "/repo/sub/file.ts")
        #expect(nodes[0].absolute == nil)
        #expect(nodes[0].ignored == nil)

        let paths = V2Mapper.findPaths(data: Data(#"{"data":[{"path":"a.swift"},{"path":"b.swift"}]}"#.utf8))
        #expect(paths == ["a.swift", "b.swift"])

        let textContent = V2Mapper.fileContent(Data("hello".utf8))
        #expect(textContent.type == "text")
        #expect(textContent.text == "hello")
        let binaryContent = V2Mapper.fileContent(Data([0xFF, 0xFE, 0x00]))
        #expect(binaryContent.type == "binary")
        #expect(binaryContent.content == nil)
    }

    // MARK: - Projects

    @Test func projectFixtureMapsWorktree() throws {
        let json = #"[{"id":"prj_1","canonical":"/repo","time":{"created":1,"updated":2,"active":3},"sandboxes":[]}]"#
        let projects = V2Mapper.projects(Data(json.utf8))
        #expect(projects.count == 1)
        #expect(projects[0].worktree == "/repo")
        #expect(projects[0].time?.created == 1)
        #expect(projects[0].sandboxes?.isEmpty == true)
    }

    @Test func currentProjectMatchesByIDOrBuildsFallback() throws {
        let known = Project(id: "prj_1", worktree: "/elsewhere", vcs: "git", icon: nil, time: nil, sandboxes: nil)
        let matched = V2Mapper.currentProject(
            locationData: Data(#"{"project":{"id":"prj_1","directory":"/repo"}}"#.utf8),
            projects: [known]
        )
        #expect(matched?.worktree == "/elsewhere")

        let built = V2Mapper.currentProject(
            locationData: Data(#"{"project":{"id":"prj_9","directory":"/fresh"}}"#.utf8),
            projects: [known]
        )
        #expect(built?.id == "prj_9")
        #expect(built?.worktree == "/fresh")
    }

    // MARK: - Status

    @Test func activeStatusesMapRunningToBusy() throws {
        let json = #"{"data":{"ses_1":{"type":"running"},"ses_2":{"type":"idle"}}}"#
        let statuses = V2Mapper.activeStatuses(data: Data(json.utf8))
        #expect(statuses["ses_1"]?.type == "busy")
        #expect(statuses["ses_2"] == nil)
    }

    // MARK: - Streaming part ids

    @Test func deltaPartIDFromOrdinal() {
        let partID = V2Mapper.textPartID(assistantMessageID: "msg_1", ordinal: 0)
        #expect(partID == "msg_1-text-0")
        #expect(V2Mapper.textPartID(assistantMessageID: "msg_1", ordinal: 2) == "msg_1-text-2")
    }

    // MARK: - Structured send

    @Test func structuredEnvelopeDecodesAndValidates() throws {
        let fixture = #"{"version":1,"status":"completed","speech":"Done","confirmation":null,"clientActions":[]}"#
        let envelope = try V2Mapper.structuredEnvelope(fromText: fixture)
        #expect(envelope.version == 1)
        #expect(envelope.speech == "Done")

        #expect(throws: CarModeError.self) {
            try V2Mapper.structuredEnvelope(fromText: "not json")
        }
        #expect(throws: CarModeError.self) {
            try V2Mapper.structuredEnvelope(fromText: #"{"version":2,"status":"completed","speech":"Done","confirmation":null,"clientActions":[]}"#)
        }
        #expect(throws: CarModeError.self) {
            try V2Mapper.structuredEnvelope(fromText: #"{"version":1,"status":"completed","speech":"  ","confirmation":null,"clientActions":[]}"#)
        }
    }
}

private extension V2Mapper {
    /// Test convenience: the public mapper entry points take envelopes;
    /// these fixtures start from a single JSON object.
    static func session(fromJSON json: String) throws -> Session {
        try sessionFromEnvelope(Data(#"{"data":\#(json)}"#.utf8))
    }
}
