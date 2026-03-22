import SwiftUI

struct ResponseView: View {

    let text: String
    let isStreaming: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 4) {
                    renderMarkdown(text + (isStreaming ? "▋" : ""))
                        .id("bottom")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: text) {
                withAnimation(.easeOut(duration: 0.1)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
        .frame(maxHeight: 546)
    }

    @ViewBuilder
    private func renderMarkdown(_ raw: String) -> some View {
        let blocks = parseBlocks(raw)
        ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
            switch block {
            case .heading(let text, let level):
                headingView(text, level: level)
            case .codeBlock(let code):
                codeBlockView(code)
            case .bulletList(let items):
                listView(items: items, numbered: false)
            case .numberedList(let items):
                listView(items: items, numbered: true)
            case .text(let line):
                inlineMarkdown(line)
            }
        }
    }

    @ViewBuilder
    private func headingView(_ text: String, level: Int) -> some View {
        let size: CGFloat = level == 1 ? 18 : level == 2 ? 16 : 14
        let weight: Font.Weight = level == 1 ? .bold : .semibold
        Text(text)
            .font(.system(size: size, weight: weight))
            .foregroundStyle(.primary)
            .textSelection(.enabled)
            .padding(.top, level == 1 ? 8 : 4)
            .padding(.bottom, 2)
    }

    @ViewBuilder
    private func codeBlockView(_ code: String) -> some View {
        ZStack(alignment: .topTrailing) {
            Text(code)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Color(hex: 0xCDD6F4))
                .textSelection(.enabled)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)

            CodeCopyButton(code: code)
                .padding(8)
        }
        .background(Color(hex: 0x1A1A1E))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.6)
        )
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func inlineMarkdown(_ line: String) -> some View {
        if line.trimmingCharacters(in: .whitespaces).isEmpty {
            Spacer().frame(height: 8)
        } else {
            Text(parseInline(line))
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.primary)
                .lineSpacing(7)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func listView(items: [(Int, String)], numbered: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(items, id: \.0) { index, item in
                HStack(alignment: .top, spacing: 8) {
                    Text(numbered ? "\(index + 1)." : "•")
                        .font(.system(size: 14, weight: numbered ? .medium : .bold))
                        .foregroundStyle(numbered ? .primary : Color.auraAccent)
                        .frame(minWidth: numbered ? 20 : 10, alignment: .leading)
                    Text(parseInline(item))
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.primary)
                        .lineSpacing(5)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private enum Block {
        case heading(String, level: Int)
        case text(String)
        case codeBlock(String)
        case bulletList([(Int, String)])
        case numberedList([(Int, String)])
    }

    private func parseBlocks(_ raw: String) -> [Block] {
        var blocks: [Block] = []
        var inCodeBlock = false
        var codeLines: [String] = []
        var bulletItems: [(Int, String)] = []
        var numberedItems: [(Int, String)] = []
        var textBuffer = ""

        func flushText() {
            guard !textBuffer.isEmpty else { return }
            for part in textBuffer.components(separatedBy: "\n") {
                blocks.append(.text(part))
            }
            textBuffer = ""
        }

        func flushLists() {
            if !bulletItems.isEmpty {
                blocks.append(.bulletList(bulletItems))
                bulletItems = []
            }
            if !numberedItems.isEmpty {
                blocks.append(.numberedList(numberedItems))
                numberedItems = []
            }
        }

        let numberedRegex = try? NSRegularExpression(pattern: #"^(\d+)\.\s(.+)"#)

        for line in raw.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                if inCodeBlock {
                    flushLists()
                    blocks.append(.codeBlock(codeLines.joined(separator: "\n")))
                    codeLines.removeAll()
                    inCodeBlock = false
                } else {
                    flushText()
                    flushLists()
                    inCodeBlock = true
                }
                continue
            }

            if inCodeBlock {
                codeLines.append(line)
                continue
            }

            if trimmed.hasPrefix("### ") {
                flushText(); flushLists()
                blocks.append(.heading(String(trimmed.dropFirst(4)), level: 3))
            } else if trimmed.hasPrefix("## ") {
                flushText(); flushLists()
                blocks.append(.heading(String(trimmed.dropFirst(3)), level: 2))
            } else if trimmed.hasPrefix("# ") {
                flushText(); flushLists()
                blocks.append(.heading(String(trimmed.dropFirst(2)), level: 1))
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                flushText()
                if !numberedItems.isEmpty { flushLists() }
                let content = String(trimmed.dropFirst(2))
                bulletItems.append((bulletItems.count, content))
            } else if let match = numberedRegex?.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
                      let contentRange = Range(match.range(at: 2), in: trimmed) {
                flushText()
                if !bulletItems.isEmpty { flushLists() }
                numberedItems.append((numberedItems.count, String(trimmed[contentRange])))
            } else {
                flushLists()
                if !textBuffer.isEmpty { textBuffer += "\n" }
                textBuffer += line
            }
        }

        if inCodeBlock && !codeLines.isEmpty {
            blocks.append(.codeBlock(codeLines.joined(separator: "\n")))
        }
        flushText()
        flushLists()

        return blocks
    }

    private func parseInline(_ text: String) -> AttributedString {
        var result = AttributedString()
        var remaining = text[...]

        while !remaining.isEmpty {
            if let boldRange = remaining.range(of: "\\*\\*(.+?)\\*\\*", options: .regularExpression) {
                let before = remaining[remaining.startIndex..<boldRange.lowerBound]
                if !before.isEmpty {
                    result += checkInlineCode(String(before))
                }
                var inner = String(remaining[boldRange])
                inner = String(inner.dropFirst(2).dropLast(2))
                var attr = AttributedString(inner)
                attr.font = .system(size: 14, weight: .bold)
                result += attr
                remaining = remaining[boldRange.upperBound...]
            } else {
                result += checkInlineCode(String(remaining))
                break
            }
        }

        return result
    }

    private func checkInlineCode(_ text: String) -> AttributedString {
        var result = AttributedString()
        var remaining = text[...]

        while !remaining.isEmpty {
            if let codeRange = remaining.range(of: "`([^`]+)`", options: .regularExpression) {
                let before = remaining[remaining.startIndex..<codeRange.lowerBound]
                if !before.isEmpty {
                    result += AttributedString(String(before))
                }
                var code = String(remaining[codeRange])
                code = String(code.dropFirst(1).dropLast(1))
                var attr = AttributedString(code)
                attr.font = .system(size: 13, design: .monospaced)
                attr.backgroundColor = Color(hex: 0x2E2E2E)
                result += attr
                remaining = remaining[codeRange.upperBound...]
            } else {
                result += AttributedString(String(remaining))
                break
            }
        }

        return result
    }
}

private struct CodeCopyButton: View {
    let code: String
    @State private var copied = false

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(code, forType: .string)
            withAnimation(.easeInOut(duration: 0.15)) { copied = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.15)) { copied = false }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 10, weight: .medium))
                Text(copied ? "Copied" : "Copy")
                    .font(.system(size: 11))
            }
            .foregroundStyle(copied ? Color(hex: 0x5CB85C) : Color(hex: 0x888888))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Color(hex: 0x2C2C30))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
