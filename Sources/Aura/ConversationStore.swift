import Foundation
import SwiftUI

@Observable
final class ConversationStore {

    var messages: [ChatMessage] = []
    var isStreaming = false
    var currentResponse = ""
    var errorMessage: String?
    var activeMode: CommandMode? = nil

    // MARK: - History

    private(set) var inputHistory: [String] = []
    private var historyIndex: Int? = nil

    func navigateHistory(up: Bool) -> String? {
        guard !inputHistory.isEmpty else { return nil }
        if up {
            let newIndex = historyIndex.map { max(0, $0 - 1) } ?? (inputHistory.count - 1)
            historyIndex = newIndex
            return inputHistory[newIndex]
        } else {
            guard let idx = historyIndex else { return nil }
            if idx < inputHistory.count - 1 {
                let newIndex = idx + 1
                historyIndex = newIndex
                return inputHistory[newIndex]
            } else {
                historyIndex = nil
                return ""
            }
        }
    }

    // MARK: - Model

    static let availableModels = ["gpt-4o", "gpt-4o-mini", "gpt-4-turbo"]

    var selectedModel: String {
        didSet { UserDefaults.standard.set(selectedModel, forKey: "aura_selected_model") }
    }

    enum Persona: String, CaseIterable {
        case dev     = "Dev"
        case general = "Geral"

        var systemPrompt: String {
            switch self {
            case .dev:     return OpenAIService.devSystemPrompt
            case .general: return OpenAIService.generalSystemPrompt
            }
        }
    }

    var selectedPersona: Persona {
        didSet { UserDefaults.standard.set(selectedPersona.rawValue, forKey: "aura_persona") }
    }

    init() {
        self.selectedModel = UserDefaults.standard.string(forKey: "aura_selected_model") ?? "gpt-4o"
        let raw = UserDefaults.standard.string(forKey: "aura_persona") ?? Persona.dev.rawValue
        self.selectedPersona = Persona(rawValue: raw) ?? .dev
    }

    // MARK: - Messaging

    func sendMessage(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if inputHistory.last != trimmed { inputHistory.append(trimmed) }
        historyIndex = nil

        messages.append(ChatMessage(role: "user", content: trimmed))
        isStreaming = true
        currentResponse = ""
        errorMessage = nil

        let systemPrompt = activeMode?.systemPrompt ?? selectedPersona.systemPrompt

        await OpenAIService.shared.streamMessage(
            messages: messages,
            systemPrompt: systemPrompt,
            model: selectedModel,
            onToken: { [weak self] token in
                self?.currentResponse += token
            },
            onComplete: { [weak self] in
                guard let self else { return }
                messages.append(ChatMessage(role: "assistant", content: currentResponse))
                currentResponse = ""
                isStreaming = false
            },
            onError: { [weak self] error in
                self?.errorMessage = error.localizedDescription
                self?.isStreaming = false
            }
        )
    }

    func clear() {
        messages.removeAll()
        currentResponse = ""
        errorMessage = nil
        isStreaming = false
        activeMode = nil
        historyIndex = nil
    }
}
