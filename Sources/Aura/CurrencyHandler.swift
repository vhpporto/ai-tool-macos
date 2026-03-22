import Foundation

struct CurrencyResult: Equatable {
    let expression: String
    let formatted: String
    let fromAmount: Double
    let fromCurrency: String
    let toCurrency: String
    let rate: Double
}

enum CurrencyError: Error {
    case noMatch, networkError(Error), invalidResponse, unsupportedCurrency(String)
    static func == (lhs: CurrencyError, rhs: CurrencyError) -> Bool { false }
}

actor CurrencyHandler {

    static let shared = CurrencyHandler()
    private init() {}

    private var cache: [String: Double] = [:]

    // Exposed for synchronous pre-check in ContentView
    private static let pattern = try! NSRegularExpression(
        pattern: #"^([\d,]+(?:\.\d+)?)\s+([A-Za-z]{3})\s+(?:to|in|em|para)\s+([A-Za-z]{3})\s*$"#,
        options: .caseInsensitive
    )

    nonisolated static func looksLike(_ input: String) -> Bool {
        let t = input.trimmingCharacters(in: .whitespacesAndNewlines)
        return pattern.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)) != nil
    }

    func convert(_ input: String) async throws -> CurrencyResult {
        let t = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let ns = NSRange(t.startIndex..., in: t)

        guard let match = Self.pattern.firstMatch(in: t, range: ns) else {
            throw CurrencyError.noMatch
        }

        func group(_ i: Int) -> String {
            guard let r = Range(match.range(at: i), in: t) else { return "" }
            return String(t[r])
        }

        let amountStr = group(1).replacingOccurrences(of: ",", with: "")
        guard let amount = Double(amountStr) else { throw CurrencyError.noMatch }

        let from = group(2).uppercased()
        let to   = group(3).uppercased()
        let rate = try await fetchRate(from: from, to: to)
        let converted = amount * rate

        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.groupingSeparator = ","

        return CurrencyResult(
            expression: t,
            formatted: f.string(from: NSNumber(value: converted)) ?? String(format: "%.2f", converted),
            fromAmount: amount,
            fromCurrency: from,
            toCurrency: to,
            rate: rate
        )
    }

    private func fetchRate(from: String, to: String) async throws -> Double {
        let key = "\(from)_\(to)"
        if let cached = cache[key] { return cached }

        var comps = URLComponents(string: "https://api.frankfurter.app/latest")!
        comps.queryItems = [
            URLQueryItem(name: "from", value: from),
            URLQueryItem(name: "to",   value: to)
        ]
        guard let url = comps.url else { throw CurrencyError.invalidResponse }

        let data: Data
        let response: URLResponse
        do { (data, response) = try await URLSession.shared.data(from: url) }
        catch { throw CurrencyError.networkError(error) }

        if let http = response as? HTTPURLResponse, http.statusCode == 404 {
            throw CurrencyError.unsupportedCurrency("\(from) ou \(to)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rates = json["rates"] as? [String: Double],
              let rate  = rates[to] else { throw CurrencyError.invalidResponse }

        cache[key] = rate
        return rate
    }
}
