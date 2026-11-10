// Checks that meeting notes asked for the usual way get exactly the usual
// prompt, and that an angle is trimmed, capped and put in, no Droppy needed:
//   cp Tools/meeting-angle-check.swift /tmp/main.swift
//   swiftc Sources/Pixpaw/MeetingNotes.swift /tmp/main.swift -o /tmp/meeting-angle-check && /tmp/meeting-angle-check

let t = "[00:01] You: hello"
let plain = MeetingNotes.prompt(t, language: .english)
assert(plain == MeetingNotes.prompt(t, language: .english, angle: nil))
assert(plain == MeetingNotes.prompt(t, language: .english, angle: "  \n"))
assert(plain.hasSuffix("Reply with the notes only.\n\nTranscript:\n" + t))
let shaped = MeetingNotes.prompt(t, language: .english, angle: "  in Thai ")
assert(shaped.contains("shaped this way: \"in Thai\". Follow it"))
assert(!MeetingNotes.prompt(t, language: .english, angle: String(repeating: "x", count: 300)).contains(String(repeating: "x", count: 201)))
print("meeting-angle-check: ok")
