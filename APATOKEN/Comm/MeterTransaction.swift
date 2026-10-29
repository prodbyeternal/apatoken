import Foundation

/// CosemResult (DlmsAPI.Client).
struct CosemResult {
    var memberObis: String?
    var memberId: UInt8 = 0
    var memberIsAttribute = true
    var memberValue: [UInt8]?
    var responseData: [UInt8]?
    var accessResult: CosemDataAccessResult?
}

// MARK: - CosemProtocol (transaction loop)

/// CosemProtocol over an HDLC transport, reduced to the get/action
/// transactions used by the token flow.
final class CosemProtocol {
    private let transport: HdlcTransport
    private let invokeIdAndPriority: UInt8 = 193

    init(transport: HdlcTransport) {
        self.transport = transport
    }

    func connect() async throws {
        try await transport.connect()
    }

    /// CosemProtocol.Disconnect(true, true) with the pre-established
    /// association: RLRQ disabled, transport DISC + port close.
    func disconnect() async throws {
        let open = await transport.isPortOpen
        if !open {
            return
        }
        try await transport.disconnect(withTransactionDisconnect: true)
    }

    var isPortOpen: Bool {
        get async {
            await transport.isPortOpen
        }
    }

    /// DoTransactionGetRequest(cosemMember, null).
    func doTransactionGetRequest(obis: String, classId: UInt16, attributeId: UInt8) async throws -> CosemRequestResult {
        let obisBytes = try ObisCode(obis).bytes
        let apdu = GetRequestNormal.bytes(classId: classId, obis: obisBytes, attributeId: attributeId)
        let results = try await processRequest([apdu], isGetRequestTxn: true)
        if results.count == 0 {
            throw CommsError("No request results in response")
        }
        let requestResult = results[0]
        requestResult.memberObis = obisBytes
        requestResult.memberId = attributeId
        requestResult.memberIsAttribute = true
        return requestResult
    }

    /// DoTransactionActionRequest(method, methodParameters).
    func doTransactionActionRequest(obis: String, classId: UInt16, methodId: UInt8, parameters: [UInt8]?) async throws -> CosemRequestResult {
        let obisBytes = try ObisCode(obis).bytes
        let apdu = ActionRequestNormal.bytes(classId: classId, obis: obisBytes, methodId: methodId, parameters: parameters)
        let results = try await processRequest([apdu], isGetRequestTxn: false)
        if results.count == 0 {
            throw CommsError("No request results in response.")
        }
        let requestResult = results[0]
        requestResult.memberObis = obisBytes
        requestResult.memberId = methodId
        requestResult.memberIsAttribute = false
        return requestResult
    }

    /// DoTransaction(List<IDlmsApdu>): transport exchange + apdu
    /// parse + confirmedServiceError detection.
    private func processRequest(_ apdus: [[UInt8]], isGetRequestTxn: Bool) async throws -> [CosemRequestResult] {
        let received = try await doTransaction(apdus)
        var results: [CosemRequestResult]
        if isGetRequestTxn {
            results = try CosemApduResponse.processGetResponses(received)
        } else {
            results = try CosemApduResponse.processActionResponses(received)
        }
        return results
    }

    private func doTransaction(_ apdus: [[UInt8]]) async throws -> [COSEMResponseApdu] {
        let frames = try await doTransactionInner(apdus.map { ByteBuffer($0) })
        var receivedApdus: [COSEMResponseApdu] = []
        for frame in frames {
            receivedApdus.append(try ApduParser.parse(frame))
        }
        for apdu in receivedApdus {
            if case .confirmedServiceError(let details) = apdu {
                throw FrameCosemError("\(L.message.msgAccessError) \(details)")
            }
        }
        return receivedApdus
    }

