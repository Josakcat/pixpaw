//
//  PowerSaver.swift
//  Pixpaw
//
//  Battery saver: on battery (or in Low Power Mode) with the switch on, the
//  pet stays where it is and draws at 30 frames a second. And the numbers
//  Settings shows for how much CPU the pet's own work takes.
//

import DroppyKit
import Foundation
import SwiftUI
import IOKit.ps

enum PowerSource {
    /// Running on the battery right now. One IOKit call, no permission.
    static var onBattery: Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String?
        else { return false }
        return type == kIOPSBatteryPowerValue
    }

    static var lowPowerMode: Bool { ProcessInfo.processInfo.isLowPowerModeEnabled }
}

/// Time the pet's own loop and frames take on the main thread. Two clock
/// reads around each step and each frame, nothing else: the pet runs inside
/// Droppy's process, so this is the only way to tell its share apart.
@MainActor
enum PetCPU {
    private static var busyTicks: UInt64 = 0
    private static let secondsPerTick: Double = {
        var base = mach_timebase_info_data_t()
        mach_timebase_info(&base)
        return Double(base.numer) / Double(base.denom) / 1_000_000_000
    }()

    static func measure(_ body: () -> Void) {
        let start = mach_absolute_time()
        body()
        busyTicks &+= mach_absolute_time() &- start
    }

    static var busySeconds: Double { Double(busyTicks) * secondsPerTick }

    /// CPU time Droppy's whole process (with every droplet) has used.
    nonisolated static func processSeconds() -> Double {
        var usage = rusage()
        guard getrusage(RUSAGE_SELF, &usage) == 0 else { return 0 }
        func seconds(_ time: timeval) -> Double { Double(time.tv_sec) + Double(time.tv_usec) / 1_000_000 }
        return seconds(usage.ru_utime) + seconds(usage.ru_stime)
    }
}

/// "Energy use" in Settings: the pet's own share of one core, and Droppy's
/// with every droplet, read every five seconds only while the page is open.
struct PetEnergyRow: View {
    @State private var pet: Double?
    @State private var droppy: Double?

    var body: some View {
        DropletControlRow(
            title: "Energy use",
            infoTip: "How much of one CPU core your pet's walking and thinking take, measured while this page is open. Droppy's number is the whole app with every droplet. Drawing done by macOS isn't counted."
        ) {
            DropletValuePill(text: pet.map { "Pet \(PowerSaverRule.text($0)) · Droppy \(droppy.map(PowerSaverRule.text) ?? "…")" } ?? "Measuring…")
        }
        .task {
            var last = (pet: PetCPU.busySeconds, droppy: await Self.processSeconds(), at: Date())
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }
                let now = (pet: PetCPU.busySeconds, droppy: await Self.processSeconds(), at: Date())
                let over = now.at.timeIntervalSince(last.at)
                pet = PowerSaverRule.percent(busySeconds: now.pet - last.pet, overSeconds: over)
                droppy = PowerSaverRule.percent(busySeconds: now.droppy - last.droppy, overSeconds: over)
                last = now
            }
        }
    }

    /// Off the main thread, as everything that asks the kernel is.
    private static func processSeconds() async -> Double {
        await Task.detached(priority: .utility) { PetCPU.processSeconds() }.value
    }
}
