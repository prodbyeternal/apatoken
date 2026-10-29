import Foundation

// MARK: - Cosem data type tags

/// CosemDataTypes.Types tag values.
enum CosemDataType: UInt8, CaseIterable {
    case nullData = 0
    case arrayData = 1
    case structure = 2
    case boolean = 3
    case bitString = 4
    case doubleLong = 5
    case doubleLongUnsigned = 6
    case octetString = 9
    case visibleString = 10
    case utf8String = 12
    case bcd = 13
    case integer = 15
    case longData = 16
    case unsigned = 17
    case longUnsigned = 18
    case long64 = 20
    case long64Unsigned = 21
    case enumData = 22
    case float32 = 23
    case float64 = 24
    case dateTime = 25
    case date = 26
    case time = 27
    case compactArray = 19

    var name: String {
        switch self {
        case .nullData: return "NULL_DATA"
        case .arrayData: return "ARRAY"
        case .structure: return "STRUCTURE"
        case .boolean: return "BOOLEAN"
        case .bitString: return "BIT_STRING"
        case .doubleLong: return "DOUBLE_LONG"
        case .doubleLongUnsigned: return "DOUBLE_LONG_UNSIGNED"
        case .octetString: return "OCTET_STRING"
        case .visibleString: return "VISIBLE_STRING"
        case .utf8String: return "UTF8_STRING"
        case .bcd: return "BCD"
        case .integer: return "INTEGER"
        case .longData: return "LONG"
        case .unsigned: return "UNSIGNED"
        case .longUnsigned: return "LONG_UNSIGNED"
        case .long64: return "LONG64"
        case .long64Unsigned: return "LONG64_UNSIGNED"
        case .enumData: return "ENUM"
        case .float32: return "FLOAT32"
        case .float64: return "FLOAT64"
        case .dateTime: return "DATE_TIME"
        case .date: return "DATE"
        case .time: return "TIME"
        case .compactArray: return "COMPACT_ARRAY"
        }
    }
}

// MARK: - Requests

/// GetRequestNormal APDU builder.
enum GetRequestNormal {
    static func bytes(classId: UInt16, obis: [UInt8], attributeId: UInt8) -> [UInt8] {
        let buffer = ByteBuffer()
        buffer.add(192) // PDU.getRequest
        buffer.add(1)   // get-request-normal
        buffer.add(0xC1) // InvokeIdAndPriority (193)
        buffer.addUInt16(classId)
        buffer.addRange(obis) // 6 bytes
        buffer.add(attributeId)
        buffer.add(0) // no selective access descriptor
        return buffer.toByteArray()
    }
}

/// ActionRequestNormal APDU builder.
enum ActionRequestNormal {
    static func bytes(classId: UInt16, obis: [UInt8], methodId: UInt8, parameters: [UInt8]?) -> [UInt8] {
        let buffer = ByteBuffer()
        buffer.add(195) // PDU.actionRequest
        buffer.add(1)   // action-request-normal
        buffer.add(0xC1) // InvokeIdAndPriority (193)
        buffer.addUInt16(classId)
        buffer.addRange(obis)
        buffer.add(methodId)
        if let parameters {
            buffer.add(1) // parameters present
            buffer.addRange(parameters)
        } else {
            buffer.add(0)
        }
        return buffer.toByteArray()
    }
}

// MARK: - Access-result enums

/// COSEM_DATA_ACCESS_RESULT (names preserved for the message chain).
enum CosemDataAccessResult: UInt8, CustomStringConvertible, Equatable {
    case success = 0
    case hardwareFault = 1
    case temporaryFailure = 2
    case readWriteDenied = 3
    case objectUndefined = 4
    case objectClassInconsistent = 9
    case objectUnavailable = 11
    case typeUnmatched = 12
    case scopeOfAccessViolated = 13
    case dataBlockUnavailable = 14
    case longGetAborted = 15
    case noLongGetInProgress = 16
    case longSetAborted = 17
    case noLongSetInProgress = 18
    case otherReason = 250

