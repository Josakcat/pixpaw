//
//  CatSounds.swift
//  Pixpaw
//
//  The voices, synthesised the first time they are needed: the cat's meow
//  (two pitches), purr and chew, and the other characters' calls: the bee's
//  buzz, the parrot's squawk, the dinosaur's rawr, the dog's bark, the
//  hamster's squeak, the chicken's bawk, the giraffe's hum, the hippo's
//  honk, the rabbit's thump, the shark's chomp and the pig's oink. Made from sine waves and noise in
//  code. Where Pixpaw ships a recorded voice (CC0 recordings in
//  Assets/Sounds, credited in README.md: every pet's call, the cat's purr and
//  the chew) that plays instead, the synthesised one behind it in case the
//  file is missing or won't decode. Pets you draw yourself can bring sounds
//  of their own (OwnPets.swift).
//
//  What to play is decided here, on the main actor; making a voice's samples,
//  reading a pet's own sound file and the playing all happen on SoundOutput's
//  own queue, because synthesis and file reads are heavy and starting a sound
//  waits for the audio device to start.
//

import AppKit
import AVFoundation

@MainActor
final class CatSounds {
    enum Sound { case meow, purr, chew, hiss }

    static let shared = CatSounds()

    /// Off in Settings, or while the cat is keeping quiet.
    var isEnabled = true
    private nonisolated static let sampleRate = 22_050.0
    private static let volume: Float = 0.35

    /// One character's sounds, made once.
    private struct Voice {
        var calls: [SoundClip]
        var content: SoundClip?
        var chew: SoundClip?
    }

    private var voices: [PetKind: Voice] = [:]
    private var lastMeow = Date.distantPast
    private lazy var hiss = Self.clip(Self.hissSamples())
    /// One chew for everyone: a recording, shared by every pet's voice.
    private lazy var chew = Self.recorded("all-chew", else: Self.clip(Self.chewSamples()))

    private init() {}

    /// Plays a sound in a character's voice: for the bee, a meow is a buzz
    /// and a purr a contented hum.
    func play(_ sound: Sound, voice kind: PetKind = .cat) {
        guard isEnabled else { return }
        let voice = prepare(kind)
        let clip: SoundClip?
        switch sound {
        case .meow:
            // A call every few seconds at most; a chatty pet is charming once.
            guard Date().timeIntervalSince(lastMeow) > 4 else { return }
            lastMeow = Date()
            clip = voice.calls.randomElement()
        case .purr: clip = voice.content
        case .chew: clip = voice.chew
        // A warning: a dog barks it, everyone else hisses.
        case .hiss: clip = kind.actsLike == .dog ? voice.calls.first : hiss
        }
        if let clip { SoundOutput.shared.play(clip, volume: Self.volume) }
    }

    /// Drops the voices of the pets you drew, after their sounds changed.
    func forgetOwnPets() {
        voices = voices.filter { !$0.key.isOwn }
    }

    /// Plays one of a pet's own sounds, to try it.
    func preview(_ url: URL) {
        SoundOutput.shared.preview(url, volume: Self.volume)
    }

    private func prepare(_ kind: PetKind) -> Voice {
        guard kind.isOwn else { return builtIn(kind) }
        if let made = voices[kind] { return made }
        // A pet you drew speaks in its own sounds, and in the voice of the
        // character it acts like for the ones it hasn't got. Each is a WAV
        // Pixpaw wrote when you brought it in, read whole on the sound queue
        // the first time it plays; one that can't be read plays the built-in.
        func own(_ sound: OwnSound, else fallback: SoundClip?) -> SoundClip? {
            guard let url = OwnPets.sound(sound, of: kind) else { return nil }
            return SoundClip { (try? Data(contentsOf: url)) ?? fallback?.bytes() }
        }
        var voice = builtIn(kind.actsLike)
        if let call = own(.call, else: voice.calls.first) { voice.calls = [call] }
        if let happy = own(.happy, else: voice.content) { voice.content = happy }
        if let eating = own(.eating, else: voice.chew) { voice.chew = eating }
        voices[kind] = voice
        return voice
    }

