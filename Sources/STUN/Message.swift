//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftRTC open source project
//
// Copyright (c) 2024 ngRTC and the SwiftRTC project authors
// Licensed under MIT License
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftRTC project authors
//
// SPDX-License-Identifier: MIT
//
//===----------------------------------------------------------------------===//
import Utils

/// Interfaces that are implemented by message attributes, shorthands for them,
/// or helpers for message fields as type or transaction id.
public protocol Setter {
    func addTo(_ m: Message) throws
}

/// Getter parses attribute from *Message.
public protocol Getter {
    mutating func getFrom(_ m: Message) throws
}

/// Checker checks *Message attribute.
public protocol Checker {
    func check(_ m: Message) throws
}

/// MAGIC_COOKIE is fixed value that aids in distinguishing STUN packets
/// from packets of other protocols when STUN is multiplexed with those
/// other protocols on the same Port.
///
/// The magic cookie field MUST contain the fixed value 0x2112A442 in
/// network byte order.
///
/// Defined in "STUN Message Structure", section 6.
public let magicCookie: UInt32 = 0x2112_A442
public let attributeHeaderSize: Int = 4
public let messageHeaderSize: Int = 20
let defaultRawCapacity: Int = 120
// TRANSACTION_ID_SIZE is length of transaction id array (in bytes).
public let transactionIdSize: Int = 12  // 96 bit

public struct TransactionId: Equatable {
    public var rawValue: [UInt8]

    /// new returns new random transaction ID using crypto/rand
    /// as source.
    public init() {
        self.rawValue = (0..<transactionIdSize).map { _ in UInt8.random(in: UInt8.min...UInt8.max)
        }
    }

    public static func == (lhs: TransactionId, rhs: TransactionId) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
}

extension TransactionId: Setter {
    public func addTo(_ m: Message) throws {
        m.transactionId = self
        m.writeTransactionId()
    }
}

/// isMessage returns true if b looks like STUN message.
/// Useful for multiplexing. is_message does not guarantee
/// that decoding will be successful.
public func isMessage(b: inout [UInt8]) -> Bool {
    b.count >= messageHeaderSize
        && UInt32.fromBeBytes(b[4], b[5], b[6], b[7]) == magicCookie
}

/// Message represents a single STUN packet. It uses aggressive internal
/// buffering to enable zero-allocation encoding and decoding,
/// so there are some usage constraints:
///
/// Message, its fields, results of m.Get or any attribute a.GetFrom
/// are valid only until Message.Raw is not modified.
public class Message: Equatable {
    var typ: MessageType
    var length: Int
    var transactionId: TransactionId
    var attributes: Attributes
    var raw: [UInt8]

    public init() {
        self.typ = bindingRequest
        self.length = 0
        self.transactionId = TransactionId()
        self.attributes = Attributes()
        self.raw = [UInt8](repeating: 0, count: messageHeaderSize)
    }

    public static func == (lhs: Message, rhs: Message) -> Bool {
        return
            lhs.typ == rhs.typ && lhs.length == rhs.length && lhs.transactionId == rhs.transactionId
            && lhs.attributes == rhs.attributes
    }

    // marshal_binary implements the encoding.BinaryMarshaler interface.
    public func marshalBinary() -> [UInt8] {
        // We can't return m.Raw, allocation is expected by implicit interface
        // contract induced by other implementations.
        return self.raw
    }

    // unmarshal_binary implements the encoding.BinaryUnmarshaler interface.
    public func unmarshalBinary(data: inout [UInt8]) throws {
        // We can't retain data, copy is expected by interface contract.
        self.raw = data
        try self.decode()
    }

    // NewTransactionID sets m.TransactionID to random value from crypto/rand
    // and returns error if any.
    public func newTransactionDd() {
        self.transactionId = TransactionId()
        self.writeTransactionId()
    }

