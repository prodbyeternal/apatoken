import Foundation

/// Exceptions thrown through the DLMS/BLE stack.
/// Mirrors the C# exception chain: each has a human-readable message,
/// and chains to an underlying cause. `isTimeoutType` mirrors
/// `CommonMethods.IsTimeoutException` – a type check plus a "timeout"
/// substring check on the whole chain.
open class CommsError: Error, CustomStringConvertible {
    public let message: String
    public private(set) var cause: CommsError?

    public init(_ message: String, cause: CommsError? = nil) {
        self.message = message
        self.cause = cause
    }

    public var description: String { message }

    /// The complete chain of messages, root first, joined with " ",
    /// skipping messages already contained in the accumulated text
    /// (`CommonMethods.GetCompleteExceptionMessage`).
    public var chainMessage: String {
        var text = message
        var current = cause
        while let c = current {
            if !c.message.isEmpty && !text.contains(c.message) {
                if text.isEmpty {
                    text = c.message
                } else if text.endsWithNewLine {
                    text += c.message
                } else {
                    text += " " + c.message
                }
            }
            current = c.cause
        }
        return text
    }

    /// Mirrors `CommonMethods.IsTimeoutException`: true when any
    /// exception in the chain is a TimeoutError OR its message
    /// contains "timeout (case-insensitive)".
    public var isTimeout: Bool {
        var current: CommsError? = self
        while let c = current {
            if c is TimeoutError { return true }
            if c.message.lowercased().contains("timeout") { return true }
            current = c.cause
        }
        return false
    }
}

/// TimeoutException equivalent: timeout-typed errors. Detection by
/// `is`-check plus the "timeout" substring rule on the message chain.
public final class TimeoutError: CommsError {}

/// TransportProtocolException equivalent: thrown by the HDLC layer for
/// frame-level failures (no response, bad CRC, invalid frame, …).
public final class TransportProtocolError: CommsError {}

/// CommunicationPortException equivalent: thrown by the port adapter
/// for open/read/write failures that are not timeout-typed.
public final class CommunicationPortError: CommsError {}

/// Growable byte buffer with big-endian integer IO, HDLC checksums,
/// address coding and DLMS length (8182) helpers – a 1:1 port of the
/// parts of `ByteBuffer` used by the token flow.
public final class ByteBuffer {
    private(set) var bytes: [UInt8] = []
    private var _parseOffset = 0

    public var count: Int { bytes.count }
    public var parseOffset: Int { _parseOffset }

    /// Direct parse-offset manipulation (used with the static
    /// cosemComplexTypeSize helper).
    public var bytesOffset: Int {
        get { _parseOffset }
        set { _parseOffset = max(0, min(newValue, count)) }
    }

    public init() {}

    public init(_ bytes: [UInt8]) {
        self.bytes = bytes
    }

    public init(_ byte: UInt8) {
        bytes = [byte]
    }

    public init(_ data: Data) {
        bytes = [UInt8](data)
    }

    public func add(_ byte: UInt8) {
        bytes.append(byte)
    }

    public func add(_ b: Int) {
        bytes.append(UInt8(truncatingIfNeeded: b))
    }

    public func addRange(_ range: [UInt8]) {
        bytes.append(contentsOf: range)
    }

    public func insert(_ index: Int, _ byte: UInt8) {
        bytes.insert(byte, at: index)
    }

    /// Mirrors `ByteBuffer.RemoveLLC`: removes a leading 3-byte LLC
    /// header (0xE6 0xE6 0x00).
    public func removeLLC() throws {
        if count < 3 || bytes[0] != 230 || bytes[2] != 0 {
            throw CommsError(L.message.msgNoLLC)
        }
        bytes.removeFirst(3)
    }

    public func getRangeBuffer(_ offset: Int, _ length: Int) -> ByteBuffer {
        let result = ByteBuffer()
        var i = offset
        while i < offset + length && i < count {
            result.add(bytes[i])
            i += 1
        }
        return result
    }

    public func setRange(_ index: Int, _ value: UInt8) {
        guard index >= 0, index < count else { return }
        bytes[index] = value
    }

    public subscript(index: Int) -> UInt8 {
        get { bytes[index] }
        set { bytes[index] = newValue }
    }

    public func toByteArray() -> [UInt8] {
        bytes
    }

