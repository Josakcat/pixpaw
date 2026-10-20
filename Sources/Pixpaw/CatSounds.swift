//
//  CatSounds.swift
//  Pixpaw
//
//  The cat's voice, synthesised once at launch: a meow (two pitches), a purr
//  and a chew. Made from sine waves and noise in code, so there are no sound
//  files to license or ship.
//

import AppKit

@MainActor
final class CatSounds {
    enum Sound { case meow, purr, chew }

    static let shared = CatSounds()

    /// Off in Settings, or while the cat is keeping quiet.
    var isEnabled = true
    private static let sampleRate = 22_050.0
    private static let volume: Float = 0.35

    private var meows: [NSSound] = []
    private var purr: NSSound?
    private var chew: NSSound?
    private var lastMeow = Date.distantPast

    private init() {}

    func play(_ sound: Sound) {
        guard isEnabled else { return }
        prepare()
        switch sound {
        case .meow:
            // A meow every few seconds at most; a chatty cat is charming once.
            guard Date().timeIntervalSince(lastMeow) > 4 else { return }
            lastMeow = Date()
            meows.randomElement().map(start)
        case .purr: purr.map(start)
        case .chew: chew.map(start)
        }
    }

    private func start(_ sound: NSSound) {
        sound.stop()
        sound.volume = Self.volume
        sound.play()
    }

    private func prepare() {
        guard meows.isEmpty else { return }
        meows = [Self.meow(pitch: 1), Self.meow(pitch: 1.18)].compactMap { NSSound(data: Self.wav($0)) }
        purr = NSSound(data: Self.wav(Self.purrSamples()))
        chew = NSSound(data: Self.wav(Self.chewSamples()))
    }

    // MARK: Synthesis

    /// "Mi-aow": the pitch rises then falls while the vowel opens and closes,
    /// with a little vibrato.
    private static func meow(pitch: Double) -> [Float] {
        let duration = 0.55
        let count = Int(duration * sampleRate)
        var samples = [Float](repeating: 0, count: count)
        var phase = 0.0
        for i in 0..<count {
            let t = Double(i) / sampleRate
            let p = t / duration
            // Pitch contour: 460 → 760 Hz at a third of the way, down to 380.
            let contour = p < 0.33 ? 460 + (760 - 460) * sin(p / 0.33 * .pi / 2)
                : 760 - (760 - 380) * pow((p - 0.33) / 0.67, 1.3)
            let f0 = contour * pitch * (1 + 0.015 * sin(2 * .pi * 6 * t))
            phase += 2 * .pi * f0 / sampleRate
            // The vowel: a formant that slides up for "ee", then down for "ow".
            let formant = 900 + 900 * sin(.pi * min(1, p * 1.4))
            var value = 0.0
            for k in 1...7 {
                let freq = f0 * Double(k)
                let emphasis = exp(-pow((freq - formant) / 700, 2))
                value += sin(phase * Double(k)) * (0.25 + emphasis) / Double(k)
            }
            let attack = min(1, t / 0.04)
            let release = min(1, (duration - t) / 0.16)
            samples[i] = Float(value * attack * release * 0.32)
        }
        return samples
    }

    /// A low rumble pulsing about 25 times a second, louder on the in-breath.
    private static func purrSamples() -> [Float] {
        let duration = 1.3
        let count = Int(duration * sampleRate)
        var samples = [Float](repeating: 0, count: count)
        var noise: Float = 0
        for i in 0..<count {
            let t = Double(i) / sampleRate
            noise = noise * 0.97 + Float.random(in: -1...1) * 0.03
            let rumble = 0.5 * sin(2 * .pi * 48 * t) + 0.3 * sin(2 * .pi * 96 * t) + Double(noise) * 6
            let pulse = pow(0.5 + 0.5 * sin(2 * .pi * 25 * t), 2)
            let breath = t < 0.6 ? 1.0 : 0.7
            let envelope = min(1, t / 0.1) * min(1, (duration - t) / 0.2)
            samples[i] = Float(rumble * pulse * breath * envelope * 0.5)
        }
        return samples
    }

    /// Three crunches of filtered noise.
    private static func chewSamples() -> [Float] {
        let duration = 0.55
        let count = Int(duration * sampleRate)
        var samples = [Float](repeating: 0, count: count)
        var previous: Float = 0
        for start in [0.0, 0.17, 0.34] {
            let from = Int(start * sampleRate)
            let length = Int(0.07 * sampleRate)
            for j in 0..<length where from + j < count {
                let white = Float.random(in: -1...1)
                let crunch = white - previous * 0.6
                previous = white
                samples[from + j] += crunch * Float(exp(-Double(j) / (0.018 * sampleRate))) * 0.45
            }
        }
        return samples
    }

    /// 16-bit mono PCM in a WAV container, which NSSound plays directly.
    private static func wav(_ samples: [Float]) -> Data {
        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
        }
        let rate = UInt32(sampleRate)
        let bytes = UInt32(samples.count * 2)
        data.append(contentsOf: Array("RIFF".utf8)); append(UInt32(36 + bytes))
        data.append(contentsOf: Array("WAVEfmt ".utf8)); append(UInt32(16)); append(UInt16(1)); append(UInt16(1))
        append(rate); append(rate * 2); append(UInt16(2)); append(UInt16(16))
        data.append(contentsOf: Array("data".utf8)); append(bytes)
        for sample in samples {
            append(Int16(max(-1, min(1, sample)) * Float(Int16.max)))
        }
        return data
    }
}
