// Checks the Beside the notch scene picker on its own, no Droppy needed:
//   cp Tools/notch-scenes-check.swift /tmp/main.swift
//   swiftc Sources/Pixpaw/NotchScenes.swift /tmp/main.swift -o /tmp/notch-check && /tmp/notch-check

import Foundation

var failures = 0
func check(_ ok: Bool, _ what: String) {
    print(ok ? "ok   \(what)" : "FAIL \(what)")
    if !ok { failures += 1 }
}

let t0 = Date(timeIntervalSince1970: 1_000_000)
let ask = NotchMoment(scene: .agentAsks, text: "Claude ✋", until: nil)
let focus = NotchMoment(scene: .focus, text: "Focus", until: nil)
let command = NotchMoment(scene: .longCommand, text: "npm test", until: nil)
let done = NotchMoment.short(.agentDone, "Done ✓", at: t0)
let snag = NotchMoment.short(.agentSnag, "Claude ✗", at: t0)
let late = NotchMoment.short(.lateNight, "Late…", at: t0)

check(NotchDirector.pick([], showing: nil, lastShortEnded: nil, now: t0) == nil, "nothing wants the row: nothing shows")
check(NotchDirector.pick([done, ask, command], showing: nil, lastShortEnded: nil, now: t0) == ask, "an agent asking outranks everything")
check(NotchDirector.pick([command, focus], showing: nil, lastShortEnded: nil, now: t0) == focus, "focus outranks a long command")
check(NotchDirector.pick([done, snag], showing: nil, lastShortEnded: nil, now: t0) == snag, "a snag outranks done")
check(NotchDirector.pick([done, command], showing: nil, lastShortEnded: nil, now: t0) == command, "a long command outranks done")
check(NotchDirector.pick([late, done], showing: nil, lastShortEnded: nil, now: t0) == done, "late night comes last")

check(NotchDirector.pick([done], showing: nil, lastShortEnded: nil, now: t0.addingTimeInterval(5)) == done, "done is up within its 6 s")
check(NotchDirector.pick([done], showing: done, lastShortEnded: nil, now: t0.addingTimeInterval(6)) == nil, "done is gone at 6 s, shown or not")
check(NotchDirector.pick([snag], showing: nil, lastShortEnded: nil, now: t0.addingTimeInterval(9)) == snag, "a snag lasts 10 s")
check(NotchDirector.pick([late], showing: nil, lastShortEnded: nil, now: t0.addingTimeInterval(8)) == nil, "late night is gone at 8 s")

let recently = t0.addingTimeInterval(-30)
check(NotchDirector.pick([done], showing: nil, lastShortEnded: recently, now: t0) == nil, "a short one waits out the 2 min gap")
check(NotchDirector.pick([done], showing: done, lastShortEnded: recently, now: t0) == done, "the short one already up keeps going")
check(NotchDirector.pick([done], showing: nil, lastShortEnded: t0.addingTimeInterval(-120), now: t0) == done, "after 2 min a short one may show")
check(NotchDirector.pick([ask], showing: nil, lastShortEnded: recently, now: t0) == ask, "the gap never holds back an agent asking")
check(NotchDirector.pick([command, done], showing: nil, lastShortEnded: recently, now: t0) == command, "long scenes ignore the gap")

check(NotchDirector.dropsWhenHidden(done), "a short one hidden by Droppy is dropped")
check(!NotchDirector.dropsWhenHidden(ask), "a long one hidden by Droppy waits")
check(!NotchDirector.dropsWhenHidden(nil), "nothing up: nothing to drop")

check(NotchMomentKind.allCases.filter(\.onByDefault).count == 4 && !NotchMomentKind.lateNight.onByDefault, "every moment on by default but late nights")
check(Set(NotchScene.allCases.map(\.kind)) == Set(NotchMomentKind.allCases), "every switch has a scene")

// The light in the wings.
let moments = NotchScene.allCases.map { NotchMoment(scene: $0, text: "x", until: $0.lasts.map { t0.addingTimeInterval($0) }) }
check(Set(moments.map { NotchGlow.moment($0).color }).count == NotchScene.allCases.count, "every scene has a colour of its own")
check(moments.allSatisfy { NotchGlow.pick(on: true, mode: .moments, showing: $0, agentWorking: false, quiet: false, recording: false) != nil }, "every scene lights up in Moments")
check(NotchGlow.pick(on: true, mode: .moments, showing: ask, agentWorking: true, quiet: false, recording: true) == nil, "no light while taking meeting notes")
check(NotchGlow.pick(on: true, mode: .always, showing: nil, agentWorking: true, quiet: false, recording: true) == nil, "no light while recording, in Always too")
check(NotchGlow.pick(on: true, mode: .moments, showing: focus, agentWorking: false, quiet: true, recording: false) == nil, "no light while quiet (a call, a shared screen)")
check(NotchGlow.pick(on: false, mode: .moments, showing: ask, agentWorking: false, quiet: false, recording: false) == nil, "switched off: no light")
check(NotchGlow.pick(on: true, mode: .off, showing: focus, agentWorking: true, quiet: false, recording: false) == nil, "Off: no light, not even for focus")
let idle = NotchGlow.pick(on: true, mode: .always, showing: nil, agentWorking: true, quiet: false, recording: false)
check(idle == NotchGlow.agentWorking && idle?.lightsPet == true && idle?.rhythm == .breathe(period: 3, low: 0.35, high: 0.7), "Always, agent working: the pet and lamp breathe blue")
check(NotchGlow.pick(on: true, mode: .always, showing: nil, agentWorking: false, quiet: false, recording: false) == nil, "Always, nothing working: no light")
check(NotchGlow.moment(ask).rhythm == .blink(period: 1.4), "an agent asking blinks every 1.4 s")
check(NotchGlow.moment(done).since == t0, "a short one's light starts with it")
check(NotchGlow.moment(command).since == nil, "a long one's light repeats")
let all = moments.map { NotchGlow.moment($0).rhythm }
check(all.allSatisfy { r in [0, 0.4, 1, 2, 7].allSatisfy { !r.moves(at: $0, reduceMotion: true) } }, "Reduce Motion: nothing moves")
check(all.allSatisfy { r in stride(from: 0.0, through: 12, by: 0.05).allSatisfy { (0...1).contains(r.level(at: $0, reduceMotion: false)) } }, "every level stays between 0 and 1")
check(NotchGlowRhythm.flashOnce.level(at: 0.15, reduceMotion: false) == 1 && NotchGlowRhythm.flashOnce.level(at: 3, reduceMotion: false) == 0.3, "done flashes once, then stays dim")
check(NotchGlowRhythm.flashTwice.level(at: 0.15, reduceMotion: false) == 1 && NotchGlowRhythm.flashTwice.level(at: 0.6, reduceMotion: false) > 0.99 && NotchGlowRhythm.flashTwice.level(at: 5, reduceMotion: false) == 0.35, "a snag flashes twice, then stays dim")
check(!NotchGlowRhythm.flashOnce.moves(at: 2, reduceMotion: false) && !NotchGlowRhythm.flashTwice.moves(at: 1, reduceMotion: false), "a flash stops moving once it is over")
check(NotchGlowRhythm.flashOnce.level(at: 1, reduceMotion: true) == 0.8 && NotchGlowRhythm.flashOnce.level(at: 2, reduceMotion: true) == 0.3, "Reduce Motion: done holds 1.5 s, no flash")

print(failures == 0 ? "All notch scene checks passed." : "\(failures) notch scene check(s) failed.")
exit(failures == 0 ? 0 : 1)