    var description: String {
        switch self {
        case .success: return "DATA_ACCESS_RESULT_SUCCESS"
        case .hardwareFault: return "DATA_ACCESS_RESULT_HARDWARE_FAULT"
        case .temporaryFailure: return "DATA_ACCESS_RESULT_TEMPORARY_FAILURE"
        case .readWriteDenied: return "DATA_ACCESS_RESULT_READ_WRITE_DENIED"
        case .objectUndefined: return "DATA_ACCESS_RESULT_OBJECT_UNDEFINED"
        case .objectClassInconsistent: return "DATA_ACCESS_RESULT_OBJECT_CLASS_INCONSISTENT"
        case .objectUnavailable: return "DATA_ACCESS_RESULT_OBJECT_UNAVAILABLE"
        case .typeUnmatched: return "DATA_ACCESS_RESULT_TYPE_UNMATCHED"
        case .scopeOfAccessViolated: return "DATA_ACCESS_RESULT_SCOPE_OF_ACCESS_VIOLATED"
        case .dataBlockUnavailable: return "DATA_ACCESS_RESULT_DATA_BLOCK_UNAVAILABLE"
        case .longGetAborted: return "DATA_ACCESS_RESULT_LONG_GET_ABORTED"
        case .noLongGetInProgress: return "DATA_ACCESS_RESULT_NO_LONG_GET_IN_PROGRESS"
        case .longSetAborted: return "DATA_ACCESS_RESULT_LONG_SET_ABORTED"
        case .noLongSetInProgress: return "DATA_ACCESS_RESULT_NO_LONG_SET_IN_PROGRESS"
        case .otherReason: return "DATA_ACCESS_RESULT_OTHER_REASON"
        }
    }
}

/// ActionResult (ActionResponseNormal.Result names).
enum CosemActionResult: UInt8, CustomStringConvertible {
    case success = 0
    case hardwareFault = 1
    case temporaryFailure = 2
    case readWriteDenied = 3
    case objectUndefined = 4
    case objectClassInconsistent = 9
    case objectUnavailable = 11
    case typeUnmatched = 12
    case scopeOfAccessViolated = 13
    case dataBlockUnavailable = 14
    case longActionAborted = 15
    case noLongActionInProgress = 16
    case otherReason = 250

    var description: String {
        switch self {
        case .success: return "Success"
        case .hardwareFault: return "HardwareFault"
        case .temporaryFailure: return "TemporaryFailure"
        case .readWriteDenied: return "ReadWriteDenied"
        case .objectUndefined: return "ObjectUndefined"
        case .objectClassInconsistent: return "ObjectClassInconsistent"
        case .objectUnavailable: return "ObjectUnavailable"
        case .typeUnmatched: return "TypeUnmatched"
        case .scopeOfAccessViolated: return "ScopeOfAccessViolated"
        case .dataBlockUnavailable: return "DataBlockUnavailable"
        case .longActionAborted: return "LongActionAborted"
        case .noLongActionInProgress: return "NoLongActionInProgress"
        case .otherReason: return "OtherReason"
        }
    }
}

// MARK: - Exceptions

/// FrameCosemException – a COSEM-level error response.
final class FrameCosemError: CommsError {}

/// CosemDataAccessResultException – Message =
/// "_message (DATA_ACCESS_RESULT_…)" or just the enum name when empty.
final class CosemAccessError: CommsError {
    let result: CosemDataAccessResult

    init(message: String, result: CosemDataAccessResult) {
        self.result = result
        let display = message.isEmpty ? result.description : "\(message) (\(result.description))"
        super.init(display)
    }
}

// MARK: - Requests results

/// RequestResult (one COSEM member's response).
final class CosemRequestResult {
    var memberObis: [UInt8]?
    var memberId: UInt8 = 0
    var memberIsAttribute = true
    var responseData: ByteBuffer
    var responseStatus: CosemDataAccessResult?
    var pduType: UInt8
    var actionReturnParametersStatus: CosemDataAccessResult?