    /// DoTransactionInner(framesToSend): per-APDU loop (20000), with
    /// the timeout-retry (3 attempts, 5 s sleep) for GetRequests only.
    private func doTransactionInner(_ framesToSend: [ByteBuffer]) async throws -> [ByteBuffer] {
        var responseFrames: [ByteBuffer] = []
        let apdusCount = framesToSend.count
        var stopEarly = false
        for i in 0 ..< apdusCount {
            if stopEarly { break }
            var byteBuffer: ByteBuffer? = framesToSend[i]
            for _ in 0 ..< 20000 {
                guard let send = byteBuffer else { break }
                let isGetRequest = send.count > 0 && send[0] == 192 // PDU.getRequest

                let recv: ByteBuffer = try await withCheckedThrowingContinuation { continuation in
                    Task.detached {
                        var retryId = 0
                        while true {
                            do {
                                let frame = try await self.transport.doTransaction(send.clone())
                                continuation.resume(returning: frame)
                                return
                            } catch let error as CommsError {
                                if error.isTimeout && isGetRequest {
                                    if retryId == 2 {
                                        continuation.resume(throwing: error)
                                        return
                                    }
                                    do {
                                        try await Task.sleep(nanoseconds: 5_000_000_000)
                                    } catch {
                                        continuation.resume(throwing: error)
                                        return
                                    }
                                    retryId += 1
                                    continue
                                }
                                continuation.resume(throwing: error)
                                return
                            } catch {
                                continuation.resume(throwing: CommsError("\(error)"))
                                return
                            }
                        }
                    }
                }

                if recv.count == 0 {
                    // C# would throw IndexOutOfRangeException on recv[0].
                    throw TransportProtocolError("Index was outside the bounds of the array.")
                }
                responseFrames.append(recv.clone())
                let firstByte = recv[0]
                if firstByte == 14 || firstByte == 46 {
                    // confirmedServiceError – stop exchanging blocks;
                    // TryGenerateRequestForNextBlock yields no more
                    // requests in this reduced port.
                    byteBuffer = nil
                    stopEarly = true
                } else {
                    // ApduFactory.TryGenerateRequestForNextBlock → null
                    // (no block transfer support in the reduced port).
                    byteBuffer = nil
                }
            }
        }
        return responseFrames
    }
}

// MARK: - DlmsClient

/// DlmsClient (DlmsAPI.Client) over CosemProtocol.
final class DlmsClient {
    private let cosemProtocol: CosemProtocol

    init(transport: HdlcTransport) {
        self.cosemProtocol = CosemProtocol(transport: transport)
    }

    /// Protocol.IsConnected() → TransportProtocol.IsPortOpen().
    func isConnected() async -> Bool {
        await cosemProtocol.isPortOpen
    }

    func connect() async throws {
        try await cosemProtocol.connect()
    }

    func disconnect() async throws {
        try await cosemProtocol.disconnect()
    }

    /// ReadCosemAttribute(obis, classId, id) with null selective access.
    func readCosemAttribute(obis: String, classId: UInt16, attributeId: UInt8) async throws -> CosemResult {
        let requestResult = try await cosemProtocol.doTransactionGetRequest(obis: obis, classId: classId, attributeId: attributeId)
        var value: [UInt8]?
        if requestResult.responseData.count > 0 {
            value = requestResult.responseData.toByteArray()
        }
        var result = CosemResult()
        result.memberObis = obis
        result.memberId = attributeId
        result.memberIsAttribute = true
        result.memberValue = value
        result.accessResult = requestResult.responseStatus
        return result
    }

    /// InvokeCosemMethod(obis, classId, id, cosemValue).
    func invokeCosemMethod(obis: String, classId: UInt16, methodId: UInt8, cosemValue: [UInt8]?) async throws -> CosemResult {
        let requestResult = try await cosemProtocol.doTransactionActionRequest(obis: obis, classId: classId, methodId: methodId, parameters: cosemValue)
        var result = CosemResult()
        result.memberObis = obis
        result.memberId = methodId
        result.memberIsAttribute = false
        result.memberValue = cosemValue
        if requestResult.responseData.count > 0 {
            result.responseData = requestResult.responseData.toByteArray()
        }
        result.accessResult = requestResult.responseStatus
        return result
    }
}

// MARK: - CommonCommunication mirror

/// CommonCommunication flows with the same error wrapping/mapping.
enum MeterCommunication {
    static let tokenGatewayObis = "0.0.19.40.0.255"

    /// Tuple<TokenDeliveryStatus, List<decimal>> result.
    struct TokenTransactionResult {
        let deliveryStatus: TokenDeliveryStatus
        let credits: [Decimal]
    }

    // MARK: PrepareDlmsClient

    static func prepareDlmsClient(deviceAddress: String, baudRate: Int) -> DlmsClient {
        let port = DspsBlePort(address: deviceAddress, meterBaudRate: baudRate)
        let transport = HdlcTransport(port: port, serverLogicalAddress: 1, serverPhysicalAddress: 0)
        transport.setFrameWindowSizes(200, 200)
        return DlmsClient(transport: transport)
    }

