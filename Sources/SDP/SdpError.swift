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

public enum SdpError: Error, Equatable {
    case errCodecNotFound
    case errMissingWhitespace
    case errMissingColon
    case errPayloadTypeNotFound
    case errSdpInvalidSyntax(String)
    case errSdpInvalidValue(String)
    case errSdpEmptyTimeDescription
    case errParseExtMap(String)
    case errSyntaxError(String, Int)
    case errParseInt(String, String)
}

extension SdpError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .errCodecNotFound:
            return "codec not found"
        case .errMissingWhitespace:
            return "missing whitespace"
        case .errMissingColon:
            return "missing colon"
        case .errPayloadTypeNotFound:
            return "payload type not found"
        case .errSdpInvalidSyntax(let syntax):
            return "SdpInvalidSyntax: \(syntax)"
        case .errSdpInvalidValue(let value):
            return "SdpInvalidValue: \(value)"
        case .errSdpEmptyTimeDescription:
            return "empty time descriptions"
        case .errParseExtMap(let extMap):
            return "parse extmap: \(extMap)"
        case .errSyntaxError(let s, let p):
            let startIndex = s.index(s.startIndex, offsetBy: p)
            let endIndex = s.index(startIndex, offsetBy: 1)
            return "\(s[..<startIndex]) --> \(s[startIndex..<endIndex]) <-- \(s[endIndex...])"
        case .errParseInt(let value, let s):
            return "parse Int: \(value) in \(s)"
        }
    }
}
