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

public let endLine: String = "\r\n"

struct Lexer {
    var desc: SessionDescription
    let input: String
    var index: String.Index

    public init(desc: SessionDescription, input: String) {
        self.desc = desc
        self.input = input
        self.index = input.startIndex
    }

    private mutating func nextToken() -> Character? {
        guard index < input.endIndex else { return nil }
        let token = input[index]
        index = input.index(after: index)
        return token
    }

    private mutating func skipWhitespace() {
        while let char = peek(), char.isWhitespace {
            index = input.index(after: index)
        }
    }

    private func peek() -> Character? {
        guard index < input.endIndex else { return nil }
        return input[index]
    }

    private mutating func consume() {
        guard index < input.endIndex else { return }
        index = input.index(after: index)
    }

    private mutating func readUntil(delim: Character) -> String {
        var string = ""
        while let char = nextToken() {
            string.append(char)
            if char == delim { break }
        }
        return string
    }

    mutating func readKey() throws -> String {
        while let char = peek() {
            if char == "\n" || char == "\r" || char == "\r\n" {
                consume()
                continue
            }
            let key = readUntil(delim: "=")
            if !(key.isEmpty || key.count == 2) {
                throw SdpError.errSdpInvalidSyntax(key)
            }
            return key
        }
        return ""
    }

    private mutating func readLine() -> String {
        var string = ""
        while let char = nextToken() {
            if char == "\n" || char == "\r\n" { break }
            string.append(char)
        }
        return String(string.trimmingNewline())
    }

    mutating func readValue() throws -> String {
        return readLine()
    }
}

struct StateFn {
    var f: (inout Lexer) throws -> StateFn?
}

func indexOf(element: String, dataSet: [String]) -> Int? {
    for (index, value) in dataSet.enumerated() {
        if element == value {
            return index
        }
    }
    return nil
}