    init(responseData: ByteBuffer, pduType: UInt8) {
        self.responseData = responseData
        self.pduType = pduType
    }

    func describe() -> String {
        // For chain-building details like "at attribute 2 of 0.0.19.10.1.255"
        let obisText = memberObis.map { ObisCode.toDisplayString($0) } ?? ""
        let kind = memberIsAttribute ? L.message.msgAttributeAccessError : L.message.msgMethodAccessError
        return L.fmt(kind, "\(memberId)", obisText)
    }

    func checkResponseStatus() throws {
        guard let status = responseStatus, status != .success else { return }
        var text = describe()
        if pduType != 0 {
            text = pduName(pduType).uppercased() + " " + text
        }
        throw CosemAccessError(message: text, result: status)
    }

    private func pduName(_ tag: UInt8) -> String {
        switch tag {
        case 192: return "getRequest"
        case 196: return "getResponse"
        case 195: return "actionRequest"
        case 199: return "actionResponse"
        case 197: return "setResponse"
        case 213: return "setResponse"
        default: return "pdu\(tag)"
        }
    }
}

// MARK: - Responses

/// Parsed response APDUs for one transaction turn.
enum CosemApduResponse {
    /// GetResponse.ProcessResponseApdus for a get-transaction.
    static func processGetResponses(_ apdus: [COSEMResponseApdu]) throws -> [CosemRequestResult] {
        var results: [CosemRequestResult] = []
        for apdu in apdus {
            if case .exceptionResponse(let state, let service) = apdu {
                throw FrameCosemError("ExceptionResponse : \(state) : \(service)")
            }
            guard case .getResponse(let invoke, let selector, let result) = apdu else {
                throw CommsError("not implemented: " + String(reflecting: apdu))
            }
            _ = invoke
            let requestResult = CosemRequestResult(responseData: result.data ?? ByteBuffer(), pduType: 196)
            requestResult.responseStatus = LogicalToEnum(result.dataAccessResult)
            results.append(requestResult)
            _ = selector
        }
        return results
    }

    /// ActionResponse.ProcessResponseApdus for an action-transaction.
    static func processActionResponses(_ apdus: [COSEMResponseApdu]) throws -> [CosemRequestResult] {
        var results: [CosemRequestResult] = []
        for apdu in apdus {
            if case .exceptionResponse(let state, let service) = apdu {
                throw FrameCosemError("ExceptionResponse : \(state) : \(service)")
            }
            guard case .actionResponse(let actionResult, let returnParameters) = apdu else {
                throw CommsError("not implemented: " + String(reflecting: apdu))
            }
            let requestResult = CosemRequestResult(responseData: returnParameters?.data ?? ByteBuffer(), pduType: 199)
            requestResult.responseStatus = actionStatusToEnum(actionResult)
            if let returnParameters {
                requestResult.actionReturnParametersStatus = LogicalToEnum(returnParameters.dataAccessResult)
                requestResult.responseData = returnParameters.data ?? ByteBuffer()
            }
            results.append(requestResult)
        }
        return results
    }

    private static func LogicalToEnum(_ r: CosemDataAccessResult?) -> CosemDataAccessResult? {
        r
    }

    private static func actionStatusToEnum(_ actionResult: CosemActionResult) -> CosemDataAccessResult? {
        switch actionResult {
        case .success: return .success
        case .hardwareFault: return .hardwareFault
        case .temporaryFailure: return .temporaryFailure
        case .readWriteDenied: return .readWriteDenied
        case .objectUndefined: return .objectUndefined
        case .objectClassInconsistent: return .objectClassInconsistent
        case .objectUnavailable: return .objectUnavailable
        case .typeUnmatched: return .typeUnmatched
        case .scopeOfAccessViolated: return .scopeOfAccessViolated
        case .dataBlockUnavailable: return .dataBlockUnavailable
        case .longActionAborted: return .longGetAborted
        case .noLongActionInProgress: return .noLongGetInProgress
        case .otherReason: return .otherReason
        }
    }
}

