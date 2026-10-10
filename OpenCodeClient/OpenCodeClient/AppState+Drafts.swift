import Foundation

/// Per-session draft input persistence + selected-model-per-session map.
/// State fields (`draftInputsBySessionID`, `selectedModelIDBySessionID`)
/// stay on `AppState` so SwiftUI observation works; only behavior moves.
extension AppState {
    func loadHostScopedPreferences() {
        if let data = defaults.data(forKey: Self.draftInputsByHostKey),
           let decoded = try? JSONDecoder().decode([String: [String: String]].self, from: data) {
            draftInputsByHost = decoded
        } else if !hostProfileBlobUnreadable,
                  let data = defaults.data(forKey: Self.draftInputsBySessionKey),
                  let decoded = try? JSONDecoder().decode([String: String].self, from: data),
                  !decoded.isEmpty {
            draftInputsByHost[currentHostProfileID.uuidString] = decoded
            persistDraftInputs()
            defaults.removeObject(forKey: Self.draftInputsBySessionKey)
        }

        if let data = defaults.data(forKey: Self.selectedModelByHostKey),
           let decoded = try? JSONDecoder().decode([String: [String: String]].self, from: data) {
            selectedModelIDsByHost = decoded
        } else if !hostProfileBlobUnreadable,
                  let data = defaults.data(forKey: Self.selectedModelBySessionKey),
                  let decoded = try? JSONDecoder().decode([String: String].self, from: data),
                  !decoded.isEmpty {
            selectedModelIDsByHost[currentHostProfileID.uuidString] = decoded
            persistSelectedModelMap()
            defaults.removeObject(forKey: Self.selectedModelBySessionKey)
        }
    }

    func persistDraftInputs() {
        if draftInputsByHost.isEmpty {
            defaults.removeObject(forKey: Self.draftInputsByHostKey)
            return
        }
        if let data = try? JSONEncoder().encode(draftInputsByHost) {
            defaults.set(data, forKey: Self.draftInputsByHostKey)
        }
    }

    func persistSelectedModelMap() {
        if selectedModelIDsByHost.isEmpty {
            defaults.removeObject(forKey: Self.selectedModelByHostKey)
            return
        }
        if let data = try? JSONEncoder().encode(selectedModelIDsByHost) {
            defaults.set(data, forKey: Self.selectedModelByHostKey)
        }
    }

    func removeHostPreference(sessionID: String) {
        var drafts = draftInputsBySessionID
        drafts.removeValue(forKey: sessionID)
        draftInputsBySessionID = drafts
        var models = selectedModelIDBySessionID
        models.removeValue(forKey: sessionID)
        selectedModelIDBySessionID = models
        persistDraftInputs()
        persistSelectedModelMap()
    }

    func draftText(for sessionID: String?) -> String {
        guard let sessionID else { return "" }
        return draftInputsBySessionID[sessionID] ?? ""
    }

    func setDraftText(_ text: String, for sessionID: String?) {
        guard let sessionID else { return }
        let cleaned = text
        if cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draftInputsBySessionID[sessionID] = nil
        } else {
            draftInputsBySessionID[sessionID] = cleaned
        }
        persistDraftInputs()
    }
}
