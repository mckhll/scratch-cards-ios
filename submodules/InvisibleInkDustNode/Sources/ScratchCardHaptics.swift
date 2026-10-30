import UIKit
import CoreHaptics

/// Short texture pulses only while new film is removed; no sustained vibration at rest.
final class ScratchCardHaptics {
    private var engine: CHHapticEngine?
    private let fallback = UIImpactFeedbackGenerator(style: .rigid)
    private var lastPulse: CFTimeInterval = 0

    func prepare() {
        fallback.prepare()
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            if engine == nil {
                let engine = try CHHapticEngine()
                engine.playsHapticsOnly = true
                engine.isAutoShutdownEnabled = true
                self.engine = engine
            }
            try engine?.start()
        } catch { engine = nil }
    }

    func scratch() {
        let now = CACurrentMediaTime()
        guard now - lastPulse > 0.045 else { return }
        lastPulse = now
        if let engine {
            do {
                try engine.start()
                let event = CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.48),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                ], relativeTime: 0)
                let pattern = try CHHapticPattern(events: [event], parameters: [])
                let player = try engine.makePlayer(with: pattern)
                try player.start(atTime: CHHapticTimeImmediate)
                return
            } catch { self.engine = nil }
        }
        fallback.impactOccurred(intensity: 0.7)
        fallback.prepare()
    }

    func finish() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.8)
    }

    func land() { UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.45) }

    func stop() { engine?.stop(completionHandler: nil) }
    deinit { engine?.stop(completionHandler: nil) }
}