/// One parsed response APDU (ApduFactory.Create output, reduced to the
/// subset the token flow can encounter).
enum COSEMResponseApdu {
    /// GetResponseNormal: tag 196 (0xC4), subtype must be 1.
    case getResponse(invoke: UInt8, selector: UInt8, result: GetDataResult)

    /// ActionResponseNormal: tag 199 (0xC7), subtype must be 1.
    case actionResponse(actionResult: CosemActionResult, returnParameters: GetDataResult?)

    /// ExceptionResponse: tag 216 (0xD8).
    case exceptionResponse(stateError: String, serviceError: String)

    /// ConfirmedServiceError: tags 14 / 46.
    case confirmedServiceError(details: String)
}

/// GetDataResult: either raw data bytes or a DataAccessResult.
struct GetDataResult {
    var data: ByteBuffer?
    var dataAccessResult: CosemDataAccessResult?
}

// MARK: - APDU parser

enum ApduParser {
    static func parse(_ buffer: ByteBuffer) throws -> COSEMResponseApdu {
        let bytes = buffer.toByteArray()
        guard let first = bytes.first else {
            throw CommsError(L.message.msgWrongPDU)
        }
        switch first {
        case 196: // getResponse
            let body = ByteBuffer(bytes)
            let tag = try body.parseUInt8()
            if tag != 196 {
                throw CommsError(L.message.msgWrongPDU)
            }
            let sub = try body.parseUInt8()
            if sub != 1 {
                throw CommsError(L.fmt(L.message.msgNotImplemented, "getResponse sub=\(sub)"))
            }
            let invoke = try body.parseUInt8()
            let selector = try body.parseUInt8()
            // selector == 0 → data-access-result byte; 0 → data follows
            var result = GetDataResult()
            let statusCode = UInt8(selector)
            if statusCode == 0 {
                result.data = try body.parseData(withLen8182: false, toEnd: 0, ignoreLengthValue: false)
            } else {
                result.dataAccessResult = CosemDataAccessResult(rawValue: statusCode) ?? .otherReason
            }
            return .getResponse(invoke: invoke, selector: selector, result: result)
        case 199: // actionResponse
            let body = ByteBuffer(bytes)
            let tag = try body.parseUInt8()
            if tag != 199 {
                throw CommsError(L.message.msgWrongPDU)
            }
            let sub = try body.parseUInt8()
            if sub != 1 {
                throw CommsError(L.fmt(L.message.msgNotImplemented, "actionResponse sub=\(sub)"))
            }
            let invoke = try body.parseUInt8()
            _ = invoke
            let actionResultByte = try body.parseUInt8()
            let actionResult = CosemActionResult(rawValue: actionResultByte) ?? .otherReason
            var returnParameters: GetDataResult?
            if body.parseOffset < body.count {
                let paramFlag = try body.parseUInt8()
                if paramFlag != 0 {
                    returnParameters = GetDataResult()
                    let kind = try body.parseUInt8()
                    if kind == 0 {
                        returnParameters!.data = try body.parseData(withLen8182: false, toEnd: 0, ignoreLengthValue: false)
                    } else {
                        returnParameters!.dataAccessResult = CosemDataAccessResult(rawValue: kind) ?? .otherReason
                    }
                }
            }
            return .actionResponse(actionResult: actionResult, returnParameters: returnParameters)
        case 216: // exceptionResponse
            let body = ByteBuffer(bytes)
            let tag = try body.parseUInt8()
            if tag != 216 {
                throw CommsError(L.message.msgWrongPDU)
            }
            let state = try body.parseUInt8()
            let service = try body.parseUInt8()
            return .exceptionResponse(stateError: exceptionStateName(state), serviceError: exceptionServiceName(service))
        case 14, 46: // confirmedServiceError
            let body = ByteBuffer(bytes)
            let tag = try body.parseUInt8()
            if tag != 14 && tag != 46 {
                throw CommsError(L.message.msgWrongPDU)
            }
            let service = try body.parseUInt8()
            let subTypeByte = try body.parseUInt8()
            var detailSuffix: String
            var initiateValue: UInt8?
            switch subTypeByte {
            case 3:
                let serviceByte = try body.parseUInt8()
                detailSuffix = serviceName(serviceByte)
            case 6:
                let initiateByte = try body.parseUInt8()
                detailSuffix = initiateName(initiateByte)
                initiateValue = initiateByte
            default:
                detailSuffix = "unknown"
            }
            var details = "confirmedServiceError : \(confirmedServiceName(service)) : \(detailSuffix)"
            if service == 1, subTypeByte == 6, initiateValue == 0 {
                // InitiateError with Initiate.Other
                details = L.message.msgAssociationError + " " + L.message.msgProbablyWrongKeys
            }
            return .confirmedServiceError(details: details)
        default:
            throw CommsError("Nierozpoznany typ ramki PDU: \(first)")
        }
    }

