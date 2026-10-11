import Foundation

enum MessageGroupItem: Identifiable {
    case user(MessageWithParts)
    case assistantMerged([MessageWithParts])

    var id: String {
        switch self {
        case .user(let message):
            return "user-\(message.info.id)"
        case .assistantMerged(let messages):
            return "assistant-\(messages.first?.info.id ?? "")"
        }
    }

    var messageIDs: [String] {
        switch self {
        case .user(let message):
            return [message.info.id]
        case .assistantMerged(let messages):
            return messages.map(\.info.id)
        }
    }

    var messages: [MessageWithParts] {
        switch self {
        case .user(let message):
            return [message]
        case .assistantMerged(let messages):
            return messages
        }
    }

    static func grouped(_ messages: [MessageWithParts]) -> [MessageGroupItem] {
        var result: [MessageGroupItem] = []
        var index = 0
        while index < messages.count {
            let message = messages[index]
            if message.info.isUser {
                result.append(.user(message))
                index += 1
                continue
            }
            var batch: [MessageWithParts] = []
            while index < messages.count {
                let next = messages[index]
                if next.info.isUser { break }
                batch.append(next)
                index += 1
                if next.parts.contains(where: \.isText) { break }
            }
            if !batch.isEmpty {
                result.append(.assistantMerged(batch))
            }
        }
        return result
    }
}

struct AssistantTurnPresentation {
    struct DisplayedSpeech: Equatable {
        let messageID: String
        let text: String
    }

    struct DisplayedError: Equatable {
        let messageID: String
        let text: String
    }

    struct Footer {
        let messageID: String
        let model: Message.ModelInfo?
        let generalThroughput: String?
    }

    let messages: [MessageWithParts]

    var parts: [Part] {
        messages.flatMap(\.parts)
    }

    var speeches: [DisplayedSpeech] {
        guard !parts.contains(where: \.isText) else { return [] }
        return messages.compactMap { message in
            guard let text = MessageRowView.structuredSpeechFallback(for: message) else { return nil }
            return DisplayedSpeech(messageID: message.info.id, text: text)
        }
    }

    var errors: [DisplayedError] {
        messages.compactMap { message in
            guard let text = message.info.errorMessageForDisplay else { return nil }
            return DisplayedError(messageID: message.info.id, text: text)
        }
    }

    var copyableText: String {
        guard let info = messages.first?.info else { return "" }
        if parts.contains(where: \.isText) {
            return MessageRowView.copyableText(for: MessageWithParts(info: info, parts: parts))
        }
        if !speeches.isEmpty {
            return speeches.map(\.text).joined(separator: "\n\n")
        }
        return MessageRowView.copyableText(for: MessageWithParts(info: info, parts: parts))
    }

    var footer: Footer? {
        guard let message = messages.last else { return nil }
        let model = message.info.resolvedModel
        guard model != nil || !copyableText.isEmpty else { return nil }
        return Footer(
            messageID: message.info.id,
            model: model,
            generalThroughput: message.info.throughputLabelExcludingToolSeconds(message.toolRunSeconds)
        )
    }
}