    // MARK: Flows

    /// EnterTokenAndReadCreditsInkWh (wrapped + finally-Disconnect).
    static func enterTokenAndReadCreditsInkWh(client: DlmsClient, obises: [String], token: String) async throws -> TokenTransactionResult {
        do {
            let result = try await enterTokenAndReadCreditsInkWhInner(client: client, obises: obises, token: token)
            try await disconnectInFinal(client)
            return TokenTransactionResult(deliveryStatus: result.deliveryStatus, credits: result.credits)
        } catch {
            let wrapped = CommsError(L.message.msgUnsuccessfulTokenEntering, cause: error as? CommsError ?? CommsError("\(error)"))
            try await disconnectInFinal(client)
            throw wrapped
        }
    }

    /// Body of EnterTokenAndReadCreditsInkWh without catch/finally.
    private static func enterTokenAndReadCreditsInkWhInner(client: DlmsClient, obises: [String], token: String) async throws -> (deliveryStatus: TokenDeliveryStatus, credits: [Decimal]) {
        let connected = await client.isConnected()
        if !connected {
            try await client.connect()
        }
        let methodParameters = TokenEncoder.addToMethodParameters(TokenEncoder.octetStringRepresentation(token: token))
        let cosemResult = try await client.invokeCosemMethod(obis: tokenGatewayObis, classId: 115, methodId: 1, cosemValue: methodParameters)
        try await verifyResult(cosemResult)
        let responseData = ByteBuffer(cosemResult.responseData ?? [])
        let tokenDeliveryStatus = try TokenDeliveryStatus(responseData: responseData)
        var credits: [Decimal] = []
        if tokenDeliveryStatus.statusCode == .tokenExecutionResultOk {
            let scaler: Int8 = -1
            for obise in obises {
                let raw = try await readCreditValue(client: client, obis: obise)
                credits.append(scaleValue(raw, scaler: scaler))
            }
        }
        return (tokenDeliveryStatus, credits)
    }

    /// ReadCreditsInkWh (same wrapping as the C# – token message).
    static func readCreditsInkWh(client: DlmsClient, obises: [String]) async throws -> [Decimal] {
        do {
            let connected = await client.isConnected()
            if !connected {
                try await client.connect()
            }
            var list: [Decimal] = []
            let scaler: Int8 = -1
            for obise in obises {
                let raw = try await readCreditValue(client: client, obis: obise)
                list.append(scaleValue(raw, scaler: scaler))
            }
            try await disconnectInFinal(client)
            return list
        } catch {
            let wrapped = CommsError(L.message.msgUnsuccessfulTokenEntering, cause: error as? CommsError ?? CommsError("\(error)"))
            try await disconnectInFinal(client)
            throw wrapped
        }
    }

    /// finally { client?.Disconnect(); } – an exception here replaces
    /// the in-flight one (C# finally semantics).
    private static func disconnectInFinal(_ client: DlmsClient) async throws {
        try await client.disconnect()
    }

    // MARK: ReadCreditValue (IC112 attribute 2)

    /// SimpleAttribute[DOUBLE_LONG] parse: null → 0; wrong tag /
    /// wrong length → WrongValueRepresentationException equivalents.
    static func readCreditValue(client: DlmsClient, obis: String) async throws -> Int32 {
        let cosemResult = try await client.readCosemAttribute(obis: obis, classId: 112, attributeId: 2)
        try await verifyResult(cosemResult)
        let memberValue = cosemResult.memberValue ?? []
        if memberValue.isEmpty || memberValue[0] == 0 {
            return 0 // Value = null → IsNullValue → 0m
        }
        let tag = memberValue[0]
        if tag != 5 { // CosemDataTypes.Types.DOUBLE_LONG
            let inner = CommsError("\(L.message.msgWrongDataType) \(L.fmt(L.message.msgExpectedVsReceived, "DOUBLE_LONG", cosemTypeName(tag)))")
            throw CommsError(L.message.msgWrongBinaryRepresentation, cause: inner)
        }
        let remaining = memberValue.count - 1
        if remaining < 4 {
            let inner = CommsError("\(L.message.msgWrongValue) \(L.message.msgWrongNumberOfBytes) \(L.fmt(L.message.msgExpectedVsReceived, "4", "\(remaining)"))")
            throw CommsError(L.message.msgWrongBinaryRepresentation, cause: inner)
        }
        // BE signed Int32 (C#: revert + BitConverter.ToInt32).
        var raw = Int32(memberValue[1])
        raw <<= 8
        raw |= Int32(memberValue[2])
        raw <<= 8
        raw |= Int32(memberValue[3])
        raw <<= 8
        raw |= Int32(memberValue[4])
        return raw
    }

