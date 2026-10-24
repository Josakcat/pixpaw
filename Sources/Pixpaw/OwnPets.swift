//
//  OwnPets.swift
//  Pixpaw
//
//  Pets you draw yourself: a sprite sheet in the layout Art/README.md
//  describes, brought in from any pixel editor. One sitting pose is enough;
//  the frames left empty are made from the ones that are there.
//

import AppKit
import AVFoundation
import UniformTypeIdentifiers

/// A pet you drew, acting like one of the built-in characters: it sounds,
/// talks, moves and lives like that one, in your picture.
struct OwnPet: Codable, Equatable, Identifiable {
    /// Which of the five places it has, 1 to 5; its `PetKind` is `own<slot>`.
    var slot: Int
    var name: String
    var actsLike: PetKind
    /// The sheet as Pixpaw keeps it: one art pixel per pixel, 20 tall, a cell
    /// for each frame drawn.
    var sheet: Data
    /// Sounds of its own, by `OwnSound` name: the file in `OwnPets.soundFolder`.
    /// The ones it hasn't got are the voice of the character it acts like.
    var sounds: [String: String]?

    var id: Int { slot }
    var kind: PetKind { PetKind(rawValue: "own\(slot)") ?? .own1 }
}

/// A pet you drew, in one file to share: its picture, its name, the
/// character it acts like and its own sounds. JSON, `.pixpaw`.
struct OwnPetPack: Codable {
    var pixpaw = 1
    var name: String
    var actsLike: String
    var sheet: Data
    var sounds: [String: Data]?

    static let type = UTType(filenameExtension: "pixpaw", conformingTo: .json) ?? .json
    /// Bigger than any pet with three short sounds needs to be.
    static let largest = 8_000_000
}

/// The sounds a pet you drew can have of its own.
enum OwnSound: String, CaseIterable, Identifiable {
    case call, happy, eating

    var id: String { rawValue }

    var title: String {
        switch self {
        case .call: "Call"
        case .happy: "Happy"
        case .eating: "Eating"
        }
    }

    /// When it plays.
    var when: String {
        switch self {
        case .call: "when it talks"
        case .happy: "when you pet it"
        case .eating: "while it eats"
        }
    }

    /// The longest a sound may be, in seconds; eating repeats every second or so.
    var longest: Double { self == .eating ? 1.5 : 3 }
}

/// What can be wrong with a picture brought in as a pet.
enum OwnPetProblem: LocalizedError {
    case unreadable
    case size(Int, Int)
    case noSittingPose
    case unplayable
    case notAPet
    case tooLong(Double)

    var errorDescription: String? {
        switch self {
        case .unreadable:
            "Pixpaw can't open that picture. Save it as a PNG and try again."
        case let .size(width, height):
            "That picture is \(width) × \(height). A pet is 20 pixels tall, with one 20 × 20 cell for each pose side by side (up to 18). Scaled up evenly is fine."
        case .noSittingPose:
            "The first cell, the sitting pose, is empty. Draw your pet there first."
        case .notAPet:
            "That isn't a Pixpaw pet. Bring in a PNG, or a .pixpaw file someone shared."
        case .unplayable:
            "Pixpaw can't play that sound. Try a WAV, MP3, M4A or AIFF file."
        case let .tooLong(seconds):
            "That sound is too long. Keep it under \(seconds.formatted()) seconds: a short sound plays best."
        }
    }
}

/// The pets you drew, turned into the same character grids as the built-in
/// ones so the rest of Pixpaw draws them alike.
@MainActor
enum OwnPets {
    static let limit = 5
    static let cell = 20
    /// The order of the cells in a sheet, left to right (see Art/README.md).
    static let cellOrder: [CatFrame] = [.sit, .blink, .happy, .walk1, .walk2, .walk3, .run1, .run2, .groom1, .groom2,
                                        .sleep1, .sleep2, .eat1, .eat2, .crouch1, .crouch2, .held1, .held2]

