//
//  PhotoCoat.swift
//  Pixpaw
//
//  A coat for the cat in your own cat's colours, read from a photo of it on
//  the Mac: Vision cuts the animal out of the picture, its colours are
//  grouped into fur, stripes or patches, and white, and the eyes are sampled
//  where Vision finds them. Only the colours are kept, never the photo.
//

import AppKit
import CoreImage
import Vision

enum PhotoCoatProblem: LocalizedError {
    case unreadable, noAnimal

    var errorDescription: String? {
        switch self {
        case .unreadable: "That file isn't a photo Pixpaw can open."
        case .noAnimal: "No animal stood out in that photo. Try one with your pet clearly in view, on a plain background."
        }
    }
}

@MainActor
enum PhotoCoat {
    /// The coat read from your photo, by palette letter (outline, fur,
    /// stripe, white, pink, eye), once you have chosen one.
    private(set) static var palette: [Character: UInt32]?

    static func use(_ stored: [String: UInt32]?) {
        palette = stored.map { Dictionary(uniqueKeysWithValues: $0.compactMap { key, rgb in key.first.map { ($0, rgb) } }) }
        CatSprites.shared.forgetDrawings()
    }

    /// The palette as preferences keep it.
    static var stored: [String: UInt32]? {
        palette.map { Dictionary(uniqueKeysWithValues: $0.map { (String($0.key), $0.value) }) }
    }

    typealias RGB = (Double, Double, Double)

    /// Reads a photo into a palette. Slow (a few tenths of a second): call it
    /// off the main actor.
    nonisolated static func read(_ url: URL) throws -> [String: UInt32] {
        guard let image = NSImage(contentsOf: url),
              let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { throw PhotoCoatProblem.unreadable }
        let handler = VNImageRequestHandler(cgImage: cg)
        let maskRequest = VNGenerateForegroundInstanceMaskRequest()
        let poseRequest = VNDetectAnimalBodyPoseRequest()
        try? handler.perform([maskRequest, poseRequest])
        guard let found = maskRequest.results?.first,
              let mask = try? found.generateScaledMaskForImage(forInstances: found.allInstances, from: handler) else {
            throw PhotoCoatProblem.noAnimal
        }

        // The photo's pixels at the mask's size, rows top down like the mask's.
        let width = CVPixelBufferGetWidth(mask), height = CVPixelBufferGetHeight(mask)
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(data: &rgba, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw PhotoCoatProblem.unreadable }
        context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        func pixel(_ x: Int, _ y: Int) -> RGB {
            let k = (y * width + x) * 4
            return (Double(rgba[k]), Double(rgba[k + 1]), Double(rgba[k + 2]))
        }

        // About 40,000 pixels from inside the animal are plenty.
        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(mask) else { throw PhotoCoatProblem.noAnimal }
        let maskRow = CVPixelBufferGetBytesPerRow(mask) / 4
        let inside = base.assumingMemoryBound(to: Float32.self)
        let step = max(1, Int(sqrt(Double(width * height) / 40_000)))
        var samples: [RGB] = []
        for y in stride(from: 0, to: height, by: step) {
            for x in stride(from: 0, to: width, by: step) where inside[y * maskRow + x] > 0.8 {
                samples.append(pixel(x, y))
            }
        }
        guard samples.count >= 200 else { throw PhotoCoatProblem.noAnimal }

        // Grouped into five colours.
        let k = 5
        var centres = (0..<k).map { samples[$0 * samples.count / k] }
        var counts = [Int](repeating: 0, count: k)
        for _ in 0..<20 {
            var sums = [RGB](repeating: (0, 0, 0), count: k)
            counts = [Int](repeating: 0, count: k)
            for sample in samples {
                let i = (0..<k).min { distance(sample, centres[$0]) < distance(sample, centres[$1]) }!
                sums[i] = (sums[i].0 + sample.0, sums[i].1 + sample.1, sums[i].2 + sample.2)
                counts[i] += 1
            }
            for i in 0..<k where counts[i] > 0 {
                centres[i] = (sums[i].0 / Double(counts[i]), sums[i].1 / Double(counts[i]), sums[i].2 / Double(counts[i]))
            }
        }
        // Light and shade of one colour (a ginger back in sun and in shadow)
        // come out as two: fold them back together.
        for i in 0..<k {
            for j in 0..<k where j != i && counts[i] > 0 && counts[j] > 0 && counts[i] >= counts[j] {
                let a = centres[i], b = centres[j]
                guard [a, b].allSatisfy({ luma($0) > 25 && luma($0) < 215 }), sameColour(a, b) else { continue }
                centres[i] = mix(a, b, Double(counts[j]) / Double(counts[i] + counts[j]))
                counts[i] += counts[j]
                counts[j] = 0
            }
        }
        let total = Double(samples.count)
        // Specks and stray background (under 6%) are left out; biggest first.
        let kept = (0..<k).filter { Double(counts[$0]) / total > 0.06 }.sorted { counts[$0] > counts[$1] }
        var colours = kept.map { centres[$0] }
        guard !colours.isEmpty else { throw PhotoCoatProblem.noAnimal }
        // Deep shadow is often the biggest colour: unless the animal really
        // is dark (over 45% of it), the fur is the biggest colour that isn't.
        let dark = kept.filter { luma(centres[$0]) < 50 }.reduce(0.0) { $0 + Double(counts[$1]) } / total
        if dark < 0.45, let lit = colours.firstIndex(where: { luma($0) >= 50 }), lit > 0 {
            colours.insert(colours.remove(at: lit), at: 0)
        }

        // White: the lightest colour if it really is light, else a pale fur.
        let lightest = colours.indices.max { luma(colours[$0]) < luma(colours[$1]) }!
        let hasWhite = colours.count > 1 && luma(colours[lightest]) > 185
        let white = hasWhite ? colours[lightest] : mix(colours[0], (255, 255, 255), 0.7)
        var rest = colours
        if hasWhite { rest.remove(at: lightest) }
        // A white cat keeps white fur.
        let fur = rest.first ?? white
        // Stripes or patches: the colour least like the fur, if it's far
        // enough from it to show; else a darker fur.
        let patch = rest.dropFirst().max { distance($0, fur) < distance($1, fur) }
        let stripe = patch.flatMap { distance($0, fur) > 1600 ? $0 : nil } ?? mix(fur, (0, 0, 0), 0.3)
        let outline = mix(colours.min { luma($0) < luma($1) }!, (0, 0, 0), 0.75)

        // The eyes, where Vision finds them on a cat or a dog: the most
        // coloured pixel around each, so the iris rather than the pupil.
        var eye: RGB = luma(fur) < 70 ? (255, 211, 77) : (29, 20, 12)
        if let pose = poseRequest.results?.first, let points = try? pose.recognizedPoints(.head) {
            var around: [RGB] = []
            for name in [VNAnimalBodyPoseObservation.JointName.leftEye, .rightEye] {
                guard let point = points[name], point.confidence > 0.3 else { continue }
                let cx = Int(point.location.x * Double(width)), cy = Int((1 - point.location.y) * Double(height))
                let r = max(2, width / 200)
                for y in (cy - r)...(cy + r) where y >= 0 && y < height {
                    for x in (cx - r)...(cx + r) where x >= 0 && x < width { around.append(pixel(x, y)) }
                }
            }
            if let iris = around.filter({ luma($0) > 50 }).max(by: { saturation($0) < saturation($1) }), saturation(iris) > 40 {
                eye = iris
            }
        }

        let palette: [String: RGB] = ["o": outline, "f": fur, "s": stripe, "w": white, "e": eye]
        return palette.mapValues(packed).merging(["p": 0xF59AA8]) { $1 }
    }

