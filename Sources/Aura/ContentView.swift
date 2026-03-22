import SwiftUI
import AppKit

struct ContentView: View {

    @Bindable var store: ConversationStore
    var onDismiss: () -> Void
    var onHeightChange: () -> Void = {}

    @State private var inputText = ""
    @State private var hoveredSuggestion: CommandMode? = nil
    @State private var specialResult: SpecialResult? = nil
    @State private var showSettings = false

    private var commandSuggestions: [CommandMode] {
        guard store.activeMode == nil, specialResult == nil else { return [] }
        return CommandMode.suggestions(for: inputText)
    }

    private var displayText: String {
        store.isStreaming ? store.currentResponse
            : store.messages.last(where: { $0.role == "assistant" })?.content ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            if showSettings {
                InlineSettingsView(onDone: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        showSettings = false
                    }
                    onHeightChange()
                })
            } else {
                InputBarView(
                    text: $inputText,
                    activeMode: $store.activeMode,
                    isStreaming: store.isStreaming,
                    onSubmit: sendMessage,
                    onDismiss: onDismiss,
                    onClear: clearConversation,
                    onHistoryNavigate: navigateHistory,
                    onClipboard: { specialResult = .clipboard; onHeightChange() }
                )

                Rectangle().fill(Color.primary.opacity(0.07)).frame(height: 0.5)

                if !commandSuggestions.isEmpty {
                    commandSuggestionsView
                } else if let special = specialResult {
                    SpecialResultView(result: special)
                } else if let error = store.errorMessage {
                    errorView(error)
                } else if store.messages.isEmpty && !store.isStreaming {
                    emptyStateView
                } else {
                    ZStack(alignment: .topTrailing) {
                        ResponseView(text: displayText, isStreaming: store.isStreaming)
                        if !displayText.isEmpty && !store.isStreaming {
                            CopyButton(text: displayText).padding(10)
                        }
                    }
                }
            }

            FooterView(model: $store.selectedModel, persona: $store.selectedPersona, showSettings: $showSettings)
        }
        .background(Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.white.opacity(0.14), lineWidth: 0.6)
        )
        .onChange(of: commandSuggestions.count) { onHeightChange() }
        .onChange(of: store.isStreaming) { onHeightChange() }
        .onChange(of: store.currentResponse) { onHeightChange() }
        .onChange(of: store.errorMessage) { onHeightChange() }
        .onChange(of: store.messages.count) { onHeightChange() }
        .onChange(of: specialResult) { onHeightChange() }
        .onChange(of: showSettings) { onHeightChange() }
    }

    // MARK: - Subviews

    private var commandSuggestionsView: some View {
        VStack(spacing: 0) {
            ForEach(commandSuggestions) { mode in
                Button {
                    selectCommand(mode)
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.auraAccent.opacity(hoveredSuggestion == mode ? 0.18 : 0.10))
                                .frame(width: 28, height: 28)
                            Image(systemName: mode.icon)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.auraAccent)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(mode.trigger)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.primary)
                            Text(mode.hint)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(hoveredSuggestion == mode ? Color.primary.opacity(0.05) : Color.clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { hoveredSuggestion = $0 ? mode : nil }

                if mode != commandSuggestions.last {
                    Rectangle().fill(Color.primary.opacity(0.07)).frame(height: 0.5).padding(.horizontal, 16)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var emptyStateView: some View {
        HStack(spacing: 6) {
            Text("Type")
                .foregroundStyle(.tertiary)
            Text("/")
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            Text("for commands · ask anything · or")
                .foregroundStyle(.tertiary)
            Button {
                specialResult = .clipboard
                onHeightChange()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "doc.on.clipboard").font(.system(size: 10))
                    Text("clipboard")
                }
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.08))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .font(.system(size: 12))
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
    }

    private func errorView(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(Color.auraAccent)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(Color.auraAccent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.auraAccent.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // 1. Calculator (sync)
        if let calc = CalculatorHandler.evaluate(text) {
            inputText = ""
            specialResult = .calculation(calc)
            onHeightChange()
            return
        }

        // 2. Currency (async)
        if CurrencyHandler.looksLike(text) {
            inputText = ""
            specialResult = .currencyLoading
            onHeightChange()
            Task {
                do {
                    let result = try await CurrencyHandler.shared.convert(text)
                    specialResult = .currency(result)
                } catch CurrencyError.unsupportedCurrency(let code) {
                    specialResult = .currencyError("Moeda não suportada: \(code)")
                } catch {
                    // Network failure → fall through to AI
                    specialResult = nil
                    await store.sendMessage(text)
                }
                onHeightChange()
            }
            return
        }

        // 3. AI
        specialResult = nil
        inputText = ""
        Task { await store.sendMessage(text) }
    }

    private func clearConversation() {
        store.clear()
        inputText = ""
        specialResult = nil
        onHeightChange()
    }

    private func navigateHistory(up: Bool) {
        if let text = store.navigateHistory(up: up) { inputText = text }
    }

    private func selectCommand(_ mode: CommandMode) {
        store.activeMode = mode
        inputText = ""
        hoveredSuggestion = nil
    }
}

// MARK: - Copy Button

private struct CopyButton: View {
    let text: String
    @State private var copied = false

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { copied = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { copied = false }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 10, weight: .medium))
                Text(copied ? "Copied" : "Copy").font(.system(size: 11))
            }
            .foregroundStyle(copied ? Color(hex: 0x5CB85C) : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(0.07))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.primary.opacity(0.09), lineWidth: 0.6))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Footer

