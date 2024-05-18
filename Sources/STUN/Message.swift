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
    func addTo(m: inout Message) throws
}

/// Getter parses attribute from *Message.
public protocol Getter {
    mutating func getFrom(m: inout Message) throws
}

/// Checker checks *Message attribute.
public protocol Checker {
    func check(m: inout Message) throws
}

/// MAGIC_COOKIE is fixed value that aids in distinguishing STUN packets
/// from packets of other protocols when STUN is multiplexed with those
/// other protocols on the same Port.
///
/// The magic cookie field MUST contain the fixed value 0x2112A442 in
/// network byte order.
///
/// Defined in "STUN Message Structure", section 6.
public let MAGIC_COOKIE: UInt32 = 0x2112_A442
public let ATTRIBUTE_HEADER_SIZE: Int = 4
public let MESSAGE_HEADER_SIZE: Int = 20
let DEFAULT_RAW_CAPACITY: Int = 120
// TRANSACTION_ID_SIZE is length of transaction id array (in bytes).
public let TRANSACTION_ID_SIZE: Int = 12  // 96 bit

public struct TransactionId: Equatable, Setter {
    public var rawValue: [UInt8]

    /// new returns new random transaction ID using crypto/rand
    /// as source.
    public init() {
        self.rawValue = (0..<TRANSACTION_ID_SIZE).map { _ in UInt8.random(in: UInt8.min...UInt8.max)
        }
    }

    public static func == (lhs: TransactionId, rhs: TransactionId) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }

    public func addTo(m: inout Message) throws {
        m.transactionId = self
        m.writeTransactionId()
    }
}

/// isMessage returns true if b looks like STUN message.
/// Useful for multiplexing. is_message does not guarantee
/// that decoding will be successful.
public func isMessage(b: inout [UInt8]) -> Bool {
    b.count >= MESSAGE_HEADER_SIZE
        && UInt32.fromBeBytes(byte1: b[4], byte2: b[5], byte3: b[6], byte4: b[7]) == MAGIC_COOKIE
}

/// Message represents a single STUN packet. It uses aggressive internal
/// buffering to enable zero-allocation encoding and decoding,
/// so there are some usage constraints:
///
/// Message, its fields, results of m.Get or any attribute a.GetFrom
/// are valid only until Message.Raw is not modified.
public class Message: Equatable, Setter {
    var typ: MessageType
    var length: Int
    var transactionId: TransactionId
    //var attributes: Attributes
    var raw: [UInt8]

    public init() {
        self.typ = BINDING_REQUEST
        self.length = 0
        self.transactionId = TransactionId()
        self.raw = [UInt8](repeating: 0, count: MESSAGE_HEADER_SIZE)
    }

    /// writeTransactionID writes m.TransactionID to m.Raw.
    public func writeTransactionId() {
        self.raw[8..<MESSAGE_HEADER_SIZE] = self.transactionId.rawValue[...]
    }

    public static func == (lhs: Message, rhs: Message) -> Bool {
        return
            //TODO: lhs.typ == rhs.typ && &&
            // lhs.attributes == rhs.attributes &&
            lhs.transactionId == rhs.transactionId && lhs.length == rhs.length
    }

