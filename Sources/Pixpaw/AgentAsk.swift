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

    /// Where questions and answers pass between the hook and the pet.
    static let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Pixpaw/asks", isDirectory: true)
    /// Touched while the pet is out to answer, so a hook can tell nobody is
    /// there and leave the question to the agent at once.
    static var alive: URL { folder.appendingPathComponent("alive") }
    /// The answer that hands the question back to the agent's own prompt.
    static let skip = "skip"

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
        ask.options = Array(ask.options.map { String($0.prefix(40)) }.filter { !$0.isEmpty }.prefix(4))
        return ask.options.isEmpty ? nil : ask
    }

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

    func show(_ ask: AgentAsk?, answer: @escaping (String) -> Void) {
        self.ask = ask
        guard let ask else { return close() }
        let options = ask.options
        let held = keys.hold(min(options.count, AskKeys.answers)) { [weak self] index in
            // Only for the card that is still up.
            guard self?.ask?.id == ask.id else { return }
            answer(index == 0 ? AgentAsk.skip : options[index - 1])
        }
        let view = AskCardView(ask: ask, keys: held, answer: answer)
        if let hosting {
            hosting.rootView = view
        } else {
            let hosting = AskHostingView(rootView: view)
            let panel = CatPanel(contentRect: CGRect(x: 0, y: 0, width: 10, height: 10))
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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(ask.place.map { "\(ask.agent) · \($0)" } ?? ask.agent, systemImage: "hand.raised.fill")
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(white: 0.35))
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
                    .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color(white: 0.93)))
                    .fixedSize(horizontal: false, vertical: true)
            }
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
                    .buttonStyle(AskButtonStyle(prominent: index == 0, warns: option.localizedCaseInsensitiveContains("deny")))
                    .accessibilityLabel(option)
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
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(ask.agent) asks: \(ask.title)")
    }
}

/// Small rounded answer buttons that read on the white card.
struct AskButtonStyle: ButtonStyle {
    let prominent: Bool
    let warns: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .foregroundStyle(prominent ? Color.white : warns ? Color(red: 0.75, green: 0.15, blue: 0.12) : Color(white: 0.1))
            .background(
                Capsule(style: .continuous)
                    .fill(prominent ? Color(red: 0.27, green: 0.27, blue: 0.96) : Color(white: 0.9))
                    .opacity(configuration.isPressed ? 0.7 : 1)
            )
            .contentShape(Capsule())
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
