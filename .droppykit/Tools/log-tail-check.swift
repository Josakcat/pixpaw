// Checks LogTail, the incremental read of a growing transcript: only the
// lines added since the last read, a half-written line waits, a file that
// shrank or was replaced starts over, and never more than its limit at once.
// On its own, no Droppy needed:
//   cp .droppykit/Tools/log-tail-check.swift /tmp/main.swift
//   swiftc Sources/Pixpaw/LogTail.swift /tmp/main.swift -o /tmp/log-tail-check && /tmp/log-tail-check

import Foundation

var failures = 0
func check(_ ok: Bool, _ what: String) {
    print(ok ? "ok   \(what)" : "FAIL \(what)")
    if !ok { failures += 1 }
}

let folder = FileManager.default.temporaryDirectory.appendingPathComponent("log-tail-check-\(getpid())", isDirectory: true)
try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: folder) }
let file = folder.appendingPathComponent("session.jsonl")

func write(_ text: String) { try! Data(text.utf8).write(to: file) }
func append(_ text: String) {
    let handle = try! FileHandle(forWritingTo: file)
    try! handle.seekToEnd()
    try! handle.write(contentsOf: Data(text.utf8))
    try! handle.close()
}
func strings(_ lines: [Substring]) -> [String] { lines.map(String.init) }

var tail = LogTail(limit: 64)

// The first read takes what is there and says it started over.
write("a\nb\n")
var got = tail.read(file.path)!
check(strings(got.lines) == ["a", "b"] && got.restarted, "first read: every line, restarted")
check(tail.offset == 4, "offset past the last newline")

// Nothing new: nothing read.
got = tail.read(file.path)!
check(got.lines.isEmpty && !got.restarted, "unchanged file: no lines")

// Only what was appended.
append("c\nd\n")
got = tail.read(file.path)!
check(strings(got.lines) == ["c", "d"] && !got.restarted, "appended lines only")

// A line still being written waits for its newline.
append("{\"half")
got = tail.read(file.path)!
check(got.lines.isEmpty && tail.offset == 8, "half a line: nothing, offset kept")
append("\":1}\ne\n")
got = tail.read(file.path)!
check(strings(got.lines) == ["{\"half\":1}", "e"], "the finished line comes whole")

// A file that shrank starts over.
write("x\n")
got = tail.read(file.path)!
check(strings(got.lines) == ["x"] && got.restarted, "shrunk file: read again from the start")

// A file replaced by another (new inode), even one as long or longer, starts over.
let other = folder.appendingPathComponent("other.jsonl")
try! Data("p\nq\nr\n".utf8).write(to: other)
_ = try! FileManager.default.replaceItemAt(file, withItemAt: other)
got = tail.read(file.path)!
check(strings(got.lines) == ["p", "q", "r"] && got.restarted, "replaced file: read again from the start")

// More appended than the limit: only the end, the cut line left out.
let long = (0..<40).map { "line\($0)" }.joined(separator: "\n") + "\n"
append(long)
got = tail.read(file.path)!
let bytes = got.lines.reduce(0) { $0 + $1.utf8.count + 1 }
check(bytes <= 64 && got.lines.last == "line39" && !got.lines.contains("p"), "a big append: at most the limit, the end kept")
check(got.lines.allSatisfy { $0.hasPrefix("line") && Int($0.dropFirst(4)) != nil }, "no cut line in a big append")

// One huge line with no end is skipped, not read again each time.
append(String(repeating: "z", count: 200))
got = tail.read(file.path)!
let after = tail.offset
got = tail.read(file.path)!
check(got.lines.isEmpty && tail.offset == after, "a huge unfinished line: skipped once, not re-read")

// A missing file: nil.
var gone = LogTail(limit: 64)
check(gone.read(folder.appendingPathComponent("none.jsonl").path) == nil, "missing file: nil")

print(failures == 0 ? "all good" : "\(failures) failed")
exit(failures == 0 ? 0 : 1)