    // Reset resets Message, attributes and underlying buffer length.
    public func reset() {
        self.raw = []
        self.length = 0
        self.attributes.rawAttributes = []
    }

    // grow ensures that internal buffer has n length.
    public func grow(_ n: Int, _ resize: Bool) {
        if self.raw.count >= n {
            if resize {
                self.raw = Array(self.raw[..<n])
            }
            return
        }
        self.raw.append(contentsOf: Array(repeating: 0, count: n - self.raw.count))
    }

    // Add appends new attribute to message. Not goroutine-safe.
    //
    // Value of attribute is copied to internal buffer so
    // it is safe to reuse v.
    public func add(_ t: AttrType, _ v: [UInt8]) {
        // Allocating buffer for TLV (type-length-value).
        // T = t, L = len(v), V = v.
        // m.Raw will look like:
        // [0:20]                               <- message header
        // [20:20+m.Length]                     <- existing message attributes
        // [20+m.Length:20+m.Length+len(v) + 4] <- allocated buffer for new TLV
        // [first:last]                         <- same as previous
        // [0 1|2 3|4    4 + len(v)]            <- mapping for allocated buffer
        //   T   L        V
        let allocSize = attributeHeaderSize + v.count  // ~ len(TLV) = len(TL) + len(V)
        let first = messageHeaderSize + self.length  // first byte number
        var last = first + allocSize  // last byte number
        self.grow(last, true)  // growing cap(Raw) to fit TLV
        self.length += allocSize  // rendering length change

        // Encoding attribute TLV to allocated buffer.
        self.raw.replaceSubrange(first..<first + 2, with: t.value().toBeBytes())  // T
        self.raw.replaceSubrange(
            first + 2..<first + attributeHeaderSize, with: UInt16(v.count).toBeBytes())  // L
        self.raw.replaceSubrange(first + attributeHeaderSize..<last, with: v)  // V

        let attr = RawAttribute(
            typ: t,  // T
            length: v.count,  // L
            value: Array(self.raw[first + attributeHeaderSize..<last])  // V
        )

        // Checking that attribute value needs padding.
        if attr.length % padding != 0 {
            // Performing padding.
            let bytesToAdd = nearestPaddedValueLength(v.count) - v.count
            last += bytesToAdd
            self.grow(last, true)
            // setting all padding bytes to zero
            // to prevent data leak from previous
            // data in next bytes_to_add bytes
            self.raw.replaceSubrange(
                last - bytesToAdd..<last, with: Array(repeating: 0, count: bytesToAdd))
            self.length += bytesToAdd  // rendering length change
        }
        self.attributes.rawAttributes.append(attr)
        self.writeLength()
    }

    // WriteLength writes m.Length to m.Raw.
    public func writeLength() {
        self.grow(4, false)
        self.raw.replaceSubrange(2..<4, with: UInt16(self.length).toBeBytes())
    }

    // WriteHeader writes header to underlying buffer. Not goroutine-safe.
    public func writeHeader() {
        self.grow(messageHeaderSize, false)

        self.writeType()
        self.writeLength()
        self.raw.replaceSubrange(4..<8, with: magicCookie.toBeBytes())  // magic cookie
        self.raw.replaceSubrange(8..<messageHeaderSize, with: self.transactionId.rawValue)
        // transaction ID
    }

    // WriteTransactionID writes m.TransactionID to m.Raw.
    public func writeTransactionId() {
        self.raw.replaceSubrange(8..<messageHeaderSize, with: self.transactionId.rawValue)
        // transaction ID
    }

    // WriteAttributes encodes all m.Attributes to m.
    public func writeAttributes() {
        for a in self.attributes.rawAttributes {
            self.add(a.typ, a.value)
        }
    }

    // WriteType writes m.Type to m.Raw.
    public func writeType() {
        self.grow(2, false)
        self.raw.replaceSubrange(..<2, with: self.typ.value().toBeBytes())  // message type
    }

