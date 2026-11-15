import Foundation

/// The pure half of "In its own words": what the on-device model is asked,
/// what of its answer is kept, and how often it is asked. No model and no
/// Droppy here, so `.droppykit/Tools/pet-lines-check.swift` can check it.
enum PetLineRules {
    /// The model gets this long to answer before the usual line is said.
    static let timeout: TimeInterval = 2.5
    /// It is asked at most this often; between, the usual lines are said.
    static let minimumGap: TimeInterval = 45
    /// A line longer than this is not a bubble: the usual line is said.
    static let maxLength = 90

    /// Morning, afternoon, evening or night, for the prompt.
    static func partOfDay(hour: Int) -> String {
        switch hour {
        case 5..<12: "morning"
        case 12..<17: "afternoon"
        case 17..<22: "evening"
        default: "late at night"
        }
    }

    /// Whether the model may be asked now.
    static func mayAsk(lastAsked: Date?, now: Date, busy: Bool) -> Bool {
        if busy { return false }
        guard let lastAsked else { return true }
        return now.timeIntervalSince(lastAsked) >= minimumGap
    }

    /// The instructions the session starts with.
    static func instructions(pet: String) -> String {
        """
        You are a small pixel \(pet) that lives on someone's Mac desktop. \
        Rewrite the line you are given as you would say it: one short sentence, \
        at most 12 words, warm and playful. Keep every name and number exactly as given. \
        Never scold, never make the person feel guilty, no emoji, no quotation marks, \
        no hashtags. Answer with the sentence only.
        """
    }

    /// What the model is asked for one line.
    static func prompt(gist: String, doing: String, hour: Int) -> String {
        "Line: \(gist)\nWhat you are doing: \(doing)\nTime: \(partOfDay(hour: hour))"
    }

    /// The model's answer as a bubble line, or nil when the usual line
    /// should be said instead: empty, too long, more than one line, or it
    /// dropped a name or number the usual line had (`keep`: names it must
    /// keep even at the start, such as the agent's).
    static func clean(_ answer: String, gist: String, keep: [String] = []) -> String? {
        var line = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        if line.contains("\n") { return nil }
        let quotes = CharacterSet(charactersIn: "\"'“”‘’`")
        line = line.trimmingCharacters(in: quotes).trimmingCharacters(in: .whitespaces)
        if line.isEmpty || line.count > maxLength { return nil }
        if line.lowercased().hasPrefix("line:") || line.contains("#") { return nil }
        for token in keptTokens(gist) + keep where !line.contains(token) { return nil }
        return line
    }

    /// Words of the usual line that must survive: numbers, and names
    /// (capitalised words that do not start a sentence).
    static func keptTokens(_ gist: String) -> [String] {
        let raw = gist.split(whereSeparator: { $0 == " " }).map(String.init)
        var kept: [String] = []
        var startsSentence = true
        for piece in raw {
            let word = piece.trimmingCharacters(in: .punctuationCharacters.union(.symbols))
            defer { startsSentence = piece.last.map { ".!?…".contains($0) } ?? false }
            if word.isEmpty { continue }
            if word.contains(where: \.isNumber) { kept.append(word); continue }
            if !startsSentence, let first = word.first, first.isUppercase, word != "I" { kept.append(word) }
        }
        return kept
    }
}
