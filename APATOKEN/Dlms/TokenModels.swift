import Foundation

// MARK: - Token structure enums

/// TokenStatusCode (CosemAPI.Enums.TokenStatusCode).
enum TokenStatusCode: UInt8 {
    case tokenFormatResultOk = 0
    case authenticationResultOk = 1
    case validationResultOk = 2
    case tokenExecutionResultOk = 3
    case tokenFormatFailure = 4
    case authenticationFailure = 5
    case validationResultFailure = 6
    case tokenExecutionResultFailure = 7
    case tokenReceivedAndNotYetProcessed = 8
}

/// TokenCodeStatus (CosemAPI.Structures.TokenCodeStatus).
enum TokenCodeStatus: UInt8 {
    case none = 0
    case ok = 1
    case notOk = 2
    case okTooOld = 3
    case okUsed = 4
    case okAboveLimit = 5
    case blocked = 6
    case error = 7
    case prepaidOff = 8
}

/// TokenCodeType (CosemAPI.Structures.TokenCodeType).
enum TokenCodeType: UInt8, CustomStringConvertible {
    case none = 0
    case oneRate = 16
    case bothRates = 32
    case resetCredit = 48
    case unlockCommunication = 64
    case validationResultFailure = 80

    var description: String {
        switch self {
        case .none: return "NONE"
        case .oneRate: return "ONE_RATE"
        case .bothRates: return "BOTH_RATES"
        case .resetCredit: return "RESET_CREDIT"
        case .unlockCommunication: return "UNLOCK_COMMUNICATION"
        case .validationResultFailure: return "VALIDATION_RESULT_FAILURE"
        }
    }
}

// MARK: - TokenDeliveryStatus

/// TokenDeliveryStatus: parsed from IC115 attribute 6 (structure of
/// ENUM + BIT-STRING). Parsing mirrors the C# StructureAttribute +
/// ctor(string[]) chain with the same strict checks.
final class TokenDeliveryStatus {
    private(set) var statusCodeValue: UInt8 = 0
    private(set) var dataValue: [UInt8] = []

    var statusCode: TokenStatusCode {
        TokenStatusCode(rawValue: statusCodeValue) ?? .tokenReceivedAndNotYetProcessed
    }

    init(statusCodeValue: UInt8, dataValue: [UInt8]) {
        self.statusCodeValue = statusCodeValue
        self.dataValue = dataValue
    }

    /// Parses attribute-6 DLMS value: [STRUCTURE-tag][length][ENUM member][BIT_STRING member].
    /// Throws the same composed messages as the C# attribute setter chain.
    convenience init(responseData: ByteBuffer) throws {
        let bytes = responseData.toByteArray()
        if bytes.isEmpty || bytes[0] == 0 {
            // StructureAttribute null path: C# then null-refs on
            // tokenDeliveryStatus.StatusCode.
            throw CommsError("Object reference not set to an instance of an object.")
        }
        let tag = bytes[0]
        let source = ByteBuffer(bytes)
        _ = try source.parseUInt8() // tag byte
        guard tag == 2 else {
            // STRUCTURE expected; print enum-style names
            throw CommsError("\(L.message.msgWrongDataType) \(L.fmt(L.message.msgExpectedVsReceived, "STRUCTURE", cosemTypeName(tag)))")
        }
        let memberCount = try ByteBuffer.cosemComplexTypeSize(bytes, index: &source.bytesOffset)
        if memberCount != 2 {
            throw CommsError("\(L.message.msgWrongNumberOfStructureFields) \(L.fmt(L.message.msgExpectedVsReceived, "2", "\(memberCount)"))")
        }
        // member 1: TokenStatusCode ENUM (1 byte)
        let member1Tag = try source.parseUInt8()
        guard member1Tag == CosemDataType.enumData.rawValue else {
            throw CommsError("\(L.message.msgWrongDataType) \(L.fmt(L.message.msgExpectedVsReceived, CosemDataType.enumData.name, cosemTypeName(member1Tag)))")
        }
        guard try ByteBuffer.cosemComplexTypeSize(bytes, index: &source.bytesOffset) == 1 else {
            throw CommsError(L.message.msgSimpleDataTypeExpected)
        }
        let statusValue = try source.parseUInt8()
        // member 2: BIT_STRING (tag 4) – length prefix is in BITS.
        let member2Tag = try source.parseUInt8()
        guard member2Tag == CosemDataType.bitString.rawValue else {
            throw CommsError("\(L.message.msgWrongDataType) \(L.fmt(L.message.msgExpectedVsReceived, CosemDataType.bitString.name, cosemTypeName(member2Tag)))")
        }
        let bitsCount = try ByteBuffer.cosemComplexTypeSize(bytes, index: &source.bytesOffset)
        let byteCount = (bitsCount + 7) / 8
        let remaining = source.count - source.parseOffset
        if remaining < byteCount {
            throw CommsError("\(L.message.msgWrongValue) \(L.message.msgWrongNumberOfBytes) \(L.fmt(L.message.msgExpectedVsReceived, "\(byteCount)", "\(remaining)"))")
        }
        let data = try source.parseData(withLen8182: false, toEnd: 0, ignoreLengthValue: false).toByteArray()
        self.init(statusCodeValue: statusValue, dataValue: Array(data.prefix(byteCount)))
    }
}

