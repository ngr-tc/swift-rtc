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

final class FingerprintTests: XCTestCase {
    func testFingerprintUsesCRS32IsoHdlc() throws {
        var m = Message()

        let a = TextAttribute(
            attr: attrSoftware,
            text: "software"
        )
        try a.addTo(&m)
        m.writeHeader()

        try fingerprint.addTo(&m)
        m.writeHeader()

        let rawView = ByteBufferView(m.raw)
        XCTAssertEqual(
            m.raw.getBytes(at: 0, length: rawView.count - 8)!,
            [
                0x00, 0x00, 0x00, 0x14, 0x21, 0x12, 0xA4, 0x42, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80, 0x22, 0x00, 0x08, 0x73, 0x6F, 0x66, 0x74,
                0x77, 0x61, 0x72, 0x65,
            ])

        XCTAssertEqual(m.raw.getBytes(at: rawView.count - 4, length: 4)!, [0xe4, 0x4c, 0x33, 0xd9])
    }
    /*
    #[test]
    fn test_fingerprint_check() -> Result<()> {
        let mut m = Message::new();
        let a = TextAttribute {
            attr: attrSoftware,
            text: "software".to_owned(),
        };
        a.add_to(&mut m)?;
        m.write_header();

        FINGERPRINT.add_to(&mut m)?;
        m.write_header();
        FINGERPRINT.check(&m)?;
        m.raw[3] += 1;

        let result = FINGERPRINT.check(&m);
        assert!(result.is_err(), "should error");

        Ok(())
    }

    #[test]
    fn test_fingerprint_check_bad() -> Result<()> {
        let mut m = Message::new();
        let a = TextAttribute {
            attr: attrSoftware,
            text: "software".to_owned(),
        };
        a.add_to(&mut m)?;
        m.write_header();

        let result = FINGERPRINT.check(&m);
        assert!(result.is_err(), "should error");

        m.add(ATTR_FINGERPRINT, &[1, 2, 3]);

        let result = FINGERPRINT.check(&m);
        if let Err(err) = result {
            assert!(
                is_attr_size_invalid(&err),
                "IsAttrSizeInvalid should be true"
            );
        } else {
            panic!("Expected error, but got ok");
        }

        Ok(())
    }
*/
}