    // SetType sets m.Type and writes it to m.Raw.
    public func setType(_ t: MessageType) {
        self.typ = t
        self.writeType()
    }

    // Encode re-encodes message into m.Raw.
    public func encode() {
        self.raw = []
        self.writeHeader()
        self.length = 0
        self.writeAttributes()
    }

    // Decode decodes m.Raw into m.
    public func decode() throws {
        // decoding message header
        if self.raw.count < messageHeaderSize {
            throw STUNError.errUnexpectedHeaderEof
        }

        let t = UInt16.fromBeBytes(self.raw[0], self.raw[1])  // first 2 bytes
        let size = Int(UInt16.fromBeBytes(self.raw[2], self.raw[3]))  // second 2 bytes
        // last 4 bytes
        let cookie = UInt32.fromBeBytes(self.raw[4], self.raw[5], self.raw[6], self.raw[7])
        let fullSize = messageHeaderSize + size  // len(m.Raw)

        if cookie != magicCookie {
            throw STUNError.errInvalidMagicCookie(cookie)
        }
        if self.raw.count < fullSize {
            throw STUNError.errBufferTooSmall
        }

        // saving header data
        self.typ.readValue(t)
        self.length = size
        self.transactionId.rawValue = Array(self.raw[8..<messageHeaderSize])

        self.attributes.rawAttributes = []
        var offset = 0
        var b = self.raw[messageHeaderSize..<fullSize]

        while offset < size {
            // checking that we have enough bytes to read header
            if b.count < attributeHeaderSize {
                throw STUNError.errBufferTooSmall
            }

            var a = RawAttribute(
                typ: compatAttrType(UInt16.fromBeBytes(b[0], b[1])),  // first 2 bytes
                length: Int(UInt16.fromBeBytes(b[2], b[3])),  // second 2 bytes
                value: []
            )
            let al = a.length  // attribute length
            let abuffl = nearestPaddedValueLength(al)  // expected buffer length (with padding)

            b = b[attributeHeaderSize...]  // slicing again to simplify value read
            offset += attributeHeaderSize
            if b.count < abuffl {
                // checking size
                throw STUNError.errBufferTooSmall
            }
            a.value = Array(b[..<al])
            offset += abuffl
            b = b[abuffl...]

            self.attributes.rawAttributes.append(a)
        }
    }

    // WriteTo implements WriterTo via calling Write(m.Raw) on w and returning
    // call result.
    public func writeTo(writer: inout [UInt8]) throws -> Int {
        let n = min(writer.count, self.raw.count)
        writer.replaceSubrange(..<n, with: self.raw[..<n])
        return n
    }

    // ReadFrom implements ReaderFrom. Reads message from r into m.Raw,
    // Decodes it and return error if any. If m.Raw is too small, will return
    // ErrUnexpectedEOF, ErrUnexpectedHeaderEOF or *DecodeErr.
    //
    // Can return *DecodeErr while decoding too.
    public func readFrom(reader: [UInt8]) throws -> Int {
        let n = reader.count
        self.raw = reader
        try self.decode()
        return n
    }

    // Write decodes message and return error if any.
    //
    // Any error is unrecoverable, but message could be partially decoded.
    public func write(_ tbuf: [UInt8]) throws -> Int {
        self.raw = []
        self.raw.append(contentsOf: tbuf)
        try self.decode()
        return tbuf.count
    }

    // CloneTo clones m to b securing any further m mutations.
    public func cloneTo(b: Message) throws {
        b.raw = []
        b.raw.append(contentsOf: self.raw)
        try b.decode()
    }

    // Contains return true if message contain t attribute.
    public func contains(t: AttrType) -> Bool {
        for a in self.attributes.rawAttributes {
            if a.typ == t {
                return true
            }
        }
        return false
    }

