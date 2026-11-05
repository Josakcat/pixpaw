//
//  Lofi.swift
//  Pixpaw
//
//  Lofi through your pet: it opens beats to study to where you listen
//  (Lofi Girl's live radio on YouTube, her playlist in Spotify or Apple
//  Music, or a link of your own), and pauses them for a break when it
//  started them for a focus session. Nothing is streamed by the droplet
//  itself: the music plays in your browser or your player.
//

import AppKit
import ApplicationServices

enum LofiSource: String, CaseIterable, Identifiable {
    case youtube, spotify, appleMusic, own

    var id: String { rawValue }

    var title: String {
        switch self {
        case .youtube: "YouTube, Lofi Girl's radio"
        case .spotify: "Spotify, Lofi Girl's playlist"
        case .appleMusic: "Apple Music, Lofi Girl's playlist"
        case .own: "A link of your own"
        }
    }

    /// Its name in the pet's menu.
    var short: String {
        switch self {
        case .youtube: "YouTube"
        case .spotify: "Spotify"
        case .appleMusic: "Apple Music"
        case .own: "Your link"
        }
    }

    /// The app that plays it and answers play and pause, when it's one of
    /// the players rather than a browser.
    var player: (name: String, bundleID: String)? {
        switch self {
        case .spotify: ("Spotify", "com.spotify.client")
        case .appleMusic: ("Music", "com.apple.Music")
        case .youtube, .own: nil
        }
    }
}

@MainActor
enum Lofi {
    /// The channel's live page, not one video: Lofi Girl restarts her streams, and an old ID stops playing.
    static let youtube = URL(string: "https://www.youtube.com/@LofiGirl/live")!
    static let spotifyPlaylist = "spotify:playlist:0vvXsWCC9xrXsKd4FyS8kM"
    static let spotifyWeb = URL(string: "https://open.spotify.com/playlist/0vvXsWCC9xrXsKd4FyS8kM")!
    static let appleMusic = URL(string: "music://music.apple.com/us/playlist/lofi-girl-beats-to-relax-study-to/pl.bf7a3cbca49644d8a33f09c1285aef5c")!

    /// A song, artist or album that says it's lofi.
    nonisolated static func isLofi(_ text: String) -> Bool {
        let said = text.lowercased()
        return ["lofi", "lo-fi", "lo fi", "chillhop", "beats to relax", "beats to study"].contains { said.contains($0) }
    }

    /// A link of your own that can be opened: a web page or a player's own.
    static func ownLink(_ text: String) -> URL? {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(), ["https", "http", "spotify", "music"].contains(scheme) else { return nil }
        return url
    }

    /// Starts it: Spotify plays the playlist straight away; YouTube and a
    /// link of your own open in your browser; Apple Music opens the playlist
    /// for you to press play. False when there was nothing it could open.
    static func play(_ source: LofiSource, ownLink: String) async -> Bool {
        switch source {
        case .spotify:
            if installed("com.spotify.client"), await tell("Spotify", id: "com.spotify.client", "play track \"\(spotifyPlaylist)\"") { return true }
            return NSWorkspace.shared.open(spotifyWeb)
        case .appleMusic:
            return NSWorkspace.shared.open(appleMusic)
        case .youtube:
            return NSWorkspace.shared.open(youtube)
        case .own:
            guard let url = Self.ownLink(ownLink) else { return false }
            return NSWorkspace.shared.open(url)
        }
    }

    /// Picks up again where it was paused.
    static func resume(_ source: LofiSource) async {
        if let player = source.player, NSRunningApplication.runningApplications(withBundleIdentifier: player.bundleID).first != nil {
            _ = await tell(player.name, id: player.bundleID, "play")
        } else {
            pressPlayPause()
        }
    }

    /// Pauses it for a break: the player is told to pause; in a browser,
    /// the play/pause key does it, so it is only pressed while something
    /// is playing.
    static func pause(_ source: LofiSource, somethingPlaying: Bool) async {
        if let player = source.player, NSRunningApplication.runningApplications(withBundleIdentifier: player.bundleID).first != nil {
            _ = await tell(player.name, id: player.bundleID, "pause")
        } else if somethingPlaying {
            pressPlayPause()
        }
    }

    private static func installed(_ bundleID: String) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
    }

    /// One line to a player, asking once for Droppy to control it, off the
    /// main thread, since the question waits for you. On the same serial
    /// queue as the page capture, since NSAppleScript isn't safe across threads.
    private static func tell(_ app: String, id: String, _ line: String) async -> Bool {
        let source = """
        with timeout of 10 seconds
        tell application "\(app)" to \(line)
        end timeout
        """
        return (try? await CaptureQueue.shared.perform {
            let target = NSAppleEventDescriptor(bundleIdentifier: id)
            guard let desc = target.aeDesc, AEDeterminePermissionToAutomateTarget(desc, typeWildCard, typeWildCard, true) == noErr else { return false }
            var error: NSDictionary?
            // droppykit-lint: allow process: an in-process AppleScript to Spotify or Music only, to start or pause lofi the user turned on, on one serial background queue, bounded by `with timeout`, and only after macOS's Automation consent for that player
            NSAppleScript(source: source)?.executeAndReturnError(&error)
            return error == nil
        }) ?? false
    }

    /// The keyboard's play/pause key, which goes to whatever is playing,
    /// a video in a browser included.
    private static func pressPlayPause() {
        let key = 16 // NX_KEYTYPE_PLAY
        for down in [true, false] {
            let flags = NSEvent.ModifierFlags(rawValue: down ? 0xA00 : 0xB00)
            let data = (key << 16) | ((down ? 0xA : 0xB) << 8)
            NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0,
                               context: nil, subtype: 8, data1: data, data2: -1)?.cgEvent?.post(tap: .cghidEventTap)
        }
    }
}