struct FooterView: View {
    @Binding var model: String
    @Binding var persona: ConversationStore.Persona
    @Binding var showSettings: Bool

    var body: some View {
        Rectangle().fill(Color.primary.opacity(0.07)).frame(height: 0.5)

        HStack(spacing: 12) {
            if showSettings {
                Text("ESC or ✕ to close")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            } else {
                shortcutLabel("↵", "send")
                shortcutLabel("esc", "close")
                shortcutLabel("⌘K", "clear")
                shortcutLabel("⌘⇧V", "clipboard")
            }
            Spacer()
            if !showSettings {
                PersonaToggle(selected: $persona)
                ModelPicker(selected: $model)
            }
            settingsButton
        }
        .padding(.horizontal, 18)
        .frame(height: 32)
        .background(Color.primary.opacity(0.03))
    }

    private var settingsButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                showSettings.toggle()
            }
        } label: {
            Image(systemName: showSettings ? "gearshape.fill" : "gearshape")
                .font(.system(size: 12))
                .foregroundStyle(showSettings ? Color.auraAccent : Color.secondary.opacity(0.6))
        }
        .buttonStyle(.plain)
    }

    private func shortcutLabel(_ key: String, _ label: String) -> some View {
        HStack(spacing: 3) {
            Text(key).fontWeight(.medium)
            Text(label)
        }
        .font(.system(size: 11))
        .foregroundStyle(.tertiary)
    }
}

private struct PersonaToggle: View {
    @Binding var selected: ConversationStore.Persona
    @State private var hovered: ConversationStore.Persona? = nil

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ConversationStore.Persona.allCases, id: \.self) { persona in
                personaButton(persona)
            }
        }
        .padding(2)
        .background(Color.primary.opacity(0.06))
        .clipShape(Capsule())
    }

    private func personaButton(_ persona: ConversationStore.Persona) -> some View {
        let isSelected = selected == persona
        let isHovered  = hovered == persona
        let bg: Color  = isSelected ? Color.auraAccent.opacity(0.12)
                       : isHovered  ? Color.primary.opacity(0.05)
                       : Color.clear
        return Button { selected = persona } label: {
            Text(persona.rawValue)
                .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.auraAccent : Color.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(bg)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 ? persona : nil }
    }
}

// MARK: - Model Picker

private struct ModelPicker: View {
    @Binding var selected: String

    var body: some View {
        Menu {
            ForEach(ConversationStore.availableModels, id: \.self) { model in
                Button {
                    selected = model
                } label: {
                    HStack {
                        Text(model)
                        if model == selected {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text(selected)
                    .font(.system(size: 10, weight: .medium))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 7, weight: .medium))
            }
            .foregroundStyle(.tertiary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: UInt, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    // Adapts between dark and light mode
    static let auraAccent = Color(NSColor(name: nil, dynamicProvider: { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark
            ? NSColor(red: 1.0,  green: 0.388, blue: 0.388, alpha: 1) // FF6363 - dark
            : NSColor(red: 0.75, green: 0.13,  blue: 0.13,  alpha: 1) // BF2020 - light
    }))
}