    // get returns byte slice that represents attribute value,
    // if there is no attribute with such type,
    // ErrAttributeNotFound is returned.
    public func get(_ t: AttrType) throws -> [UInt8] {
        let (v, ok) = self.attributes.get(t)
        if !ok {
            throw STUNError.errAttributeNotFound
        }
        return v.value
    }

    // Build resets message and applies setters to it in batch, returning on
    // first error. To prevent allocations, pass pointers to values.
    //
    // Example:
    //  var (
    //      t        = BindingRequest
    //      username = NewUsername("username")
    //      nonce    = NewNonce("nonce")
    //      realm    = NewRealm("example.org")
    //  )
    //  m := new(Message)
    //  m.Build(t, username, nonce, realm)     // 4 allocations
    //  m.Build(&t, &username, &nonce, &realm) // 0 allocations
    //
    // See BenchmarkBuildOverhead.
    public func build(setters: inout [Setter]) throws {
        self.reset()
        self.writeHeader()
        for s in setters {
            try s.addTo(self)
        }
    }

    // Check applies checkers to message in batch, returning on first error.
    public func check(checkers: inout [Checker]) throws {
        for c in checkers {
            try c.check(self)
        }
    }

    /*TODO?
     // Parse applies getters to message in batch, returning on first error.
     public func parse(getters: inout [inout Getter]) throws {
         for c in getters {
             try c.getFrom(self)
         }
     }*/
}

extension Message: Setter {
    public func addTo(_ m: Message) throws {
        m.transactionId = self.transactionId
        m.writeTransactionId()
    }
}

/// Possible values for message class in STUN Message Type.
public let classRequest: MessageClass = MessageClass(0x00)
public let classIndication: MessageClass = MessageClass(0x01)
public let classSuccessResponse: MessageClass = MessageClass(0x02)
public let classErrorResponse: MessageClass = MessageClass(0x03)

/// MessageClass is 8-bit representation of 2-bit class of STUN Message Class.
public struct MessageClass: Equatable, CustomStringConvertible {
    var rawValue: UInt8

    public var description: String {
        switch self.rawValue {
        case 0x00:
            return "request"
        case 0x01:
            return "indication"
        case 0x02:
            return "success response"
        case 0x03:
            return "error response"
        default:
            return "unknown message class"
        }
    }

    public init(_ rawValue: UInt8) {
        self.rawValue = rawValue
    }
}

/// Possible methods for STUN Message.
public let methodBinding: Method = Method(0x001)
public let methodAllocate: Method = Method(0x003)
public let methodRefresh: Method = Method(0x004)
public let methodSend: Method = Method(0x006)
public let methodData: Method = Method(0x007)
public let methodCreatePermission: Method = Method(0x008)
public let methodChannelBind: Method = Method(0x009)

/// Methods from RFC 6062.
public let methodConnect: Method = Method(0x000a)
public let methodConnectionBind: Method = Method(0x000b)
public let methodConnectionAttempt: Method = Method(0x000c)

/// Method is uint16 representation of 12-bit STUN method.
public struct Method: Equatable, CustomStringConvertible {
    var rawValue: UInt16

    public var description: String {
        switch self.rawValue {
        case 0x001:
            return "Binding"
        case 0x003:
            return "Allocate"
        case 0x004:
            return "Refresh"
        case 0x006:
            return "Send"
        case 0x007:
            return "Data"
        case 0x008:
            return "CreatePermission"
        case 0x009:
            return "ChannelBind"

        // RFC 6062.
        case 0x000a:
            return "Connect"
        case 0x000b:
            return "ConnectionBind"
        case 0x000c:
            return "ConnectionAttempt"
        default:
            return "0x\(String(self.rawValue, radix: 16, uppercase: false))"
        }
    }

    public init(_ rawValue: UInt16) {
        self.rawValue = rawValue
    }
}

