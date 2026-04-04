import Testing
@testable import Aura

@Suite("CommandMode")
struct CommandModeTests {

    @Test func allCasesExist() {
        #expect(CommandMode.allCases.count == 6)
    }

    @Test func triggerHasSlashPrefix() {
        for mode in CommandMode.allCases {
            #expect(mode.trigger.hasPrefix("/"))
        }
    }

    @Test func labelIsCapitalized() {
        #expect(CommandMode.translate.label == "Translate")
        #expect(CommandMode.fix.label == "Fix")
        #expect(CommandMode.code.label == "Code")
    }

    @Test func systemPromptContainsBase() {
        let base = "You are a concise AI assistant inside a macOS launcher."
        for mode in CommandMode.allCases {
            #expect(mode.systemPrompt.contains(base))
        }
    }

    @Test func iconIsNotEmpty() {
        for mode in CommandMode.allCases {
            #expect(!mode.icon.isEmpty)
        }
    }

    @Test func hintIsNotEmpty() {
        for mode in CommandMode.allCases {
            #expect(!mode.hint.isEmpty)
        }
    }

    // MARK: - Suggestions

    @Test func suggestionsEmptyForNoSlash() {
        #expect(CommandMode.suggestions(for: "hello").isEmpty)
    }

    @Test func suggestionsAllForBareSlash() {
        let suggestions = CommandMode.suggestions(for: "/")
        #expect(suggestions.count == CommandMode.allCases.count)
    }

    @Test func suggestionsFilterByPrefix() {
        let suggestions = CommandMode.suggestions(for: "/tr")
        #expect(suggestions.count == 1)
        #expect(suggestions.first == .translate)
    }

    @Test func suggestionsMultipleMatches() {
        // /s matches summarize and shorter
        let suggestions = CommandMode.suggestions(for: "/s")
        #expect(suggestions.count == 2)
        #expect(suggestions.contains(.summarize))
        #expect(suggestions.contains(.shorter))
    }

    @Test func suggestionsNoMatch() {
        #expect(CommandMode.suggestions(for: "/zzz").isEmpty)
    }
}
