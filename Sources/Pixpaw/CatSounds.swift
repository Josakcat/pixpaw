//
//  CatSounds.swift
//  Pixpaw
//
//  The voices, synthesised the first time they are needed: the cat's meow
//  (two pitches), purr and chew, and the other characters' calls: the bee's
//  buzz, the parrot's squawk, the dinosaur's rawr, the dog's bark, the
//  hamster's squeak, the chicken's bawk, the giraffe's hum, the hippo's
//  honk, the rabbit's thump and the shark's chomp. Made from sine waves and noise in
//  code, so there are no sound files to license or ship. Pets you draw
//  yourself can bring sounds of their own (OwnPets.swift).
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

    /// One character's sounds, made once.
    private struct Voice {
        var calls: [NSSound]
        var content: NSSound?
        var chew: NSSound?
    }

    private var voices: [PetKind: Voice] = [:]
    private var lastMeow = Date.distantPast

    private init() {}

    /// Plays a sound in a character's voice: for the bee, a meow is a buzz
    /// and a purr a contented hum.
    func play(_ sound: Sound, voice kind: PetKind = .cat) {
        guard isEnabled else { return }
        let voice = prepare(kind)
        switch sound {
        case .meow:
            // A call every few seconds at most; a chatty pet is charming once.
            guard Date().timeIntervalSince(lastMeow) > 4 else { return }
            lastMeow = Date()
            voice.calls.randomElement().map(start)
        case .purr: voice.content.map(start)
        case .chew: voice.chew.map(start)
        }
    }

    private func start(_ sound: NSSound) {
        sound.stop()
        sound.volume = Self.volume
        sound.play()
    }

    /// Drops the voices of the pets you drew, after their sounds changed.
    func forgetOwnPets() {
        voices = voices.filter { !$0.key.isOwn }
    }

    /// Plays one of a pet's own sounds, to try it.
    func preview(_ url: URL) {
        NSSound(contentsOf: url, byReference: false).map(start)
    }

    private func prepare(_ kind: PetKind) -> Voice {
        guard kind.isOwn else { return builtIn(kind) }
        if let made = voices[kind] { return made }
        // A pet you drew speaks in its own sounds, and in the voice of the
        // character it acts like for the ones it hasn't got.
        var voice = builtIn(kind.actsLike)
        let own = { (sound: OwnSound) in OwnPets.sound(sound, of: kind).flatMap { NSSound(contentsOf: $0, byReference: false) } }
        if let call = own(.call) { voice.calls = [call] }
        if let happy = own(.happy) { voice.content = happy }
        if let eating = own(.eating) { voice.chew = eating }
        voices[kind] = voice
        return voice
    }

    private func builtIn(_ kind: PetKind) -> Voice {
        if let made = voices[kind] { return made }
        let sound = { (samples: [Float]) in NSSound(data: Self.wav(samples)) }
        let voice: Voice
        switch kind {
        case .cat, .own1, .own2, .own3, .own4, .own5:
            voice = Voice(calls: [Self.meow(pitch: 1), Self.meow(pitch: 1.18)].compactMap(sound),
                          content: sound(Self.purrSamples()), chew: sound(Self.chewSamples()))
        case .bee:
            voice = Voice(calls: [Self.buzz(pitch: 1), Self.buzz(pitch: 1.2)].compactMap(sound),
                          content: sound(Self.humSamples()), chew: sound(Self.chewSamples()))
        case .parrot:
            voice = Voice(calls: [Self.squawk(pitch: 1), Self.squawk(pitch: 1.15)].compactMap(sound),
                          content: sound(Self.chirpSamples()), chew: sound(Self.chewSamples()))
        case .dino:
            voice = Voice(calls: [Self.rawr(pitch: 1), Self.rawr(pitch: 1.2)].compactMap(sound),
                          content: sound(Self.purrSamples()), chew: sound(Self.chewSamples()))
        case .dog:
            voice = Voice(calls: [Self.bark(pitch: 1, times: 2), Self.bark(pitch: 1.15, times: 1)].compactMap(sound),
                          content: sound(Self.pantSamples()), chew: sound(Self.chewSamples()))
        case .hamster:
            voice = Voice(calls: [Self.squeak(pitch: 1, times: 1), Self.squeak(pitch: 1.12, times: 2)].compactMap(sound),
                          content: sound(Self.chitterSamples()), chew: sound(Self.chewSamples()))
        case .chicken:
            voice = Voice(calls: [Self.bawk(pitch: 1), Self.bawk(pitch: 1.12)].compactMap(sound),
                          content: sound(Self.cluckSamples()), chew: sound(Self.chewSamples()))
        case .giraffe:
            voice = Voice(calls: [Self.lowHum(pitch: 1), Self.lowHum(pitch: 1.15)].compactMap(sound),
                          content: sound(Self.humSamples()), chew: sound(Self.chewSamples()))
        case .hippo:
            voice = Voice(calls: [Self.honk(pitch: 1, times: 2), Self.honk(pitch: 0.9, times: 3)].compactMap(sound),
                          content: sound(Self.bubbles(pitch: 0.6)), chew: sound(Self.chewSamples()))
        case .rabbit:
            voice = Voice(calls: [Self.thump(times: 2), Self.squeak(pitch: 1.3, times: 1)].compactMap(sound),
                          content: sound(Self.chitterSamples()), chew: sound(Self.chewSamples()))
        case .shark:
            voice = Voice(calls: [Self.chomp(times: 2), Self.chomp(times: 1)].compactMap(sound),
                          content: sound(Self.bubbles(pitch: 1)), chew: sound(Self.chewSamples()))
        }
        voices[kind] = voice
        return voice
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

    /// "Bzzz-zz": a buzzy sawtooth that swells, dips and swells again, its
    /// pitch wavering like wings beating.
    private static func buzz(pitch: Double) -> [Float] {
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
    private static func humSamples() -> [Float] {
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
    private static func squawk(pitch: Double) -> [Float] {
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
    private static func rawr(pitch: Double) -> [Float] {
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

    /// "Woof" (or "woof-woof"): short bursts that start high and drop,
    /// rough with a little noise.
    private static func bark(pitch: Double, times: Int) -> [Float] {
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
    private static func pantSamples() -> [Float] {
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
    private static func squeak(pitch: Double, times: Int) -> [Float] {
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
    private static func chitterSamples() -> [Float] {
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
    private static func bawk(pitch: Double) -> [Float] {
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
    private static func cluckSamples() -> [Float] {
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
    private static func chirpSamples() -> [Float] {
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
    /// "Mmmm": the low hum giraffes make at night, a soft warm tone that
    /// slides down a little.
    private static func lowHum(pitch: Double) -> [Float] {
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
    private static func honk(pitch: Double, times: Int) -> [Float] {
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

    /// Thump-thump: a back foot stamped on the floor, a soft low knock.
    private static func thump(times: Int) -> [Float] {
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
    private static func chomp(times: Int) -> [Float] {
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
    private static func bubbles(pitch: Double) -> [Float] {
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