    public func toData() -> Data {
        Data(bytes)
    }

    public func clone() -> ByteBuffer {
        ByteBuffer(bytes)
    }

    // MARK: - Add (big-endian writers)

    public func addUInt8(_ data: UInt8) {
        add(data)
    }

    public func addUInt16(_ data: UInt16) {
        add(UInt8(data >> 8))
        add(UInt8(data & 0xFF))
    }

    public func addUInt32(_ data: UInt32) {
        add(UInt8((data >> 24) & 0xFF))
        add(UInt8((data >> 16) & 0xFF))
        add(UInt8((data >> 8) & 0xFF))
        add(UInt8(data & 0xFF))
    }

    // MARK: - Parse (big-endian readers)

    public func parseUInt8() throws -> UInt8 {
        if _parseOffset < count {
            let result = bytes[_parseOffset]
            _parseOffset += 1
            return result
        }
        throw CommsError(L.message.msgNotEnoughData)
    }

    public func parseUInt16() throws -> UInt16 {
        let hi = try parseUInt8()
        let lo = try parseUInt8()
        return (UInt16(hi) << 8) | UInt16(lo)
    }

    public func parseUInt32() throws -> UInt32 {
        let b3 = try parseUInt8()
        let b2 = try parseUInt8()
        let b1 = try parseUInt8()
        let b0 = try parseUInt8()
        return (UInt32(b3) << 24) | (UInt32(b2) << 16) | (UInt32(b1) << 8) | UInt32(b0)
    }

    /// Parses an HDLC link address (callback-less variant): value shifted
    /// per 7 bits, terminating when the LSB of a byte is set – max 4 bytes.
    public func parseAddress() throws -> UInt32 {
        var result: UInt32 = 0
        for i in 0 ..< 4 {
            let b = try parseUInt8()
            result &+= UInt32(b >> 1) << (i * 7)
            if (b & 1) == 1 {
                break
            }
        }
        return result
    }

    /// Parses variable-length HDLC addresses of the general form
    /// used in received frames (never used directly by the token flow
    /// but kept for parity with setRecv frame parsing).
    public static func parseAddress(from buffer: [UInt8], index: inout Int) -> UInt32 {
        var result: UInt32 = 0
        var i = 0
        while i < 4 {
            guard index < buffer.count else { break }
            let b = buffer[index]
            index += 1
            result |= UInt32(b >> 1) << (i * 7)
            i += 1
            if (b & 1) == 1 {
                break
            }
        }
        return result
    }

    /// Parses an HDLC checksum; checksum area = bytes [1 .. parseOffset-1]
    /// (i.e. everything read so far, excluding the leading 0x7E flag).
    public func parseHdlcChecksum() throws -> Bool {
        let computed = ByteBuffer.calculateChecksum(0xFFFF, fromByte: 1, bytesLength: _parseOffset - 1, bytes: bytes)
        let lo = try parseUInt8()
        var stored = UInt16(lo)
        let hi = try parseUInt8()
        stored |= UInt16(hi) << 8
        return computed == stored
    }

    // MARK: - HDLC checksums

    /// X.25 CRC-16 (reflected 0x8408) starting from `fcs`, over
    /// `bytes[fromByte ..< fromByte+bytesLength]`, final XOR 0xFFFF.
    public static func calculateChecksum(_ fcsIn: UInt16, fromByte: Int, bytesLength: Int, bytes: [UInt8]) -> UInt16 {
        var fcs = fcsIn
        var i = fromByte
        let end = bytesLength + fromByte
        while i < end {
            fcs = (fcs >> 8) ^ checksumTable[Int((fcs ^ UInt16(bytes[i])) & 0xFF)]
            i += 1
        }
        fcs ^= 0xFFFF
        return fcs
    }

    /// Mirrors `ByteBuffer.AddHdlcChecksum` (called with buffer already
    /// containing everything up to FCS): computes over [1 .. Count-1]
    /// and appends LOW byte then HIGH byte.
    public func addHdlcChecksum() {
        let fcs = ByteBuffer.calculateChecksum(0xFFFF, fromByte: 1, bytesLength: count - 1, bytes: bytes)
        add(UInt8(fcs & 0xFF))
        add(UInt8(fcs >> 8))
    }