// MARK: - TokenDescriptor

/// TokenDescriptor over the 10-byte data value.
struct TokenDescriptor {
    private(set) var dataValueHex: String
    private(set) var codeStatus: TokenCodeStatus
    private(set) var codeType: TokenCodeType
    private(set) var rateId: UInt8
    private(set) var chargeRate1: Int32
    private(set) var chargeRate2: Int32

    init(dataValue: [UInt8]) {
        dataValueHex = dataValue.map { String(format: "%02X", $0) }.joined()
        // C# indexes dataValue[0..9] and throws on short input; that
        // exception is caught upstream and shown as an error alert. Swift
        // indexing would crash instead, so short inputs map to defaults.
        let b = { (i: Int) -> UInt8 in i < dataValue.count ? dataValue[i] : 0 }
        codeStatus = TokenCodeStatus(rawValue: b(0)) ?? .none
        codeType = TokenCodeType(rawValue: b(1) & 0xF0) ?? .none
        rateId = b(1) & 0x0F
        chargeRate1 = Int32(b(5))
        chargeRate1 |= Int32(b(4)) << 8
        chargeRate1 |= Int32(b(3)) << 16
        chargeRate1 |= Int32(b(2)) << 24
        chargeRate1 /= 10
        chargeRate2 = Int32(b(9))
        chargeRate2 |= Int32(b(8)) << 8
        chargeRate2 |= Int32(b(7)) << 16
        chargeRate2 |= Int32(b(6)) << 24
        chargeRate2 /= 10
    }

    // Swift Int32 division: C# integer division truncates toward zero,
    // which matches Swift's default for Int32 as well.

    func getCodeDescription() -> String {
        switch codeType {
        case .oneRate:
            let num = rateId == 0 ? 1 : Int(rateId)
            return "\(L.ui.txtRecharge):\r\n- \(L.ui.txtTariffZone) \(num): \(chargeRate1) kWh."
        case .bothRates:
            return "\(L.ui.txtRecharge):\r\n- \(L.ui.txtTariffZone) 1: \(chargeRate1) kWh\r\n- \(L.ui.txtTariffZone) 2: \(chargeRate2) kWh."
        case .resetCredit:
            return L.ui.txtResetCredit
        case .unlockCommunication:
            return L.ui.txtUnlockCommunication
        case .validationResultFailure:
            return L.message.msgValidationResultFailure
        default:
            return "\(L.ui.txtUnknown) (\(codeType))."
        }
    }

