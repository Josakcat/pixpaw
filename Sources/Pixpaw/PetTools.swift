//
//  PetTools.swift
//  Pixpaw
//
//  What AI apps (Claude, Cursor, Codex…) may ask of the pet through Droppy's
//  MCP server, when "Let AI apps talk to your pet" is on (off by default):
//  say a short line in its bubble, and put a to-do on its sign. Droppy lists
//  them as droplet_pixpaw_say, droplet_pixpaw_add_note and
//  droplet_pixpaw_status. Focus, timers, reminders and calendars stay
//  Droppy's own tools. Every argument is untrusted (a model may have read
//  it in a web page): one line of plain text, capped, no links, and the
//  bubble at most once every ten seconds. Nothing is opened or run.
//  The checks are pure, so .droppykit/Tools/pet-tools-check.swift checks them.
//

import Foundation

enum PetTools {
    static let say = "say"
    static let addNote = "add_note"
    static let status = "status"

    static let textLimit = 140
    /// The bubble at most this often; a note a little more often.
    static let sayEvery: TimeInterval = 10
    static let noteEvery: TimeInterval = 5

    static func schema(limit: Int) -> String {
        #"{"type":"object","properties":{"text":{"type":"string","minLength":1,"maxLength":\#(limit),"description":"One short line of plain text, no links."}},"required":["text"],"additionalProperties":false}"#
    }

    enum Problem: LocalizedError, Equatable {
        case off
        case unknown(String)
        case badArguments
        case empty
        case link
        case tooSoon(seconds: Int)
        case quiet(String)
        case away
        case notesFull(Int)

        var errorDescription: String? {
            switch self {
            case .off: "Pixpaw's tools for AI apps are off. The user can turn on Let AI apps talk to your pet in Pixpaw's settings."
            case let .unknown(name): "Pixpaw has no tool named \(name.prefix(40))."
            case .badArguments: "Send {\"text\": \"…\"}: one string and nothing else."
            case .empty: "The text is empty once newlines and control characters are taken out."
            case .link: "No links: the pet only says plain words."
            case let .tooSoon(seconds): "Too soon: the pet speaks at most once every 10 seconds. Try again in \(seconds) s."
            case let .quiet(reason): "The pet is keeping quiet right now (\(reason)). Try again later."
            case .away: "The pet is put away right now, so nobody would see it."
            case let .notesFull(limit): "The pet's sign is full (\(limit) notes). The user has to tick one off first."
            }
        }
    }

    /// The `text` argument as one clean line, or why not.
    static func text(from argumentsJSON: String, limit: Int = textLimit) throws -> String {
        guard argumentsJSON.utf8.count <= 4096,
              let object = try? JSONSerialization.jsonObject(with: Data(argumentsJSON.utf8)) as? [String: Any],
              object.count == 1, let raw = object["text"] as? String else { throw Problem.badArguments }
        guard let line = PlainText.line(raw, limit: limit) else { throw Problem.empty }
        guard !hasLink(line) else { throw Problem.link }
        return line
    }

    /// A web address, a scheme (`https:`, `mailto:`, `file:`…) or a bare
    /// domain ("example.com/x"), so the bubble can't be used to push a link.
    static func hasLink(_ text: String) -> Bool {
        let lower = text.lowercased()
        if lower.contains("://") || lower.contains("www.") { return true }
        if lower.contains(#/\b(mailto|file|javascript|data|tel|sms|x-[a-z-]+|droppy|pixpaw):/#) { return true }
        return lower.contains(#/\b[a-z0-9-]+\.(com|net|org|io|ai|app|dev|co|me|ly|gg|xyz|info|biz|link|site|top|click|to|tk|ru|cn)\b/#)
    }

    /// At most one call per `every`; `allow` answers how long to wait, or nil.
    struct RateLimit: Equatable {
        let every: TimeInterval
        private(set) var last: Date?

        init(every: TimeInterval) { self.every = every }

        mutating func allow(at now: Date = Date()) -> Int? {
            if let last, now.timeIntervalSince(last) < every, now >= last {
                return max(1, Int((every - now.timeIntervalSince(last)).rounded(.up)))
            }
            last = now
            return nil
        }
    }
}
