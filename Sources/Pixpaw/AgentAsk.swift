//
//  AgentAsk.swift
//  Pixpaw
//
//  A coding agent asking you something (may Claude run this command? which
//  of these did you mean?): your pet comes over, says it, and holds up the
//  choices on a card over its head; a click answers. The agent's hook
//  (Tools/agent-hooks/pixpaw-ask.py) leaves the question in a file, opens
//  `ask?id=…`, and waits for the answer file the click writes. Nothing is
//  answered unless you click; ignored, the agent asks you as usual.
//  While the card is up, Option-1 to Option-4 pick an answer and Option-0
//  hands the question back, so your hands stay on the keyboard.
//  A risky one (a command that deletes for good, a force-push, a secrets
//  file) gets the pet's hackles up: a warning on the card, no "Always
//  allow", and the Option keys only after a moment, so a reflex can't
//  allow it, and allowing it takes Touch ID (or your password).
//  An agent's hook that takes a typed answer gets a field for one: your own
//  answer to a question, or what to do instead of a command it asked about.
//

import AppKit
import Carbon.HIToolbox
import SwiftUI

/// What the hook wrote: who asks, what, and the answers to offer.
struct AgentAsk: Decodable, Equatable, Identifiable {
    var id: String
    var agent: String
    var title: String
    /// The command, file or page it's about, shown in a smaller type.
    var detail: String?
    /// The project it is working in.
    var place: String?
    /// The answers, first the likeliest; one is written back as it is.
    var options: [String]
    /// What it says aloud, when that is on.
    var spoken: String?
    /// Whether the hook takes a typed answer: "answer" (your own answer to
    /// its question) or "instead" (no, and what to do instead).
    var typed: String?

    /// Where questions and answers pass between the hook and the pet.
    static let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Pixpaw/asks", isDirectory: true)
    /// Touched while the pet is out to answer, so a hook can tell nobody is
    /// there and leave the question to the agent at once.
    static var alive: URL { folder.appendingPathComponent("alive") }
    /// The answer that hands the question back to the agent's own prompt.
    static let skip = "skip"
    /// Before an answer you typed, so the hook tells it from the buttons'.
    static let typedPrefix = "text:"

    var file: URL { Self.folder.appendingPathComponent("\(id).json") }
    var answerFile: URL { Self.folder.appendingPathComponent("\(id).answer") }