    private static func exceptionStateName(_ value: UInt8) -> String {
        switch value {
        case 1: return "ServiceNotAllowed"
        case 2: return "ServiceUnknown"
        default: return "\(value)"
        }
    }

    private static func exceptionServiceName(_ value: UInt8) -> String {
        switch value {
        case 1: return "OperationNotPossible"
        case 2: return "ServiceNotSupported"
        case 3: return "OtherReason"
        case 4: return "PduTooLong"
        case 5: return "DecipheringError"
        case 6: return "InvocationCounterError"
        default: return "\(value)"
        }
    }

    private static func confirmedServiceName(_ value: UInt8) -> String {
        switch value {
        case 1: return "InitiateError"
        case 2: return "GetStatus"
        case 3: return "GetNameList"
        case 4: return "GetVariableAttribute"
        case 5: return "Read"
        case 6: return "Write"
        case 7: return "GetDataSetAttribute"
        case 8: return "GetTIAttribute"
        case 9: return "ChangeScope"
        case 10: return "Start"
        case 11: return "Stop"
        case 12: return "Resume"
        case 13: return "MakeUsable"
        case 14: return "InitiateLoad"
        case 15: return "LoadSegment"
        case 16: return "TerminateLoad"
        case 17: return "InitiateUpLoad"
        case 18: return "UpLoadSegment"
        case 19: return "TerminateUpLoad"
        default: return "\(value)"
        }
    }

    private static func serviceName(_ value: UInt8) -> String {
        switch value {
        case 0: return "Other"
        case 1: return "PduSize"
        case 2: return "ServiceUnsupported"
        default: return "\(value)"
        }
    }

    private static func initiateName(_ value: UInt8) -> String {
        switch value {
        case 0: return "Other"
        case 1: return "DlmsVersionTooLow"
        case 2: return "IncompatibleConformance"
        case 3: return "PduSizeTooShort"
        case 4: return "RefusedByTheVdeHandler"
        default: return "\(value)"
        }
    }
}

// MARK: - OBIS

/// CosemObisCode helper.
struct ObisCode {
    let bytes: [UInt8]

    init(_ obisString: String) throws {
        let parts = obisString.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 6 else {
            throw CommsError(L.message.msgWrongObisString)
        }
        var parsed: [UInt8] = []
        for part in parts {
            guard let v = UInt8(part) else {
                throw CommsError(L.fmt(L.message.msgWrongCharInObisCode, String(part)))
            }
            parsed.append(v)
        }
        bytes = parsed
    }

    static func toDisplayString(_ bytes: [UInt8]) -> String {
        bytes.map { "\($0)" }.joined(separator: ".")
    }
}
