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
import NIOPosix
import STUN
import Shared

// swift run XExampleStunClient stun.l.google.com 19302 0
// Local address: 0.0.0.0:58998
// Local address: [IPv4]0.0.0.0/0.0.0.0:51344, Remote addres: [IPv4]stun.l.google.com/74.125.250.129:19302
// Got response: [IPv4]24.130.67.207:51344

private final class StunClientHandler: ChannelInboundHandler {
    public typealias InboundIn = AddressedEnvelope<ByteBuffer>
    public typealias OutboundOut = AddressedEnvelope<ByteBuffer>

    private var client: Client? = nil
    private let remoteAddressInitializer: () throws -> SocketAddress

    init(remoteAddressInitializer: @escaping () throws -> SocketAddress) {
        self.remoteAddressInitializer = remoteAddressInitializer
    }

    public func channelActive(context: ChannelHandlerContext) {

        do {
            // Channel is available. It's time to send the message to the server to initialize the ping-pong sequence.

            // Get the server address.
            let remoteAddress = try self.remoteAddressInitializer()
            let localAddress = context.localAddress!

            print(
                "Local address: \(localAddress.description), Remote addres: \(remoteAddress.description)"
            )

            client = ClientBuilder().build(
                local: localAddress, remote: remoteAddress, proto: TransportProtocol.udp)

            var msg = Message()
            try msg.build([TransactionId(), bindingRequest])
            try client?.handleWrite(msg)
            while let transmit = client?.pollTransmit() {
                // Forward the data.
                let envelope = AddressedEnvelope<ByteBuffer>(
                    remoteAddress: remoteAddress, data: transmit.message)

                context.writeAndFlush(self.wrapOutboundOut(envelope), promise: nil)
            }
        } catch {
            print("Could not resolve remote address")
        }
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let envelope = self.unwrapInboundIn(data)
        let byteBuffer = ByteBufferView(envelope.data)

        do {
            try client?.handleRead(byteBuffer)

            if let event = client?.pollEvent() {
                guard case .success(var msg) = event.result else {
                    return
                }
                var xorAddr = XorMappedAddress()
                try xorAddr.getFrom(&msg)
                print("Got response: \(xorAddr)")
            }

            try client?.handleClose()
        } catch let err {
            print("\(err)")
        }

        context.close(promise: nil)
    }

    public func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("error: ", error)

        // As we are not really interested getting notified on success or failure we just pass nil as promise to
        // reduce allocations.
        context.close(promise: nil)
    }
}

// First argument is the program path
var arguments = CommandLine.arguments
// Support for `--connect` if it appears as the first argument.
let connectedMode: Bool
if let connectedModeFlagIndex = arguments.firstIndex(where: { $0 == "--connect" }) {
    connectedMode = true
    arguments.remove(at: connectedModeFlagIndex)
} else {
    connectedMode = false
}
// Now process the positional arguments.
let arg1 = arguments.dropFirst().first
let arg2 = arguments.dropFirst(2).first
let arg3 = arguments.dropFirst(3).first

// If only writing to the destination address, bind to local port 0 and address 0.0.0.0 or ::.
let defaultHost = "stun.l.google.com"  //"::1"
// If the server and the client are running on the same computer, these will need to differ from each other.
let defaultServerPort: Int = 19302  //9999
let defaultListeningPort: Int = 0  //8888

enum ConnectTo {
    case ip(host: String, sendPort: Int, listeningPort: Int)
    case unixDomainSocket(sendPath: String, listeningPath: String)
}

let connectTarget: ConnectTo

switch (arg1, arg1.flatMap(Int.init), arg2, arg2.flatMap(Int.init), arg3.flatMap(Int.init)) {
case (.some(let h), .none, _, .some(let sp), .some(let lp)):
    /* We received three arguments (String Int Int), let's interpret that as a server host with a server port and a local listening port */
    connectTarget = .ip(host: h, sendPort: sp, listeningPort: lp)
case (.some(let sp), .none, .some(let lp), .none, _):
    /* We received two arguments (String String), let's interpret that as sending socket path and listening socket path  */
    assert(sp != lp, "The sending and listening sockets should differ.")
    connectTarget = .unixDomainSocket(sendPath: sp, listeningPath: lp)
case (_, .some(let sp), _, .some(let lp), _):
    /* We received two argument (Int Int), let's interpret that as the server port and a listening port on the default host. */
    connectTarget = .ip(host: defaultHost, sendPort: sp, listeningPort: lp)
default:
    connectTarget = .ip(
        host: defaultHost, sendPort: defaultServerPort, listeningPort: defaultListeningPort)
}

let remoteAddress = { () -> SocketAddress in
    switch connectTarget {
    case .ip(let host, let sendPort, _):
        return try SocketAddress.makeAddressResolvingHost(host, port: sendPort)
    case .unixDomainSocket(let sendPath, _):
        return try SocketAddress(unixDomainSocketPath: sendPath)
    }
}

let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
let bootstrap = DatagramBootstrap(group: group)
    // Enable SO_REUSEADDR.
    .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
    .channelInitializer { channel in
        channel.pipeline.addHandler(StunClientHandler(remoteAddressInitializer: remoteAddress))
    }
defer {
    try! group.syncShutdownGracefully()
}

let channel = try { () -> Channel in
    switch connectTarget {
    case .ip(_, _, let listeningPort):
        return try bootstrap.bind(host: "0.0.0.0", port: listeningPort).wait()
    case .unixDomainSocket(_, let listeningPath):
        return try bootstrap.bind(unixDomainSocketPath: listeningPath).wait()
    }
}()

if connectedMode {
    let remoteAddress = try remoteAddress()
    print("Connecting to remote: \(remoteAddress)")
    try channel.connect(to: remoteAddress).wait()
}

// Will be closed after we echo-ed back to the server.
try channel.closeFuture.wait()

print("Client closed")
