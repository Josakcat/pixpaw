// Checks when the app in front counts as full screen (the pet goes quiet),
// on its own, no Droppy needed:
//   cp .droppykit/Tools/quiet-check.swift /tmp/main.swift
//   swiftc Sources/Pixpaw/FullScreenRule.swift /tmp/main.swift -o /tmp/quiet-check && /tmp/quiet-check

import CoreGraphics

var failures = 0
func expect(_ ok: Bool, _ what: String) {
    if !ok { failures += 1; print("FAIL:", what) }
}

typealias W = FullScreenRule.Window
let main = CGRect(x: 0, y: 0, width: 1512, height: 982)
let side = CGRect(x: 1512, y: 0, width: 2560, height: 1440)
let displays = [main, side]

expect(FullScreenRule.fills([W(pid: 5, layer: 0, alpha: 1, bounds: main)], front: 5, own: 1, displays: displays), "front app full screen on the main display")
expect(FullScreenRule.fills([W(pid: 5, layer: 0, alpha: 1, bounds: side)], front: 5, own: 1, displays: displays), "front app full screen on a second display")
expect(FullScreenRule.fills([W(pid: 5, layer: 0, alpha: 1, bounds: main.insetBy(dx: -0.5, dy: -0.5))], front: 5, own: 1, displays: displays), "a rounded frame still counts")
expect(FullScreenRule.fills([W(pid: 5, layer: 101, alpha: 1, bounds: main)], front: 5, own: 1, displays: displays), "a slideshow above normal level counts")
expect(!FullScreenRule.fills([W(pid: 5, layer: 0, alpha: 1, bounds: CGRect(x: 0, y: 25, width: 1512, height: 957))], front: 5, own: 1, displays: displays), "a big window under the menu bar is not full screen")
expect(!FullScreenRule.fills([W(pid: 6, layer: 0, alpha: 1, bounds: main)], front: 5, own: 1, displays: displays), "another app's full-screen window behind does not count")
expect(!FullScreenRule.fills([W(pid: 5, layer: 0, alpha: 0, bounds: main)], front: 5, own: 1, displays: displays), "a clear overlay does not count")
expect(!FullScreenRule.fills([W(pid: 5, layer: 2000, alpha: 1, bounds: main)], front: 5, own: 1, displays: displays), "a screen-saver level window does not count")
expect(!FullScreenRule.fills([W(pid: 1, layer: 0, alpha: 1, bounds: main)], front: 1, own: 1, displays: displays), "Droppy itself in front never counts")
expect(!FullScreenRule.fills([], front: 5, own: 1, displays: displays), "no windows")
expect(!FullScreenRule.covers(main, .zero), "an empty display covers nothing")

if failures == 0 { print("quiet-check: all good") } else { print("quiet-check: \(failures) failed"); exit(1) }