    public static let checksumTable: [UInt16] = [
        0x0000, 0x1189, 0x2312, 0x329B, 0x4624, 0x57AD, 0x6536, 0x74BF,
        0x8C48, 0x9DC1, 0xAF5A, 0xBED3, 0xCA6C, 0xDBE5, 0xE97E, 0xF8F7,
        0x1081, 0x0108, 0x3393, 0x221A, 0x56A5, 0x472C, 0x75B7, 0x643E,
        0x9CC9, 0x8D40, 0xBFDB, 0xAE52, 0xDAED, 0xCB64, 0xF9FF, 0xE876,
        0x2102, 0x308B, 0x0210, 0x1399, 0x6726, 0x76AF, 0x4434, 0x55BD,
        0xAD4A, 0xBCC3, 0x8E58, 0x9FD1, 0xEB6E, 0xFAE7, 0xC87C, 0xD9F5,
        0x3183, 0x200A, 0x1291, 0x0318, 0x77A7, 0x662E, 0x54B5, 0x453C,
        0xBDCB, 0xAC42, 0x9ED9, 0x8F50, 0xFBEF, 0xEA66, 0xD8FD, 0xC974,
        0x4204, 0x538D, 0x6116, 0x709F, 0x0420, 0x15A9, 0x2732, 0x36BB,
        0xCE4C, 0xDFC5, 0xED5E, 0xFCD7, 0x8868, 0x99E1, 0xAB7A, 0xBAF3,
        0x5285, 0x430C, 0x7197, 0x601E, 0x14A1, 0x0528, 0x37B3, 0x263A,
        0xDECD, 0xCF44, 0xFDDF, 0xEC56, 0x98E9, 0x8960, 0xBBFB, 0xAA72,
        0x6306, 0x728F, 0x4014, 0x519D, 0x2522, 0x34AB, 0x0630, 0x17B9,
        0xEF4E, 0xFEC7, 0xCC5C, 0xDDD5, 0xA96A, 0xB8E3, 0x8A78, 0x9BF1,
        0x7387, 0x620E, 0x5095, 0x411C, 0x35A3, 0x242A, 0x16B1, 0x0738,
        0xFFCF, 0xEE46, 0xDCDD, 0xCD54, 0xB9EB, 0xA862, 0x9AF9, 0x8B70,
        0x8408, 0x9581, 0xA71A, 0xB693, 0xC22C, 0xD3A5, 0xE13E, 0xF0B7,
        0x0840, 0x19C9, 0x2B52, 0x3ADB, 0x4E64, 0x5FED, 0x6D76, 0x7CFF,
        0x9489, 0x8500, 0xB79B, 0xA612, 0xD2AD, 0xC324, 0xF1BF, 0xE036,
        0x18C1, 0x0948, 0x3BD3, 0x2A5A, 0x5EE5, 0x4F6C, 0x7DF7, 0x6C7E,
        0xA50A, 0xB483, 0x8618, 0x9791, 0xE32E, 0xF2A7, 0xC03C, 0xD1B5,
        0x2942, 0x38CB, 0x0A50, 0x1BD9, 0x6F66, 0x7EEF, 0x4C74, 0x5DFD,
        0xB58B, 0xA402, 0x9699, 0x8710, 0xF3AF, 0xE226, 0xD0BD, 0xC134,
        0x39C3, 0x284A, 0x1AD1, 0x0B58, 0x7FE7, 0x6E6E, 0x5CF5, 0x4D7C,
        0xC60C, 0xD785, 0xE51E, 0xF497, 0x8028, 0x91A1, 0xA33A, 0xB2B3,
        0x4A44, 0x5BCD, 0x6956, 0x78DF, 0x0C60, 0x1DE9, 0x2F72, 0x3EFB,
        0xD68D, 0xC704, 0xF59F, 0xE416, 0x90A9, 0x8120, 0xB3BB, 0xA232,
        0x5AC5, 0x4B4C, 0x79D7, 0x685E, 0x1CE1, 0x0D68, 0x3FF3, 0x2E7A,
        0xE70E, 0xF687, 0xC41C, 0xD595, 0xA12A, 0xB0A3, 0x8238, 0x93B1,
        0x6B46, 0x7ACF, 0x4854, 0x59DD, 0x2D62, 0x3CEB, 0x0E70, 0x1FF9,
        0xF78F, 0xE606, 0xD49D, 0xC514, 0xB1AB, 0xA022, 0x92B9, 0x8330,
        0x7BC7, 0x6A4E, 0x58D5, 0x495C, 0x3DE3, 0x2C6A, 0x1EF1, 0x0F78,
    ]