    private(set) static var pets: [OwnPet] = []
    /// Each frame by art key ("own2.walk1"), one character per colour.
    private(set) static var frames: [String: [String]] = [:]
    private(set) static var colours: [PetKind: [Character: UInt32]] = [:]
    /// Where a hat sits on each frame: its centre and the row of its brim.
    private(set) static var hatSpots: [String: (Double, Int)] = [:]

    static func pet(_ kind: PetKind) -> OwnPet? { pets.first { $0.kind == kind } }

    /// Where the pets' own sounds are kept, in the droplet's own folder.
    static var soundFolder: URL?

    /// A pet's own sound, if it has that one.
    static func sound(_ sound: OwnSound, of kind: PetKind) -> URL? {
        guard let name = pet(kind)?.sounds?[sound.rawValue] else { return nil }
        return soundFolder?.appendingPathComponent(name)
    }

    /// How loud a pet's own sound is made: the level of Pixpaw's own voices,
    /// about -18 dBFS RMS over the parts that aren't silent, with its peaks
    /// kept below -1 dBFS. Every sound brought in is evened out to it, so a
    /// whisper and a shout come out as loud as a meow.
    static let loudness: Float = -18
    private static let ceiling: Float = -1
    /// A 20 ms stretch this far below the loudest one counts as silence
    /// (and anything under -60 dBFS always does), so a sound recorded
    /// quietly loses no more of its tail than a loud one.
    private static let silence: Float = 35

