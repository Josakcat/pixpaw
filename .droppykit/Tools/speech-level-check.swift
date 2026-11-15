// Checks the meeting-notes gain (SpeechLevel): quiet speech comes up slowly,
// loud speech is never pushed past the ceiling or clipped, noise isn't lifted;
// and SpeechWords: an empty final keeps the words, Stop waits at most 4 s,
// on its own, no Droppy needed:
//   cp .droppykit/Tools/speech-level-check.swift /tmp/main.swift
//   swiftc Sources/Pixpaw/SpeechLevel.swift /tmp/main.swift -o /tmp/speech-level-check && /tmp/speech-level-check

import Foundation

var failures = 0
func check(_ ok: Bool, _ what: String) {
    print(ok ? "ok   \(what)" : "FAIL \(what)")
    if !ok { failures += 1 }
}

/// A sine of `amplitude`, `count` samples at 16 kHz.
func tone(_ amplitude: Float, count: Int = 1600) -> [Float] {
    (0..<count).map { amplitude * sin(Float($0) * 0.3) }
}

func run(_ level: inout SpeechLevel, _ samples: [Float], rate: Double = 16_000) -> [Float] {
    var copy = samples
    copy.withUnsafeMutableBufferPointer { level.apply($0.baseAddress!, count: $0.count, sampleRate: rate) }
    return copy
}

// The maths alone.
check(SpeechLevel.next(from: 1, peak: 0.7, seconds: 0.1) == 1, "speech at the ceiling isn't lifted")
check(SpeechLevel.next(from: 4, peak: 0.7, seconds: 0.1) == 1, "loud speech drops the gain at once")
check(SpeechLevel.next(from: 1, peak: 0.001, seconds: 1) == 1, "noise below the floor isn't lifted")
check(SpeechLevel.next(from: 3, peak: 0.001, seconds: 1) == 3, "a pause holds the gain")
var g: Float = 1
for _ in 0..<100 { g = SpeechLevel.next(from: g, peak: 0.01, seconds: 1) }
check(g == SpeechLevel.most, "never more than the most")
check(SpeechLevel.next(from: 1, peak: 0.01, seconds: 100) <= SpeechLevel.risePerSecond, "a long buffer rises one second's worth")
check(SpeechLevel.next(from: 1, peak: 0.05, seconds: 0.1) <= 1.11, "the gain rises slowly")
check(SpeechLevel.next(from: 1, peak: .nan, seconds: 0.1) == 1, "a broken peak changes nothing")
check(SpeechLevel.next(from: 1, peak: 2, seconds: 0.1) == 1, "never quieter than as it came")

// Quiet speech, five seconds of it: comes up to near the ceiling.
var level = SpeechLevel()
var out: [Float] = []
for _ in 0..<50 { out = run(&level, tone(0.05)) }
let quietPeak = out.map(abs).max()!
check(quietPeak > 0.3 && quietPeak <= SpeechLevel.ceiling + 0.0001, "quiet speech comes up (peak \(quietPeak))")

// Then someone loud: not one sample past the ceiling, nothing clipped.
out = run(&level, tone(0.9))
let loudPeak = out.map(abs).max()!
check(loudPeak <= 0.9 + 0.0001, "loud speech straight after isn't lifted (peak \(loudPeak))")
check(out.allSatisfy { abs($0) <= 1 }, "nothing past ±1")

// Never a click: a rising gain ramps.
var ramp = SpeechLevel()
let flat = run(&ramp, [Float](repeating: 0.1, count: 1600))
check(zip(flat, flat.dropFirst()).allSatisfy { $1 >= $0 - 0.00001 }, "the gain ramps up within a buffer")
check(flat.max()! <= SpeechLevel.ceiling, "the ramp stays under the ceiling")

// Silence stays silence; garbage doesn't spread.
var quiet = SpeechLevel()
check(run(&quiet, [Float](repeating: 0, count: 512)).allSatisfy { $0 == 0 }, "silence stays silent")
var odd = SpeechLevel()
_ = run(&odd, [0.01, .infinity, -0.01])
check(odd.gain.isFinite && odd.gain >= 1, "an infinite sample leaves the gain sane")

// SpeechWords: what Stop keeps, and how long it waits.
check(SpeechWords.after("see you on", "see you on Monday") == "see you on Monday", "a final result replaces the partial")
check(SpeechWords.after("see you on Monday", "") == "see you on Monday", "an empty final keeps the words")
check(SpeechWords.after("see you", "  ") == "see you", "a blank final keeps the words")
check(SpeechWords.after("", "hello") == "hello", "first words come in")
check(SpeechWords.wait == 4, "Stop waits the same 4 s as a line break")
check(SpeechWords.doneWaiting(open: 0, stoppedAt: 100, now: 100), "nothing open: done at once")
check(!SpeechWords.doneWaiting(open: 2, stoppedAt: 100, now: 103.9), "both sides open: still waiting at 3.9 s")
check(SpeechWords.doneWaiting(open: 1, stoppedAt: 100, now: 104), "a side that never answers: given up at 4 s")

print(failures == 0 ? "all ok" : "\(failures) failed")
exit(failures == 0 ? 0 : 1)
