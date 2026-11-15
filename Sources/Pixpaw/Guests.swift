//
//  Guests.swift
//  Pixpaw
//
//  Guests in the home: each Claude Code or Codex session your pet already
//  follows (its hooks, or "Follow agents without hooks") sends a small
//  guest, one of the other pets, to sit in front of the home while it is
//  out. Its pose is all it says: at a laptop while the session works, a
//  paw up while it waits on you, pleased once it is done; ten minutes after
//  that it goes home. Characters only: Droppy's own mascot and Agents
//  widget already show agent status, so there is no panel or list here.
//  Pure, so `.droppykit/Tools/guests-check.swift` checks it without Droppy.
//

import Foundation

/// What a guest is doing, from its session.
enum GuestPose: String, Equatable {
    case working, waiting, done
}

/// One session as a log watcher last saw it: read off the agent-files
/// queue, handed to the main thread as a value.
struct GuestSeen: Equatable, Sendable {
    /// The session's id, or its log's path.
    let id: String
    /// "Claude" or "Codex", the name its events go by.
    let agent: String
    /// True while it works on a turn, false once it's over, nil unknown.
    let busy: Bool?
    /// When its log was last written.
    let modified: Date
}

/// What a hook last said of an agent, for agents with no log being read.
struct GuestHeard: Equatable {
    let agent: String
    let pose: GuestPose
    let at: Date
}

/// One guest in front of the home.
struct HomeGuest: Equatable {
    let id: String
    let agent: String
    let pose: GuestPose
}

enum HomeGuests {
    /// The home has room for this many in front of it.
    static let room = 3
    /// A finished session's guest stays this long, then goes home.
    static let doneStays: TimeInterval = 10 * 60
    /// A session nobody has heard from in this long has left, busy or not
    /// (a crashed turn never says it ended).
    static let forgottenAfter: TimeInterval = 30 * 60

    /// The guests for what the watchers and hooks know now: one per running
    /// session, else one per agent the hooks told of. A hook's "waiting"
    /// goes to that agent's most recently written session. Waiting first,
    /// then working, then done when there are more than fit; in the order
    /// they're kept, by id, so nobody swaps places as poses change.
    static func list(sessions: [GuestSeen], heard: [GuestHeard], now: Date) -> [HomeGuest] {
        var guests: [HomeGuest] = []
        let waitingAgents = Set(heard.filter { $0.pose == .waiting && now.timeIntervalSince($0.at) < forgottenAfter }.map(\.agent))
        var waitingID: [String: String] = [:]
        for agent in waitingAgents {
            waitingID[agent] = sessions.filter { $0.agent == agent }.max { ($0.modified, $0.id) < ($1.modified, $1.id) }?.id
        }
        for seen in sessions {
            let quiet = now.timeIntervalSince(seen.modified)
            guard quiet < forgottenAfter else { continue }
            let pose: GuestPose
            if waitingID[seen.agent] == seen.id {
                pose = .waiting
            } else if seen.busy == true {
                pose = .working
            } else if quiet < doneStays {
                pose = .done
            } else {
                continue
            }
            guests.append(HomeGuest(id: seen.id, agent: seen.agent, pose: pose))
        }
        let watched = Set(sessions.map(\.agent))
        for hook in heard where !watched.contains(hook.agent) {
            let age = now.timeIntervalSince(hook.at)
            guard age < (hook.pose == .done ? doneStays : forgottenAfter) else { continue }
            guests.append(HomeGuest(id: "hook:\(hook.agent)", agent: hook.agent, pose: hook.pose))
        }
        guard guests.count > room else { return guests.sorted { $0.id < $1.id } }
        let order: [GuestPose] = [.waiting, .working, .done]
        let kept = guests.sorted { (order.firstIndex(of: $0.pose)!, $0.id) < (order.firstIndex(of: $1.pose)!, $1.id) }.prefix(room)
        return kept.sorted { $0.id < $1.id }
    }

    /// Which of the other pets a guest is, the same one every time for the
    /// same session: `choices` is every built-in pet but yours.
    static func pick<T>(_ id: String, from choices: [T]) -> T? {
        guard !choices.isEmpty else { return nil }
        // FNV-1a, not hashValue: that changes with every launch.
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in id.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return choices[Int(hash % UInt64(choices.count))]
    }

    /// "Claude Code guest, working", for VoiceOver.
    static func label(_ guest: HomeGuest, agentName: String) -> String {
        let doing = switch guest.pose {
        case .working: "working"
        case .waiting: "waiting for you"
        case .done: "done"
        }
        return "\(agentName) guest, \(doing)"
    }
}