    func getCodeStatusDescription() -> String {
        switch codeStatus {
        case .ok: return L.message.msgCodeStatusOk
        case .notOk: return L.message.msgCodeStatusNotOk
        case .okTooOld: return L.message.msgCodeStatusTooOld
        case .okUsed: return L.message.msgCodeStatusUsed
        case .okAboveLimit: return L.message.msgCodeStatusAboveLimit
        case .blocked: return L.message.msgCodeStatusBlocked
        case .error: return L.message.msgCodeStatusError
        case .prepaidOff: return L.message.msgCodeStatusPrepaidOff
        default:
            return "\(L.message.msgCodeStatusUnknown) (\(codeStatus.rawValue))."
        }
    }
}

// MARK: - Token data encoding (OctetString)

enum TokenEncoder {
    /// OctetString(token): hex tokens → binary; otherwise ASCII bytes.
    static func octetStringRepresentation(token: String) -> [UInt8] {
        if StringHelper.isHexString(token) {
            return TypeConverter.convertHexStringToBytes(token)!
        }
        return Array(token.utf8)
    }

    /// ConvertToDLMSRepresentation for the OCTET_STRING method
    /// parameter: tag 9 + length (8182 encoding) + bytes.
    static func addToMethodParameters(_ bytes: [UInt8]) -> [UInt8] {
        let buffer = ByteBuffer()
        buffer.add(CosemDataType.octetString.rawValue)
        buffer.addLength8182(bytes.count)
        buffer.addRange(bytes)
        return buffer.toByteArray()
    }
}

// MARK: - Helpers

enum StringHelper {
    /// StringHelper.IsHexString: no separators allowed, even length,
    /// all hex digits.
    static func isHexString(_ s: String) -> Bool {
        guard !s.isEmpty, s.count % 2 == 0 else { return false }
        return s.allSatisfy { $0.isHexDigit }
    }
}

enum TypeConverter {
    /// ConvertHexStringToBytes: strips '-', parses pairs.
    static func convertHexStringToBytes(_ hexString: String) -> [UInt8]? {
        let cleaned = hexString.replacingOccurrences(of: "-", with: "")
        var result: [UInt8] = []
        result.reserveCapacity(cleaned.count / 2)
        var index = cleaned.startIndex
        while index < cleaned.endIndex {
            let next = cleaned.index(index, offsetBy: 2)
            let pair = String(cleaned[index ..< next])
            guard let byte = UInt8(pair, radix: 16) else { return nil }
            result.append(byte)
            index = next
        }
        return result
    }
}

// MARK: - Formatting

enum DoubleFormatter {
    /// decimal.ToString(): device-culture decimal separator, no
    /// grouping; token credits have exactly one fraction digit.
    static func deviceCulture(_ value: Decimal) -> String {
        let separator = Locale.current.decimalSeparator ?? ","
        return format(value, separator: separator)
    }

    /// decimal.ToString("F1", InvariantCulture): dot separator, always
    /// exactly 1 fraction digit.
    static func invariantF1(_ value: Decimal) -> String {
        format(value, separator: ".")
    }

    /// ScalerUnitType.ScaleValue(value, -1) = Math.Round(value * 0.1, 1):
    /// with Decimal arithmetic the product is exact (a tenth), so the
    /// division below reproduces it losslessly.
    static func scaledCredits(_ raw: Int32) -> Decimal {
        Decimal(Int(raw)) / Decimal(10)
    }

    private static func format(_ value: Decimal, separator: String) -> String {
        // The values processed here are exact tenths (int/10). Mirror
        // .NET's 1-digit rendering (banker's rounding) both for
        // ToString() and ToString("F1").
        let behavior = NSDecimalNumberHandler(roundingMode: .bankers, scale: 1,
                                              raiseOnExactness: false, raiseOnOverflow: false,
                                              raiseOnUnderflow: false, raiseOnDivideByZero: false)
        let rounded = (value as NSDecimalNumber).rounding(accordingToBehavior: behavior)
        let tenths = rounded.multiplying(byPowerOf10: 1).int64Value
        let negative = tenths < 0
        let magnitude = abs(tenths)
        let prefix = negative ? "-" : ""
        return prefix + String(magnitude / 10) + separator + String(magnitude % 10)
    }
}
