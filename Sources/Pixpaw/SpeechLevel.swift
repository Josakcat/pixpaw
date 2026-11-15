//
//  SpeechLevel.swift
//  Pixpaw
//
//  Lifts quiet speech before Apple's recognizer hears it, for meeting
//  notes. Plain Swift, no frameworks, so .droppykit/Tools/speech-level-check.swift
//  can compile it on its own.
//

/// A slow, peak-limited gain: quiet talk comes up to a level the recognizer
/// makes out, loud talk is never pushed past `ceiling`, and room noise
/// (below `floor`) isn't lifted further. Runs on the audio thread: no
/// allocation, one pass over the samples.
struct SpeechLevel {
    /// The loudest a sample is lifted to, about -3 dBFS.
    static let ceiling: Float = 0.7
    /// At most this much louder, about +18 dB.
    static let most: Float = 8
    /// A buffer whose peak is under this is noise or silence: the gain holds.
    static let floor: Float = 0.004
    /// How fast the gain may rise, in times per second (about +6 dB/s).
    /// It falls at once, so nothing clips.
    static let risePerSecond: Float = 2

    private(set) var gain: Float = 1

    /// The gain for a buffer whose peak is `peak` and which lasts `seconds`,
    /// coming from `current`. Never more than `ceiling / peak`.
    static func next(from current: Float, peak: Float, seconds: Float) -> Float {
        guard peak.isFinite, peak >= floor else { return min(current, most) }
        let wanted = min(max(ceiling / peak, 1), most)
        if wanted <= current { return wanted }
        let step = 1 + (risePerSecond - 1) * min(max(seconds, 0), 1)
        return min(wanted, current * step)
    }

    /// Lifts `count` samples in place. A rising gain ramps across the buffer
    /// so it doesn't click; every sample stays within ±1.
    mutating func apply(_ samples: UnsafeMutablePointer<Float>, count: Int, sampleRate: Double) {
        guard count > 0, sampleRate > 0 else { return }
        var peak: Float = 0
        for i in 0..<count { peak = max(peak, abs(samples[i])) }
        let start = gain
        let end = Self.next(from: gain, peak: peak, seconds: Float(Double(count) / sampleRate))
        gain = end
        // Falling: the new, lower gain from the first sample. Rising: a ramp.
        let from = min(start, end)
        let step = (end - from) / Float(count)
        if from == 1, end == 1 { return }
        for i in 0..<count {
            let lifted = samples[i] * (from + step * Float(i + 1))
            samples[i] = lifted.isFinite ? min(max(lifted, -1), 1) : 0
        }
    }
}

/// What a recognition request leaves when it ends, and how long anything
/// waits for it: at a line break and on Stop alike.
enum SpeechWords {
    /// How long an ended request (`endAudio`) may take to send its final
    /// words before it's cancelled.
    static let wait: Double = 4

    /// The words after a result comes in. An empty one never wipes what was
    /// already made out: an on-device final can come back empty after a pause.
    static func after(_ heard: String, _ result: String) -> String {
        result.allSatisfy(\.isWhitespace) ? heard : result
    }

    /// Whether a Stop is done waiting: no request left open, or `wait`
    /// seconds since it began (times in seconds, any clock).
    static func doneWaiting(open: Int, stoppedAt: Double, now: Double) -> Bool {
        open == 0 || now - stoppedAt >= wait
    }
}
