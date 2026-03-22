import Foundation

enum CommandMode: String, CaseIterable, Identifiable {
    case translate, fix, explain, summarize, code, shorter

    var id: String { rawValue }
    var trigger: String { "/\(rawValue)" }
    var label: String { rawValue.capitalized }

    var icon: String {
        switch self {
        case .translate: "globe"
        case .fix:       "wrench.and.screwdriver"
        case .explain:   "lightbulb"
        case .summarize: "doc.text"
        case .code:      "chevron.left.forwardslash.chevron.right"
        case .shorter:   "arrow.down.right.and.arrow.up.left"
        }
    }

    var hint: String {
        switch self {
        case .translate: "Translate text"
        case .fix:       "Fix grammar & improve writing"
        case .explain:   "Explain a concept or code"
        case .summarize: "Summarize content"
        case .code:      "Write or review code"
        case .shorter:   "Make it shorter & punchier"
        }
    }

    var systemPrompt: String {
        let base = "You are a concise AI assistant inside a macOS launcher. Be direct. Use markdown when helpful."
        switch self {
        case .translate:
            return base + " Detect the source language and translate. If no target is specified, translate to English."
        case .fix:
            return base + " Fix grammar, spelling, and improve clarity. Return only the corrected text, no commentary."
        case .explain:
            return base + " Explain clearly using simple terms and examples where helpful."
        case .summarize:
            return base + " Summarize in concise bullet points. Maximum 5 bullets unless asked for more."
        case .code:
            return base + " You are an expert programmer. Write clean, well-structured code in markdown code blocks. Briefly explain the approach before the code."
        case .shorter:
            return base + " Rewrite to be significantly shorter and more direct. Preserve the key meaning. Return only the rewritten text."
        }
    }

    static func suggestions(for input: String) -> [CommandMode] {
        guard input.hasPrefix("/") else { return [] }
        let query = String(input.dropFirst()).lowercased()
        if query.isEmpty { return Array(allCases) }
        return allCases.filter { $0.rawValue.hasPrefix(query) }
    }
}
