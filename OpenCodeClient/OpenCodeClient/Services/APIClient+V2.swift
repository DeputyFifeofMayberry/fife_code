//
//  APIClient+V2.swift
//  OpenCodeClient
//
//  V2 wire implementations (docs/v2_server_compatibility.md). Public
//  APIClient methods branch here when the host generation is v2; every
//  request goes through the same makeRequest plumbing as V1.
//

import Foundation

extension APIClient {
    // MARK: - Sessions

    func v2Sessions(directory: String?, limit: Int) async throws -> [Session] {
        var queryItems: [URLQueryItem] = []
        if limit > 0 {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        if let directory, !directory.isEmpty {
            queryItems.append(URLQueryItem(name: "directory", value: directory))
        }
        let (data, _) = try await makeRequest(path: "/api/session", queryItems: queryItems.isEmpty ? nil : queryItems)
        return try V2Mapper.sessionList(data)
    }

    func v2CreateSession(title: String?, directory: String?) async throws -> Session {
        var body: [String: Any] = [:]
        if let title {
            body["title"] = title
        }
        if let directory, !directory.isEmpty {
            body["location"] = ["directory": directory]
        }
        let (data, _) = try await makeRequest(
            path: "/api/session",
            method: "POST",
            body: try JSONSerialization.data(withJSONObject: body)
        )
        return try V2Mapper.sessionFromEnvelope(data)
    }

    func v2UpdateSession(sessionID: String, title: String) async throws -> Session {
        let (data, http) = try await makeRequest(
            path: "/api/session/\(sessionID)",
            method: "PATCH",
            body: try JSONSerialization.data(withJSONObject: ["title": title])
        )
        // 204 with an empty body; never decode the patch body.
        guard http.statusCode == 204, data.isEmpty else {
            throw APIError.httpError(statusCode: http.statusCode, data: data)
        }
        let (sessionData, _) = try await makeRequest(path: "/api/session/\(sessionID)")
        return try V2Mapper.sessionFromEnvelope(sessionData)
    }

    // MARK: - Send (spec: Send, Structured send)

    func v2PromptAsync(
        sessionID: String,
        messageID: String,
        text: String,
        attachments: [ComposerImageAttachment],
        agent: String,
        model: Message.ModelInfo?
    ) async throws {
        try await v2SwitchAgentModel(sessionID: sessionID, agent: agent, model: model)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = V2Mapper.promptBody(
            text: trimmed,
            files: attachments.map { (uri: $0.dataURL, name: $0.filename) },
            messageID: messageID
        )
        let (data, http) = try await makeRequest(
            path: "/api/session/\(sessionID)/prompt",
            method: "POST",
            body: try JSONSerialization.data(withJSONObject: body)
        )
        guard http.statusCode == 200 else {
            throw APIError.httpError(statusCode: http.statusCode, data: data)
        }
    }

    func v2PromptStructured(
        sessionID: String,
        messageID: String?,
        text: String,
        system: String,
        format: StructuredOutputFormat,
        agent: String,
        model: Message.ModelInfo
    ) async throws -> MessageWithParts {
        try await v2SwitchAgentModel(sessionID: sessionID, agent: agent, model: model)

        let schemaText = String(data: try JSONEncoder().encode(format), encoding: .utf8) ?? "{}"
        let combined = "\(system)\n\n\(text)\n\nReply with only JSON matching this schema:\n\(schemaText)"
        let admittedUserID = try await v2AdmitPrompt(
            sessionID: sessionID,
            body: V2Mapper.promptBody(text: combined, files: [], messageID: messageID),
            expectedID: messageID
        )

        // Poll every 1 second for at most 60 seconds; stop early when the
        // open SSE socket reports the session idle or retry.
        let deadline = Date().addingTimeInterval(60)
        var transcript: [MessageWithParts] = []
        while true {
            transcript = try await messages(sessionID: sessionID, limit: nil)
            if V2Mapper.structuredAssistant(in: transcript, afterUserID: admittedUserID) != nil {
                break
            }
            if Date() >= deadline { break }
            if let probe = v2IdleProbe, await probe() { break }
            try await Task.sleep(for: .seconds(1))
        }

        guard let assistant = V2Mapper.structuredAssistant(in: transcript, afterUserID: admittedUserID),
              let textPart = assistant.parts.last(where: { $0.type == "text" }),
              let partText = textPart.text else {
            throw CarModeError.invalidResponse
        }
        let envelope = try V2Mapper.structuredEnvelope(fromText: partText)
        let isIdle = await v2IdleProbe?() ?? true
        let structured = try WireJSON(encoding: envelope)
        return MessageWithParts(
            info: assistant.info.withStructured(structured, completingWhenIdle: isIdle),
            parts: assistant.parts
        )
    }

    /// Agent/model switches before a v2 prompt: 204 each, agent and model
    /// never travel in the prompt body.
    func v2SwitchAgentModel(sessionID: String, agent: String, model: Message.ModelInfo?) async throws {
        if !agent.isEmpty {
            let (data, http) = try await makeRequest(
                path: "/api/session/\(sessionID)/agent",
                method: "POST",
                body: try JSONSerialization.data(withJSONObject: ["agent": agent])
            )
            guard http.statusCode == 204 else {
                throw APIError.httpError(statusCode: http.statusCode, data: data)
            }
        }
        if let model {
            let (data, http) = try await makeRequest(
                path: "/api/session/\(sessionID)/model",
                method: "POST",
                body: try JSONSerialization.data(
                    withJSONObject: ["model": ["id": model.modelID, "providerID": model.providerID]]
                )
            )
            guard http.statusCode == 204 else {
                throw APIError.httpError(statusCode: http.statusCode, data: data)
            }
        }
    }

    /// Admits the prompt and returns the admitted user message id. A 409 on
    /// the client-supplied id means it was already admitted: continue the
    /// poll only when that user id is present, else the response is invalid.
    private func v2AdmitPrompt(sessionID: String, body: [String: Any], expectedID: String?) async throws -> String {
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        do {
            let (data, http) = try await makeRequest(path: "/api/session/\(sessionID)/prompt", method: "POST", body: bodyData)
            guard http.statusCode == 200 else {
                throw APIError.httpError(statusCode: http.statusCode, data: data)
            }
            if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let payload = object["data"] as? [String: Any],
               let id = payload["id"] as? String, !id.isEmpty {
                return id
            }
            return expectedID ?? ""
        } catch let error as APIError {
            guard case .httpError(409, _) = error else { throw error }
            guard let expected = expectedID else { throw CarModeError.invalidResponse }
            let transcript = try await messages(sessionID: sessionID, limit: nil)
            guard transcript.contains(where: { $0.info.isUser && $0.info.id == expected }) else {
                throw CarModeError.invalidResponse
            }
            return expected
        }
    }

    // MARK: - Providers

    func v2Providers() async throws -> ProvidersResponse {
        let (modelData, _) = try await makeRequest(path: "/api/model")
        let (providerData, _) = try await makeRequest(path: "/api/provider")
        let defaultData = try? await makeRequest(path: "/api/model/default")
        return V2Mapper.providers(modelData: modelData, providerData: providerData, defaultData: defaultData?.0)
    }

    // MARK: - Files

    func v2FileList(path: String, directory: String?) async throws -> [FileNode] {
        var queryItems = [URLQueryItem(name: "path", value: path)]
        if let directory, !directory.isEmpty {
            queryItems.append(URLQueryItem(name: "location[directory]", value: directory))
        }
        let (data, _) = try await makeRequest(path: "/api/fs/list", queryItems: queryItems)
        return V2Mapper.fileNodes(data: data)
    }

    func v2FileContent(path: String, directory: String?) async throws -> FileContent {
        var queryItems: [URLQueryItem]? = nil
        if let directory, !directory.isEmpty {
            queryItems = [URLQueryItem(name: "location[directory]", value: directory)]
        }
        let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let (data, _) = try await makeRequest(path: "/api/fs/read/\(encoded)", queryItems: queryItems)
        return V2Mapper.fileContent(data)
    }

    func v2FindFile(query: String, limit: Int, directory: String?) async throws -> [String] {
        var queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        if let directory, !directory.isEmpty {
            queryItems.append(URLQueryItem(name: "location[directory]", value: directory))
        }
        let (data, _) = try await makeRequest(path: "/api/fs/find", queryItems: queryItems)
        return V2Mapper.findPaths(data: data)
    }
}