    private func builtIn(_ kind: PetKind) -> Voice {
        if let made = voices[kind] { return made }
        var voice: Voice
        switch kind {
        case .cat, .own1, .own2, .own3, .own4, .own5:
            voice = Voice(calls: [Self.clip(Self.meow(pitch: 1)), Self.clip(Self.meow(pitch: 1.18))],
                          content: Self.clip(Self.purrSamples()), chew: Self.clip(Self.chewSamples()))
        case .bee:
            voice = Voice(calls: [Self.clip(Self.buzz(pitch: 1)), Self.clip(Self.buzz(pitch: 1.2))],
                          content: Self.clip(Self.humSamples()), chew: Self.clip(Self.chewSamples()))
        case .parrot:
            voice = Voice(calls: [Self.clip(Self.squawk(pitch: 1)), Self.clip(Self.squawk(pitch: 1.15))],
                          content: Self.clip(Self.chirpSamples()), chew: Self.clip(Self.chewSamples()))
        case .dino:
            voice = Voice(calls: [Self.clip(Self.rawr(pitch: 1)), Self.clip(Self.rawr(pitch: 1.2))],
                          content: Self.clip(Self.purrSamples()), chew: Self.clip(Self.chewSamples()))
        case .dragon:
            voice = Voice(calls: [Self.clip(Self.tripleRawr(pitch: 1)), Self.clip(Self.tripleRawr(pitch: 1.1))],
                          content: Self.clip(Self.purrSamples(pitch: 0.7)), chew: Self.clip(Self.chewSamples()))
        case .dog:
            voice = Voice(calls: [Self.clip(Self.bark(pitch: 1, times: 2)), Self.clip(Self.bark(pitch: 1.15, times: 1))],
                          content: Self.clip(Self.pantSamples()), chew: Self.clip(Self.chewSamples()))
        case .hamster:
            voice = Voice(calls: [Self.clip(Self.squeak(pitch: 1, times: 1)), Self.clip(Self.squeak(pitch: 1.12, times: 2))],
                          content: Self.clip(Self.chitterSamples()), chew: Self.clip(Self.chewSamples()))
        case .chicken:
            voice = Voice(calls: [Self.clip(Self.bawk(pitch: 1)), Self.clip(Self.bawk(pitch: 1.12))],
                          content: Self.clip(Self.cluckSamples()), chew: Self.clip(Self.chewSamples()))
        case .giraffe:
            voice = Voice(calls: [Self.clip(Self.lowHum(pitch: 1)), Self.clip(Self.lowHum(pitch: 1.15))],
                          content: Self.clip(Self.humSamples()), chew: Self.clip(Self.chewSamples()))
        case .hippo:
            voice = Voice(calls: [Self.clip(Self.honk(pitch: 1, times: 2)), Self.clip(Self.honk(pitch: 0.9, times: 3))],
                          content: Self.clip(Self.bubbles(pitch: 0.6)), chew: Self.clip(Self.chewSamples()))
        case .rabbit:
            voice = Voice(calls: [Self.clip(Self.thump(times: 2)), Self.clip(Self.squeak(pitch: 1.3, times: 1))],
                          content: Self.clip(Self.chitterSamples()), chew: Self.clip(Self.chewSamples()))
        case .shark:
            voice = Voice(calls: [Self.clip(Self.chomp(times: 2)), Self.clip(Self.chomp(times: 1))],
                          content: Self.clip(Self.bubbles(pitch: 1)), chew: Self.clip(Self.chewSamples()))
        case .pig:
            voice = Voice(calls: [Self.clip(Self.oink(pitch: 1, times: 2)), Self.clip(Self.oink(pitch: 1.12, times: 1))],
                          content: Self.clip(Self.oink(pitch: 0.85, times: 3)), chew: Self.clip(Self.chewSamples()))
        }
        // The recorded voices, the synthesised ones kept behind them.
        voice.calls = [Self.recorded(Self.recordedCall(kind), else: voice.calls.first)]
        if kind == .cat { voice.content = Self.recorded("cat-purr", else: voice.content) }
        voice.chew = chew
        voices[kind] = voice
        return voice
    }

