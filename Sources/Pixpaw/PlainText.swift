//
//  PlainText.swift
//  Pixpaw
//
//  One short line of plain text from anything typed or sent: what you're
//  working on in a focus session, and what an AI app hands the pet. Pure, so
//  .droppykit/Tools/focus-buddy-check.swift and .droppykit/Tools/pet-tools-check.swift check it.
//

import Foundation

enum PlainText {
    /// Control and invisible formatting characters out (newlines, tabs, bidi
    /// overrides, zero-width joiners), runs of whitespace as one space,
    /// trimmed, and at most `limit` characters with an ellipsis; nil when
    /// nothing is left.
    static func line(_ raw: String, limit: Int) -> String? {
        var out = String.UnicodeScalarView()
        var space = false
        for scalar in raw.unicodeScalars {
            let props = scalar.properties
            if props.isWhitespace || scalar.properties.generalCategory == .control {
                space = !out.isEmpty
                continue
            }
            // Format characters (bidi overrides, zero-width), unassigned and
            // private-use ones: nothing anyone meant to show.
            switch props.generalCategory {
            case .format, .unassigned, .privateUse, .surrogate, .lineSeparator, .paragraphSeparator: continue
            default: break
            }
            if space { out.append(" ") }
            space = false
            out.append(scalar)
        }
        let text = String(out)
        guard !text.isEmpty, limit > 0 else { return nil }
        return text.count > limit ? String(text.prefix(limit - 1)).trimmingCharacters(in: .whitespaces) + "…" : text
    }
}
