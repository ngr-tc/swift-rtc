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
import SDP

final class ExtMapTests: XCTestCase {
    let exampleAttrExtMap1: String = "extmap:1 http://example.com/082005/ext.htm#ttime"
    let exampleAttrExtMap2: String =
        "extmap:2/sendrecv http://example.com/082005/ext.htm#xmeta short"
    let failingAttrExtMap1: String =
        "extmap:257/sendrecv http://example.com/082005/ext.htm#xmeta short"
    let failingAttrExtMap2: String =
        "extmap:2/blorg http://example.com/082005/ext.htm#xmeta short"

    func testExtMap() throws {
        let exampleAttrExtMap1Line = exampleAttrExtMap1
        let exampleAttrExtMap2Line = exampleAttrExtMap2
        let failingAttrExtMap1Line = "\(attributeKey)\(failingAttrExtMap1)\(endLine)"
        let failingAttrExtMap2Line = "\(attributeKey)\(failingAttrExtMap2)\(endLine)"
        let passingTests = [
            (exampleAttrExtMap1, exampleAttrExtMap1Line),
            (exampleAttrExtMap2, exampleAttrExtMap2Line),
        ]
        let failingTests = [
            (failingAttrExtMap1, failingAttrExtMap1Line),
            (failingAttrExtMap2, failingAttrExtMap2Line),
        ]

        for (_, line) in passingTests {
            let actual = try? ExtMap.unmarshal(line: line)
            XCTAssertEqual(
                line,
                actual?.marshal()
            )
        }

        for (_, line) in failingTests {
            let actual = try? ExtMap.unmarshal(line: line)
            XCTAssertEqual(nil, actual)
        }
    }

    func testTransportCcExtMap() throws {
        // a=extmap:<value>["/"<direction>] <URI> <extensionattributes>
        // a=extmap:3 http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01
        let uri: String? =
            "http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01"
        let e = ExtMap(
            value: 3,
            direction: nil,
            uri: uri,
            extAttr: nil)

        XCTAssertEqual(
            "extmap:3 http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01",
            e.marshal()
        )
    }
}
