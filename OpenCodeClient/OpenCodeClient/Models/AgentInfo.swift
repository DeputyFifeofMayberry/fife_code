//
//  AgentInfo.swift
//  OpenCodeClient
//

import Foundation

/// Represents an agent from the OpenCode server.
/// Used for agent selection in the Chat toolbar.
struct AgentInfo: Codable, Identifiable, Hashable {
    var id: String { name }
    
    let name: String              // Display name, e.g. "Plan" (agent ID may differ, e.g. "plan")
    let description: String?      // Human-readable description
    let mode: String?             // "primary" or "subagent"
    let hidden: Bool?             // If true, should not be shown in UI
    let native: Bool?             // If true, it's a built-in agent
    var serverID: String? = nil   // Server agent ID (V2 `/api/agent` "id"); nil on legacy V1 payloads

    /// What to send in switch/prompt requests: the server matches on ID,
    /// and the plan agent is id "plan" with display name "Plan".
    var switchID: String { serverID ?? name }

    private enum CodingKeys: String, CodingKey {
        case name, description, mode, hidden, native
        case serverID = "id"
    }
    
    /// Short display name for UI (first word before space or parenthesis)
    var shortName: String {
        // Extract first word or name before parenthesis
        if let parenIndex = name.firstIndex(of: "(") {
            return String(name[..<parenIndex]).trimmingCharacters(in: .whitespaces)
        }
        if let spaceIndex = name.firstIndex(of: " ") {
            return String(name[..<spaceIndex])
        }
        return name
    }
    
    /// Whether this agent should be shown in the UI selector
    /// Filters out hidden agents and subagents (only primary/all modes shown)
    var isVisible: Bool {
        guard hidden != true else { return false }
        guard let mode = mode else { return true }
        return mode == "primary" || mode == "all"
    }

    static let fallbackAgentName = "build"

    /// Keep `selection` when the server catalog is empty or contains it
    /// (by display name or server ID). Otherwise use the first visible
    /// agent, then `fallbackAgentName`.
    static func effectiveSelectedAgent(selection: String, agents: [AgentInfo]) -> String {
        guard !agents.isEmpty else { return selection }
        if agents.contains(where: { $0.name == selection || $0.serverID == selection }) {
            return selection
        }
        return agents.first(where: { $0.isVisible })?.name ?? fallbackAgentName
    }
}
