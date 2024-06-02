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
    case codecNotFound
    case missingWhitespace
    case missingColon
    case payloadTypeNotFound
    case sdpInvalidSyntax(String)
    case sdpInvalidValue(String)
    case sdpEmptyTimeDescription
    case parseExtMap(String)
    case syntaxError(String, Int)
    case parseInt(String, String)
}

extension SdpError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .codecNotFound:
            return "codec not found"
        case .missingWhitespace:
            return "missing whitespace"
        case .missingColon:
            return "missing colon"
        case .payloadTypeNotFound:
            return "payload type not found"
        case .sdpInvalidSyntax(let syntax):
            return "SdpInvalidSyntax: \(syntax)"
        case .sdpInvalidValue(let value):
            return "SdpInvalidValue: \(value)"
        case .sdpEmptyTimeDescription:
            return "empty time descriptions"
        case .parseExtMap(let extMap):
            return "parse extmap: \(extMap)"
        case .syntaxError(let s, let p):
            let startIndex = s.index(s.startIndex, offsetBy: p)
            let endIndex = s.index(startIndex, offsetBy: 1)
            return "\(s[..<startIndex]) --> \(s[startIndex..<endIndex]) <-- \(s[endIndex...])"
        case .parseInt(let value, let s):
            return "parse Int: \(value) in \(s)"
        }
    }
}