    // MARK: - Length 8182 helpers

    /// Mirrors `ParseLength8182`: 1 byte < 0x81; >=0x81 uses 1 (≤0xFF),
    /// 0x82 uses 2 bytes, 0x83 uses 3 bytes.
    public func parseLength8182() throws -> Int {
        guard _parseOffset < count else {
            throw CommsError(L.message.msgNotEnoughData)
        }
        if bytes[_parseOffset] == 130 {
            if count > _parseOffset + 2 {
                let v = Int(bytes[_parseOffset + 1]) << 8 | Int(bytes[_parseOffset + 2])
                _parseOffset += 3
                return v
            }
        }
        if bytes[_parseOffset] == 129 {
            if count > _parseOffset + 1 {
                let v = Int(bytes[_parseOffset + 1])
                _parseOffset += 2
                return v
            }
        }
        let v = Int(bytes[_parseOffset])
        _parseOffset += 1
        return v
    }

    /// Mirrors `AddLength8182(bytesLength)`: writes a length using the
    /// shortest encoding: <0x80 single byte; 0x80..0xFF prefix 0x81;
    /// 0x100..0xFFFF prefix 0x82 + 2 bytes big-endian.
    public func addLength8182(_ length: Int) {
        if length > 0xFF {
            add(130)
            addUInt16(UInt16(length))
        } else if length > 0x7F {
            add(129)
            addUInt8(UInt8(length))
        } else {
            addUInt8(UInt8(length))
        }
    }

    // MARK: - Data parsing helper

    /// Mirrors `ParseData(withLen8182, toEnd)`: with a length prefix
    /// returns exactly `length` bytes following the prefix; without,
    /// returns everything up to `toEnd` bytes from the end.
    public func parseData(withLen8182: Bool, toEnd: Int, ignoreLengthValue: Bool) throws -> ByteBuffer {
        var num: Int
        if withLen8182 {
            num = try parseLength8182()
        } else {
            num = count - _parseOffset - toEnd
            if num < 0 {
                num = 0
            }
        }
        if ignoreLengthValue {
            num = count - _parseOffset
        }
        let result = getRangeBuffer(_parseOffset, num)
        _parseOffset += num
        return result
    }

    // MARK: - Cosem data sizes

    /// `CosemDataTypes.GetCosemSimpleTypeSize`
    static func cosemSimpleTypeSize(_ type: CosemDataType) -> Int {
        switch type {
        case .nullData: return 0
        case .boolean, .integer, .unsigned, .enumData: return 1
        case .bitString, .longData, .longUnsigned, .octetString:
            return 0 // variable; callers handle
        case .doubleLong, .float32: return 4
        case .doubleLongUnsigned: return 4
        case .long64, .long64Unsigned, .float64: return 8
        case .visibleString, .utf8String, .bcd: return 0
        case .dateTime: return 12
        case .date: return 5
        case .time: return 4
        case .arrayData, .structure, .compactArray: return 0
        }
    }

    /// `GetCosemComplexTypeSize` – reads a length prefix (0x81/0x82 aware)
    /// at `index`, advancing it past the prefix.
    public static func cosemComplexTypeSize(_ bytes: [UInt8], index: inout Int) throws -> Int {
        guard !bytes.isEmpty, index < bytes.count else {
            throw CommsError(L.message.msgEmptyDlmsArray)
        }
        var num = Int(bytes[index])
        index += 1
        if num < 129 {
            return num
        }
        guard index < bytes.count else {
            throw CommsError(L.message.msgDlmsArrayIsTooShort)
        }
        let first = bytes[index]
        index += 1
        num = Int(first)
        if index - 2 < bytes.count, bytes[index - 2] == 130 {
            num = (num << 8) | Int(bytes[index])
            index += 1
        }
        return num
    }
}

private extension StringProtocol {
    var endsWithNewLine: Bool {
        var s = Substring(self)
        if s.hasSuffix("\r") { s = s.dropLast() }
        return s.hasSuffix("\n")
    }
}
