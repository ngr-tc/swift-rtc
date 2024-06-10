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
import NIOCore
import Shared

// One byte header size
public let videoOrientationExtensionSize: Int = 1

/// Coordination of Video Orientation in RTP streams.
///
/// Coordination of Video Orientation consists in signaling of the current
/// orientation of the image captured on the sender side to the receiver for
/// appropriate rendering and displaying.
///
/// C = Camera: indicates the direction of the camera used for this video
///     stream. It can be used by the MTSI client in receiver to e.g. display
///     the received video differently depending on the source camera.
///
/// 0: front-facing camera, facing the user. If camera direction is
///    unknown by the sending MTSI client in the terminal then this is the
///    default value used.
/// 1: back-facing camera, facing away from the user.
///
/// F = Flip: indicates a horizontal (left-right flip) mirror operation on
///     the video as sent on the link.
///
///    0                   1
///    0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5
///   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
///   |  ID   | len=0 |0 0 0 0 C F R R|
///   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
public struct VideoOrientationExtension: Equatable {
    public var direction: CameraDirection
    public var flip: Bool
    public var rotation: VideoRotation
}

public enum CameraDirection: UInt8, Equatable {
    case front = 0
    case back = 1

    public init(value: UInt8) throws {
        switch value {
        case 0:
            self = CameraDirection.front
        case 1:
            self = CameraDirection.back
        default:
            throw RtpError.errInvalidCameraDirectionValue(value)
        }
    }
}

public enum VideoRotation: UInt8, Equatable {
    case degree0 = 0
    case degree90 = 1
    case degree180 = 2
    case degree270 = 3

    public init(value: UInt8) throws {
        switch value {
        case 0:
            self = VideoRotation.degree0
        case 1:
            self = VideoRotation.degree90
        case 2:
            self = VideoRotation.degree180
        case 3:
            self = VideoRotation.degree270
        default:
            throw RtpError.errInvalidVideoRotationValue(value)
        }
    }
}

extension VideoOrientationExtension: Unmarshal {
    public init(_ buf: ByteBuffer) throws {
        if buf.readableBytes < videoOrientationExtensionSize {
            throw RtpError.errBufferTooSmall
        }
        var reader = buf.slice()
        guard let b: UInt8 = reader.readInteger() else {
            throw RtpError.errBufferTooSmall
        }

        let c = (b & 0b1000) >> 3
        let f = b & 0b0100
        let r = b & 0b0011

        self.direction = try CameraDirection(value: c)
        self.flip = f > 0
        self.rotation = try VideoRotation(value: r)
    }
}

extension VideoOrientationExtension: MarshalSize {
    public func marshalSize() -> Int {
        return videoOrientationExtensionSize
    }
}

extension VideoOrientationExtension: Marshal {
    public func marshalTo(_ buf: inout ByteBuffer) throws -> Int {
        let c = UInt8(self.direction.rawValue) << 3
        let f: UInt8 = self.flip ? 0b0100 : 0
        let r = UInt8(self.rotation.rawValue)

        buf.writeInteger(UInt8(c | f | r))

        return videoOrientationExtensionSize
    }
}

extension VideoOrientationExtension: HeaderExtension {
    public func uri() -> String {
        return "urn:3gpp:video-orientation"
    }
}
