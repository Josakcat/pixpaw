import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// "In its own words": Apple's on-device model rewrites the pet's usual line
/// from what is going on (its mood, the time, what just finished). Off by
/// default. Asked off the main thread, at most once every 45 seconds, given
/// 2.5 seconds; anything else, or anything odd in the answer, says the usual
/// line. Nothing leaves the Mac: the model runs on it.
@MainActor
final class PetLines {
    static let shared = PetLines()

    /// The setting, set by the droplet.
    var enabled = false
    private var lastAsked: Date?
    private var asking = false
    /// Bumped by `stop()`, so an answer that comes back afterwards is dropped.
    private var generation = 0

    enum Status: Equatable {
        case ready, tooOld, notEligible, turnedOff, notReady, language
    }

    /// Whether the model can write lines on this Mac, in its language.
    static var status: Status {
        #if canImport(FoundationModels)
        guard #available(macOS 26, *) else { return .tooOld }
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            let language = Locale(identifier: Locale.preferredLanguages.first ?? "en")
            return model.supportsLocale(language) ? .ready : .language
        case .unavailable(.deviceNotEligible): return .notEligible
        case .unavailable(.appleIntelligenceNotEnabled): return .turnedOff
        default: return .notReady
        }
        #else
        return .tooOld
        #endif
    }

    /// Says `gist` in the pet's own words when it can, else `gist` itself,
    /// through `show` on the main actor. `keep`: names the answer must keep.
    func say(_ gist: String, pet: String, doing: String, keep: [String] = [],
             show: @escaping @MainActor (String) -> Void) {
        let now = Date()
        guard enabled, PetLineRules.mayAsk(lastAsked: lastAsked, now: now, busy: asking),
              Self.status == .ready else { show(gist); return }
        lastAsked = now
        asking = true
        let mine = generation
        let instructions = PetLineRules.instructions(pet: pet)
        let prompt = PetLineRules.prompt(gist: gist, doing: doing, hour: Calendar.current.component(.hour, from: now))
        Task { [weak self] in
            let answer = await Self.ask(instructions: instructions, prompt: prompt)
            guard let self, self.generation == mine else { return }
            self.asking = false
            show(answer.flatMap { PetLineRules.clean($0, gist: gist, keep: keep) } ?? gist)
        }
    }

    /// Forgets anything in flight; from `deactivate()`.
    func stop() {
        enabled = false
        generation += 1
        asking = false
        lastAsked = nil
    }

    /// One answer, or nil after the timeout or on any error. The model runs
    /// in a detached task, never on the main thread.
    nonisolated private static func ask(instructions: String, prompt: String) async -> String? {
        #if canImport(FoundationModels)
        guard #available(macOS 26, *) else { return nil }
        let once = Once()
        return await withCheckedContinuation { continuation in
            once.set(continuation)
            let work = Task.detached(priority: .utility) {
                let session = LanguageModelSession(instructions: instructions)
                let options = GenerationOptions(temperature: 0.9, maximumResponseTokens: 40)
                let answer = try? await session.respond(to: prompt, options: options).content
                once.finish(answer)
            }
            Task.detached {
                try? await Task.sleep(nanoseconds: UInt64(PetLineRules.timeout * 1_000_000_000))
                work.cancel()
                once.finish(nil)
            }
        }
        #else
        return nil
        #endif
    }
}

/// Resumes a continuation once, from whichever side gets there first.
private final class Once: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<String?, Never>?

    func set(_ continuation: CheckedContinuation<String?, Never>) {
        lock.lock(); self.continuation = continuation; lock.unlock()
    }

    func finish(_ value: String?) {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(returning: value)
    }
}
