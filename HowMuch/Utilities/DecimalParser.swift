import Foundation

enum DecimalParser {
    static func parseCurrencyInput(_ rawValue: String, locale: Locale = .current) throws -> Decimal {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            throw CatalogError.missingPriceInput
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        formatter.generatesDecimalNumbers = true

        if let number = formatter.number(from: trimmed) as? NSDecimalNumber {
            return number.decimalValue
        }

        let cleaned = trimmed
            .replacingOccurrences(of: locale.currencySymbol ?? "", with: "")
            .replacingOccurrences(of: locale.groupingSeparator ?? ",", with: "")
            .replacingOccurrences(of: " ", with: "")

        let normalizedDecimal = cleaned.replacingOccurrences(of: locale.decimalSeparator ?? ".", with: ".")
        if let decimal = Decimal(string: normalizedDecimal, locale: Locale(identifier: "en_US_POSIX")) {
            return decimal
        }

        throw CatalogError.invalidPriceInput(rawValue)
    }
}
