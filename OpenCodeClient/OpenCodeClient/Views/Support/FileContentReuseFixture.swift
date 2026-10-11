import Foundation
import SwiftUI

@MainActor
@Observable
final class FileContentProbe {
    var contentDirectories: [String] = []
    var contentRequestCount = 0
    var lateDelivered = false

    var summary: String {
        "count:\(contentRequestCount) dirs:\(contentDirectories.joined(separator: "|")) late:\(lateDelivered ? 1 : 0)"
    }
}

enum FileContentReuseFixture {
    static let argument = "UITEST_FILE_CONTENT_REUSE_FIXTURE"
    static let modeKey = "FILE_CONTENT_FIXTURE_MODE"
    static let workspaceA = "/tmp/w06-ws-a"
    static let workspaceB = "/tmp/w06-ws-b"
    static let contentA = "CONTENT_A"
    static let contentB = "CONTENT_B"
    @MainActor static let probe = FileContentProbe()
    static var script: FileContentScript?

    enum Mode: String {
        case latePath = "late-path"
        case lateError = "late-error"
        case lateWorkspace = "late-workspace"
        case refresh

        var initialPath: String {
            switch self {
            case .latePath, .lateError: return "a.txt"
            case .lateWorkspace, .refresh: return "notes.txt"
            }
        }

        var initialWorkspace: String {
            switch self {
            case .latePath, .lateError: return "/ws"
            case .lateWorkspace: return FileContentReuseFixture.workspaceA
            case .refresh: return FileContentReuseFixture.workspaceB
            }
        }
    }

    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains(argument)
    }

    static var mode: Mode {
        let raw = ProcessInfo.processInfo.environment[modeKey] ?? Mode.latePath.rawValue
        return Mode(rawValue: raw) ?? .latePath
    }

    @MainActor
    static func makeAppState() -> AppState {
        probe.contentDirectories = []
        probe.contentRequestCount = 0
        probe.lateDelivered = false
        let script = FileContentScript()
        self.script = script
        return AppState(
            apiClient: script,
            sseClient: SSEClient(),
            userDefaults: UserDefaults(suiteName: "opencode.uitest.file-content.\(UUID().uuidString)")!,
            hostCredentialAccess: HostCredentialAccess(
                save: { _, _ in },
                load: { _ in nil },
                delete: { _ in }
            )
        )
    }
}

struct FileContentReuseHost: View {
    @Bindable var state: AppState
    @State private var path = FileContentReuseFixture.mode.initialPath
    @State private var workspace = FileContentReuseFixture.mode.initialWorkspace

    var body: some View {
        NavigationStack {
            FileContentView(state: state, filePath: path, workspaceDirectory: workspace)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Text(FileContentReuseFixture.probe.summary)
                    .font(.system(size: 1))
                    .accessibilityIdentifier("file-content-probe")
                HStack {
                    Button("switch-path") { path = "b.txt" }
                        .accessibilityIdentifier("file-content-switch-path")
                    Button("switch-workspace") { workspace = FileContentReuseFixture.workspaceB }
                        .accessibilityIdentifier("file-content-switch-workspace")
                    Button("release-late") {
                        Task { await FileContentReuseFixture.script?.releaseLate() }
                    }
                    .accessibilityIdentifier("file-content-release-late")
                }
            }
        }
    }
}

private struct FileContentScriptError: Error {}

