import SwiftUI

struct InputBarView: View {

    @Binding var text: String
    @Binding var activeMode: CommandMode?
    var isStreaming: Bool
    var onSubmit: () -> Void
    var onDismiss: () -> Void
    var onClear: () -> Void
    var onHistoryNavigate: (Bool) -> Void
    var onClipboard: () -> Void = {}

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.auraAccent)

            if let mode = activeMode {
                ModeBadge(mode: mode) { activeMode = nil }
            }

            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(activeMode.map { "Type to \($0.rawValue)..." } ?? "Ask anything dev...")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(.tertiary)
                        .allowsHitTesting(false)
                }
                TextField("", text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(.primary)
                    .focused($isFocused)
                    .onSubmit(onSubmit)
                    .onKeyPress(.escape) {
                        onDismiss()
                        return .handled
                    }
                    .onKeyPress(keys: [.init("k")], phases: .down) { press in
                        if press.modifiers.contains(.command) { onClear(); return .handled }
                        return .ignored
                    }
                    .onKeyPress(.upArrow) {
                        if text.isEmpty { onHistoryNavigate(true); return .handled }
                        return .ignored
                    }
                    .onKeyPress(.downArrow) {
                        if text.isEmpty { onHistoryNavigate(false); return .handled }
                        return .ignored
                    }
                    .onKeyPress(keys: [.init("v")], phases: .down) { press in
                        if press.modifiers.contains(.command) && press.modifiers.contains(.shift) {
                            onClipboard(); return .handled
                        }
                        return .ignored
                    }
            }

            if isStreaming {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.8)
            } else if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 62)
        .onAppear { isFocused = true }
    }
}

private struct ModeBadge: View {
    let mode: CommandMode
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: mode.icon)
                .font(.system(size: 10, weight: .medium))
            Text(mode.label)
                .font(.system(size: 12, weight: .semibold))
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .padding(2)
                    .background(Color.auraAccent.opacity(0.2))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 5)
        .background(Color.auraAccent.opacity(0.12))
        .foregroundStyle(Color.auraAccent)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.auraAccent.opacity(0.2), lineWidth: 0.5))
    }
}
