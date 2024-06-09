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

final class VideoOrientationExtensionTests: XCTestCase {
    func testVideoOrientationExtensionTooSmall() throws {
        var buf = ByteBuffer()
        let result = try? VideoOrientationExtension(&buf)
        XCTAssertTrue(result == nil)
    }

    func testVideoOrientationExtensionBackFacingCamera() throws {
        let raw = ByteBuffer(bytes: [0b1000])
        var buf = raw.slice()
        let a1 = try? VideoOrientationExtension(&buf)
        let a2 = VideoOrientationExtension(
            direction: CameraDirection.back,
            flip: false,
            rotation: VideoRotation.degree0
        )
        XCTAssertEqual(a1, a2)

        var dst = ByteBuffer()
        let _ = try a2.marshalTo(&dst)
        XCTAssertEqual(raw, dst)
    }

    func testVideoOrientationExtensionFlipTrue() throws {
        let raw = ByteBuffer(bytes: [0b0100])
        var buf = raw.slice()
        let a1 = try? VideoOrientationExtension(&buf)
        let a2 = VideoOrientationExtension(
            direction: CameraDirection.front,
            flip: true,
            rotation: VideoRotation.degree0)
        XCTAssertEqual(a1, a2)

        var dst = ByteBuffer()
        let _ = try a2.marshalTo(&dst)
        XCTAssertEqual(raw, dst)
    }

    func testVideoOrientationExtensionDegree90() throws {
        let raw = ByteBuffer(bytes: [0b0001])
        var buf = raw.slice()
        let a1 = try? VideoOrientationExtension(&buf)
        let a2 = VideoOrientationExtension(
            direction: CameraDirection.front,
            flip: false,
            rotation: VideoRotation.degree90)
        XCTAssertEqual(a1, a2)

        var dst = ByteBuffer()
        let _ = try a2.marshalTo(&dst)
        XCTAssertEqual(raw, dst)
    }

    func testVideoOrientationExtensionDegree180() throws {
        let raw = ByteBuffer(bytes: [0b0010])
        var buf = raw.slice()
        let a1 = try? VideoOrientationExtension(&buf)
        let a2 = VideoOrientationExtension(
            direction: CameraDirection.front,
            flip: false,
            rotation: VideoRotation.degree180)
        XCTAssertEqual(a1, a2)

        var dst = ByteBuffer()
        let _ = try a2.marshalTo(&dst)
        XCTAssertEqual(raw, dst)
    }

    func testVideoOrientationExtensionDegree270() throws {
        let raw = ByteBuffer(bytes: [0b0011])
        var buf = raw.slice()
        let a1 = try? VideoOrientationExtension(&buf)
        let a2 = VideoOrientationExtension(
            direction: CameraDirection.front,
            flip: false,
            rotation: VideoRotation.degree270)
        XCTAssertEqual(a1, a2)

        var dst = ByteBuffer()
        let _ = try a2.marshalTo(&dst)
        XCTAssertEqual(raw, dst)
    }
}