    /// Brings a sound in for a pet and returns the name it is kept under:
    /// made mono, the silence at either end cut off, evened out to
    /// `loudness`, and saved as a WAV in the pets' own folder.
    static func keep(_ url: URL, as sound: OwnSound, for slot: Int) throws -> String {
        guard let folder = soundFolder else { throw OwnPetProblem.unplayable }
        guard let file = try? AVAudioFile(forReading: url), file.length > 0 else { throw OwnPetProblem.unplayable }
        let rate = file.processingFormat.sampleRate
        // Anything much longer than a pet's sound isn't worth reading.
        guard Double(file.length) / rate <= 30,
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: buffer)) != nil, let channels = buffer.floatChannelData else { throw OwnPetProblem.unplayable }
        let count = Int(buffer.frameLength), channelCount = Int(buffer.format.channelCount)
        var samples = (0..<count).map { i in (0..<channelCount).reduce(Float(0)) { $0 + channels[$1][i] } / Float(channelCount) }

        // The silence at either end cut off, keeping 10 ms either side.
        let window = max(1, Int(rate * 0.02))
        let level = { (range: Range<Int>) -> Float in
            let power = samples[range].reduce(Float(0)) { $0 + $1 * $1 } / Float(range.count)
            return 10 * log10(max(power, 1e-12))
        }
        let windows = stride(from: 0, to: samples.count, by: window).map { $0..<min(samples.count, $0 + window) }
        let loudest = windows.map(level).max() ?? -120
        let heard = windows.filter { level($0) > max(-60, loudest - silence) }
        guard let first = heard.first, let last = heard.last else { throw OwnPetProblem.unplayable }
        let heardPower = heard.map { range in pow(10, level(range) / 10) * Float(range.count) }.reduce(0, +)
            / Float(heard.map(\.count).reduce(0, +))
        let margin = Int(rate * 0.01)
        samples = Array(samples[max(0, first.lowerBound - margin)..<min(samples.count, last.upperBound + margin)])
        guard Double(samples.count) / rate <= sound.longest + 0.05 else { throw OwnPetProblem.tooLong(sound.longest) }

        // Evened out to the loudness of the parts that are heard; a peak that
        // would go over is rounded off softly rather than clipped.
        let gain = pow(10, (loudness - 10 * log10(heardPower)) / 20)
        let knee: Float = 0.5, top = pow(10, ceiling / 20)
        samples = samples.map { sample in
            let loud = sample * gain, size = abs(loud)
            guard size > knee else { return loud }
            return (loud < 0 ? -1 : 1) * (knee + (top - knee) * tanh((size - knee) / (top - knee)))
        }
        // 5 ms fades, so it never starts or stops with a click.
        let fade = min(samples.count / 2, Int(rate * 0.005))
        for i in 0..<fade {
            let ramp = Float(i) / Float(max(fade, 1))
            samples[i] *= ramp
            samples[samples.count - 1 - i] *= ramp
        }

        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        // A new name each time, so a sound already loaded is never the one replaced.
        let name = "own\(slot)-\(sound.rawValue)-\(UUID().uuidString.prefix(8)).wav"
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: rate, channels: 1, interleaved: false),
              let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let data = out.floatChannelData else { throw OwnPetProblem.unplayable }
        out.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { data[0].update(from: $0.baseAddress!, count: samples.count) }
        let settings: [String: Any] = [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: rate, AVNumberOfChannelsKey: 1,
                                       AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false]
        let written = try AVAudioFile(forWriting: folder.appendingPathComponent(name), settings: settings,
                                      commonFormat: .pcmFormatFloat32, interleaved: false)
        try written.write(from: out)
        return name
    }

    /// A pet in one file, its sounds and all, to share.
    static func pack(_ pet: OwnPet) -> Data? {
        let sounds = (pet.sounds ?? [:]).compactMapValues { name in
            soundFolder.flatMap { try? Data(contentsOf: $0.appendingPathComponent(name)) }
        }
        let pack = OwnPetPack(name: pet.name, actsLike: pet.actsLike.rawValue, sheet: pet.sheet, sounds: sounds.isEmpty ? nil : sounds)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try? encoder.encode(pack)
    }

    /// A shared pet, checked: its picture read like any sheet, and each sound
    /// brought in like one you chose, evened out and kept for `slot`. A sound
    /// that won't play is left out.
    static func unpack(_ data: Data, into slot: Int) throws -> OwnPet {
        guard data.count <= OwnPetPack.largest,
              let pack = try? JSONDecoder().decode(OwnPetPack.self, from: data), pack.pixpaw == 1 else { throw OwnPetProblem.notAPet }
        let sheet = try sheet(from: pack.sheet)
        var kept: [String: String] = [:]
        for (key, sound) in pack.sounds ?? [:] {
            guard let which = OwnSound(rawValue: key) else { continue }
            let file = FileManager.default.temporaryDirectory.appendingPathComponent("pixpaw-\(UUID().uuidString).wav")
            defer { try? FileManager.default.removeItem(at: file) }
            guard (try? sound.write(to: file)) != nil, let name = try? keep(file, as: which, for: slot) else { continue }
            kept[which.rawValue] = name
        }
        let actsLike = PetKind(rawValue: pack.actsLike).flatMap { $0.isOwn ? nil : $0 } ?? .cat
        let name = pack.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return OwnPet(slot: slot, name: String((name.isEmpty ? "My pet" : name).prefix(30)), actsLike: actsLike, sheet: sheet,
                      sounds: kept.isEmpty ? nil : kept)
    }

    /// Deletes kept sounds no pet uses any more.
    static func tidySounds() {
        guard let folder = soundFolder,
              let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return }
        let used = Set(pets.flatMap { $0.sounds?.values.map { $0 } ?? [] })
        for name in names where !used.contains(name) {
            try? FileManager.default.removeItem(at: folder.appendingPathComponent(name))
        }
    }

    /// Takes the pets as they are now, and forgets any pictures drawn of the old ones.
    static func use(_ pets: [OwnPet]) {
        self.pets = pets.sorted { $0.slot < $1.slot }
        frames = [:]
        colours = [:]
        hatSpots = [:]
        for pet in self.pets {
            guard let cells = try? cells(in: pet.sheet) else { continue }
            add(pet.kind, cells: cells)
        }
        CatSprites.shared.forgetOwnPets()
        CatSounds.shared.forgetOwnPets()
    }

    /// The first free place, or nil when all five are taken.
    static var freeSlot: Int? { (1...limit).first { slot in !pets.contains { $0.slot == slot } } }

    // MARK: Reading a sheet

    /// The picture at one art pixel per pixel, ready to keep: checked, scaled
    /// down if it was scaled up, and trimmed to the cells that have something in them.
    static func sheet(from data: Data) throws -> Data {
        let cells = try cells(in: data)
        let count = (cells.lastIndex { cell in cell.contains { $0.contains { $0 != nil } } } ?? 0) + 1
        return png(Array(cells.prefix(count))) ?? data
    }

    /// The cells of a sheet, left to right, each 20 rows of 20 colours (nil
    /// where it is transparent).
    private static func cells(in data: Data) throws -> [[[UInt32?]]] {
        guard let source = NSBitmapImageRep(data: data)?.cgImage else { throw OwnPetProblem.unreadable }
        let width = source.width, height = source.height
        let scale = height / cell
        guard scale >= 1, height % cell == 0, width % (cell * scale) == 0, width / (cell * scale) <= cellOrder.count else {
            throw OwnPetProblem.size(width, height)
        }
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw OwnPetProblem.unreadable }
        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
        // The middle of each scaled-up pixel; half transparent or more is empty.
        let colour = { (x: Int, y: Int) -> UInt32? in
            let i = ((y * scale + scale / 2) * width + x * scale + scale / 2) * 4
            let alpha = bytes[i + 3]
            guard alpha >= 128 else { return nil }
            let unpremultiply = { (value: UInt8) in UInt32(min(255, Int(value) * 255 / Int(alpha))) }
            return unpremultiply(bytes[i]) << 16 | unpremultiply(bytes[i + 1]) << 8 | unpremultiply(bytes[i + 2])
        }
        let cells = (0..<(width / (cell * scale))).map { index in
            (0..<cell).map { y in (0..<cell).map { x in colour(index * cell + x, y) } }
        }
        guard cells.first?.contains(where: { $0.contains { $0 != nil } }) == true else { throw OwnPetProblem.noSittingPose }
        return cells
    }

    // MARK: Filling in the frames

    /// Every frame for a pet, from the cells drawn and, for the rest, the
    /// nearest pose drawn: walking hops, sleeping and crouching sink lower.
    private static func add(_ kind: PetKind, cells: [[[UInt32?]]]) {
        var drawn: [CatFrame: [[UInt32?]]] = [:]
        for (index, grid) in cells.enumerated() where index < cellOrder.count && grid.contains(where: { $0.contains { $0 != nil } }) {
            drawn[cellOrder[index]] = grid
        }
        var made: [CatFrame: [[UInt32?]]] = [:]
        // Each frame is made from ones earlier in the order.
        for frame in cellOrder {
            if let grid = drawn[frame] { made[frame] = grid; continue }
            let pose = { (other: CatFrame) in made[other] ?? made[.sit] ?? [] }
            made[frame] = switch frame {
            case .sit: []
            case .blink, .happy, .groom1, .eat2, .held1: pose(.sit)
            case .walk1, .walk3: pose(.sit)
            case .walk2: raised(pose(.walk1))
            case .run1: pose(.walk1)
            case .run2: pose(.walk2)
            case .groom2: pose(.groom1)
            case .sleep1, .eat1, .crouch1: sunk(pose(.sit))
            case .sleep2: drawn[.sleep1] == nil ? sunk(pose(.sleep1)) : pose(.sleep1)
            case .crouch2: sunk(pose(.crouch1))
            case .held2: pose(.held1)
            }
        }

        // One character per colour, '.' for none.
        var letters: [UInt32: Character] = [:]
        var palette: [Character: UInt32] = [:]
        for frame in cellOrder {
            let grid = trimmed(made[frame] ?? [])
            let rows = grid.map { row in
                String(row.map { colour -> Character in
                    guard let colour else { return "." }
                    if let letter = letters[colour] { return letter }
                    let letter = Character(UnicodeScalar(0xE000 + letters.count) ?? "?")
                    letters[colour] = letter
                    palette[letter] = colour
                    return letter
                })
            }
            let key = kind.artKey(frame)
            frames[key] = rows
            hatSpots[key] = hatSpot(rows)
        }
        colours[kind] = palette
    }

    /// One art pixel higher, as in the middle of a hop.
    private static func raised(_ grid: [[UInt32?]]) -> [[UInt32?]] {
        guard let width = grid.first?.count else { return grid }
        let rows = grid + [Array(repeating: nil, count: width)]
        return rows.first?.allSatisfy({ $0 == nil }) == true ? Array(rows.dropFirst()) : rows
    }

    /// One art pixel lower, a row taken out of the middle of the body.
    private static func sunk(_ grid: [[UInt32?]]) -> [[UInt32?]] {
        guard let width = grid.first?.count else { return grid }
        let filled = grid.indices.filter { grid[$0].contains { $0 != nil } }
        guard let top = filled.first, let bottom = filled.last, bottom - top >= 3 else { return grid }
        var rows = grid
        rows.remove(at: top + (bottom - top) / 2)
        return [Array(repeating: nil, count: width)] + rows
    }

    /// The bottom 16 rows like every other pet, unless the pet reaches above them.
    private static func trimmed(_ grid: [[UInt32?]]) -> [[UInt32?]] {
        let extra = grid.count - CatArt.height
        guard extra > 0, grid.prefix(extra).allSatisfy({ $0.allSatisfy { $0 == nil } }) else { return grid }
        return Array(grid.dropFirst(extra))
    }

    /// A hat on the top of the head: over the middle of the topmost few rows.
    private static func hatSpot(_ rows: [String]) -> (Double, Int) {
        guard let top = rows.firstIndex(where: { $0.contains { $0 != "." } }) else { return (10, 0) }
        let columns = rows[top..<min(rows.count, top + 3)].flatMap { row in
            row.enumerated().filter { $0.element != "." }.map(\.offset)
        }
        let centre = Double((columns.min() ?? 0) + (columns.max() ?? 0) + 1) / 2
        return (centre, top)
    }

    // MARK: Writing a sheet

    /// A built-in character's sheet, for drawing a pet of your own over it.
    static func template(_ kind: PetKind, coat: CatCoat) -> Data? {
        let cells = cellOrder.map { frame -> [[UInt32?]] in
            guard let rows = CatArt.frames[kind.artKey(frame)],
                  let palette = kind.isOwn ? colours[kind] : CatArt.coats[kind.hasCoats ? coat.rawValue : kind.rawValue] else { return [] }
            let grid = rows.map { row in row.map { palette[$0] } }
            let width = grid.first?.count ?? cell
            // Bottom of the cell, from its left edge.
            return Array(repeating: Array(repeating: nil, count: cell), count: max(0, cell - grid.count))
                + grid.map { $0 + Array(repeating: nil, count: max(0, cell - width)) }
        }
        return png(cells)
    }

    /// Cells side by side as a PNG, one pixel per art pixel.
    private static func png(_ cells: [[[UInt32?]]]) -> Data? {
        let width = cells.count * cell
        guard width > 0, let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: cell, bitsPerSample: 8,
                                                    samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                                    bytesPerRow: width * 4, bitsPerPixel: 32),
              let bytes = rep.bitmapData else { return nil }
        for (index, grid) in cells.enumerated() {
            for (y, row) in grid.prefix(cell).enumerated() {
                for (x, colour) in row.prefix(cell).enumerated() {
                    guard let colour else { continue }
                    let i = (y * width + index * cell + x) * 4
                    bytes[i] = UInt8((colour >> 16) & 0xFF)
                    bytes[i + 1] = UInt8((colour >> 8) & 0xFF)
                    bytes[i + 2] = UInt8(colour & 0xFF)
                    bytes[i + 3] = 0xFF
                }
            }
        }
        return rep.representation(using: .png, properties: [:])
    }
}
