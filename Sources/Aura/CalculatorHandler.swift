import Foundation

struct CalculatorResult: Equatable {
    let expression: String
    let formatted: String
    let rawValue: Double
}

enum CalculatorHandler {

    private static let allowedChars = CharacterSet(charactersIn: "0123456789+-*/.()%, \t")

    private static let percentOf = try! NSRegularExpression(
        pattern: #"(\d+(?:\.\d+)?)\s*%\s*of\s*(\d+(?:\.\d+)?)"#,
        options: .caseInsensitive
    )

    private static let plainPercent = try! NSRegularExpression(
        pattern: #"(\d+(?:\.\d+)?)\s*%"#
    )

    static func evaluate(_ input: String) -> CalculatorResult? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Reject if any character is not a math character
        guard trimmed.unicodeScalars.allSatisfy({ allowedChars.contains($0) }) else { return nil }

        // Must have at least one operator or paren (not just a bare number)
        guard trimmed.contains(where: { "+-*/%()".contains($0) }) else { return nil }

        var expr = trimmed

        // "X% of Y" → "(X/100)*Y"
        let nsExpr = expr as NSString
        let fullRange = NSRange(location: 0, length: nsExpr.length)
        expr = percentOf.stringByReplacingMatches(in: expr, range: fullRange, withTemplate: "($1/100)*$2")

        // Remaining "X%" → "(X/100)"
        expr = plainPercent.stringByReplacingMatches(
            in: expr,
            range: NSRange(expr.startIndex..., in: expr),
            withTemplate: "($1/100)"
        )

        // Remove thousand separators
        expr = expr.replacingOccurrences(of: ",", with: "")

        guard let value = nsEvaluate(expr), value.isFinite else { return nil }

        return CalculatorResult(
            expression: trimmed,
            formatted: format(value),
            rawValue: value
        )
    }

    private static func nsEvaluate(_ expr: String) -> Double? {
        let e = NSExpression(format: expr)
        return (e.expressionValue(with: nil, context: nil) as? NSNumber)?.doubleValue
    }

    private static func format(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        if value.truncatingRemainder(dividingBy: 1) == 0, abs(value) < 1e15 {
            formatter.maximumFractionDigits = 0
        } else {
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 10
        }
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