    /// A question the hook left, read and kept to sizes the card can show.
    static func load(id: String) -> AgentAsk? {
        guard id.wholeMatch(of: #/[A-Za-z0-9-]{8,64}/#) != nil,
              let data = try? Data(contentsOf: folder.appendingPathComponent("\(id).json")),
              var ask = try? JSONDecoder().decode(AgentAsk.self, from: data), ask.id == id else { return nil }
        ask.agent = String(ask.agent.prefix(24))
        ask.title = String(ask.title.prefix(120))
        ask.detail = ask.detail.map { String($0.prefix(240)) }
        ask.place = ask.place.map { String($0.prefix(40)) }
        ask.spoken = ask.spoken.map { String($0.prefix(160)) }
        if !["answer", "instead"].contains(ask.typed ?? "") { ask.typed = nil }
        ask.options = Array(ask.options.map { String($0.prefix(40)) }.filter { !$0.isEmpty }.prefix(4))
        // Allowed for good, a risky one would never be asked about again.
        if ask.risk != nil { ask.options.removeAll { $0 == "Always allow" } }
        return ask.options.isEmpty ? nil : ask
    }

    /// What makes it risky, said plainly ("Deletes files for good"), or nil.
    var risk: String? {
        guard let detail, !detail.isEmpty else { return nil }
        if detail.contains(Self.secrets.pattern) { return Self.secrets.reason }
        // A search or a page only looks like a command.
        guard !title.hasPrefix("Search"), !title.hasPrefix("Open this page") else { return nil }
        return Self.risks.first { detail.contains($0.pattern) }?.reason
    }

    private struct Risk {
        let pattern: Regex<AnyRegexOutput>
        let reason: String

        init(_ pattern: String, _ reason: String) {
            self.pattern = try! Regex(pattern)
            self.reason = reason
        }
    }

    /// Commands that can't be taken back, or reach past this Mac.
    nonisolated(unsafe) private static let risks = [
        Risk(#"\brm\s+(-\S+\s+)*-[a-zA-Z]*[rRf]|\brm\b[^|;&]*--(recursive|force)\b|\bfind\b[^|;&]*\s-delete\b|\bshred\b"#, "Deletes files for good"),
        Risk(#"\bgit\s+push\b[^|;&]*(\s-f\b|\s--force\b|\s--force-with-lease\b|\s\+\S)"#, "Force-pushes over what's there"),
        Risk(#"\bgit\s+push\b[^|;&]*(\s--delete\b|\s-d\b|\s:\S)|\bgit\s+branch\s+[^|;&]*-D\b"#, "Deletes a branch"),
        Risk(#"\bgit\s+reset\b[^|;&]*--hard\b|\bgit\s+clean\s+-\S*f|\bgit\s+(checkout|restore)\s+(--\s+)?\.(\s|$)|\bgit\s+stash\s+(drop|clear)\b"#, "Throws away changes"),
        Risk(#"(?i)\b(drop\s+(table|database|schema)|truncate\s+table)\b"#, "Drops data for good"),
        Risk(#"\b(curl|wget)\b[^;&]*\|\s*(sudo\s+)?(ba|z)?sh\b"#, "Runs a script from the internet"),
        Risk(#"\bmkfs\b|\bdd\s+[^|;&]*of=/dev/|\bdiskutil\s+(erase|zero|partition|reformat)"#, "Can wipe a disk"),
        Risk(#"\bsudo\b"#, "Runs as an administrator"),
        Risk(#"\b(terraform|tofu)\s+destroy\b|\bkubectl\s+delete\b|\bdocker\s+(system\s+prune|volume\s+(rm|prune))\b"#, "Tears down what's running"),
        Risk(#"\b(npm|yarn|pnpm|cargo|gem)\s+publish\b|\btwine\s+upload\b"#, "Publishes for everyone to see"),
        Risk(#"\bsecurity\s+(find-\S*-password|dump-keychain)\b"#, "Reads your keychain"),
        Risk(#"\bchmod\s+(-R\s+)?777\b|\bcrontab\s+-r\b"#, "Changes your Mac for good"),
    ]

    /// Files with keys or passwords in them, whatever the agent does to them.
    nonisolated(unsafe) private static let secrets = Risk(
        #"(^|[\s/"'=])(\.env(?!\.(example|sample|template|dist)\b)(\.[\w-]+)?|id_(rsa|ed25519|ecdsa)|[\w-]+\.(pem|p12|p8)|\.npmrc|\.netrc|\.pypirc|\.aws/credentials|credentials\.json|secrets?\.(json|ya?ml|toml))($|[\s"';|&)])"#,
        "A file with secrets in it")

    /// Writes the answer for the hook to pick up.
    func answer(_ choice: String) {
        try? choice.write(to: answerFile, atomically: true, encoding: .utf8)
    }

    /// Whether the hook still waits; gone when the agent stopped asking.
    var isOpen: Bool { FileManager.default.fileExists(atPath: file.path) }
}

/// The card over the pet's head while an agent asks.
@MainActor
final class AskCard {
    private var panel: CatPanel?
    private var hosting: AskHostingView?
    private let keys = AskKeys()
    private(set) var ask: AgentAsk?

    /// The top of the card on screen, while it is up.
    var top: CGFloat? { panel?.isVisible == true ? panel?.frame.maxY : nil }

    /// How long a risky one waits for its Option keys.
    static let riskyKeysAfter: TimeInterval = 2

    func show(_ ask: AgentAsk?, answer: @escaping (String) -> Void) {
        self.ask = ask
        guard let ask else { return close() }
        guard ask.risk != nil else { return show(ask, keys: holdKeys(for: ask, answer: answer), answer: answer) }
        // Read before it can be allowed from the keyboard: a click still can.
        keys.release()
        show(ask, keys: [], answer: answer)
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.riskyKeysAfter) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.ask?.id == ask.id else { return }
                self.show(ask, keys: self.holdKeys(for: ask, answer: answer), answer: answer)
            }
        }
    }

    private func holdKeys(for ask: AgentAsk, answer: @escaping (String) -> Void) -> Set<Int> {
        let options = ask.options
        return keys.hold(min(options.count, AskKeys.answers)) { [weak self] index in
            // Only for the card that is still up.
            guard self?.ask?.id == ask.id else { return }
            answer(index == 0 ? AgentAsk.skip : options[index - 1])
        }
    }

    private func show(_ ask: AgentAsk, keys held: Set<Int>, answer: @escaping (String) -> Void) {
        let view = AskCardView(ask: ask, keys: held, answer: answer)
        if let hosting {
            hosting.rootView = view
        } else {
            let hosting = AskHostingView(rootView: view)
            let panel = CatPanel(contentRect: CGRect(x: 0, y: 0, width: 10, height: 10))
            // Key only while you click into the answer field, without
            // bringing Droppy forward.
            panel.takesKeys = true
            panel.contentView = hosting
            self.hosting = hosting
            self.panel = panel
        }
        panel?.setContentSize(hosting?.fittingSize ?? .zero)
    }

    /// Over the pet's head, its tail at `head`; or out of sight.
    func place(head: CGPoint?) {
        guard let panel, ask != nil else { return }
        guard let head else { return panel.orderOut(nil) }
        let size = panel.frame.size
        var origin = CGPoint(x: (head.x - size.width / 2).rounded(), y: head.y.rounded())
        if let area = NSScreen.screens.first(where: { NSMouseInRect(head, $0.frame, false) })?.visibleFrame {
            origin.x = min(max(origin.x, area.minX + 4), area.maxX - size.width - 4)
            origin.y = min(origin.y, area.maxY - size.height)
        }
        panel.setFrameOrigin(origin)
        if !panel.isVisible { panel.orderFrontRegardless() }
    }

    func close() {
        ask = nil
        keys.release()
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
        hosting = nil
    }
}

/// Takes the first click without making Droppy active.
final class AskHostingView: NSHostingView<AskCardView> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// The speech bubble's look, with the answers as buttons under the question.
struct AskCardView: View {
    let ask: AgentAsk
    /// The numbers Option answers it with: 1 to 4 for the answers, 0 to
    /// hand it back.
    var keys: Set<Int> = []
    let answer: (String) -> Void

    private static let warning = Color(red: 0.75, green: 0.15, blue: 0.12)
    @State private var typing = ""

    var body: some View {
        let risk = ask.risk
        VStack(alignment: .leading, spacing: 6) {
            Label(ask.place.map { "\(ask.agent) · \($0)" } ?? ask.agent, systemImage: "hand.raised.fill")
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(white: 0.35))
            if let risk {
                Label("Careful: \(risk.prefix(1).lowercased() + risk.dropFirst())", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundStyle(Self.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(ask.title)
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
            if let detail = ask.detail, !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 11, design: .monospaced))
                    .lineLimit(4)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(risk == nil ? Color(white: 0.93) : Color(red: 1, green: 0.9, blue: 0.88)))
                    .fixedSize(horizontal: false, vertical: true)
            }
            // One row of capsules while every answer fits whole; otherwise a
            // list, each answer on its own full-width row that wraps.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    ForEach(Array(ask.options.enumerated()), id: \.offset) { index, option in
                        Button { answer(option) } label: {
                            HStack(spacing: 4) {
                                Text(option)
                                if keys.contains(index + 1) {
                                    Text("⌥\(index + 1)").opacity(0.6)
                                }
                            }
                        }
                        .buttonStyle(style(index, option, row: false))
                        .accessibilityLabel(option)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(ask.options.enumerated()), id: \.offset) { index, option in
                        Button { answer(option) } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(option)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if keys.contains(index + 1) {
                                    Text("⌥\(index + 1)").opacity(0.6)
                                }
                            }
                        }
                        .buttonStyle(style(index, option, row: true))
                        .accessibilityLabel(option)
                    }
                }
            }
            if let typed = ask.typed {
                HStack(spacing: 4) {
                    TextField("Answer", text: $typing,
                              prompt: Text(typed == "instead" ? "Or tell \(ask.agent) what to do instead" : "Or type your own answer")
                                .foregroundStyle(Color(white: 0.5)))
                        .textFieldStyle(.plain)
                        .foregroundStyle(Color(white: 0.1))
                        .font(.system(size: 11.5, design: .rounded))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color(white: 0.93)))
                        .onSubmit(send)
                    Button(action: send) {
                        Image(systemName: "arrow.up.circle.fill").font(.system(size: 17))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color(red: 0.27, green: 0.27, blue: 0.96))
                    .disabled(typing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Send")
                }
            }
            Button(keys.contains(0) ? "Answer in \(ask.agent) instead  ⌥0" : "Answer in \(ask.agent) instead") { answer(AgentAsk.skip) }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Color(white: 0.45))
        }
        .foregroundStyle(Color(white: 0.1))
        .frame(width: 250, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 14)
        .background(AskBubbleShape().fill(Color.white))
        .overlay(AskBubbleShape().stroke(Color(white: 0.12), lineWidth: 2))
        .padding(2)
        .fixedSize()
        .onChange(of: ask.id) { typing = "" }
        // A white card in dark mode too, its field and caret included.
        .environment(\.colorScheme, .light)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(risk.map { "Careful. \(ask.agent) asks: \(ask.title) \($0)." } ?? "\(ask.agent) asks: \(ask.title)")
    }

    /// A risky one puts nothing forward: Allow is no easier than Deny.
    private func style(_ index: Int, _ option: String, row: Bool) -> AskButtonStyle {
        AskButtonStyle(prominent: index == 0 && ask.risk == nil, warns: option.localizedCaseInsensitiveContains("deny"), row: row)
    }

    private func send() {
        let text = typing.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        answer(AgentAsk.typedPrefix + String(text.prefix(500)))
    }
}

/// Small rounded answer buttons that read on the white card: capsules in a
/// row, or full-width rows whose text wraps when the answers are long.
struct AskButtonStyle: ButtonStyle {
    let prominent: Bool
    let warns: Bool
    var row = false

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: row ? 8 : 100, style: .continuous)
        configuration.label
            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
            .lineLimit(row ? nil : 1)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 9)
            .padding(.vertical, row ? 5 : 4)
            .frame(maxWidth: row ? .infinity : nil, alignment: .leading)
            .foregroundStyle(prominent ? Color.white : warns ? Color(red: 0.75, green: 0.15, blue: 0.12) : Color(white: 0.1))
            .background(
                shape
                    .fill(prominent ? Color(red: 0.27, green: 0.27, blue: 0.96) : Color(white: 0.9))
                    .opacity(configuration.isPressed ? 0.7 : 1)
            )
            .contentShape(shape)
    }
}