    // MARK: VerifyResult

    static func verifyResult(_ result: CosemResult) async throws {
        if let accessResult = result.accessResult, accessResult != .success {
            throw CosemAccessError(message: "", result: accessResult)
        }
    }

    // MARK: ScaleValue (ScalerUnitType)

    /// ScaleValue(value, -1) = Math.Round(value * 0.1, 1) with exact
    /// decimal arithmetic (credits are integers → exact tenths with
    /// scale 1, banker's rounding) – Decimal ToString() → "1543.0".
    static func scaleValue(_ raw: Int32, scaler: Int8) -> Decimal {
        if scaler == 0 {
            return Decimal(Int(raw))
        }
        if scaler < 0 {
            // Reuse the pinned tenths conversion (NSDecimalNumber,
            // banker's rounding to -scaler digits).
            return DoubleFormatter.scaledCredits(raw)
        }
        // scaler > 0 path not used in this app; kept for parity.
        var multiplier = Decimal(1)
        for _ in 0 ..< Int(scaler) {
            multiplier = multiplier * 10
        }
        return Decimal(Int(raw)) * multiplier
    }

    // MARK: IsNoResponseFromMeter

    static func isTransportProtocolError(_ error: CommsError) -> Bool {
        var current: CommsError? = error
        while let c = current {
            if c is TransportProtocolError { return true }
            current = c.cause
        }
        return false
    }

    /// IsNoResponseFromMeter: timeout / transport exception anywhere in
    /// the chain, or the direct inner is a CommunicationPortException.
    static func isNoResponseFromMeter(_ error: CommsError) -> Bool {
        if error.isTimeout {
            return true
        }
        if isTransportProtocolError(error) {
            return true
        }
        if error.cause is CommunicationPortError {
            return true
        }
        return false
    }

    // MARK: BeginTransaction / BeginReadingTransaction

    /// BeginTransaction(token): Task<TransactionResult> outcome.
    /// Any error is either msgNoResponseFromMeter (chain DROPPED) or
    /// rethrown as-is (the raw CommsError with the full chain).
    static func beginTokenTransaction(token: String, deviceAddress: String, baudRate: Int) async throws -> TokenTransactionResult {
        do {
            let client = prepareDlmsClient(deviceAddress: deviceAddress, baudRate: baudRate)
            return try await enterTokenAndReadCreditsInkWh(client: client, obises: ["0.0.19.10.1.255", "0.0.19.10.2.255"], token: token)
        } catch let error as CommsError {
            if isNoResponseFromMeter(error) {
                throw CommsError(L.message.msgNoResponseFromMeter) // chain dropped
            }
            throw error
        } catch {
            throw CommsError("\(error)")
        }
    }

    /// BeginReadingTransaction: Task<List<decimal>> outcome.
    static func beginReadingTransaction(deviceAddress: String, baudRate: Int) async throws -> [Decimal] {
        do {
            let client = prepareDlmsClient(deviceAddress: deviceAddress, baudRate: baudRate)
            return try await readCreditsInkWh(client: client, obises: ["0.0.19.10.1.255", "0.0.19.10.2.255"])
        } catch let error as CommsError {
            if isNoResponseFromMeter(error) {
                throw CommsError(L.message.msgNoResponseFromMeter) // chain dropped
            }
            throw error
        } catch {
            throw CommsError("\(error)")
        }
    }
}

// MARK: - Cosem data type names (diagnostics)

func cosemTypeName(_ tag: UInt8) -> String {
    if let type = CosemDataType(rawValue: tag) {
        return type.name
    }
    switch tag {
    case 28: return "DELTA_INTEGER"
    case 29: return "DELTA_LONG"
    case 30: return "DELTA_DOUBLE_LONG"
    case 31: return "DELTA_UNSIGNED"
    case 32: return "DELTA_LONG_UNSIGNED"
    case 33: return "DELTA_DOUBLE_LONG_UNSIGNED"
    case 34: return "CHOICE"
    default:
        return "\(tag)"
    }
}
