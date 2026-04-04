import Testing
@testable import Aura

@Suite("CalculatorHandler")
struct CalculatorHandlerTests {

    // MARK: - Basic arithmetic

    @Test func simpleAddition() {
        let result = CalculatorHandler.evaluate("2+2")
        #expect(result != nil)
        #expect(result?.rawValue == 4)
    }

    @Test func subtraction() {
        let result = CalculatorHandler.evaluate("10-3")
        #expect(result?.rawValue == 7)
    }

    @Test func multiplication() {
        let result = CalculatorHandler.evaluate("6*7")
        #expect(result?.rawValue == 42)
    }

    @Test func division() {
        let result = CalculatorHandler.evaluate("100/4")
        #expect(result?.rawValue == 25)
    }

    @Test func complexExpression() {
        let result = CalculatorHandler.evaluate("(10+5)*2")
        #expect(result?.rawValue == 30)
    }

    @Test func decimalArithmetic() {
        let result = CalculatorHandler.evaluate("3.5+1.5")
        #expect(result?.rawValue == 5)
    }

    // MARK: - Percentage

    @Test func percentOf() {
        let result = CalculatorHandler.evaluate("20% of 100")
        #expect(result != nil)
        #expect(result?.rawValue == 20)
    }

    @Test func percentOfDecimal() {
        let result = CalculatorHandler.evaluate("15.5% of 200")
        #expect(result?.rawValue == 31)
    }

    @Test func plainPercent() {
        let result = CalculatorHandler.evaluate("50%+0.25")
        #expect(result?.rawValue == 0.75)
    }

    @Test func percentInExpression() {
        let result = CalculatorHandler.evaluate("10%")
        #expect(result?.rawValue == 0.1)
    }

    // MARK: - Formatting

    @Test func integerFormatting() {
        let result = CalculatorHandler.evaluate("1000+2000")
        #expect(result?.formatted == "3,000")
    }

    @Test func decimalFormatting() {
        let result = CalculatorHandler.evaluate("10/3")
        #expect(result != nil)
        // Result should have fractional digits (locale-dependent separator)
        #expect(result!.rawValue > 3.33)
        #expect(result!.rawValue < 3.34)
    }

    // MARK: - Edge cases / rejection

    @Test func bareNumberReturnsNil() {
        #expect(CalculatorHandler.evaluate("42") == nil)
    }

    @Test func emptyStringReturnsNil() {
        #expect(CalculatorHandler.evaluate("") == nil)
    }

    @Test func textInputReturnsNil() {
        #expect(CalculatorHandler.evaluate("hello world") == nil)
    }

    @Test func divisionByZeroReturnsNil() {
        #expect(CalculatorHandler.evaluate("1/0") == nil)
    }

    @Test func whitespaceTrimmed() {
        let result = CalculatorHandler.evaluate("  2 + 3  ")
        #expect(result?.rawValue == 5)
    }

    @Test func preservesOriginalExpression() {
        let result = CalculatorHandler.evaluate("20% of 50")
        #expect(result?.expression == "20% of 50")
    }

    @Test func textWithOperatorsReturnsNil() {
        #expect(CalculatorHandler.evaluate("buy 2+2 apples") == nil)
    }
}
