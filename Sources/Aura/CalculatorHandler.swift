import Foundation
import JavaScriptCore

struct CalculatorResult: Equatable {
    let expression: String
    let formatted: String
    let rawValue: Double
}

enum CalculatorHandler {

    private static let allowedChars = CharacterSet(charactersIn: "0123456789+-*/.()%, \t")
    private static let maxInputLength = 200

    private static let percentOf = try! NSRegularExpression(
        pattern: #"(\d+(?:\.\d+)?)\s*%\s*of\s*(\d+(?:\.\d+)?)"#,
        options: .caseInsensitive
    )

    private static let plainPercent = try! NSRegularExpression(
        pattern: #"(\d+(?:\.\d+)?)\s*%"#
    )

    static func evaluate(_ input: String) -> CalculatorResult? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= maxInputLength else { return nil }

        // Must have at least one operator, paren, or percent (not just a bare number)
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

        // Reject if any remaining character is not a math character
        guard expr.unicodeScalars.allSatisfy({ allowedChars.contains($0) }) else { return nil }

        guard let value = jsEvaluate(expr), value.isFinite else { return nil }

        return CalculatorResult(
            expression: trimmed,
            formatted: format(value),
            rawValue: value
        )
    }

    private static func jsEvaluate(_ expr: String) -> Double? {
        guard let ctx = JSContext() else { return nil }
        // Disable access to anything beyond pure math evaluation
        ctx.exceptionHandler = { _, _ in }
        guard let result = ctx.evaluateScript(expr) else { return nil }
        guard result.isNumber, !result.isUndefined, !result.isNull else { return nil }
        return result.toDouble()
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
