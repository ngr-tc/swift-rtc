import NIOCore
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
import Shared

/// Interfaces that are implemented by message attributes, shorthands for them,
/// or helpers for message fields as type or transaction id.
public protocol Setter {
    func addTo(_ m: inout Message) throws
}

/// Getter parses attribute from *Message.
public protocol Getter {
    mutating func getFrom(_ m: inout Message) throws
}

/// Checker checks *Message attribute.
public protocol Checker {
    func check(_ m: inout Message) throws
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

public struct TransactionId: Equatable, Hashable {
    public var rawValue: ByteBuffer

    /// new returns new random transaction ID using crypto/rand
    /// as source.
    public init() {
        self.rawValue = ByteBuffer(
            bytes: (0..<transactionIdSize).map { _ in UInt8.random(in: UInt8.min...UInt8.max)
            })
    }

    public init(_ rawValue: [UInt8]) {
        self.rawValue = ByteBuffer(bytes: rawValue)
    }

    public init(_ rawValue: ByteBuffer) {
        self.rawValue = rawValue
    }

    public static func == (lhs: TransactionId, rhs: TransactionId) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
}

extension TransactionId: CustomStringConvertible {
    public var description: String {
        return Base64.encode(
            bytes: self.rawValue.getBytes(at: 0, length: self.rawValue.readableBytes) ?? [])
    }
}

extension TransactionId: Setter {
    public func addTo(_ m: inout Message) throws {
        m.transactionId = self
        m.writeTransactionId()
    }
}

/// isMessage returns true if b looks like STUN message.
/// Useful for multiplexing. is_message does not guarantee
/// that decoding will be successful.
public func isMessage(b: ByteBufferView) -> Bool {
    b.count >= messageHeaderSize
        && UInt32.fromBeBytes(b.at(4), b.at(5), b.at(6), b.at(7)) == magicCookie
}

/// Message represents a single STUN packet. It uses aggressive internal
/// buffering to enable zero-allocation encoding and decoding,
/// so there are some usage constraints:
///
/// Message, its fields, results of m.Get or any attribute a.GetFrom
/// are valid only until Message.Raw is not modified.
public struct Message: Equatable {
    public var typ: MessageType
    public var length: Int
    public var transactionId: TransactionId
    public var attributes: Attributes
    public var raw: ByteBuffer

    public init() {
        self.typ = MessageType(method: Method(0), messageClass: MessageClass(0))
        self.length = 0
        self.transactionId = TransactionId(ByteBuffer(repeating: 0, count: transactionIdSize))
        self.attributes = Attributes()
        self.raw = ByteBuffer(repeating: 0, count: messageHeaderSize)
    }

    public static func == (lhs: Message, rhs: Message) -> Bool {
        return
            lhs.typ == rhs.typ && lhs.length == rhs.length && lhs.transactionId == rhs.transactionId
            && lhs.attributes == rhs.attributes
    }

    // marshal_binary implements the encoding.BinaryMarshaler interface.
    public func marshalBinary() -> ByteBuffer {
        // We can't return m.Raw, allocation is expected by implicit interface
        // contract induced by other implementations.
        return self.raw
    }

    // unmarshal_binary implements the encoding.BinaryUnmarshaler interface.
    public mutating func unmarshalBinary(data: ByteBuffer) throws {
        // We can't retain data, copy is expected by interface contract.
        self.raw = data
        try self.decode()
    }

    // NewTransactionID sets m.TransactionID to random value from crypto/rand
    // and returns error if any.
    public mutating func newTransactionDd() {
        self.transactionId = TransactionId()
        self.writeTransactionId()
    }

    // Reset resets Message, attributes and underlying buffer length.
    public mutating func reset() {
        self.raw = ByteBuffer()
        self.length = 0
        self.attributes.rawAttributes = []
    }

    // grow ensures that internal buffer has n length.
    public mutating func grow(_ n: Int, _ resize: Bool) {
        if self.raw.readableBytes >= n {
            if resize {
                self.raw = ByteBuffer(self.raw.readableBytesView[..<n])
            }
            return
        }
        self.raw.writeBytes(Array(repeating: 0, count: n - self.raw.readableBytes))
    }