    public func addTo(m: inout Message) throws {
        m.transactionId = self.transactionId
        m.writeTransactionId()
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

    /*
         // Reset resets Message, attributes and underlying buffer length.
         public func reset() {
             self.raw = []
             self.length = 0
             self.attributes.0.clear();
         }
    
         // grow ensures that internal buffer has n length.
         fn grow(&mut self, n: usize, resize: bool) {
             if self.raw.len() >= n {
                 if resize {
                     self.raw.resize(n, 0);
                 }
                 return;
             }
             self.raw.extend_from_slice(&vec![0; n - self.raw.len()]);
         }

         // Add appends new attribute to message. Not goroutine-safe.
         //
         // Value of attribute is copied to internal buffer so
         // it is safe to reuse v.
         public func add(&mut self, t: AttrType, v: &[u8]) {
             // Allocating buffer for TLV (type-length-value).
             // T = t, L = len(v), V = v.
             // m.Raw will look like:
             // [0:20]                               <- message header
             // [20:20+m.Length]                     <- existing message attributes
             // [20+m.Length:20+m.Length+len(v) + 4] <- allocated buffer for new TLV
             // [first:last]                         <- same as previous
             // [0 1|2 3|4    4 + len(v)]            <- mapping for allocated buffer
             //   T   L        V
             let alloc_size = ATTRIBUTE_HEADER_SIZE + v.len(); // ~ len(TLV) = len(TL) + len(V)
             let first = MESSAGE_HEADER_SIZE + self.length as usize; // first byte number
             let mut last = first + alloc_size; // last byte number
             self.grow(last, true); // growing cap(Raw) to fit TLV
             self.length += alloc_size as u32; // rendering length change

             // Encoding attribute TLV to allocated buffer.
             let buf = &mut self.raw[first..last];
             buf[0..2].copy_from_slice(&t.value().to_be_bytes()); // T
             buf[2..4].copy_from_slice(&(v.len() as u16).to_be_bytes()); // L

             let value = &mut buf[ATTRIBUTE_HEADER_SIZE..];
             value.copy_from_slice(v); // V

             let attr = RawAttribute {
                 typ: t,                 // T
                 length: v.len() as u16, // L
                 value: value.to_vec(),  // V
             };

             // Checking that attribute value needs padding.
             if attr.length as usize % PADDING != 0 {
                 // Performing padding.
                 let bytes_to_add = nearest_padded_value_length(v.len()) - v.len();
                 last += bytes_to_add;
                 self.grow(last, true);
                 // setting all padding bytes to zero
                 // to prevent data leak from previous
                 // data in next bytes_to_add bytes
                 let buf = &mut self.raw[last - bytes_to_add..last];
                 for b in buf {
                     *b = 0;
                 }
                 self.length += bytes_to_add as u32; // rendering length change
             }
             self.attributes.0.push(attr);
             self.write_length();
         }

         // WriteLength writes m.Length to m.Raw.
         public func write_length(&mut self) {
             self.grow(4, false);
             self.raw[2..4].copy_from_slice(&(self.length as u16).to_be_bytes());
         }

         // WriteHeader writes header to underlying buffer. Not goroutine-safe.
         public func write_header(&mut self) {
             self.grow(MESSAGE_HEADER_SIZE, false);

             self.write_type();
             self.write_length();
             self.raw[4..8].copy_from_slice(&MAGIC_COOKIE.to_be_bytes()); // magic cookie
             self.raw[8..MESSAGE_HEADER_SIZE].copy_from_slice(&self.transaction_id.0);
             // transaction ID
         }

         // WriteTransactionID writes m.TransactionID to m.Raw.
         public func write_transaction_id(&mut self) {
             self.raw[8..MESSAGE_HEADER_SIZE].copy_from_slice(&self.transaction_id.0);
             // transaction ID
         }

         // WriteAttributes encodes all m.Attributes to m.
         public func write_attributes(&mut self) {
             let attributes: Vec<RawAttribute> = self.attributes.0.drain(..).collect();
             for a in &attributes {
                 self.add(a.typ, &a.value);
             }
             self.attributes = Attributes(attributes);
         }

    */
    // WriteType writes m.Type to m.Raw.
    public func writeType() {
        //TODO: self.grow(2, false);
        //TODO: self.raw[..2].copy_from_slice(&self.typ.value().to_be_bytes()); // message type
    }

    // SetType sets m.Type and writes it to m.Raw.
    public func setType(_ t: MessageType) {
        self.typ = t
        self.writeType()
    }
    
         // Encode re-encodes message into m.Raw.
        /* public func encode() {
             self.raw = []
             self.writeHeader()
             self.length = 0;
             self.writeAttributes()
         }*/
    
         // Decode decodes m.Raw into m.
         public func decode() throws  {
             /*TODO:
             // decoding message header
             let buf = &self.raw;
             if buf.len() < MESSAGE_HEADER_SIZE {
                 return Err(Error::ErrUnexpectedHeaderEof);
             }

             let t = u16::from_be_bytes([buf[0], buf[1]]); // first 2 bytes
             let size = u16::from_be_bytes([buf[2], buf[3]]) as usize; // second 2 bytes
             let cookie = u32::from_be_bytes([buf[4], buf[5], buf[6], buf[7]]); // last 4 bytes
             let full_size = MESSAGE_HEADER_SIZE + size; // len(m.Raw)

             if cookie != MAGIC_COOKIE {
                 return Err(Error::Other(format!(
                     "{cookie:x} is invalid magic cookie (should be {MAGIC_COOKIE:x})"
                 )));
             }
             if buf.len() < full_size {
                 return Err(Error::Other(format!(
                     "buffer length {} is less than {} (expected message size)",
                     buf.len(),
                     full_size
                 )));
             }

             // saving header data
             self.typ.read_value(t);
             self.length = size as u32;
             self.transaction_id
                 .0
                 .copy_from_slice(&buf[8..MESSAGE_HEADER_SIZE]);

             self.attributes.0.clear();
             let mut offset = 0;
             let mut b = &buf[MESSAGE_HEADER_SIZE..full_size];

             while offset < size {
                 // checking that we have enough bytes to read header
                 if b.len() < ATTRIBUTE_HEADER_SIZE {
                     return Err(Error::Other(format!(
                         "buffer length {} is less than {} (expected header size)",
                         b.len(),
                         ATTRIBUTE_HEADER_SIZE
                     )));
                 }

                 let mut a = RawAttribute {
                     typ: compat_attr_type(u16::from_be_bytes([b[0], b[1]])), // first 2 bytes
                     length: u16::from_be_bytes([b[2], b[3]]),                // second 2 bytes
                     ..Default::default()
                 };
                 let a_l = a.length as usize; // attribute length
                 let a_buff_l = nearest_padded_value_length(a_l); // expected buffer length (with padding)

                 b = &b[ATTRIBUTE_HEADER_SIZE..]; // slicing again to simplify value read
                 offset += ATTRIBUTE_HEADER_SIZE;
                 if b.len() < a_buff_l {
                     // checking size
                     return Err(Error::Other(format!(
                         "buffer length {} is less than {} (expected value size for {})",
                         b.len(),
                         a_buff_l,
                         a.typ
                     )));
                 }
                 a.value = b[..a_l].to_vec();
                 offset += a_buff_l;
                 b = &b[a_buff_l..];

                 self.attributes.0.push(a);
             }

             Ok(())*/
         }
/*
         // WriteTo implements WriterTo via calling Write(m.Raw) on w and returning
         // call result.
         public func write_to<W: Write>(&self, writer: &mut W) -> Result<usize> {
             let n = writer.write(&self.raw)?;
             Ok(n)
         }

         // ReadFrom implements ReaderFrom. Reads message from r into m.Raw,
         // Decodes it and return error if any. If m.Raw is too small, will return
         // ErrUnexpectedEOF, ErrUnexpectedHeaderEOF or *DecodeErr.
         //
         // Can return *DecodeErr while decoding too.
         public func read_from<R: Read>(&mut self, reader: &mut R) -> Result<usize> {
             let mut t_buf = vec![0; DEFAULT_RAW_CAPACITY];
             let n = reader.read(&mut t_buf)?;
             self.raw = t_buf[..n].to_vec();
             self.decode()?;
             Ok(n)
         }

         // Write decodes message and return error if any.
         //
         // Any error is unrecoverable, but message could be partially decoded.
         public func write(&mut self, t_buf: &[u8]) -> Result<usize> {
             self.raw.clear();
             self.raw.extend_from_slice(t_buf);
             self.decode()?;
             Ok(t_buf.len())
         }

         // CloneTo clones m to b securing any further m mutations.
         public func clone_to(&self, b: &mut Message) -> Result<()> {
             b.raw.clear();
             b.raw.extend_from_slice(&self.raw);
             b.decode()
         }

         // Contains return true if message contain t attribute.
         public func contains(&self, t: AttrType) -> bool {
             for a in &self.attributes.0 {
                 if a.typ == t {
                     return true;
                 }
             }
             false
         }

         // get returns byte slice that represents attribute value,
         // if there is no attribute with such type,
         // ErrAttributeNotFound is returned.
         public func get(&self, t: AttrType) -> Result<Vec<u8>> {
             let (v, ok) = self.attributes.get(t);
             if ok {
                 Ok(v.value)
             } else {
                 Err(Error::ErrAttributeNotFound)
             }
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
         public func build(&mut self, setters: &[Box<dyn Setter>]) -> Result<()> {
             self.reset();
             self.write_header();
             for s in setters {
                 s.add_to(self)?;
             }
             Ok(())
         }

         // Check applies checkers to message in batch, returning on first error.
         public func check<C: Checker>(&self, checkers: &[C]) -> Result<()> {
             for c in checkers {
                 c.check(self)?;
             }
             Ok(())
         }

         // Parse applies getters to message in batch, returning on first error.
         public func parse<G: Getter>(&self, getters: &mut [G]) -> Result<()> {
             for c in getters {
                 c.get_from(self)?;
             }
             Ok(())
         }
     */
}

/// Possible values for message class in STUN Message Type.
public let CLASS_REQUEST: MessageClass = MessageClass(0x00)
public let CLASS_INDICATION: MessageClass = MessageClass(0x01)
public let CLASS_SUCCESS_RESPONSE: MessageClass = MessageClass(0x02)
public let CLASS_ERROR_RESPONSE: MessageClass = MessageClass(0x03)

/// MessageClass is 8-bit representation of 2-bit class of STUN Message Class.
public struct MessageClass: CustomStringConvertible {
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
public let METHOD_BINDING: Method = Method(0x001)
public let METHOD_ALLOCATE: Method = Method(0x003)
public let METHOD_REFRESH: Method = Method(0x004)
public let METHOD_SEND: Method = Method(0x006)
public let METHOD_DATA: Method = Method(0x007)
public let METHOD_CREATE_PERMISSION: Method = Method(0x008)
public let METHOD_CHANNEL_BIND: Method = Method(0x009)

/// Methods from RFC 6062.
public let METHOD_CONNECT: Method = Method(0x000a)
public let METHOD_CONNECTION_BIND: Method = Method(0x000b)
public let METHOD_CONNECTION_ATTEMPT: Method = Method(0x000c)

/// Method is uint16 representation of 12-bit STUN method.
public struct Method: CustomStringConvertible {
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
public let BINDING_REQUEST: MessageType = MessageType(
    method: METHOD_BINDING,
    messageClass: CLASS_REQUEST
)
/// Binding success response message type
public let BINDING_SUCCESS: MessageType = MessageType(
    method: METHOD_BINDING,
    messageClass: CLASS_SUCCESS_RESPONSE
)
/// Binding error response message type.
public let BINDING_ERROR: MessageType = MessageType(
    method: METHOD_BINDING,
    messageClass: CLASS_ERROR_RESPONSE
)

let METHOD_ABITS: UInt16 = 0xf  // 0b0000000000001111
let METHOD_BBITS: UInt16 = 0x70  // 0b0000000001110000
let METHOD_DBITS: UInt16 = 0xf80  // 0b0000111110000000

let METHOD_BSHIFT: UInt16 = 1
let METHOD_DSHIFT: UInt16 = 2

let FIRST_BIT: UInt16 = 0x1
let SECOND_BIT: UInt16 = 0x2

let C0BIT: UInt16 = FIRST_BIT
let C1BIT: UInt16 = SECOND_BIT

let CLASS_C0SHIFT: UInt16 = 4
let CLASS_C1SHIFT: UInt16 = 7

// MessageType is STUN Message Type Field.
public struct MessageType: CustomStringConvertible, Setter {
    var method: Method  // e.g. binding
    var messageClass: MessageClass  // e.g. request

