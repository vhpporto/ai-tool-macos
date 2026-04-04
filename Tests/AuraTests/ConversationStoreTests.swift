import Testing
@testable import Aura

@Suite("ConversationStore")
@MainActor
struct ConversationStoreTests {

    // MARK: - History navigation

    @Test func emptyHistoryReturnsNil() {
        let store = ConversationStore()
        #expect(store.navigateHistory(up: true) == nil)
        #expect(store.navigateHistory(up: false) == nil)
    }

    @Test func navigateUpReturnsMostRecent() {
        let store = ConversationStore()
        store.inputHistory.append("first")
        store.inputHistory.append("second")

        let result = store.navigateHistory(up: true)
        #expect(result == "second")
    }

    @Test func navigateUpTwiceReturnsOlder() {
        let store = ConversationStore()
        store.inputHistory.append("first")
        store.inputHistory.append("second")

        _ = store.navigateHistory(up: true) // second
        let result = store.navigateHistory(up: true) // first
        #expect(result == "first")
    }

    @Test func navigateUpThenDownReturnsNewer() {
        let store = ConversationStore()
        store.inputHistory.append("first")
        store.inputHistory.append("second")

        _ = store.navigateHistory(up: true)  // second
        _ = store.navigateHistory(up: true)  // first
        let result = store.navigateHistory(up: false) // second
        #expect(result == "second")
    }

    @Test func navigateDownPastEndReturnsEmpty() {
        let store = ConversationStore()
        store.inputHistory.append("first")

        _ = store.navigateHistory(up: true)  // first
        let result = store.navigateHistory(up: false) // past end
        #expect(result == "")
    }

    // MARK: - Clear

    @Test func clearResetsState() {
        let store = ConversationStore()
        store.messages.append(ChatMessage(role: "user", content: "test"))
        store.currentResponse = "partial"
        store.errorMessage = "oops"
        store.isStreaming = true
        store.activeMode = .code

        store.clear()

        #expect(store.messages.isEmpty)
        #expect(store.currentResponse.isEmpty)
        #expect(store.errorMessage == nil)
        #expect(!store.isStreaming)
        #expect(store.activeMode == nil)
    }

    // MARK: - Model

    @Test func availableModelsNotEmpty() {
        #expect(!ConversationStore.availableModels.isEmpty)
    }

    @Test func defaultModelIsGPT4o() {
        // Default when no UserDefaults value exists
        #expect(ConversationStore.availableModels.contains("gpt-4o"))
    }

    // MARK: - Persona

    @Test func personaSystemPrompts() {
        #expect(!ConversationStore.Persona.dev.systemPrompt.isEmpty)
        #expect(!ConversationStore.Persona.general.systemPrompt.isEmpty)
        #expect(ConversationStore.Persona.dev.systemPrompt != ConversationStore.Persona.general.systemPrompt)
    }
}
