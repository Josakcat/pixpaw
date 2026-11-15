// Checks what AI apps may send the pet (sanitising, links, arguments) and the
// bubble's rate limit, on its own, no Droppy needed:
//   cp .droppykit/Tools/pet-tools-check.swift /tmp/main.swift
//   swiftc Sources/Pixpaw/PetTools.swift Sources/Pixpaw/PlainText.swift /tmp/main.swift -o /tmp/pet-tools-check && /tmp/pet-tools-check

import Foundation

var failures = 0
func check(_ ok: Bool, _ what: String) {
    print(ok ? "ok   \(what)" : "FAIL \(what)")
    if !ok { failures += 1 }
}
func problem(_ json: String) -> PetTools.Problem? {
    do { _ = try PetTools.text(from: json); return nil } catch { return error as? PetTools.Problem }
}

// Arguments
check((try? PetTools.text(from: #"{"text":"Build passed!"}"#)) == "Build passed!", "plain text goes through")
check((try? PetTools.text(from: #"{"text":"line one\nline two\t\u0007 end"}"#)) == "line one line two end", "newlines, tabs and control characters out")
check((try? PetTools.text(from: #"{"text":"ok‮gnp.exe"}"#)) == "okgnp.exe", "bidi overrides out")
check((try? PetTools.text(from: "{\"text\":\"\(String(repeating: "x", count: 500))\"}"))?.count == PetTools.textLimit, "capped at 140")
check(problem(#"{"text":"   \n  "}"#) == .empty, "nothing left: refused")
check(problem(#"{"text": 5}"#) == .badArguments, "a number is refused")
check(problem(#"["hi"]"#) == .badArguments, "an array is refused")
check(problem(#"{"text":"hi","open":"https://x.io"}"#) == .badArguments, "extra fields are refused")
check(problem("not json") == .badArguments, "not JSON is refused")
check(problem("{\"text\":\"\(String(repeating: "y", count: 5000))\"}") == .badArguments, "a huge payload is refused")

// Links
for text in ["See https://evil.example", "go to www.example.org", "mailto:me@x.com", "visit example.com/login", "pixpaw://quiet", "file:///etc/passwd", "javascript:alert(1)"] {
    check(problem("{\"text\":\"\(text)\"}") == .link, "a link is refused: \(text)")
}
for text in ["Tests passed: 42 of 42", "Deploy done. Time for tea?", "Version 2.1 is out", "3.5 hours left"] {
    check(problem("{\"text\":\"\(text)\"}") == nil, "not a link: \(text)")
}

// Rate limit
let t0 = Date(timeIntervalSince1970: 1_000_000)
var limit = PetTools.RateLimit(every: PetTools.sayEvery)
check(limit.allow(at: t0) == nil, "the first line goes")
check(limit.allow(at: t0.addingTimeInterval(3)) == 7, "3 s later: wait 7 s")
check(limit.allow(at: t0.addingTimeInterval(9.5)) == 1, "9.5 s later: wait 1 s")
check(limit.allow(at: t0.addingTimeInterval(10)) == nil, "10 s later it goes")
check(limit.allow(at: t0.addingTimeInterval(10.5)) != nil, "and the clock starts again")
check(limit.allow(at: t0.addingTimeInterval(-60)) == nil, "a clock set back never locks it")

// Schema
let schema = try? JSONSerialization.jsonObject(with: Data(PetTools.schema(limit: 140).utf8)) as? [String: Any]
check(schema?["type"] as? String == "object", "the schema is a JSON object")
check(PetTools.Problem.tooSoon(seconds: 4).errorDescription?.contains("4 s") == true, "too soon says how long")

print(failures == 0 ? "All good." : "\(failures) failed.")
exit(failures == 0 ? 0 : 1)
