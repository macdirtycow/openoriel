import Foundation
import AVFoundation
import Observation

/// Local ambience for Oriel Pulse — procedural tones, not a streaming soundtrack.
@MainActor
@Observable
final class PulseAmbiencePlayer {
    enum Track: String, CaseIterable, Identifiable, Sendable {
        case off
        case neonHum
        case softPulse
        case nightDrive

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .off: "Off"
            case .neonHum: "Neon hum"
            case .softPulse: "Soft pulse"
            case .nightDrive: "Night drive"
            }
        }
    }

    private(set) var track: Track = .off
    private(set) var isPlaying = false
    var volume: Float = 0.22 {
        didSet {
            volume = min(1, max(0, volume))
            engine.mainMixerNode.outputVolume = volume
            UserDefaults.standard.set(volume, forKey: volumeKey)
        }
    }

    private let engine = AVAudioEngine()
    private var source: AVAudioSourceNode?
    private var phase: Double = 0
    private let trackKey = "oriel.pulseAmbienceTrack"
    private let volumeKey = "oriel.pulseAmbienceVolume"

    init() {
        if let raw = UserDefaults.standard.string(forKey: trackKey),
           let value = Track(rawValue: raw) {
            track = value
        }
        let stored = UserDefaults.standard.object(forKey: volumeKey) as? Float
        volume = stored ?? 0.22
        engine.mainMixerNode.outputVolume = volume
    }

    func select(_ next: Track) {
        track = next
        UserDefaults.standard.set(next.rawValue, forKey: trackKey)
        if next == .off {
            stop()
        } else {
            start(track: next)
        }
    }

    func stop() {
        engine.stop()
        if let source {
            engine.detach(source)
            self.source = nil
        }
        isPlaying = false
    }

    private func start(track: Track) {
        stop()
        let sampleRate = 44_100.0
        let freqs: [Double]
        switch track {
        case .off:
            return
        case .neonHum:
            freqs = [110, 165, 220]
        case .softPulse:
            freqs = [98, 147]
        case .nightDrive:
            freqs = [82.5, 123.5, 247]
        }

        let node = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let self, let buffer = abl.first?.mData?.assumingMemoryBound(to: Float.self) else {
                return noErr
            }
            let frames = Int(frameCount)
            for i in 0..<frames {
                self.phase += 1.0 / sampleRate
                var sample: Double = 0
                for (index, freq) in freqs.enumerated() {
                    let amp = 0.12 / Double(freqs.count)
                    let wobble = 1 + 0.01 * sin(self.phase * (0.4 + Double(index) * 0.15))
                    sample += sin(self.phase * 2 * .pi * freq * wobble) * amp
                }
                // Soft pulse envelope for Soft Pulse / Night Drive
                if track == .softPulse || track == .nightDrive {
                    let env = 0.65 + 0.35 * sin(self.phase * 2 * .pi * 0.35)
                    sample *= env
                }
                buffer[i] = Float(sample)
            }
            return noErr
        }

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        source = node
        do {
            #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            #endif
            try engine.start()
            isPlaying = true
        } catch {
            isPlaying = false
        }
    }
}