/// A rounded rectangle with a little tail at the bottom middle, pointing
/// down at the pet.
struct AskBubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let bottom = rect.maxY - 6, r: CGFloat = 10
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: bottom), radius: r)
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: bottom), tangent2End: CGPoint(x: rect.minX, y: bottom), radius: r)
        path.addLine(to: CGPoint(x: rect.midX + 6, y: bottom))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX - 6, y: bottom))
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: bottom), tangent2End: CGPoint(x: rect.minX, y: rect.minY), radius: r)
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY), radius: r)
        path.closeSubpath()
        return path
    }
}

/// Option-1 to Option-4 for the card's answers and Option-0 to hand it
/// back, from any app. Held only while a card is up and let go the moment
/// it goes, so the keys are yours the rest of the time. A key some other
/// app already holds is left alone.
@MainActor
final class AskKeys {
    static let answers = 4
    private static let signature: OSType = 0x5058_4B59 // "PXKY"
    private static let codes = [kVK_ANSI_0, kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4]

    private var refs: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    private var pressed: ((Int) -> Void)?

    /// Holds Option-0 and Option-1 up to Option-`count`; `pressed` gets the
    /// number. The numbers it could hold.
    func hold(_ count: Int, pressed: @escaping (Int) -> Void) -> Set<Int> {
        release()
        self.pressed = pressed
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let me = Unmanaged.passUnretained(self).toOpaque()
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, event, data in
            guard let event, let data else { return OSStatus(eventNotHandledErr) }
            var key = EventHotKeyID()
            let read = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                         nil, MemoryLayout<EventHotKeyID>.size, nil, &key)
            guard read == noErr, key.signature == AskKeys.signature else { return OSStatus(eventNotHandledErr) }
            let number = Int(key.id)
            MainActor.assumeIsolated {
                // Answering closes the card, which takes this handler away:
                // not from inside it, so on the next turn.
                let pressed = Unmanaged<AskKeys>.fromOpaque(data).takeUnretainedValue().pressed
                DispatchQueue.main.async { pressed?(number) }
            }
            return noErr
        }, 1, &spec, me, &handler)
        guard installed == noErr else { return [] }
        var held: Set<Int> = []
        for number in 0...min(count, Self.answers) {
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(UInt32(Self.codes[number]), UInt32(optionKey),
                                             EventHotKeyID(signature: Self.signature, id: UInt32(number)),
                                             GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let ref {
                refs.append(ref)
                held.insert(number)
            }
        }
        return held
    }

    func release() {
        refs.forEach { UnregisterEventHotKey($0) }
        refs = []
        if let handler { RemoveEventHandler(handler) }
        handler = nil
        pressed = nil
    }
}
