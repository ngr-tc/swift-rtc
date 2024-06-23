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

@testable import DTLS

final class AlertTests: XCTestCase {
    func testAlert() throws {
        let tests = [
            (
                "Valid Alert",
                ByteBuffer(bytes: [0x02, 0x0A]),
                Alert(
                    alertLevel: AlertLevel.fatal,
                    alertDescription: AlertDescription.unexpectedMessage
                ),
                nil
            ),
            (
                "Invalid alert length",
                ByteBuffer(bytes: [0x00]),
                Alert(
                    alertLevel: AlertLevel.invalid,
                    alertDescription: AlertDescription.invalid
                ),
                DtlsError.errTooShortBuffer
            ),
        ]

        for (name, data, wanted, unmarshalError) in tests {
            if unmarshalError != nil {
                do {
                    let _ = try Alert.unmarshal(data)
                    XCTFail("should Error")
                } catch let err as DtlsError {
                    XCTAssertEqual(unmarshalError, err)
                } catch {
                    XCTFail("should DtlsError")
                }
            } else {
                let (actual, _) = try Alert.unmarshal(data)

                XCTAssertEqual(wanted, actual, "\(name)")

                let data2 = try actual.marshal()
                XCTAssertEqual(data, data2, "\(name)")
            }
        }
    }
}
