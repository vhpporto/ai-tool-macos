import SwiftUI
import AppKit

@MainActor
struct ContentView: View {

    @Bindable var store: ConversationStore
    var onDismiss: () -> Void
    var onHeightChange: () -> Void = {}

    @State private var inputText = ""
    @State private var hoveredSuggestion: CommandMode? = nil
    @State private var selectedSuggestionIndex: Int? = nil
    @State private var specialResult: SpecialResult? = nil
    @State private var showSettings = false

    private var hasAPIKey: Bool {
        KeychainHelper.read(key: "openai_api_key") != nil
            || !(UserDefaults.standard.string(forKey: "aura_custom_endpoint") ?? "").isEmpty
    }

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
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                InputBarView(
                    text: $inputText,
                    activeMode: $store.activeMode,
                    isStreaming: store.isStreaming,
                    onSubmit: handleSubmitOrSelect,
                    onDismiss: onDismiss,
                    onClear: clearConversation,
                    onArrow: handleArrowKey,
                    onClipboard: { specialResult = .clipboard; onHeightChange() },
                    onStop: { store.clear(); onHeightChange() }
                )

                Divider()

                Group {
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
                                AuraCopyButton(text: displayText).padding(10)
                            }
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.15), value: store.errorMessage == nil)
            }

            FooterView(model: $store.selectedModel, persona: $store.selectedPersona, showSettings: $showSettings)
        }
        .background(Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.panelBorder, lineWidth: 0.6)
        )
        .onChange(of: commandSuggestions.count) {
            selectedSuggestionIndex = nil
            scheduleHeightUpdate()
        }
        .onChange(of: store.isStreaming) { scheduleHeightUpdate() }
        .onChange(of: store.currentResponse) { scheduleHeightUpdate() }
        .onChange(of: store.errorMessage) { scheduleHeightUpdate() }
        .onChange(of: store.messages.count) { scheduleHeightUpdate() }
        .onChange(of: specialResult) { scheduleHeightUpdate() }
        .onChange(of: showSettings) { scheduleHeightUpdate() }
    }

    // MARK: - Subviews

    private var commandSuggestionsView: some View {
        VStack(spacing: 0) {
            ForEach(Array(commandSuggestions.enumerated()), id: \.element.id) { index, mode in
                let isHighlighted = selectedSuggestionIndex == index || hoveredSuggestion == mode
                Button {
                    selectCommand(mode)
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.auraAccent.opacity(isHighlighted ? 0.18 : 0.10))
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

                        if isHighlighted {
                            Text("↵")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.tertiary)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(isHighlighted ? Color.primary.opacity(0.05) : Color.clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { isHovering in
                    hoveredSuggestion = isHovering ? mode : nil
                    if isHovering { selectedSuggestionIndex = nil }
                }

                if mode != commandSuggestions.last {
                    Divider().padding(.horizontal, 16)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var emptyStateView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !hasAPIKey {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        showSettings = true
                    }
                    onHeightChange()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 12))
                        Text("Set up your API key to get started")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(Color.auraAccent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.auraAccent.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Configure API key")
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }

            HStack(spacing: 6) {
                Text("Ask anything or type")
                    .foregroundStyle(.tertiary)
                Text("/")
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Text("for commands")
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .font(.system(size: 13))
            .padding(.horizontal, 16)
            .padding(.top, hasAPIKey ? 16 : 0)
            .padding(.bottom, 16)
        }
    }

    private func errorView(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(Color.auraError)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(Color.auraError)
            Spacer()
            Button {
                store.errorMessage = nil
                onHeightChange()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.auraError.opacity(0.6))
                    .padding(4)
                    .background(Color.auraError.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss error")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.auraError.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Actions

    private func handleSubmitOrSelect() {
        // If a suggestion is keyboard-selected, pick it
        if let index = selectedSuggestionIndex, !commandSuggestions.isEmpty,
           index < commandSuggestions.count {
            selectCommand(commandSuggestions[index])
            return
        }
        sendMessage()
    }

    private func handleArrowKey(up: Bool) {
        // Arrow keys navigate suggestions when visible
        if !commandSuggestions.isEmpty {
            let count = commandSuggestions.count
            if up {
                selectedSuggestionIndex = selectedSuggestionIndex.map { max(0, $0 - 1) } ?? (count - 1)
            } else {
                if let idx = selectedSuggestionIndex {
                    selectedSuggestionIndex = idx < count - 1 ? idx + 1 : nil
                }
            }
            hoveredSuggestion = nil
            return
        }

        // Otherwise navigate input history (only when text is empty)
        if inputText.isEmpty {
            if let text = store.navigateHistory(up: up) { inputText = text }
        }
    }

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
                    specialResult = .currencyError("Unsupported currency: \(code)")
                } catch {
                    // Network failure → fall through to AI
                    specialResult = nil
                    store.sendMessage(text)
                }
                onHeightChange()
            }
            return
        }

        // 3. AI
        specialResult = nil
        inputText = ""
        store.sendMessage(text)
    }

    private func clearConversation() {
        store.clear()
        inputText = ""
        specialResult = nil
        selectedSuggestionIndex = nil
        onHeightChange()
    }

    /// Delays height recalculation to the next run-loop tick so that
    /// SwiftUI has finished its layout pass and fittingSize is accurate.
    private func scheduleHeightUpdate() {
        DispatchQueue.main.async { onHeightChange() }
    }

    private func selectCommand(_ mode: CommandMode) {
        store.activeMode = mode
        inputText = ""
        hoveredSuggestion = nil
        selectedSuggestionIndex = nil
    }
}