    /// The name of a character's recorded call in Assets/Sounds.
    private static func recordedCall(_ kind: PetKind) -> String {
        switch kind {
        case .cat, .own1, .own2, .own3, .own4, .own5: "cat-call"
        case .bee: "bee-call"
        case .parrot: "parrot-call"
        case .dino: "dino-call"
        case .dragon: "dragon-call"
        case .dog: "dog-call"
        case .hamster: "hamster-call"
        case .chicken: "chicken-call"
        case .giraffe: "giraffe-call"
        case .hippo: "hippo-call"
        case .rabbit: "rabbit-call"
        case .shark: "shark-call"
        case .pig: "pig-call"
        }
    }

    // MARK: Recordings

    /// A recorded sound from the droplet's bundle, found and decoded the
    /// first time it plays, on the sound queue, never on the main thread. One
    /// that is missing or won't decode plays the synthesised `fallback`.
    /// Played a little faster or slower each time, so repeats differ.
    private nonisolated static func recorded(_ name: String, else fallback: SoundClip?) -> SoundClip {
        SoundClip(varies: true) {
            let url = Bundle(for: SoundClip.self)
                .url(forResource: name, withExtension: "m4a", subdirectory: "Assets/Sounds")
            if let url, let data = decoded(url) { return data }
            return fallback?.bytes()
        }
    }