/// Common STUN message types.
/// Binding request message type.
public let bindingRequest: MessageType = MessageType(
    method: methodBinding,
    messageClass: classRequest
)
/// Binding success response message type
public let bindingSuccess: MessageType = MessageType(
    method: methodBinding,
    messageClass: classSuccessResponse
)
/// Binding error response message type.
public let bindigError: MessageType = MessageType(
    method: methodBinding,
    messageClass: classErrorResponse
)

let methodAbits: UInt16 = 0xf  // 0b0000000000001111
let methodBbits: UInt16 = 0x70  // 0b0000000001110000
let methodDbits: UInt16 = 0xf80  // 0b0000111110000000

let methodBshift: UInt16 = 1
let methodDshift: UInt16 = 2

let firstBit: UInt16 = 0x1
let secondBit: UInt16 = 0x2

let c0Bit: UInt16 = firstBit
let c1Bit: UInt16 = secondBit

let classC0Shift: UInt16 = 4
let classC1Shift: UInt16 = 7

// MessageType is STUN Message Type Field.
public struct MessageType: Equatable, CustomStringConvertible {
    var method: Method  // e.g. binding
    var messageClass: MessageClass  // e.g. request

    public init(method: Method, messageClass: MessageClass) {
        self.method = method
        self.messageClass = messageClass
    }

    public var description: String {
        return "\(self.method) \(messageClass)"
    }

    /// value returns bit representation of messageType.
    public func value() -> UInt16 {
        //     0                 1
        //     2  3  4 5 6 7 8 9 0 1 2 3 4 5
        //    +--+--+-+-+-+-+-+-+-+-+-+-+-+-+
        //    |M |M |M|M|M|C|M|M|M|C|M|M|M|M|
        //    |11|10|9|8|7|1|6|5|4|0|3|2|1|0|
        //    +--+--+-+-+-+-+-+-+-+-+-+-+-+-+
        // Figure 3: Format of STUN Message Type Field

        // Warning: Abandon all hope ye who enter here.
        // Splitting M into A(M0-M3), B(M4-M6), D(M7-M11).
        var method = self.method.rawValue
        let a = method & methodAbits  // A = M * 0b0000000000001111 (right 4 bits)
        let b = method & methodBbits  // B = M * 0b0000000001110000 (3 bits after A)
        let d = method & methodDbits  // D = M * 0b0000111110000000 (5 bits after B)

        // Shifting to add "holes" for C0 (at 4 bit) and C1 (8 bit).
        method = a + (b << methodBshift) + (d << methodDshift)

        // C0 is zero bit of C, C1 is first bit.
        // C0 = C * 0b01, C1 = (C * 0b10) >> 1
        // Ct = C0 << 4 + C1 << 8.
        // Optimizations: "((C * 0b10) >> 1) << 8" as "(C * 0b10) << 7"
        // We need C0 shifted by 4, and C1 by 8 to fit "11" and "7" positions
        // (see figure 3).
        let c = UInt16(self.messageClass.rawValue)
        let c0 = (c & c0Bit) << classC0Shift
        let c1 = (c & c1Bit) << classC1Shift
        let messageClass = c0 + c1

        return method + messageClass
    }

    /// readValue decodes uint16 into MessageType.
    public mutating func readValue(_ value: UInt16) {
        // Decoding class.
        // We are taking first bit from v >> 4 and second from v >> 7.
        let c0 = (value >> classC0Shift) & c0Bit
        let c1 = (value >> classC1Shift) & c1Bit
        let messageClass = c0 + c1
        self.messageClass = MessageClass(UInt8(messageClass))

        // Decoding method.
        let a = value & methodAbits  // A(M0-M3)
        let b = (value >> methodBshift) & methodBbits  // B(M4-M6)
        let d = (value >> methodDshift) & methodDbits  // D(M7-M11)
        let m = a + b + d
        self.method = Method(m)
    }
}

extension MessageType: Setter {
    /// addTo sets m type to t.
    public func addTo(_ m: Message) throws {
        m.setType(self)
    }
}
