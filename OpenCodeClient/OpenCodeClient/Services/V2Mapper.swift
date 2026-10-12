//
//  V2Mapper.swift
//  OpenCodeClient
//
//  Pure v2 → UI-model mappings per docs/v2_server_compatibility.md. No
//  network, no state, no second Session/Message type: everything produces
//  the existing model types the v1 wire path already decodes into.
//

import Foundation

/// In-memory record of a v2 form, kept on APIClient so `replyQuestion` /
/// `rejectQuestion` (which only receive a request id) can rebuild the
/// session-scoped route and the label → value answer conversion.
nonisolated struct V2FormRecord: Sendable, Equatable {
    let formID: String
    let sessionID: String
    let fields: [V2FormFieldRecord]
}

nonisolated struct V2FormFieldRecord: Sendable, Equatable {
    let key: String
    let multiple: Bool
    let isNumber: Bool
    let isBoolean: Bool
    let options: [V2FormOptionRecord]
}

nonisolated struct V2FormOptionRecord: Sendable, Equatable {
    let label: String
    let value: String
}

nonisolated enum V2Mapper {
    enum MappingError: Error, Equatable {
        case missingRequiredField(String)
        case unsupportedShape
    }

    // MARK: - Envelope helpers

    static func envelopeObject(_ data: Data) throws -> [String: Any] {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dict = object as? [String: Any] else {
            throw MappingError.unsupportedShape
        }
        return dict
    }

    static func dataObject(_ data: Data) throws -> [String: Any] {
        guard let value = try envelopeObject(data)["data"] as? [String: Any] else {
            throw MappingError.unsupportedShape
        }
        return value
    }

    static func dataArray(_ data: Data) throws -> [Any] {
        guard let value = try envelopeObject(data)["data"] as? [Any] else {
            throw MappingError.unsupportedShape
        }
        return value
    }

    /// JSON numbers arrive as NSNumber through JSONSerialization; only accept
    /// integral doubles so an epoch-millis value is never silently truncated.
    static func intValue(_ value: Any?) -> Int? {
        if let int = value as? Int { return int }
        if let number = value as? NSNumber { return number.intValue }
        if let double = value as? Double, double == double.rounded() { return Int(double) }
        return nil
    }

    static func doubleValue(_ value: Any?) -> Double? {
        if let double = value as? Double { return double }
        if let int = value as? Int { return Double(int) }
        if let number = value as? NSNumber { return number.doubleValue }
        return nil
    }

    static func decode<T: Decodable>(_ value: Any, as type: T.Type) -> T? {
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value) else {
            return nil
        }
        return try? JSONDecoder().decode(type, from: data)
    }

    /// Encodes an Encodable value into a JSON-object dictionary (for building
    /// SSE property payloads).
    static func objectDictionary<T: Encodable>(from value: T) -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(value),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object
    }

    // MARK: - Sessions (spec: Session and message maps)

    /// Session, from `data` on get, create, and fork. Missing id, directory,
    /// or time throws.
    static func session(_ item: [String: Any]) throws -> Session {
        guard let id = item["id"] as? String, !id.isEmpty else {
            throw MappingError.missingRequiredField("id")
        }
        let location = item["location"] as? [String: Any]
        guard let directory = location?["directory"] as? String else {
            throw MappingError.missingRequiredField("location.directory")
        }
        let time = item["time"] as? [String: Any]
        guard let created = intValue(time?["created"]),
              let updated = intValue(time?["updated"]) else {
            throw MappingError.missingRequiredField("time.created/updated")
        }
        return Session(
            id: id,
            slug: id,
            projectID: item["projectID"] as? String ?? "",
            directory: directory,
            parentID: item["parentID"] as? String,
            title: item["title"] as? String ?? "Untitled",
            version: "2",
            time: Session.TimeInfo(
                created: created,
                updated: updated,
                archived: intValue(time?["archived"])
            ),
            share: nil,
            summary: nil,
            revert: (item["revert"] as? [String: Any]).flatMap(revertInfo),
            tokens: (item["tokens"] as? [String: Any]).flatMap(tokenInfo),
            cost: doubleValue(item["cost"])
        )
    }

    static func sessionFromEnvelope(_ data: Data) throws -> Session {
        try session(try dataObject(data))
    }

    /// List elements missing required fields are skipped, not errors.
    static func sessionList(_ data: Data) throws -> [Session] {
        try dataArray(data).compactMap { ($0 as? [String: Any]).flatMap { try? session($0) } }
    }

    private static func revertInfo(_ dict: [String: Any]) -> Session.RevertInfo? {
        guard let messageID = dict["messageID"] as? String else { return nil }
        return Session.RevertInfo(
            messageID: messageID,
            partID: dict["partID"] as? String,
            snapshot: dict["snapshot"] as? String,
            diff: dict["diff"] as? String
        )
    }

    private static func tokenInfo(_ dict: [String: Any]) -> Message.TokenInfo? {
        guard !dict.isEmpty else { return nil }
        let cache = dict["cache"] as? [String: Any]
        return Message.TokenInfo(
            input: intValue(dict["input"]) ?? 0,
            output: intValue(dict["output"]) ?? 0,
            reasoning: intValue(dict["reasoning"]) ?? 0,
            cache: cache.map {
                Message.TokenInfo.CacheInfo(read: intValue($0["read"]) ?? 0, write: intValue($0["write"]) ?? 0)
            }
        )
    }

    // MARK: - Messages

    /// Transcript from `data` of `GET /api/session/:id/message`. `sessionID`
    /// is the id that was queried. Rows missing id or time.created are
    /// skipped; `{"data":[]}` and all-skipped are empty transcripts, not
    /// errors; a malformed envelope throws.
    static func messages(sessionID: String, data: Data) throws -> [MessageWithParts] {
        let rows = try dataArray(data)
        var results: [MessageWithParts] = []
        var lastUserID: String?

        for row in rows {
            guard let item = row as? [String: Any],
                  let id = item["id"] as? String, !id.isEmpty else { continue }
            let time = item["time"] as? [String: Any]
            guard let created = intValue(time?["created"]) else { continue }
            let completed = intValue(time?["completed"])

            switch item["type"] as? String {
            case "user":
                guard let built = userMessage(
                    id: id, sessionID: sessionID, item: item,
                    created: created, completed: completed, synthetic: false
                ) else { continue }
                results.append(built)
                lastUserID = id
            case "synthetic":
                // Resolved open question (user decision): map the receipt so
                // the task card renders on v2. Same text sources as the user
                // row, flagged synthetic.
                if let built = userMessage(
                    id: id, sessionID: sessionID, item: item,
                    created: created, completed: completed, synthetic: true
                ) {
                    results.append(built)
                }
            case "assistant":
                guard let built = assistantMessage(
                    id: id, sessionID: sessionID, item: item,
                    created: created, completed: completed, parentID: lastUserID
                ) else { continue }
                results.append(built)
            default:
                // `idle` and anything else is skipped.
                continue
            }
        }
        return results
    }

    private static func userMessage(
        id: String,
        sessionID: String,
        item: [String: Any],
        created: Int,
        completed: Int?,
        synthetic: Bool
    ) -> MessageWithParts? {
        let payload = item["payload"] as? [String: Any]
        var parts: [Part] = []
        if let text = (item["text"] as? String) ?? (payload?["text"] as? String) {
            parts.append(makeTextPart(id: partID(id, parts.count), messageID: id, sessionID: sessionID, text: text, synthetic: synthetic))
        }
        let files = (item["files"] as? [Any]) ?? (payload?["files"] as? [Any]) ?? []
        for file in files {
            guard let fileDict = file as? [String: Any],
                  let data = fileDict["data"] as? String,
                  let mime = fileDict["mime"] as? String else { continue }
            parts.append(Part(
                id: partID(id, parts.count),
                messageID: id,
                sessionID: sessionID,
                type: "file",
                text: nil,
                tool: nil,
                callID: nil,
                state: nil,
                metadata: nil,
                files: nil,
                mime: mime,
                filename: fileDict["name"] as? String,
                url: "data:\(mime);base64,\(data)"
            ))
        }
        guard !parts.isEmpty else { return nil }
        let info = Message(
            id: id,
            sessionID: sessionID,
            role: "user",
            parentID: nil,
            providerID: nil,
            modelID: nil,
            model: nil,
            error: nil,
            time: Message.TimeInfo(created: created, completed: completed),
            finish: nil,
            tokens: nil,
            cost: nil
        )
        return MessageWithParts(info: info, parts: parts)
    }

    private static func assistantMessage(
        id: String,
        sessionID: String,
        item: [String: Any],
        created: Int,
        completed: Int?,
        parentID: String?
    ) -> MessageWithParts? {
        let content = item["content"] as? [Any] ?? []
        var parts: [Part] = []
        for entry in content {
            guard let entryDict = entry as? [String: Any] else { continue }
            switch entryDict["type"] as? String {
            case "text":
                guard let text = entryDict["text"] as? String else { continue }
                parts.append(makeTextPart(id: partID(id, parts.count), messageID: id, sessionID: sessionID, text: text))
            case "tool":
                // The spec says "tool is name"; accept either key so a server
                // that ships the name under `tool` still renders.
                guard let toolName = (entryDict["tool"] as? String) ?? (entryDict["name"] as? String) else { continue }
                parts.append(Part(
                    id: partID(id, parts.count),
                    messageID: id,
                    sessionID: sessionID,
                    type: "tool",
                    text: nil,
                    tool: toolName,
                    callID: entryDict["id"] as? String,
                    state: (entryDict["state"] as? [String: Any]).flatMap { decode($0, as: PartStateBridge.self) },
                    metadata: nil,
                    files: nil
                ))
            default:
                // Reasoning entries are not visible text.
                continue
            }
        }
        guard !parts.isEmpty else { return nil }

        let modelDict = item["model"] as? [String: Any]
        let providerID = modelDict?["providerID"] as? String
        let modelID = modelDict?["id"] as? String
        let model: Message.ModelInfo? = {
            guard let providerID, let modelID else { return nil }
            return Message.ModelInfo(providerID: providerID, modelID: modelID)
        }()
        let error = (item["error"] as? [String: Any]).map { errorDict in
            Message.MessageError(
                name: errorDict["type"] as? String ?? "",
                data: ["message": AnyCodable(errorDict["message"] as? String ?? "")]
            )
        }

        let info = Message(
            id: id,
            sessionID: sessionID,
            role: "assistant",
            parentID: parentID,
            providerID: providerID,
            modelID: modelID,
            model: model,
            error: error,
            time: Message.TimeInfo(created: created, completed: completed),
            finish: item["finish"] as? String,
            tokens: (item["tokens"] as? [String: Any]).flatMap(tokenInfo),
            cost: doubleValue(item["cost"]),
            structured: nil
        )
        return MessageWithParts(info: info, parts: parts)
    }

    private static func makeTextPart(id: String, messageID: String, sessionID: String, text: String, synthetic: Bool? = nil) -> Part {
        Part(
            id: id,
            messageID: messageID,
            sessionID: sessionID,
            type: "text",
            text: text,
            synthetic: synthetic,
            tool: nil,
            callID: nil,
            state: nil,
            metadata: nil,
            files: nil
        )
    }

    private static func partID(_ messageID: String, _ index: Int) -> String {
        "\(messageID)-\(index)"
    }

    /// Streaming text part id from the SSE frame's `ordinal` — the same
    /// ordinal always yields the same id, including after reconnect.
    static func textPartID(assistantMessageID: String, ordinal: Int) -> String {
        "\(assistantMessageID)-text-\(ordinal)"
    }

    /// Structured-send selection (spec step 5): the assistant whose
    /// parentID is the admitted user id; the last one when several match.
    static func structuredAssistant(in transcript: [MessageWithParts], afterUserID: String) -> MessageWithParts? {
        transcript.last { $0.info.isAssistant && $0.info.parentID == afterUserID }
    }

    // MARK: - Forms (spec: Questions)

    /// Each form becomes one `QuestionRequest` plus the reply-table record.
    /// `external` fields are skipped; duplicate option labels keep the first.
    static func form(from item: [String: Any]) -> (request: QuestionRequest, record: V2FormRecord)? {
        guard let id = item["id"] as? String, !id.isEmpty,
              let sessionID = item["sessionID"] as? String,
              let fields = item["fields"] as? [Any] else { return nil }

        var questions: [QuestionInfo] = []
        var fieldRecords: [V2FormFieldRecord] = []

        for field in fields {
            guard let fieldDict = field as? [String: Any],
                  let key = fieldDict["key"] as? String else { continue }
            let type = fieldDict["type"] as? String ?? "string"
            if type == "external" { continue }
            let title = fieldDict["title"] as? String ?? key

            var options: [QuestionOption] = []
            var optionRecords: [V2FormOptionRecord] = []
            var seenLabels = Set<String>()
            for option in fieldDict["options"] as? [Any] ?? [] {
                guard let optionDict = option as? [String: Any],
                      let label = optionDict["label"] as? String else { continue }
                guard !seenLabels.contains(label) else { continue }
                seenLabels.insert(label)
                options.append(QuestionOption(label: label, description: optionDict["description"] as? String ?? ""))
                optionRecords.append(V2FormOptionRecord(label: label, value: optionDict["value"] as? String ?? label))
            }

            let hasOptions = !options.isEmpty
            let multiple = type == "multiselect"
            let custom: Bool
            switch type {
            case "multiselect", "string":
                // String with options keeps the declared `custom`; a string
                // field without options is a free-text field.
                custom = hasOptions ? (fieldDict["custom"] as? Bool ?? false) : true
            case "number", "integer", "boolean":
                custom = true
            default:
                custom = hasOptions ? (fieldDict["custom"] as? Bool ?? false) : true
            }

            questions.append(QuestionInfo(question: title, header: key, options: options, multiple: multiple, custom: custom))
            fieldRecords.append(V2FormFieldRecord(
                key: key,
                multiple: multiple,
                isNumber: type == "number" || type == "integer",
                isBoolean: type == "boolean",
                options: optionRecords
            ))
        }

        let request = QuestionRequest(id: id, sessionID: sessionID, questions: questions, tool: nil)
        let record = V2FormRecord(formID: id, sessionID: sessionID, fields: fieldRecords)
        return (request, record)
    }

    static func forms(data: Data) -> [(request: QuestionRequest, record: V2FormRecord)] {
        guard let rows = try? dataArray(data) else { return [] }
        return rows.compactMap { ($0 as? [String: Any]).flatMap { form(from: $0) } }
    }

    /// Converts the UI's `[[String]]` selections through the reply-table
    /// record into the v2 `{answer: {key: value}}` body.
    static func replyBody(for answers: [[String]], record: V2FormRecord) throws -> [String: Any] {
        var answer: [String: Any] = [:]
        for (index, field) in record.fields.enumerated() {
            guard index < answers.count else { break }
            let selections = answers[index]
            guard !selections.isEmpty else { continue }

            if field.isBoolean {
                answer[field.key] = selections.first == "true"
                continue
            }

            let values = selections.map { selection in
                field.options.first { $0.label == selection }?.value ?? selection
            }

            if field.isNumber {
                guard let raw = values.first as? String else {
                    throw APIError.httpError(statusCode: 400, data: Data())
                }
                if let int = Int(raw) {
                    answer[field.key] = int
                } else if let double = Double(raw) {
                    answer[field.key] = double
                } else {
                    throw APIError.httpError(statusCode: 400, data: Data())
                }
            } else if field.multiple {
                answer[field.key] = values
            } else {
                answer[field.key] = values.first
            }
        }
        return ["answer": answer]
    }

    // MARK: - Permissions (spec: Permissions)

    static func permission(_ item: [String: Any]) -> APIClient.PermissionRequest? {
        guard let id = item["id"] as? String,
              let sessionID = item["sessionID"] as? String else { return nil }
        let metadata: APIClient.PermissionRequest.Metadata? = (item["metadata"] as? [String: Any]).flatMap { meta in
            (meta["filepath"] as? String).map { APIClient.PermissionRequest.Metadata(filepath: $0, parentDir: nil) }
        }
        let tool: APIClient.PermissionRequest.ToolRef?
        if let source = item["source"] as? [String: Any], source["type"] as? String == "tool" {
            tool = APIClient.PermissionRequest.ToolRef(
                messageID: source["messageID"] as? String,
                callID: source["id"] as? String
            )
        } else {
            tool = nil
        }
        return APIClient.PermissionRequest(
            id: id,
            sessionID: sessionID,
            permission: item["action"] as? String,
            patterns: item["resources"] as? [String],
            metadata: metadata,
            always: item["save"] as? [String],
            tool: tool
        )
    }

    static func permissions(data: Data) -> [APIClient.PermissionRequest] {
        guard let rows = try? dataArray(data) else { return [] }
        return rows.compactMap { ($0 as? [String: Any]).flatMap { permission($0) } }
    }

    /// Shapes a permission payload into what
    /// `PermissionController.parseAskedEvent` accepts.
    static func permissionAskedProperties(_ item: [String: Any]) -> [String: Any]? {
        guard let mapped = permission(item) else { return nil }
        var properties: [String: Any] = [
            "sessionID": mapped.sessionID,
            "id": mapped.id,
            "permission": mapped.permission ?? "",
            "patterns": mapped.patterns ?? [],
            "always": mapped.always ?? [],
        ]
        if let metadata = mapped.metadata, let filepath = metadata.filepath {
            properties["metadata"] = ["filepath": filepath]
        }
        if let tool = mapped.tool {
            properties["tool"] = ["messageID": tool.messageID ?? "", "callID": tool.callID ?? ""]
        }
        return properties
    }

    static func permissionReplyBody(_ response: APIClient.PermissionResponse) -> [String: Any] {
        ["decision": response.rawValue]
    }

    // MARK: - Providers and models (spec: Files, diff, models, projects)

    static func providers(modelData: Data, providerData: Data, defaultData: Data?) -> ProvidersResponse {
        let providerList = providerRows(providerData)
        let modelsByProvider = modelsGroupedByProvider(modelData)

        var byID: [String: ConfigProvider] = [:]
        for provider in providerList {
            byID[provider.id] = ConfigProvider(id: provider.id, name: provider.name ?? provider.id, models: modelsByProvider[provider.id] ?? [:])
        }
        // A model whose provider is absent from the provider list still
        // appears, under a provider whose id and name are that providerID.
        for (providerID, models) in modelsByProvider where byID[providerID] == nil {
            byID[providerID] = ConfigProvider(id: providerID, name: providerID, models: models)
        }

        let defaultProvider = defaultData
            .flatMap { try? envelopeObject($0) }
            .flatMap { defaultProvider(from: $0["data"]) }

        return ProvidersResponse(providers: byID.values.sorted { $0.id < $1.id }, default: defaultProvider)
    }

    static func providerRegistry(modelData: Data, providerData: Data) -> ProviderRegistryResponse {
        let providerList = providerRows(providerData)
        let modelsByProvider = modelsGroupedByProvider(modelData)
        let providers = providerIDsOrdered(providerList, modelProviders: modelsByProvider)
            .map { id in
                let name = providerList.first { $0.id == id }?.name ?? id
                return ConfigProvider(id: id, name: name ?? id, models: modelsByProvider[id] ?? [:])
            }
        var connected = providerList.filter { $0.activation != "disabled" }.map(\.id)
        if connected.isEmpty {
            connected = Array(modelsByProvider.keys).sorted()
        }
        return ProviderRegistryResponse(providers: providers, connectedProviderIDs: connected)
    }

    private typealias ProviderRow = (id: String, name: String?, activation: String?)

    private static func providerRows(_ data: Data) -> [ProviderRow] {
        guard let rows = try? dataArray(data) else { return [] }
        return rows.compactMap { row in
            guard let dict = row as? [String: Any], let id = dict["id"] as? String, !id.isEmpty else { return nil }
            return (id, dict["name"] as? String, dict["activation"] as? String)
        }
    }

    private static func providerIDsOrdered(_ providers: [ProviderRow], modelProviders: [String: [String: ProviderModel]]) -> [String] {
        var ids = providers.map(\.id)
        for id in modelProviders.keys where !ids.contains(id) {
            ids.append(id)
        }
        return ids.sorted()
    }

    private static func modelsGroupedByProvider(_ data: Data) -> [String: [String: ProviderModel]] {
        guard let rows = try? dataArray(data) else { return [:] }
        var grouped: [String: [String: ProviderModel]] = [:]
        for row in rows {
            guard let dict = row as? [String: Any],
                  let modelID = dict["id"] as? String, !modelID.isEmpty,
                  let providerID = dict["providerID"] as? String, !providerID.isEmpty else { continue }
            grouped[providerID, default: [:]][modelID] = providerModel(dict, modelID: modelID, providerID: providerID)
        }
        return grouped
    }

    private static func providerModel(_ dict: [String: Any], modelID: String, providerID: String) -> ProviderModel {
        let capabilities = dict["capabilities"] as? [String: Any]
        let input = capabilities?["input"] as? [Any] ?? []
        let output = capabilities?["output"] as? [Any] ?? []
        let limit = dict["limit"] as? [String: Any]
        return ProviderModel(
            id: modelID,
            name: dict["name"] as? String,
            providerID: providerID,
            limit: ProviderModelLimit(
                context: intValue(limit?["context"]),
                input: nil,
                output: intValue(limit?["output"])
            ),
            capabilities: ProviderModelCapabilities(
                reasoning: nil,
                toolCall: capabilities?["tools"] as? Bool,
                attachment: input.contains(where: { ($0 as? String) == "image" }),
                input: providerModelIO(from: input),
                output: providerModelIO(from: output)
            ),
            family: dict["family"] as? String,
            releaseDate: nil
        )
    }

    private static func providerModelIO(from list: [Any]) -> ProviderModelIO? {
        let values = list.compactMap { $0 as? String }
        guard !values.isEmpty else { return nil }
        return ProviderModelIO(
            text: values.contains("text"),
            audio: values.contains("audio"),
            image: values.contains("image"),
            video: values.contains("video"),
            pdf: values.contains("pdf")
        )
    }

    private static func defaultProvider(from data: Any?) -> DefaultProvider? {
        guard let dict = data as? [String: Any],
              let providerID = dict["providerID"] as? String,
              let modelID = dict["id"] as? String else { return nil }
        return DefaultProvider(providerID: providerID, modelID: modelID)
    }

    // MARK: - Agents

    static func agents(data: Data) -> [AgentInfo] {
        guard let rows = try? dataArray(data) else { return [] }
        return rows.compactMap { row in
            guard let dict = row as? [String: Any],
                  let id = dict["id"] as? String else { return nil }
            let name = (dict["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? id
            return AgentInfo(
                name: name,
                description: dict["description"] as? String,
                mode: dict["mode"] as? String,
                hidden: dict["hidden"] as? Bool,
                native: nil
            )
        }
    }

    // MARK: - Files, status, diff (spec: Files, diff, models, projects)

    static func fileNodes(data: Data) -> [FileNode] {
        guard let rows = try? dataArray(data) else { return [] }
        return rows.compactMap { row in
            guard let dict = row as? [String: Any],
                  let path = dict["path"] as? String else { return nil }
            return FileNode(
                name: (path as NSString).lastPathComponent,
                path: path,
                absolute: nil,
                type: dict["type"] as? String ?? "file",
                ignored: nil
            )
        }
    }

    /// Raw bytes: UTF-8 that decodes is text, anything else is binary.
    static func fileContent(_ raw: Data) -> FileContent {
        if let text = String(data: raw, encoding: .utf8) {
            return FileContent(type: "text", content: text)
        }
        return FileContent(type: "binary", content: nil)
    }

    static func findPaths(data: Data) -> [String] {
        guard let rows = try? dataArray(data) else { return [] }
        return rows.compactMap { ($0 as? [String: Any])?["path"] as? String }
    }

    static func fileStatusEntries(data: Data) -> [FileStatusEntry] {
        guard let rows = try? dataArray(data) else { return [] }
        return rows.compactMap { row in
            guard let dict = row as? [String: Any],
                  let file = dict["file"] as? String else { return nil }
            return FileStatusEntry(path: file, status: dict["status"] as? String)
        }
    }

    static func fileDiffs(data: Data) -> [FileDiff] {
        guard let rows = try? dataArray(data) else { return [] }
        return rows.compactMap { row in
            guard let dict = row as? [String: Any],
                  let file = dict["file"] as? String else { return nil }
            return FileDiff(
                file: file,
                before: "",
                after: dict["patch"] as? String ?? "",
                additions: intValue(dict["additions"]) ?? 0,
                deletions: intValue(dict["deletions"]) ?? 0,
                status: dict["status"] as? String
            )
        }
    }

    // MARK: - Projects (spec: Files, diff, models, projects)

    /// `GET /api/project` is a bare array, no `data` envelope.
    static func projects(_ data: Data) -> [Project] {
        guard let rows = try? JSONSerialization.jsonObject(with: data) as? [Any] else { return [] }
        return rows.compactMap { row in
            guard let dict = row as? [String: Any],
                  let id = dict["id"] as? String,
                  let canonical = dict["canonical"] as? String else { return nil }
            let icon = (dict["icon"] as? [String: Any]).map { Project.IconInfo(color: $0["color"] as? String) }
            let time = (dict["time"] as? [String: Any]).map {
                Project.TimeInfo(created: intValue($0["created"]), updated: intValue($0["updated"]))
            }
            return Project(
                id: id,
                worktree: canonical,
                vcs: dict["vcs"] as? String,
                icon: icon,
                time: time,
                sandboxes: []
            )
        }
    }

    /// Current project is `GET /api/location`: match `project.id` in the
    /// project list, else build one from `project.id` and `project.directory`.
    static func currentProject(locationData: Data, projects: [Project]) -> Project? {
        guard let location = try? envelopeObject(locationData),
              let project = location["project"] as? [String: Any],
              let id = project["id"] as? String else { return nil }
        if let match = projects.first(where: { $0.id == id }) {
            return match
        }
        return Project(
            id: id,
            worktree: project["directory"] as? String ?? "",
            vcs: nil,
            icon: nil,
            time: nil,
            sandboxes: []
        )
    }

    // MARK: - Session status (spec: SSE)

    /// `GET /api/session/active`: ids with `type: "running"` are busy. Every
    /// other known session is idle — handled by the existing poll merge.
    static func activeStatuses(data: Data) -> [String: SessionStatus] {
        guard let entries = try? dataObject(data) else { return [:] }
        var statuses: [String: SessionStatus] = [:]
        for (sessionID, value) in entries {
            guard let status = value as? [String: Any],
                  status["type"] as? String == "running" else { continue }
            statuses[sessionID] = SessionStatus(type: "busy", attempt: nil, message: nil, next: nil)
        }
        return statuses
    }

    // MARK: - Send encoders (spec: Send)

    /// v2 text/image prompt body: `{"text": ...}` plus `files[].uri` data
    /// URIs and the optional `id`. Never `parts`, `mime`, `source`, or
    /// `format`.
    static func promptBody(text: String, files: [(uri: String, name: String)], messageID: String?) -> [String: Any] {
        var body: [String: Any] = ["text": text]
        if let messageID, !messageID.isEmpty {
            body["id"] = messageID
        }
        if !files.isEmpty {
            body["files"] = files.map { ["uri": $0.uri, "name": $0.name] }
        }
        return body
    }

    /// Decodes the structured-send assistant text into the Car Mode envelope,
    /// enforcing the version/speech contract the caller checks today.
    static func structuredEnvelope(fromText text: String) throws -> CarResponseEnvelope {
        guard let data = text.data(using: .utf8) else {
            throw CarModeError.invalidResponse
        }
        let envelope: CarResponseEnvelope
        do {
            envelope = try JSONDecoder().decode(CarResponseEnvelope.self, from: data)
        } catch {
            throw CarModeError.invalidResponse
        }
        guard envelope.version == 1,
              !envelope.speech.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CarModeError.invalidResponse
        }
        return envelope
    }
}
