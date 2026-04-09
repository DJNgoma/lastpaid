import Foundation

enum BarcodeNormalizer {
    static func normalize(_ rawValue: String, symbology: BarcodeType? = nil) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let symbology else {
            return trimmed
        }

        if symbology.isNumericRetailCode {
            return trimmed.replacingOccurrences(
                of: #"\s+"#,
                with: "",
                options: .regularExpression
            )
        }

        return trimmed
    }

    static func validated(_ rawValue: String, symbology: BarcodeType? = nil) throws -> String {
        let normalized = normalize(rawValue, symbology: symbology)
        guard normalized.isEmpty == false else {
            throw CatalogError.invalidBarcode
        }

        guard isValid(normalized, for: symbology) else {
            throw CatalogError.invalidBarcode
        }

        return normalized
    }

    private static func isValid(_ value: String, for symbology: BarcodeType?) -> Bool {
        switch symbology {
        case .ean13:
            return value.count == 13
                && value.allSatisfy(\.isNumber)
                && hasGTINCheckDigit(value)
        case .ean8:
            return value.count == 8
                && value.allSatisfy(\.isNumber)
                && hasGTINCheckDigit(value)
        case .upca:
            return value.count == 12
                && value.allSatisfy(\.isNumber)
                && hasGTINCheckDigit(value)
        case .upce:
            return isValidUPCE(value)
        case .code128, .code39, .qr, .unknown, nil:
            return true
        }
    }

    private static func hasGTINCheckDigit(_ value: String) -> Bool {
        let digits = value.compactMap(\.wholeNumberValue)
        guard digits.count == value.count, digits.count > 1 else {
            return false
        }

        let checkDigit = digits.last ?? 0
        let sum = digits
            .dropLast()
            .reversed()
            .enumerated()
            .reduce(into: 0) { partialResult, pair in
                let weight = pair.offset.isMultiple(of: 2) ? 3 : 1
                partialResult += pair.element * weight
            }

        let expectedCheckDigit = (10 - (sum % 10)) % 10
        return checkDigit == expectedCheckDigit
    }

    private static func isValidUPCE(_ value: String) -> Bool {
        guard value.allSatisfy(\.isNumber) else {
            return false
        }

        switch value.count {
        case 6:
            return true
        case 7:
            let payload = String(value.prefix(6))
            let checkDigit = String(value.suffix(1))
            guard let expandedPayload = expandUPCEPayload(payload, numberSystem: 0) else {
                return false
            }
            return hasGTINCheckDigit(expandedPayload + checkDigit)
        case 8:
            guard let numberSystem = value.first?.wholeNumberValue else {
                return false
            }

            let payloadStartIndex = value.index(after: value.startIndex)
            let payloadEndIndex = value.index(before: value.endIndex)
            let payload = String(value[payloadStartIndex..<payloadEndIndex])
            let checkDigit = String(value.suffix(1))

            guard let expandedPayload = expandUPCEPayload(payload, numberSystem: numberSystem) else {
                return false
            }
            return hasGTINCheckDigit(expandedPayload + checkDigit)
        default:
            return false
        }
    }

    private static func expandUPCEPayload(_ payload: String, numberSystem: Int) -> String? {
        guard payload.count == 6,
              payload.allSatisfy(\.isNumber),
              (0...1).contains(numberSystem) else {
            return nil
        }

        let digits = payload.map(String.init)
        switch digits[5] {
        case "0", "1", "2":
            return "\(numberSystem)\(digits[0])\(digits[1])\(digits[5])0000\(digits[2])\(digits[3])\(digits[4])"
        case "3":
            return "\(numberSystem)\(digits[0])\(digits[1])\(digits[2])00000\(digits[3])\(digits[4])"
        case "4":
            return "\(numberSystem)\(digits[0])\(digits[1])\(digits[2])\(digits[3])00000\(digits[4])"
        default:
            return "\(numberSystem)\(digits[0])\(digits[1])\(digits[2])\(digits[3])\(digits[4])0000\(digits[5])"
        }
    }
}