actor FileContentScript: APIClientProtocol, FileDirectorySearching {
    private var parked: CheckedContinuation<Result<FileContent, Error>, Never>?
    private var requests = 0

    func releaseLate() {
        let result: Result<FileContent, Error>
        if FileContentReuseFixture.mode == .lateError {
            result = .failure(FileContentScriptError())
        } else {
            result = .success(FileContent(type: "text", content: FileContentReuseFixture.contentA))
        }
        parked?.resume(returning: result)
        parked = nil
    }

    func configure(baseURL: String, username: String?, password: String?) {}
    func health() async throws -> HealthResponse { HealthResponse(healthy: true, version: "fixture") }
    func projects() async throws -> [Project] { [] }
    func projectCurrent() async throws -> Project? { nil }
    func sessions(directory: String?, limit: Int) async throws -> [Session] { [] }
    func session(sessionID: String) async throws -> Session {
        throw APIError.httpError(statusCode: 404, data: Data())
    }
    func createSession(title: String?, directory: String?) async throws -> Session {
        throw APIError.httpError(statusCode: 501, data: Data())
    }
    func updateSession(sessionID: String, title: String) async throws -> Session {
        throw APIError.httpError(statusCode: 501, data: Data())
    }
    func updateSessionArchived(sessionID: String, archived: Int) async throws -> Session {
        throw APIError.httpError(statusCode: 501, data: Data())
    }
    func deleteSession(sessionID: String) async throws {}
    func messages(sessionID: String, limit: Int?) async throws -> [MessageWithParts] { [] }
    func promptAsync(sessionID: String, messageID: String, text: String, attachments: [ComposerImageAttachment], agent: String, model: Message.ModelInfo?, directory: String?) async throws {}
    func promptStructured(sessionID: String, messageID: String?, text: String, system: String, format: StructuredOutputFormat, agent: String, model: Message.ModelInfo) async throws -> MessageWithParts {
        throw APIError.httpError(statusCode: 501, data: Data())
    }
    func abort(sessionID: String) async throws {}
    func sessionStatus() async throws -> [String: SessionStatus] { [:] }
    func pendingPermissions() async throws -> [APIClient.PermissionRequest] { [] }
    func respondPermission(sessionID: String, permissionID: String, response: APIClient.PermissionResponse) async throws {}
    func pendingQuestions() async throws -> [QuestionRequest] { [] }
    func replyQuestion(requestID: String, answers: [[String]]) async throws {}
    func rejectQuestion(requestID: String) async throws {}
    func providers() async throws -> ProvidersResponse {
        try JSONDecoder().decode(ProvidersResponse.self, from: Data("{\"providers\":[]}".utf8))
    }
    func providerRegistry() async throws -> ProviderRegistryResponse {
        ProviderRegistryResponse(providers: [], connectedProviderIDs: [])
    }
    func agents() async throws -> [AgentInfo] { [] }
    func sessionDiff(sessionID: String) async throws -> [FileDiff] { [] }
    func sessionTodos(sessionID: String) async throws -> [TodoItem] { [] }
    func fileList(path: String, directory: String?) async throws -> [FileNode] { [] }
    func fileContent(path: String, directory: String?) async throws -> FileContent {
        requests += 1
        let index = requests
        let recorded = directory ?? ""
        await MainActor.run {
            FileContentReuseFixture.probe.contentDirectories.append(recorded)
            FileContentReuseFixture.probe.contentRequestCount = index
        }
        if FileContentReuseFixture.mode != .refresh, index == 1 {
            let result = await withCheckedContinuation { (cont: CheckedContinuation<Result<FileContent, Error>, Never>) in
                parked = cont
            }
            await MainActor.run { FileContentReuseFixture.probe.lateDelivered = true }
            return try result.get()
        }
        if FileContentReuseFixture.mode == .refresh {
            return FileContent(type: "text", content: "BODY-\(index)")
        }
        if path == "b.txt" || directory == FileContentReuseFixture.workspaceB {
            return FileContent(type: "text", content: FileContentReuseFixture.contentB)
        }
        return FileContent(type: "text", content: FileContentReuseFixture.contentA)
    }
    func findFile(query: String, limit: Int) async throws -> [String] { [] }
    func findFile(query: String, limit: Int, directory: String?) async throws -> [String] { [] }
    func fileStatus() async throws -> [FileStatusEntry] { [] }
    func forkSession(sessionID: String, messageID: String?) async throws -> Session {
        throw APIError.httpError(statusCode: 501, data: Data())
    }
    func revertSession(sessionID: String, messageID: String, partID: String?) async throws -> Session {
        throw APIError.httpError(statusCode: 501, data: Data())
    }
}
