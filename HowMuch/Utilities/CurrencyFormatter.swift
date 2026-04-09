import Foundation

enum CurrencyFormatter {
    static func string(
        from amount: Decimal,
        currencyCode: String,
        locale: Locale = Locale(identifier: "en_ZA"),
        alwaysShowSign: Bool = false
    ) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = locale
        formatter.generatesDecimalNumbers = true
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        if alwaysShowSign {
            let positivePrefix = formatter.positivePrefix ?? ""
            formatter.positivePrefix = positivePrefix.hasPrefix("+") ? positivePrefix : "+\(positivePrefix)"
        }

        return formatter.string(from: amount as NSDecimalNumber)
            ?? "\(currencyCode) \(amount)"
    }
}
