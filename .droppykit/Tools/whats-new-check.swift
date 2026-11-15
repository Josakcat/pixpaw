// Checks when the pet says what's new after an update, no Droppy needed:
//   cp .droppykit/Tools/whats-new-check.swift /tmp/main.swift
//   swiftc Sources/Pixpaw/WhatsNew.swift /tmp/main.swift -o /tmp/whats-new-check && /tmp/whats-new-check

import Foundation

var failures = 0
func check(_ ok: Bool, _ what: String) {
    print(ok ? "ok   \(what)" : "FAIL \(what)")
    if !ok { failures += 1 }
}

check(WhatsNew.line(previous: nil, current: "2.2.0", freshInstall: true) == nil, "a fresh install hears nothing (the hello teaches instead)")
check(WhatsNew.line(previous: nil, current: "2.2.0", freshInstall: false) != nil, "an update from before the version was kept says it")
check(WhatsNew.line(previous: "2.1.0", current: "2.2.0", freshInstall: false) != nil, "2.1 to 2.2 says it")
check(WhatsNew.line(previous: "2.2.0", current: "2.2.0", freshInstall: false) == nil, "the same version again: once only")
check(WhatsNew.line(previous: "2.2.0", current: "2.2.1", freshInstall: false) == nil, "a patch of a release already told about stays quiet")
check(WhatsNew.line(previous: "2.1.3", current: "2.2.1", freshInstall: false) == WhatsNew.lines["2.2"], "jumping straight to a patch still names its release's line")
check(WhatsNew.line(previous: "2.3.0", current: "2.2.0", freshInstall: false) == nil, "going back says nothing")
check(WhatsNew.line(previous: "2.1.0", current: "9.9.0", freshInstall: false) == nil, "a release with nothing written says nothing")
check(WhatsNew.isNewer("2.10.0", than: "2.9.3"), "2.10 is after 2.9")
check(!WhatsNew.isNewer("2.2", than: "2.2.0"), "2.2 and 2.2.0 are the same")
check(WhatsNew.lines.values.allSatisfy { $0.count <= 110 }, "every line fits one bubble")

print(failures == 0 ? "all good" : "\(failures) failed")
exit(failures == 0 ? 0 : 1)