    public init(method: Method, messageClass: MessageClass) {
        self.method = method
        self.messageClass = messageClass
    }

    public var description: String {
        return "\(self.method) \(messageClass)"
    }

    /// addTo sets m type to t.
    public func addTo(m: inout Message) throws {
        m.setType(self)
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
        let a = method & METHOD_ABITS  // A = M * 0b0000000000001111 (right 4 bits)
        let b = method & METHOD_BBITS  // B = M * 0b0000000001110000 (3 bits after A)
        let d = method & METHOD_DBITS  // D = M * 0b0000111110000000 (5 bits after B)

        // Shifting to add "holes" for C0 (at 4 bit) and C1 (8 bit).
        method = a + (b << METHOD_BSHIFT) + (d << METHOD_DSHIFT)

        // C0 is zero bit of C, C1 is first bit.
        // C0 = C * 0b01, C1 = (C * 0b10) >> 1
        // Ct = C0 << 4 + C1 << 8.
        // Optimizations: "((C * 0b10) >> 1) << 8" as "(C * 0b10) << 7"
        // We need C0 shifted by 4, and C1 by 8 to fit "11" and "7" positions
        // (see figure 3).
        let c = UInt16(self.messageClass.rawValue)
        let c0 = (c & C0BIT) << CLASS_C0SHIFT
        let c1 = (c & C1BIT) << CLASS_C1SHIFT
        let messageClass = c0 + c1

        return method + messageClass
    }

    /// readValue decodes uint16 into MessageType.
    public mutating func readValue(value: UInt16) {
        // Decoding class.
        // We are taking first bit from v >> 4 and second from v >> 7.
        let c0 = (value >> CLASS_C0SHIFT) & C0BIT
        let c1 = (value >> CLASS_C1SHIFT) & C1BIT
        let messageClass = c0 + c1
        self.messageClass = MessageClass(UInt8(messageClass))

        // Decoding method.
        let a = value & METHOD_ABITS  // A(M0-M3)
        let b = (value >> METHOD_BSHIFT) & METHOD_BBITS  // B(M4-M6)
        let d = (value >> METHOD_DSHIFT) & METHOD_DBITS  // D(M7-M11)
        let m = a + b + d
        self.method = Method(m)
    }
}
