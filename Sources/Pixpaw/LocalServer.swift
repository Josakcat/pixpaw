//
//  LocalServer.swift
//  Pixpaw
//
//  A dev server a coding agent started ("npm run dev", "vite"): the hook
//  sends only the port it will be on (or the usual ones, for a project's own
//  script), and the pet knocks on this Mac's own loopback now and then to
//  see when it's up. Once it is, the pet's menu offers to open it. Nothing
//  is sent to it and nothing leaves the Mac: a knock is a connection opened
//  and closed again at once.
//

import Darwin

enum LocalServer {
    /// Whether something on this Mac listens on `port`, on IPv4 or IPv6
    /// (a Vite on a newer Node listens on ::1 only).
    static func isListening(_ port: Int) -> Bool {
        guard (1...65535).contains(port) else { return false }
        return knock(port, v6: false) || knock(port, v6: true)
    }

    private static func knock(_ port: Int, v6: Bool) -> Bool {
        let fd = socket(v6 ? AF_INET6 : AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        _ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL, 0) | O_NONBLOCK)
        var started: Int32
        if v6 {
            var address = sockaddr_in6()
            address.sin6_len = UInt8(MemoryLayout<sockaddr_in6>.size)
            address.sin6_family = sa_family_t(AF_INET6)
            address.sin6_port = in_port_t(UInt16(port).bigEndian)
            // ::1, set by hand: the C global isn't safe to touch from Swift 6.
            address.sin6_addr.__u6_addr.__u6_addr8.15 = 1
            started = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in6>.size)) }
            }
        } else {
            var address = sockaddr_in()
            address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            address.sin_family = sa_family_t(AF_INET)
            address.sin_port = in_port_t(UInt16(port).bigEndian)
            address.sin_addr.s_addr = in_addr_t(UInt32(0x7F00_0001).bigEndian)
            started = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
            }
        }
        if started == 0 { return true }
        guard errno == EINPROGRESS else { return false }
        // Loopback answers at once; a tenth of a second is plenty.
        var waiting = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
        guard poll(&waiting, 1, 100) == 1 else { return false }
        var error: Int32 = 0
        var length = socklen_t(MemoryLayout<Int32>.size)
        return getsockopt(fd, SOL_SOCKET, SO_ERROR, &error, &length) == 0 && error == 0
    }
}
