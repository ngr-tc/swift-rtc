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
public struct Codec {
    var payloadType: UInt8
    var name: String
    var clockRate: UInt32
    var encodingParameters: String
    var fmtp: String
    var rtcpFeedbacks: [String]
}

func parseRtpMap(rtpMap: String) -> Result<Codec, SDPError> {
    return .Err(.CodecNotFound)
}
