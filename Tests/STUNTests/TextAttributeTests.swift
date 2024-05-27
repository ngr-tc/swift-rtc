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
import XCTest

@testable import STUN

final class TextAttributeTests: XCTestCase {
    func testSoftwareGetFrom() throws {
        let m = Message()
        let v = "Client v0.0.1"
        m.add(attrSoftware, ByteBufferView(ByteBuffer(string: v)))
        m.writeHeader()

        let m2 = Message()

        let _ = try m2.readFrom(ByteBufferView(m.raw))
        let software = try TextAttribute.getFromAs(m, attrSoftware)
        XCTAssertEqual(software.description, v)

        let (sAttr, ok) = m.attributes.get(attrSoftware)
        XCTAssertTrue(ok, "sowfware attribute should be found")

        let s = sAttr.description
        XCTAssertTrue(s.starts(with: "SOFTWARE:"), "bad string representation {s}")
    }

    func testSoftwareAddToInvalid() throws {
        let m = Message()
        let s = TextAttribute(
            attr: attrSoftware,
            text: String(repeating: " ", count: 1024)
        )

        do {
            let _ = try s.addTo(m)
            XCTAssertTrue(false, "should error")
        } catch STUNError.errAttributeSizeOverflow {
            XCTAssertTrue(true)
        } catch {
            XCTAssertTrue(false, "should errAttributeSizeOverflow")
        }

        do {
            let _ = try TextAttribute.getFromAs(m, attrSoftware)
            XCTAssertTrue(false, "should error")
        } catch STUNError.errAttributeNotFound {
            XCTAssertTrue(true)
        } catch {
            XCTAssertTrue(false, "should errAttributeNotFound")
        }
    }

    func testSoftwareAddToRegression() throws {
        // s.add_to checked len(m.Raw) instead of len(s.Raw).
        let m = Message()
        let s = TextAttribute(
            attr: attrSoftware,
            text: String(repeating: " ", count: 100)
        )
        let _ = try s.addTo(m)
    }

    func testUsername() throws {
        let username = "username"
        let u = TextAttribute(
            attr: attrUsername,
            text: username
        )
        let m = Message()
        m.writeHeader()

        //"Bad length"
        do {
            let badU = TextAttribute(
                attr: attrUsername,
                text: String(repeating: " ", count: 600)
            )
            do {
                let _ = try badU.addTo(m)
                XCTAssertTrue(false, "should error")
            } catch STUNError.errAttributeSizeOverflow {
                XCTAssertTrue(true)
            } catch {
                XCTAssertTrue(false, "should errAttributeSizeOverflow")
            }
        }
        //"add_to"
        do {
            let _ = try u.addTo(m)

            //"GetFrom"
            do {
                let got = try TextAttribute.getFromAs(m, attrUsername)
                XCTAssertEqual(
                    got.description,
                    username,
                    "expedted: {username}, got: {got}"
                )
                //"Not found"
                do {
                    let m = Message()
                    let _ = try TextAttribute.getFromAs(m, attrUsername)
                    XCTAssertTrue(false, "should error")
                } catch STUNError.errAttributeNotFound {
                    XCTAssertTrue(true)
                } catch {
                    XCTAssertTrue(false, "should errAttributeNotFound")
                }
            }
        }

        //"No allocations"
        do {
            let m = Message()
            m.writeHeader()
            let u = TextAttribute(
                attr: attrUsername,
                text: "username")

            let _ = try u.addTo(m)
            m.reset()
        }
    }

    func testRealmGetFrom() throws {
        let m = Message()
        let v = "realm"
        m.add(attrRealm, ByteBufferView(ByteBuffer(string: v)))
        m.writeHeader()

        let m2 = Message()

        do {
            let _ = try TextAttribute.getFromAs(m2, attrRealm)
            XCTAssertTrue(false, "should error")
        } catch STUNError.errAttributeNotFound {
            XCTAssertTrue(true)
        } catch {
            XCTAssertTrue(false, "should errAttributeNotFound")
        }

        let _ = try m2.readFrom(ByteBufferView(m.raw))

        let r = try TextAttribute.getFromAs(m, attrRealm)
        XCTAssertEqual(r.description, v)

        let (r_attr, ok) = m.attributes.get(attrRealm)
        XCTAssertTrue(ok, "realm attribute should be found")

        let s = r_attr.description
        XCTAssertTrue(s.starts(with: "REALM:"), "bad string representation {s}")
    }

    func testRealmAddToInvalid() throws {
        let m = Message()
        let s = TextAttribute(
            attr: attrRealm,
            text: String(repeating: " ", count: 1024)
        )
        do {
            let _ = try s.addTo(m)
            XCTAssertTrue(false, "should error")
        } catch STUNError.errAttributeSizeOverflow {
            XCTAssertTrue(true)
        } catch {
            XCTAssertTrue(false, "should errAttributeSizeOverflow")
        }

        do {
            let _ = try TextAttribute.getFromAs(m, attrRealm)
            XCTAssertTrue(false, "should error")
        } catch STUNError.errAttributeNotFound {
            XCTAssertTrue(true)
        } catch {
            XCTAssertTrue(false, "should errAttributeNotFound")
        }
    }

    func testNonceGetFrom() throws {
        let m = Message()
        let v = "example.org"
        m.add(attrNonce, ByteBufferView(ByteBuffer(string: v)))
        m.writeHeader()

        let m2 = Message()

        do {
            let _ = try TextAttribute.getFromAs(m2, attrNonce)
            XCTAssertTrue(false, "should error")
        } catch STUNError.errAttributeNotFound {
            XCTAssertTrue(true)
        } catch {
            XCTAssertTrue(false, "should errAttributeNotFound")
        }

        let _ = try m2.readFrom(ByteBufferView(m.raw))

        let r = try TextAttribute.getFromAs(m, attrNonce)
        XCTAssertEqual(r.description, v)

        let (r_attr, ok) = m.attributes.get(attrNonce)
        XCTAssertTrue(ok, "realm attribute should be found")

        let s = r_attr.description
        XCTAssertTrue(s.starts(with: "NONCE:"), "bad string representation {s}")
    }

    func testNonceAddToInvalid() throws {
        let m = Message()
        let s = TextAttribute(
            attr: attrNonce,
            text: String(repeating: " ", count: 1024)
        )
        do {
            let _ = try s.addTo(m)
            XCTAssertTrue(false, "should error")
        } catch STUNError.errAttributeSizeOverflow {
            XCTAssertTrue(true)
        } catch {
            XCTAssertTrue(false, "should errAttributeSizeOverflow")
        }

        do {
            let _ = try TextAttribute.getFromAs(m, attrNonce)
            XCTAssertTrue(false, "should error")
        } catch STUNError.errAttributeNotFound {
            XCTAssertTrue(true)
        } catch {
            XCTAssertTrue(false, "should errAttributeNotFound")
        }
    }

    func testNonceAddTo() throws {
        let m = Message()
        let n = TextAttribute(
            attr: attrNonce,
            text: "example.org"
        )
        let _ = try n.addTo(m)

        let v = try m.get(attrNonce)
        XCTAssertEqual(v, ByteBufferView(ByteBuffer(string: "example.org")))
    }
}
