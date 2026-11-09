//
//  AskRanking.swift
//  Pixpaw
//
//  What the "What can I do?" box lists: the pet's own commands, Droppy's
//  catalog and, while you type, Droppy's search, ranked together, six at
//  most. Pure functions, no DroppyKit, so they can be checked on their own
//  (Tools/askbox-check.swift). Anything that could switch something off,
//  delete it, send your words to the web or touch the Store never gets in.
//

import Foundation

/// Where a row comes from, for its tag.
enum AskSource: String {
    case pet, droppy, now
}

/// One thing the box could list, before ranking.
struct AskCandidate: Equatable {
    /// "pet:feed", "droppy:<launcher id>", "now:screenshot.toShelf".
    let key: String
    let source: AskSource
    let title: String
    let symbol: String
    /// The launcher's kind for Droppy's ("command", "content", "clipboard"…).
    var kind = "command"
    var section = ""
    var keywords: [String] = []
    /// Any of its actions is marked destructive by Droppy.
    var destructive = false
    /// How well Droppy's own search thought it matched, 0…1.
    var relevance = 0.0
    /// Found by Droppy's search for this text rather than in the catalog.
    var fromSearch = false
    /// What the typed text itself asks for ("note buy milk"): always first.
    var parsed = false
}

enum AskRanking {
    static let limit = 6
    /// Search goes to Droppy from this many characters, this long after the last key.
    static let searchFrom = 2
    static let debounce: Duration = .milliseconds(150)

    /// Kinds the box never offers: a web answer sends the typed text out,
    /// a droplet row is the Store's, a surface opens only inside Droppy's
    /// own launcher (presentDetail), which the pet can't show.
    static let hiddenKinds: Set<String> = ["web", "droplet", "surface"]

    /// Whether it could switch something off, delete or quit something,
    /// or sleep the Mac: never listed, whatever is typed.
    static func isDangerous(_ item: AskCandidate) -> Bool {
        if item.destructive { return true }
        let title = item.title.lowercased()
        for start in ["turn off", "remove", "delete", "quit", "uninstall", "disable"] where title.hasPrefix(start) { return true }
        for word in ["sleep", "quit", "shut down", "shutdown", "restart", "log out", "empty trash", "erase"] where hasWord(title, word) {
            return true
        }
        return false
    }

    /// Whether the box may list it at all.
    static func isAllowed(_ item: AskCandidate, quiet: Bool) -> Bool {
        if item.source == .droppy {
            if hiddenKinds.contains(item.kind) || isDangerous(item) { return false }
        }
        // Your clipboard stays off a shared screen.
        if quiet, isClipboard(item) { return false }
        return true
    }

    static func isClipboard(_ item: AskCandidate) -> Bool {
        item.kind == "clipboard" || item.section.lowercased().contains("clipboard") || item.title.lowercased().contains("clipboard")
    }

    /// How well it matches what's typed; 0 is not at all.
    static func score(_ item: AskCandidate, query: String) -> Double {
        let q = normalized(query)
        guard !q.isEmpty else { return 0 }
        if item.parsed { return 1000 }
        let title = normalized(item.title)
        var best = 0.0
        if title == q { best = 120 }
        else if title.hasPrefix(q) { best = 100 }
        else if title.split(separator: " ").contains(where: { $0.hasPrefix(q) }) { best = 80 }
        else if q.count >= 3, title.contains(q) { best = 60 }
        else {
            // Every typed word starts a word of the title: "join meet".
            let words = q.split(separator: " ")
            let titleWords = title.split(separator: " ")
            if words.count > 1, words.allSatisfy({ w in titleWords.contains { $0.hasPrefix(w) } }) { best = 70 }
        }
        for keyword in item.keywords.map(normalized) {
            if keyword.hasPrefix(q) || keyword.split(separator: " ").contains(where: { $0.hasPrefix(q) }) { best = max(best, 40) }
            else if q.count >= 3, keyword.contains(q) { best = max(best, 30) }
        }
        // Droppy's search already matched it, maybe on what's inside it.
        if item.fromSearch { best = max(best, 45 + min(max(item.relevance, 0), 1) * 10) }
        return best
    }

    /// The rows for what's typed: best first, one of each, six at most.
    /// `uses` counts how often each key was run, a small nudge up.
    static func rank(_ items: [AskCandidate], query: String, quiet: Bool, uses: [String: Int] = [:]) -> [AskCandidate] {
        var seen = Set<String>()
        let scored: [(AskCandidate, Double, Int)] = items.enumerated().compactMap { index, item in
            guard isAllowed(item, quiet: quiet) else { return nil }
            let base = score(item, query: query)
            guard base > 0 else { return nil }
            return (item, base + boost(uses[item.key] ?? 0), index)
        }
        return scored
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.2 < $1.2 }
            .map(\.0)
            .filter { seen.insert(dedupe($0)).inserted }
            .prefix(limit).map { $0 }
    }

    /// The rows with nothing typed: what's happening right now first, then
    /// what you run most, then a few to start with. No search is asked.
    static func empty(now: [AskCandidate], all: [AskCandidate], defaults: [String], quiet: Bool, uses: [String: Int]) -> [AskCandidate] {
        var rows = now.filter { isAllowed($0, quiet: quiet) }
        var seen = Set(rows.map(dedupe))
        let byKey = Dictionary(all.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
        let most = uses.filter { $0.value > 0 }.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.map(\.key)
        for key in most + defaults {
            guard rows.count < limit else { break }
            guard let item = byKey[key], isAllowed(item, quiet: quiet), seen.insert(dedupe(item)).inserted else { continue }
            rows.append(item)
        }
        return Array(rows.prefix(limit))
    }

    /// Whether a search should go to Droppy for this text.
    static func searches(_ query: String) -> Bool { normalized(query).count >= searchFrom }

    /// Only the catalog's own commands are counted as used, never what
    /// Droppy's search found (your notes, your clipboard).
    static func counts(_ item: AskCandidate) -> Bool { !item.fromSearch && !item.parsed && item.source != .now }

    private static func boost(_ uses: Int) -> Double { uses > 0 ? min(10, log2(Double(uses) + 1) * 3) : 0 }

    /// Two rows that say the same thing are one: the pet's "Notes" and Droppy's.
    private static func dedupe(_ item: AskCandidate) -> String { item.source == .droppy && item.fromSearch ? item.key : normalized(item.title) }

    static func normalized(_ text: String) -> String {
        text.lowercased()
            .folding(options: [.diacriticInsensitive], locale: nil)
            .replacingOccurrences(of: "’", with: "'")
            .split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    private static func hasWord(_ text: String, _ word: String) -> Bool {
        text.range(of: "\\b\(NSRegularExpression.escapedPattern(for: word))\\b", options: .regularExpression) != nil
    }
}
