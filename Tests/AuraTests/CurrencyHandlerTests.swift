import Testing
@testable import Aura

@Suite("CurrencyHandler")
struct CurrencyHandlerTests {

    // MARK: - looksLike pattern matching

    @Test func matchesUSDtoBRL() {
        #expect(CurrencyHandler.looksLike("100 USD to BRL"))
    }

    @Test func matchesLowercase() {
        #expect(CurrencyHandler.looksLike("50 usd to eur"))
    }

    @Test func matchesDecimalAmount() {
        #expect(CurrencyHandler.looksLike("99.50 EUR to GBP"))
    }

    @Test func matchesCommaAmount() {
        #expect(CurrencyHandler.looksLike("1,000 BRL to USD"))
    }

    @Test func matchesPortuguesePrepositions() {
        #expect(CurrencyHandler.looksLike("100 USD em BRL"))
        #expect(CurrencyHandler.looksLike("100 USD para BRL"))
    }

    @Test func matchesInPreposition() {
        #expect(CurrencyHandler.looksLike("200 GBP in EUR"))
    }

    @Test func rejectsPlainText() {
        #expect(!CurrencyHandler.looksLike("hello world"))
    }

    @Test func rejectsPartialCurrency() {
        #expect(!CurrencyHandler.looksLike("100 US to BRL"))
    }

    @Test func rejectsMissingAmount() {
        #expect(!CurrencyHandler.looksLike("USD to BRL"))
    }

    @Test func rejectsEmptyString() {
        #expect(!CurrencyHandler.looksLike(""))
    }

    @Test func rejectsMathExpression() {
        #expect(!CurrencyHandler.looksLike("2+2"))
    }
}
