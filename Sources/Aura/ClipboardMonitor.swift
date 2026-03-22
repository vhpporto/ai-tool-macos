import AppKit

struct ClipboardItem: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let date: Date

    var timeAgo: String {
        let diff = Date().timeIntervalSince(date)
        if diff < 60 { return "just now" }
        if diff < 3600 { return "\(Int(diff/60))m ago" }
        if diff < 86400 { return "\(Int(diff/3600))h ago" }
        return "\(Int(diff/86400))d ago"
    }

    var preview: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let single = trimmed.replacingOccurrences(of: "\n", with: " ")
        return single.count > 120 ? String(single.prefix(120)) + "…" : single
    }
}

@Observable
final class ClipboardMonitor {

    static let shared = ClipboardMonitor()
    private init() {}

    var history: [ClipboardItem] = []
    private var timer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount

    func start() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func copyItem(_ item: ClipboardItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.text, forType: .string)
        lastChangeCount = NSPasteboard.general.changeCount
    }

    func remove(_ item: ClipboardItem) {
        history.removeAll { $0.id == item.id }
    }

    func clear() {
        history.removeAll()
    }

    private func poll() {
        let current = NSPasteboard.general.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current

        guard let text = NSPasteboard.general.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        if history.first?.text == text { return }

        history.insert(ClipboardItem(text: text, date: Date()), at: 0)
        if history.count > 50 { history = Array(history.prefix(50)) }
    }
}