    private nonisolated static func distance(_ a: RGB, _ b: RGB) -> Double {
        let d = (a.0 - b.0, a.1 - b.1, a.2 - b.2)
        return d.0 * d.0 + d.1 * d.1 + d.2 * d.2
    }

    private nonisolated static func luma(_ c: RGB) -> Double { 0.299 * c.0 + 0.587 * c.1 + 0.114 * c.2 }

    private nonisolated static func saturation(_ c: RGB) -> Double { max(c.0, c.1, c.2) - min(c.0, c.1, c.2) }

    private nonisolated static func mix(_ a: RGB, _ b: RGB, _ t: Double) -> RGB {
        (a.0 + (b.0 - a.0) * t, a.1 + (b.1 - a.1) * t, a.2 + (b.2 - a.2) * t)
    }

    /// Two colours of one hue, light or dark. Greys have no real hue, so they
    /// only count as one when about as light.
    private nonisolated static func sameColour(_ a: RGB, _ b: RGB) -> Bool {
        let (hueA, satA) = hueAndSaturation(a), (hueB, satB) = hueAndSaturation(b)
        let apart = min(abs(hueA - hueB), 360 - abs(hueA - hueB))
        return satA > 0.35 ? satB > 0.35 && apart < 15 : satB <= 0.35 && apart < 25 && abs(luma(a) - luma(b)) < 45
    }

    private nonisolated static func hueAndSaturation(_ c: RGB) -> (Double, Double) {
        let colour = NSColor(srgbRed: c.0 / 255, green: c.1 / 255, blue: c.2 / 255, alpha: 1)
        return (colour.hueComponent * 360, colour.saturationComponent)
    }

    private nonisolated static func packed(_ c: RGB) -> UInt32 {
        let byte = { (v: Double) in UInt32(min(255, max(0, v.rounded()))) }
        return byte(c.0) << 16 | byte(c.1) << 8 | byte(c.2)
    }
}