    // Add appends new attribute to message. Not goroutine-safe.
    //
    // Value of attribute is copied to internal buffer so
    // it is safe to reuse v.
    public mutating func add(_ t: AttrType, _ v: ByteBufferView) {
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
        self.raw.setBytes(t.value().toBeBytes(), at: first)  // T
        self.raw.setBytes(UInt16(v.count).toBeBytes(), at: first + 2)  // L
        self.raw.setBytes(v, at: first + attributeHeaderSize)  // V

        let attr = RawAttribute(
            typ: t,  // T
            length: v.count,  // L
            value: ByteBuffer(self.raw.readableBytesView[first + attributeHeaderSize..<last])  // V
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
            self.raw.setBytes(Array(repeating: 0, count: bytesToAdd), at: last - bytesToAdd)
            self.length += bytesToAdd  // rendering length change
        }
        self.attributes.rawAttributes.append(attr)
        self.writeLength()
    }

    // WriteLength writes m.Length to m.Raw.
    public mutating func writeLength() {
        self.grow(4, false)
        self.raw.setBytes(UInt16(self.length).toBeBytes(), at: 2)
    }

    // WriteHeader writes header to underlying buffer. Not goroutine-safe.
    public mutating func writeHeader() {
        self.grow(messageHeaderSize, false)

        self.writeType()
        self.writeLength()
        self.raw.setBytes(magicCookie.toBeBytes(), at: 4)  // magic cookie
        self.raw.setBuffer(self.transactionId.rawValue, at: 8)
        // transaction ID
    }

    // WriteTransactionID writes m.TransactionID to m.Raw.
    public mutating func writeTransactionId() {
        self.raw.setBuffer(self.transactionId.rawValue, at: 8)
        // transaction ID
    }

    // WriteAttributes encodes all m.Attributes to m.
    public mutating func writeAttributes() {
        for a in self.attributes.rawAttributes {
            self.add(a.typ, a.value.readableBytesView)
        }
    }

    // WriteType writes m.Type to m.Raw.
    public mutating func writeType() {
        self.grow(2, false)
        self.raw.setBytes(self.typ.value().toBeBytes(), at: 0)  // message type
    }

    // SetType sets m.Type and writes it to m.Raw.
    public mutating func setType(_ t: MessageType) {
        self.typ = t
        self.writeType()
    }

    // Encode re-encodes message into m.Raw.
    public mutating func encode() {
        self.raw = ByteBuffer()
        self.writeHeader()
        self.length = 0
        self.writeAttributes()
    }

    // Decode decodes m.Raw into m.
    public mutating func decode() throws {
        let rawView = self.raw.readableBytesView
        // decoding message header
        if rawView.count < messageHeaderSize {
            throw StunError.errUnexpectedHeaderEof
        }

        let t = UInt16.fromBeBytes(rawView[0], rawView[1])  // first 2 bytes
        let size = Int(UInt16.fromBeBytes(rawView[2], rawView[3]))  // second 2 bytes
        // last 4 bytes
        let cookie = UInt32.fromBeBytes(rawView[4], rawView[5], rawView[6], rawView[7])
        let fullSize = messageHeaderSize + size  // len(m.Raw)

        if cookie != magicCookie {
            throw StunError.errInvalidMagicCookie(cookie)
        }
        if rawView.count < fullSize {
            throw StunError.errBufferTooSmall
        }

        // saving header data
        self.typ.readValue(t)
        self.length = size
        self.transactionId.rawValue = ByteBuffer(rawView[8..<messageHeaderSize])

        self.attributes.rawAttributes = []
        var offset = 0
        var b = messageHeaderSize
        var bCount = fullSize - messageHeaderSize

        while offset < size {
            // checking that we have enough bytes to read header
            if bCount < attributeHeaderSize {
                throw StunError.errBufferTooSmall
            }

            var a = RawAttribute(
                typ: compatAttrType(UInt16.fromBeBytes(rawView[b + 0], rawView[b + 1])),
                length: Int(UInt16.fromBeBytes(rawView[b + 2], rawView[b + 3])),
                value: ByteBuffer()
            )
            let al = a.length  // attribute length
            let abuffl = nearestPaddedValueLength(al)  // expected buffer length (with padding)

            b += attributeHeaderSize  // slicing again to simplify value read
            bCount -= attributeHeaderSize
            offset += attributeHeaderSize

            if bCount < abuffl {
                // checking size
                throw StunError.errBufferTooSmall
            }
            a.value = ByteBuffer(rawView[b..<b + al])
            b += abuffl
            bCount -= abuffl
            offset += abuffl

            self.attributes.rawAttributes.append(a)
        }
    }

