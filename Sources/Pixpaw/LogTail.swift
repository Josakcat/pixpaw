//
//  LogTail.swift
//  Pixpaw
//
//  Follows a log that only grows: remembers how far it was read (and which
//  file that was, by inode) and reads only what was added since, whole lines
//  only. A file that shrank or was replaced is read again from its end.
//  Never holds more than `limit` bytes at once. Checked by
//  .droppykit/Tools/log-tail-check.swift in the GitHub repo (not in the Store copy).
//

import Darwin
import Foundation

struct LogTail {
    /// Where the next read starts: just past the last whole line read.
    private(set) var offset: UInt64 = 0
    private(set) var inode: UInt64 = 0
    /// The most read at once; past it only the end is read, as before.
    let limit: Int

    init(limit: Int) {
        self.limit = limit
    }

    /// The whole lines added since the last read, and whether this read
    /// started over (the first one, a file that shrank or a new file).
    mutating func read(_ path: String) -> (lines: [Substring], restarted: Bool)? {
        var info = stat()
        guard stat(path, &info) == 0 else { return nil }
        let size = UInt64(max(0, info.st_size))
        let node = UInt64(info.st_ino)
        var restarted = false
        if node != inode || size < offset || inode == 0 {
            inode = node
            offset = 0
            restarted = true
        }
        guard size > offset else { return ([], restarted) }
        let start = size - offset > UInt64(limit) ? size - UInt64(limit) : offset
        let cut = start > offset
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        guard (try? handle.seek(toOffset: start)) != nil,
              let data = try? handle.read(upToCount: Int(size - start)) else { return nil }
        // Only up to the last newline: a line still being written waits.
        guard let end = data.lastIndex(of: UInt8(ascii: "\n")) else {
            // A cut read with no line end in it is the middle of one huge
            // line: skip it rather than read it again and again.
            if cut { offset = start + UInt64(data.count) }
            return ([], restarted)
        }
        offset = start + UInt64(end - data.startIndex) + 1
        let text = String(decoding: data[data.startIndex...end], as: UTF8.self)
        var lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        // A cut read starts partway into a line (or a UTF-8 character).
        if cut, !lines.isEmpty { lines.removeFirst() }
        return (lines, restarted)
    }
}
