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

@testable import RTP

final class AudioLevelExtensionTests: XCTestCase {
    func testAudioLevelExtensionTooSmall() throws {
        let buf = ByteBuffer()
        let result = try? AudioLevelExtension(buf)
        XCTAssertTrue(result == nil)
    }

    func testAudioLevelExtensionVoiceTrue() throws {
        let raw = ByteBuffer(bytes: [0x88])
        let a1 = try AudioLevelExtension(raw)
        let a2 = AudioLevelExtension(
            level: 8,
            voice: true
        )
        XCTAssertEqual(a1, a2)

        var dst = ByteBuffer()
        let _ = try a2.marshalTo(&dst)
        XCTAssertEqual(raw, dst)
    }

    func testAudioLevelExtensionVoiceFalse() throws {
        let raw = ByteBuffer(bytes: [0x8])
        let a1 = try AudioLevelExtension(raw)
        let a2 = AudioLevelExtension(
            level: 8,
            voice: false
        )
        XCTAssertEqual(a1, a2)

        var dst = ByteBuffer()
        let _ = try a2.marshalTo(&dst)
        XCTAssertEqual(raw, dst)
    }

    func testAudioLevelExtensionLevelOverflow() throws {
        let a = AudioLevelExtension(
            level: 128,
            voice: false
        )

        var dst = ByteBuffer()
        let result = try? a.marshalTo(&dst)
        XCTAssertTrue(result == nil)
    }
}
