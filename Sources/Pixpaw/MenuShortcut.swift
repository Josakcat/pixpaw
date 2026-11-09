// The key a shortcut is bound to, spelled for an NSMenuItem, so the pet's
// menu shows what the user set on Droppy's Shortcuts page and nothing when
// they cleared it.

import AppKit
import Carbon.HIToolbox
import DroppyKit

enum MenuShortcut {
    /// The key equivalent and modifiers for `shortcut` on the current
    /// keyboard layout, or nil when the key has no character to show.
    static func keyEquivalent(_ shortcut: DropletKeyboardShortcut) -> (key: String, modifiers: NSEvent.ModifierFlags)? {
        let modifiers = NSEvent.ModifierFlags(rawValue: shortcut.modifiers)
            .intersection([.control, .option, .shift, .command])
        guard let key = character(for: shortcut.keyCode) else { return nil }
        return (key, modifiers)
    }

    /// The shortcut as Settings names it: "⌃⌥T".
    static func text(_ shortcut: DropletKeyboardShortcut) -> String? {
        guard let (key, modifiers) = keyEquivalent(shortcut) else { return nil }
        let marks: [(NSEvent.ModifierFlags, String)] = [(.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘")]
        return marks.filter { modifiers.contains($0.0) }.map(\.1).joined() + key.uppercased()
    }

    /// What the key types with no modifiers held on the ASCII-capable layout
    /// (a Thai or Russian layout would spell / as ฝ), lowercased (the menu adds
    /// ⇧ from the mask itself).
    private static func character(for keyCode: UInt16) -> String? {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(property).takeUnretainedValue() as Data
        var deadKeys: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0
        let status = data.withUnsafeBytes { raw -> OSStatus in
            guard let layout = raw.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return -1 }
            return UCKeyTranslate(layout, keyCode, UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                                  OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, chars.count, &length, &chars)
        }
        guard status == noErr, length > 0 else { return nil }
        let text = String(utf16CodeUnits: chars, count: length).lowercased()
        return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : text
    }
}
