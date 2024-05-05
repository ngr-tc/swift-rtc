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
enum Result<T, E: Error> {
    case Ok(T)
    case Err(E)
}

enum SDPError: Error, CustomStringConvertible {
    case CodecNotFound
    case MissingWhitespace
    case MissingColon
    case PayloadTypeNotFound
    case SdpInvalidSyntax(String)
    case SdpInvalidValue(String)
    case SdpEmptyTimeDescription
    case ParseExtMap(String)
    case SyntaxError(String, Int)
    
    var description: String {
        switch self {
        case .CodecNotFound:
            return "codec not found"
        case .MissingWhitespace:
            return "missing whitespace"
        case .MissingColon:
            return "missing colon"
        case .PayloadTypeNotFound:
            return "payload type not found"
        case .SdpInvalidSyntax(let syntax):
            return "SdpInvalidSyntax: \(syntax)"
        case .SdpInvalidValue(let value):
            return "SdpInvalidValue: \(value)"
        case .SdpEmptyTimeDescription:
            return "empty time descriptions"
        case .ParseExtMap(let extMap):
            return "parse extmap: \(extMap)"
        case .SyntaxError(let s, let p):
            let startIndex = s.index(s.startIndex, offsetBy: p);
            let endIndex = s.index(startIndex, offsetBy: 1);
            return "\(s[..<startIndex]) --> \(s[startIndex..<endIndex]) <-- \(s[endIndex...])"
        }
    }
}