// MARK: - Footer

struct FooterView: View {
    @Binding var model: String
    @Binding var persona: ConversationStore.Persona
    @Binding var showSettings: Bool
    @State private var settingsHovered = false

    var body: some View {
        Divider()

        HStack(spacing: 12) {
            if showSettings {
                Text("ESC to close")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if !showSettings {
                PersonaToggle(selected: $persona)
                ModelPicker(selected: $model)
            }
            settingsButton
        }
        .padding(.horizontal, 16)
        .frame(height: 36)
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
                .foregroundStyle(showSettings ? Color.auraAccent : Color.secondary.opacity(settingsHovered ? 1 : 0.6))
        }
        .buttonStyle(.plain)
        .onHover { settingsHovered = $0 }
        .accessibilityLabel(showSettings ? "Close settings" : "Open settings")
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
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.auraAccent : Color.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(bg)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 ? persona : nil }
        .accessibilityLabel("\(persona.rawValue) mode")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
                    .font(.system(size: 11, weight: .medium))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .medium))
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

    // Primary accent — used for interactive elements, branding
    static let auraAccent = Color(NSColor(name: nil, dynamicProvider: { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark
            ? NSColor(red: 1.0,  green: 0.388, blue: 0.388, alpha: 1) // FF6363 - dark
            : NSColor(red: 0.75, green: 0.13,  blue: 0.13,  alpha: 1) // BF2020 - light
    }))

    // Semantic error color — distinct from accent to avoid confusion
    static let auraError = Color(NSColor(name: nil, dynamicProvider: { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark
            ? NSColor(red: 1.0,  green: 0.45, blue: 0.35, alpha: 1) // FF7359
            : NSColor(red: 0.80, green: 0.20, blue: 0.15, alpha: 1) // CC3326
    }))

    // Semantic success color
    static let auraSuccess = Color(hex: 0x5CB85C)

    static let codeBackground = Color(NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1) // 1A1A1E
            : NSColor(red: 0.95, green: 0.95, blue: 0.96, alpha: 1) // F2F2F5
    }))

    static let codeText = Color(NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.80, green: 0.84, blue: 0.96, alpha: 1) // CDD6F4
            : NSColor(red: 0.15, green: 0.15, blue: 0.20, alpha: 1) // 262633
    }))

    static let inlineCodeBackground = Color(NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.18, green: 0.18, blue: 0.18, alpha: 1) // 2E2E2E
            : NSColor(red: 0.90, green: 0.90, blue: 0.92, alpha: 1) // E6E6EA
    }))

    static let panelBorder = Color(NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(white: 1.0, alpha: 0.14)
            : NSColor(white: 0.0, alpha: 0.10)
    }))
}

// MARK: - Unified Copy Button

struct AuraCopyButton: View {
    let text: String
    var showLabel: Bool = true
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
                if showLabel {
                    Text(copied ? "Copied" : "Copy")
                        .font(.system(size: 11))
                }
            }
            .foregroundStyle(copied ? Color.auraSuccess : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(0.07))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.primary.opacity(0.09), lineWidth: 0.6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(copied ? "Copied to clipboard" : "Copy to clipboard")
    }
}
