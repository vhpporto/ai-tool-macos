import SwiftUI
import AppKit

// MARK: - Result type

enum SpecialResult: Equatable {
    case calculation(CalculatorResult)
    case currency(CurrencyResult)
    case currencyLoading
    case currencyError(String)
    case clipboard
}

// MARK: - Main view dispatcher

struct SpecialResultView: View {
    let result: SpecialResult

    var body: some View {
        switch result {
        case .calculation(let r):  calculatorCard(r)
        case .currency(let r):     currencyCard(r)
        case .currencyLoading:     loadingCard
        case .currencyError(let m): errorCard(m)
        case .clipboard:           ClipboardHistoryView()
        }
    }

    // MARK: - Calculator

    private func calculatorCard(_ r: CalculatorResult) -> some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(r.expression)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Text(r.formatted)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
            }
            Spacer()
            ResultCopyButton(text: r.formatted)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Currency

    private func currencyCard(_ r: CurrencyResult) -> some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(r.expression)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(r.formatted)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)

                    Text(r.toCurrency)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                Text("1 \(r.fromCurrency) = \(String(format: "%.4f", r.rate)) \(r.toCurrency) · via frankfurter.app")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }
            Spacer()
            ResultCopyButton(text: r.formatted)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Loading

    private var loadingCard: some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small).scaleEffect(0.85)
            Text("Fetching exchange rate…")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Error

    private func errorCard(_ msg: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 12))
            Text(msg).font(.system(size: 12))
        }
        .foregroundStyle(Color.auraAccent)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Clipboard history view

struct ClipboardHistoryView: View {

    @State private var monitor = ClipboardMonitor.shared
    @State private var hoveredID: UUID? = nil
    @State private var copiedID: UUID? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Clipboard History")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if !monitor.history.isEmpty {
                    Button("Clear") { monitor.clear() }
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            if monitor.history.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 22))
                        .foregroundStyle(.quaternary)
                    Text("Nothing copied yet")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(monitor.history) { item in
                            clipboardRow(item)
                            if item.id != monitor.history.last?.id {
                                Rectangle()
                                    .fill(Color.primary.opacity(0.07))
                                    .frame(height: 0.5)
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
            }

            Spacer().frame(height: 8)
        }
    }

    private func clipboardRow(_ item: ClipboardItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.preview)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(item.timeAgo)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if hoveredID == item.id || copiedID == item.id {
                Button {
                    monitor.copyItem(item)
                    copiedID = item.id
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copiedID = nil }
                } label: {
                    Text(copiedID == item.id ? "Copied!" : "Copy")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(copiedID == item.id ? Color(hex: 0x5CB85C) : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.07))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(hoveredID == item.id ? Color.primary.opacity(0.04) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hoveredID = $0 ? item.id : nil }
        .onTapGesture {
            monitor.copyItem(item)
            copiedID = item.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copiedID = nil }
        }
    }
}

// MARK: - Copy button

struct ResultCopyButton: View {
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
                Text(copied ? "Copied" : "Copy")
                    .font(.system(size: 11))
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