    // WriteTo implements WriterTo via calling Write(m.Raw) on w and returning
    // call result.
    public mutating func writeTo(writer: inout ByteBuffer) throws -> Int {
        writer.writeImmutableBuffer(self.raw)
        return self.raw.readableBytes
    }

    // ReadFrom implements ReaderFrom. Reads message from r into m.Raw,
    // Decodes it and return error if any. If m.Raw is too small, will return
    // ErrUnexpectedEOF, ErrUnexpectedHeaderEOF or *DecodeErr.
    //
    // Can return *DecodeErr while decoding too.
    public mutating func readFrom(_ reader: ByteBufferView) throws -> Int {
        let n = reader.count
        self.raw = ByteBuffer(reader)
        try self.decode()
        return n
    }

    // Write decodes message and return error if any.
    //
    // Any error is unrecoverable, but message could be partially decoded.
    public mutating func write(_ tbuf: ByteBufferView) throws -> Int {
        self.raw = ByteBuffer(tbuf)
        try self.decode()
        return tbuf.count
    }

    // CloneTo clones m to b securing any further m mutations.
    public func cloneTo(b: inout Message) throws {
        b.raw = self.raw  //TODO: check whether shared memory buffer is ok?
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
    public func get(_ t: AttrType) throws -> ByteBuffer {
        let (v, ok) = self.attributes.get(t)
        if !ok {
            throw StunError.errAttributeNotFound
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
    public mutating func build(_ setters: [Setter]) throws {
        self.reset()
        self.writeHeader()
        for s in setters {
            try s.addTo(&self)
        }
    }

    // Check applies checkers to message in batch, returning on first error.
    public mutating func check(_ checkers: [Checker]) throws {
        for c in checkers {
            try c.check(&self)
        }
    }

    /*FIXME: ?
     // Parse applies getters to message in batch, returning on first error.
     public func parse(getters: inout [inout Getter]) throws {
         for c in getters {
             try c.getFrom(self)
         }
     }*/
}

extension Message: CustomStringConvertible {
    public var description: String {
        return
            "\(self.typ.description) l=\(self.length) attrs=\(self.attributes.rawAttributes.count) id=\(self.transactionId.description)"
    }
}

extension Message: Setter {
    public func addTo(_ m: inout Message) throws {
        m.transactionId = self.transactionId
        m.writeTransactionId()
    }
}

/// Possible values for MessageClass in STUN Message Type.
public let classRequest: MessageClass = MessageClass(0x00)
public let classIndication: MessageClass = MessageClass(0x01)
public let classSuccessResponse: MessageClass = MessageClass(0x02)
public let classErrorResponse: MessageClass = MessageClass(0x03)

/// MessageClass is 8-bit representation of 2-bit of STUN MessageClass.
public struct MessageClass: Equatable {
    var rawValue: UInt8

    public init(_ rawValue: UInt8) {
        self.rawValue = rawValue
    }
}

extension MessageClass: CustomStringConvertible {
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
public struct Method: Equatable {
    var rawValue: UInt16

    public init(_ rawValue: UInt16) {
        self.rawValue = rawValue
    }
}

extension Method: CustomStringConvertible {
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
public struct MessageType: Equatable {
    var method: Method  // e.g. binding
    var messageClass: MessageClass  // e.g. request

    public init(method: Method, messageClass: MessageClass) {
        self.method = method
        self.messageClass = messageClass
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

extension MessageType: CustomStringConvertible {
    public var description: String {
        return "\(self.method) \(messageClass)"
    }
}

extension MessageType: Setter {
    /// addTo sets m type to t.
    public func addTo(_ m: inout Message) throws {
        m.setType(self)
    }
}