    /// A compressed sound file as 16-bit mono PCM WAV, or nil.
    private nonisolated static func decoded(_ url: URL) -> Data? {
        do {
            let file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
            guard file.length > 0,
                  let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                                frameCapacity: AVAudioFrameCount(file.length)) else { return nil }
            try file.read(into: buffer)
            guard let channel = buffer.floatChannelData, buffer.frameLength > 0 else { return nil }
            let samples = Array(UnsafeBufferPointer(start: channel[0], count: Int(buffer.frameLength)))
            return wav(samples, rate: file.processingFormat.sampleRate)
        } catch {
            return nil
        }
    }

    // MARK: Synthesis

    /// "Hhhsss": breathy noise, bright and sharp at the start, fading out.
    private nonisolated static func hissSamples() -> [Float] {
        let duration = 0.7
        let count = Int(duration * sampleRate)
        var samples = [Float](repeating: 0, count: count)
        var last: Float = 0
        for i in 0..<count {
            let t = Double(i) / sampleRate
            let noise = Float.random(in: -1...1)
            // Differenced noise: the hiss, without the rumble.
            let bright = noise - last
            last = noise
            let envelope = min(1, t / 0.04) * pow(1 - t / duration, 1.6)
            samples[i] = bright * Float(envelope) * 0.3
        }
        return samples
    }

    /// "Mi-aow": the pitch rises then falls while the vowel opens and closes,
    /// with a little vibrato.
    private nonisolated static func meow(pitch: Double) -> [Float] {
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
    /// `pitch` below 1 lowers the rumble (the dragon's three chests).
    private nonisolated static func purrSamples(pitch: Double = 1) -> [Float] {
        let duration = 1.3
        let count = Int(duration * sampleRate)
        var samples = [Float](repeating: 0, count: count)
        var noise: Float = 0
        for i in 0..<count {
            let t = Double(i) / sampleRate
            noise = noise * 0.97 + Float.random(in: -1...1) * 0.03
            let rumble = 0.5 * sin(2 * .pi * 48 * pitch * t) + 0.3 * sin(2 * .pi * 96 * pitch * t) + Double(noise) * 6
            let pulse = pow(0.5 + 0.5 * sin(2 * .pi * 25 * t), 2)
            let breath = t < 0.6 ? 1.0 : 0.7
            let envelope = min(1, t / 0.1) * min(1, (duration - t) / 0.2)
            samples[i] = Float(rumble * pulse * breath * envelope * 0.5)
        }
        return samples
    }

    /// "Bzzz-zz": a buzzy sawtooth that swells, dips and swells again, its
    /// pitch wavering like wings beating.
    private nonisolated static func buzz(pitch: Double) -> [Float] {
        let duration = 0.6
        let count = Int(duration * sampleRate)
        var samples = [Float](repeating: 0, count: count)
        var phase = 0.0
        var smooth = 0.0
        for i in 0..<count {
            let t = Double(i) / sampleRate
            let p = t / duration
            let f0 = (210 + 40 * sin(.pi * p)) * pitch * (1 + 0.04 * sin(2 * .pi * 38 * t))
            phase += f0 / sampleRate
            let saw = 2 * (phase - floor(phase)) - 1
            // Soften the edges a little so it buzzes rather than rasps.
            smooth += (saw - smooth) * 0.35
            let swell = 0.65 + 0.35 * sin(2 * .pi * 3.2 * t)
            let envelope = min(1, t / 0.03) * min(1, (duration - t) / 0.12)
            samples[i] = Float(smooth * swell * envelope * 0.28)
        }
        return samples
    }

    /// A low, contented hum: the buzz slowed and softened.
    private nonisolated static func humSamples() -> [Float] {
        let duration = 1.1
        let count = Int(duration * sampleRate)
        var samples = [Float](repeating: 0, count: count)
        var phase = 0.0
        var smooth = 0.0
        for i in 0..<count {
            let t = Double(i) / sampleRate
            phase += 150 * (1 + 0.02 * sin(2 * .pi * 30 * t)) / sampleRate
            let saw = 2 * (phase - floor(phase)) - 1
            smooth += (saw - smooth) * 0.15
            let envelope = min(1, t / 0.12) * min(1, (duration - t) / 0.25)
            samples[i] = Float(smooth * envelope * 0.32)
        }
        return samples
    }

    /// "Rrah!": a short, raspy call that jumps up and falls away, harmonics
    /// roughened with a little noise.
    private nonisolated static func squawk(pitch: Double) -> [Float] {
        let duration = 0.34
        let count = Int(duration * sampleRate)
        var samples = [Float](repeating: 0, count: count)
        var phase = 0.0
        for i in 0..<count {
            let t = Double(i) / sampleRate
            let p = t / duration
            let f0 = (p < 0.25 ? 900 + 700 * p / 0.25 : 1600 - 700 * (p - 0.25) / 0.75) * pitch
            phase += 2 * .pi * f0 * (1 + 0.03 * Double.random(in: -1...1)) / sampleRate
            var value = 0.0
            for k in 1...5 { value += sin(phase * Double(k)) / Double(k) }
            value += Double.random(in: -1...1) * 0.25
            let envelope = min(1, t / 0.015) * min(1, (duration - t) / 0.08)
            samples[i] = Float(value * envelope * 0.22)
        }
        return samples
    }

    /// "Rawr!": a little roar, more cute than scary. A growly low tone that
    /// rises and falls, roughened by a fast flutter and a breath of noise.
    private nonisolated static func rawr(pitch: Double) -> [Float] {
        let duration = 0.55
        let count = Int(duration * sampleRate)
        var samples = [Float](repeating: 0, count: count)
        var phase = 0.0
        var noise = 0.0
        for i in 0..<count {
            let t = Double(i) / sampleRate
            let p = t / duration
            let f0 = (220 + 160 * sin(.pi * min(1, p * 1.3))) * pitch
            phase += 2 * .pi * f0 / sampleRate
            var value = 0.0
            for k in 1...6 { value += sin(phase * Double(k)) / Double(k) }
            let growl = 0.6 + 0.4 * sin(2 * .pi * 34 * t)
            noise = noise * 0.9 + Double.random(in: -1...1) * 0.1
            let envelope = min(1, t / 0.05) * min(1, (duration - t) / 0.18)
            samples[i] = Float((value * growl + noise * 1.5) * envelope * 0.22)
        }
        return samples
    }

    /// "Rawr-rawr-rawr": the dinosaur's rawr from three heads, high, middle
    /// and low, each starting about 80 ms after the last and overlapping.
    private nonisolated static func tripleRawr(pitch: Double) -> [Float] {
        let heads = [1.25, 1.0, 0.8].map { rawr(pitch: $0 * pitch) }
        let offset = Int(0.08 * sampleRate)
        var samples = [Float](repeating: 0, count: (heads.map(\.count).max() ?? 0) + offset * (heads.count - 1))
        for (n, head) in heads.enumerated() {
            for (i, value) in head.enumerated() { samples[n * offset + i] += value * 0.7 }
        }
        return samples
    }

    /// "Woof" (or "woof-woof"): short bursts that start high and drop,
    /// rough with a little noise.
    private nonisolated static func bark(pitch: Double, times: Int) -> [Float] {
        let length = 0.16, gap = 0.12
        let count = Int((Double(times) * (length + gap)) * sampleRate)
        var samples = [Float](repeating: 0, count: count)
        for n in 0..<times {
            let from = Int(Double(n) * (length + gap) * sampleRate)
            var phase = 0.0
            var noise = 0.0
            for j in 0..<Int(length * sampleRate) where from + j < count {
                let t = Double(j) / sampleRate
                let p = t / length
                let f0 = (560 - 220 * p) * pitch
                phase += 2 * .pi * f0 / sampleRate
                var value = 0.0
                for k in 1...6 { value += sin(phase * Double(k)) * (k == 2 || k == 3 ? 0.8 : 0.4) / Double(k) }
                noise = noise * 0.7 + Double.random(in: -1...1) * 0.3
                let envelope = min(1, t / 0.008) * pow(1 - p, 1.5)
                samples[from + j] = Float((value + noise * 0.5) * envelope * 0.4)
            }
        }
        return samples
    }

    /// Happy panting: four quick breathy huffs.
    private nonisolated static func pantSamples() -> [Float] {
        let duration = 1.0
        let count = Int(duration * sampleRate)
        var samples = [Float](repeating: 0, count: count)
        var low = 0.0, band = 0.0
        for i in 0..<count {
            let t = Double(i) / sampleRate
            let beat = (t * 4).truncatingRemainder(dividingBy: 1)
            let huff = beat < 0.45 ? sin(.pi * beat / 0.45) : 0
            // Noise through a rough band-pass, so it sounds like breath, not hiss.
            let white = Double.random(in: -1...1)
            low += (white - low) * 0.35
            band += (low - band) * 0.08
            let envelope = min(1, (duration - t) / 0.1)
            samples[i] = Float((low - band) * huff * envelope * 0.9)
        }
        return samples
    }

    /// "Eek" (or "eek-eek"): tiny high squeaks that rise and fall, with a
    /// fast flutter.
    private nonisolated static func squeak(pitch: Double, times: Int) -> [Float] {
        let length = 0.11, gap = 0.07
        let count = Int(Double(times) * (length + gap) * sampleRate)
        var samples = [Float](repeating: 0, count: count)
        for n in 0..<times {
            let from = Int(Double(n) * (length + gap) * sampleRate)
            var phase = 0.0
            for j in 0..<Int(length * sampleRate) where from + j < count {
                let t = Double(j) / sampleRate
                let p = t / length
                let f0 = (2400 + 900 * sin(.pi * p)) * pitch * (1 + 0.03 * sin(2 * .pi * 70 * t))
                phase += 2 * .pi * f0 / sampleRate
                let envelope = sin(.pi * p)
                samples[from + j] = Float((sin(phase) + 0.25 * sin(phase * 2)) * envelope * 0.3)
            }
        }
        return samples
    }

    /// Contented chittering: a soft run of tiny clicks, like teeth grinding.
    private nonisolated static func chitterSamples() -> [Float] {
        let duration = 0.9
        let count = Int(duration * sampleRate)
        var samples = [Float](repeating: 0, count: count)
        var t = 0.02
        while t < duration - 0.03 {
            let from = Int(t * sampleRate)
            let click = Int(0.006 * sampleRate)
            for j in 0..<click where from + j < count {
                let decay = 1 - Double(j) / Double(click)
                samples[from + j] += Float(Double.random(in: -1...1) * decay * decay * 0.35)
            }
            t += Double.random(in: 0.03...0.06)
        }
        return samples
    }

    /// "Buk-buk-BAWK": two short clucks, then a long nasal squawk that
    /// rises and falls.
    private nonisolated static func bawk(pitch: Double) -> [Float] {
        let notes: [(start: Double, length: Double, from: Double, to: Double)] =
            [(0, 0.07, 520, 480), (0.11, 0.07, 540, 500), (0.24, 0.32, 620, 900)]
        let count = Int(0.6 * sampleRate)
        var samples = [Float](repeating: 0, count: count)
        for note in notes {
            let from = Int(note.start * sampleRate)
            var phase = 0.0
            for j in 0..<Int(note.length * sampleRate) where from + j < count {
                let t = Double(j) / sampleRate
                let p = t / note.length
                // The long one goes up and comes back down at the end.
                let bend = note.length > 0.1 ? sin(.pi * min(1, p * 1.4)) : p
                let f0 = (note.from + (note.to - note.from) * bend) * pitch
                phase += 2 * .pi * f0 / sampleRate
                var value = 0.0
                for k in 1...8 { value += sin(phase * Double(k)) * (k >= 3 && k <= 5 ? 0.9 : 0.35) / Double(k) }
                let envelope = min(1, t / 0.01) * min(1, (note.length - t) / 0.04)
                samples[from + j] = Float(value * envelope * 0.3)
            }
        }
        return samples
    }

    /// Soft contented clucks: "bok... bok bok".
    private nonisolated static func cluckSamples() -> [Float] {
        let count = Int(0.9 * sampleRate)
        var samples = [Float](repeating: 0, count: count)
        for start in [0.05, 0.42, 0.6] {
            let from = Int(start * sampleRate)
            let length = 0.09
            var phase = 0.0
            for j in 0..<Int(length * sampleRate) where from + j < count {
                let t = Double(j) / sampleRate
                let f0 = 330 - 80 * t / length
                phase += 2 * .pi * f0 / sampleRate
                var value = 0.0
                for k in 1...5 { value += sin(phase * Double(k)) / Double(k) }
                let envelope = min(1, t / 0.006) * pow(1 - t / length, 2)
                samples[from + j] = Float(value * envelope * 0.32)
            }
        }
        return samples
    }

    /// Three quick rising chirps: a happy little trill.
    private nonisolated static func chirpSamples() -> [Float] {
        let duration = 0.6
        let count = Int(duration * sampleRate)
        var samples = [Float](repeating: 0, count: count)
        for (n, start) in [0.0, 0.18, 0.36].enumerated() {
            var phase = 0.0
            let length = 0.12
            let from = Int(start * sampleRate)
            for j in 0..<Int(length * sampleRate) where from + j < count {
                let t = Double(j) / sampleRate
                let f = (2200 + 1400 * t / length) * (1 + 0.06 * Double(n))
                phase += 2 * .pi * f / sampleRate
                let envelope = sin(.pi * t / length)
                samples[from + j] += Float(sin(phase) * envelope * 0.3)
            }
        }
        return samples
    }

    /// Three crunches of filtered noise.
    private nonisolated static func chewSamples() -> [Float] {
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

    /// "Mmmm": the low hum giraffes make at night, a soft warm tone that
    /// slides down a little.
    private nonisolated static func lowHum(pitch: Double) -> [Float] {
        let duration = 0.8
        let count = Int(duration * sampleRate)
        var samples = [Float](repeating: 0, count: count)
        var phase = 0.0
        for i in 0..<count {
            let t = Double(i) / sampleRate
            let p = t / duration
            phase += 2 * .pi * (120 - 25 * p) * pitch / sampleRate
            let value = sin(phase) * 0.6 + sin(phase * 2) * 0.3 + sin(phase * 3) * 0.12
            let envelope = min(1, t / 0.1) * min(1, (duration - t) / 0.3)
            samples[i] = Float(value * envelope * 0.45)
        }
        return samples
    }

    /// "Honk-honk": short, deep, nasal blasts with a breathy edge.
    private nonisolated static func honk(pitch: Double, times: Int) -> [Float] {
        let length = 0.18, gap = 0.1
        let count = Int((Double(times) * (length + gap)) * sampleRate)
        var samples = [Float](repeating: 0, count: count)
        for n in 0..<times {
            let from = Int(Double(n) * (length + gap) * sampleRate)
            var phase = 0.0
            var noise = 0.0
            for j in 0..<Int(length * sampleRate) where from + j < count {
                let t = Double(j) / sampleRate
                let p = t / length
                phase += 2 * .pi * (170 + 40 * sin(.pi * p)) * pitch / sampleRate
                var value = 0.0
                for k in 1...8 { value += sin(phase * Double(k)) * (k >= 3 && k <= 5 ? 0.9 : 0.35) / Double(k) }
                noise = noise * 0.8 + Double.random(in: -1...1) * 0.2
                let envelope = min(1, t / 0.015) * pow(1 - p, 1.2)
                samples[from + j] = Float((value + noise * 0.4) * envelope * 0.4)
            }
        }
        return samples
    }

    /// Oink: a short nasal grunt, falling in pitch, rough with breath.
    private nonisolated static func oink(pitch: Double, times: Int) -> [Float] {
        let length = 0.2, gap = 0.12
        let count = Int((Double(times) * (length + gap)) * sampleRate)
        var samples = [Float](repeating: 0, count: count)
        for n in 0..<times {
            let from = Int(Double(n) * (length + gap) * sampleRate)
            var phase = 0.0
            var noise = 0.0
            for j in 0..<Int(length * sampleRate) where from + j < count {
                let t = Double(j) / sampleRate
                let p = t / length
                phase += 2 * .pi * (290 - 110 * p) * pitch / sampleRate
                var value = 0.0
                for k in 1...6 { value += sin(phase * Double(k)) * (k >= 2 && k <= 4 ? 1 : 0.4) / Double(k) }
                noise = noise * 0.6 + Double.random(in: -1...1) * 0.4
                let rough = 0.7 + 0.3 * sin(2 * .pi * 38 * t)
                let envelope = min(1, t / 0.01) * pow(1 - p, 1.4)
                samples[from + j] = Float((value * rough + noise * 0.5) * envelope * 0.4)
            }
        }
        return samples
    }

    /// Thump-thump: a back foot stamped on the floor, a soft low knock.
    private nonisolated static func thump(times: Int) -> [Float] {
        let length = 0.09, gap = 0.11
        let count = Int((Double(times) * (length + gap)) * sampleRate)
        var samples = [Float](repeating: 0, count: count)
        for n in 0..<times {
            let from = Int(Double(n) * (length + gap) * sampleRate)
            var noise = 0.0
            for j in 0..<Int(length * sampleRate) where from + j < count {
                let t = Double(j) / sampleRate
                noise = noise * 0.9 + Double.random(in: -1...1) * 0.1
                let knock = sin(2 * .pi * (95 - 300 * t) * t)
                samples[from + j] = Float((knock * 0.8 + noise * 2) * exp(-t * 45) * 0.6)
            }
        }
        return samples
    }

    /// Chomp: jaws snapping shut, a click on top of a dull thud.
    private nonisolated static func chomp(times: Int) -> [Float] {
        let length = 0.12, gap = 0.08
        let count = Int((Double(times) * (length + gap)) * sampleRate)
        var samples = [Float](repeating: 0, count: count)
        for n in 0..<times {
            let from = Int(Double(n) * (length + gap) * sampleRate)
            for j in 0..<Int(length * sampleRate) where from + j < count {
                let t = Double(j) / sampleRate
                let click = t < 0.006 ? Double.random(in: -1...1) : 0
                let thud = sin(2 * .pi * 140 * t) * exp(-t * 30)
                samples[from + j] = Float((click * 0.7 + thud) * 0.5)
            }
        }
        return samples
    }

    /// Blub-blub: a few bubbles rising, each a quick upward chirp.
    private nonisolated static func bubbles(pitch: Double) -> [Float] {
        let duration = 0.9
        let count = Int(duration * sampleRate)
        var samples = [Float](repeating: 0, count: count)
        for start in [0.0, 0.22, 0.38, 0.62] {
            var phase = 0.0
            let from = Int(start * sampleRate)
            for j in 0..<Int(0.12 * sampleRate) where from + j < count {
                let t = Double(j) / sampleRate
                phase += 2 * .pi * (300 + 2200 * t) * pitch / sampleRate
                samples[from + j] += Float(sin(phase) * exp(-t * 25) * 0.35)
            }
        }
        return samples
    }

    /// One of the voices, its samples made the first time it plays, on the
    /// sound queue, never on the main thread.
    private nonisolated static func clip(_ samples: @escaping @autoclosure @Sendable () -> [Float]) -> SoundClip {
        SoundClip { wav(samples()) }
    }

    /// 16-bit mono PCM in a WAV container, which AVAudioPlayer plays directly.
    private nonisolated static func wav(_ samples: [Float], rate sampleRate: Double = sampleRate) -> Data {
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

/// One of the pets' sounds: its WAV bytes, made or read once, and the player
/// that plays it. A class, so a sound starts over on its own player, as the
/// NSSound it replaces did, rather than playing over itself.
final class SoundClip: @unchecked Sendable {
    /// Makes the bytes; run once, on SoundOutput's queue.
    private var make: (@Sendable () -> Data?)?
    private var made: Data?
    /// Made and touched only on SoundOutput's queue.
    fileprivate var player: AVAudioPlayer?
    /// A recording, played a little faster or slower each time (±5%).
    let varies: Bool

    init(varies: Bool = false, make: @escaping @Sendable () -> Data?) {
        self.varies = varies
        self.make = make
    }

    /// The WAV bytes, made the first time. Call only on SoundOutput's queue.
    fileprivate func bytes() -> Data? {
        if let make {
            made = make()
            self.make = nil
        }
        return made
    }
}

/// Plays the pets' sounds on a serial queue of their own, never on the main
/// thread. Starting a sound starts the audio device and waits for it, and
/// AirPods, AirPlay or a sleeping display's speakers can take many seconds to
/// wake: NSSound's play() on the main thread once held all of Droppy up for
/// 14 seconds. AVAudioPlayer has no main-thread requirement; each player is
/// made, started and let go on this one queue.
final class SoundOutput: @unchecked Sendable {
    static let shared = SoundOutput()

    private let queue = DispatchQueue(label: "app.pixpaw.sounds", qos: .userInitiated)
    /// The players that are playing, held until they finish, since a player
    /// that is let go stops. Touched only on the queue.
    private var playing: [AVAudioPlayer] = []
    /// A sound still waiting this long for a slow device is dropped, not
    /// played late: it belonged to a moment that has passed.
    private static let waitsAtMost: UInt64 = 1_000_000_000

    private init() {}

    /// Plays a sound from the start, cutting off the same sound if it is
    /// still playing.
    func play(_ clip: SoundClip, volume: Float) {
        let asked = DispatchTime.now().uptimeNanoseconds
        queue.async { [self] in
            guard Self.isOnTime(asked) else { return }
            if clip.player == nil, let data = clip.bytes() {
                clip.player = try? AVAudioPlayer(data: data)
                clip.player?.enableRate = clip.varies
            }
            guard let player = clip.player else { return }
            player.currentTime = 0
            if clip.varies { player.rate = Float.random(in: 0.95...1.05) }
            start(player, volume: volume)
        }
    }

    /// Plays a sound file once, alongside anything already playing.
    func preview(_ url: URL, volume: Float) {
        let asked = DispatchTime.now().uptimeNanoseconds
        queue.async { [self] in
            guard Self.isOnTime(asked), let data = try? Data(contentsOf: url),
                  let player = try? AVAudioPlayer(data: data) else { return }
            start(player, volume: volume)
        }
    }

    /// Stops everything playing; sounds asked for before this run first (the
    /// queue is serial), so they are stopped too.
    func stopAll() {
        queue.async { [self] in
            playing.forEach { $0.stop() }
            playing.removeAll()
        }
    }

    private func start(_ player: AVAudioPlayer, volume: Float) {
        playing.removeAll { !$0.isPlaying }
        player.volume = volume
        player.play()
        if !playing.contains(where: { $0 === player }) { playing.append(player) }
    }

    private nonisolated static func isOnTime(_ asked: UInt64) -> Bool {
        DispatchTime.now().uptimeNanoseconds - asked < waitsAtMost
    }
}
