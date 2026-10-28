import AVFoundation

/// Music and sound effects. Everything is synthesized at launch, so the app ships no audio files.
@MainActor
final class Sound {
    static let shared = Sound()

    enum Effect: CaseIterable {
        case jump, land, trick, crash, gate, comboUp, comboLost, clear, warn, toss, splat
        case yeti, penguin, bear, narwhal
        case prize, buried, blip, highScore
    }

    /// M cycles through these.
    enum Mode: Int {
        case all, effectsOnly, muted
        var label: String {
            switch self {
            case .all: "Music + sound"
            case .effectsOnly: "Sound effects only"
            case .muted: "Muted"
            }
        }
    }

    private let engine = AVAudioEngine()
    private let format = AVAudioFormat(standardFormatWithSampleRate: Synth.rate, channels: 1)!
    private var buffers: [Effect: AVAudioPCMBuffer] = [:]
    private var voices: [AVAudioPlayerNode] = []
    private var nextVoice = 0
    private let music = AVAudioPlayerNode()
    private let rumble = AVAudioPlayerNode()
    private var musicBuffer: AVAudioPCMBuffer?
    private var musicPlaying = false

    var mode: Mode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: "soundMode")
            applyMode()
        }
    }

    var isRunning: Bool { engine.isRunning }

    private init() {
        mode = Mode(rawValue: UserDefaults.standard.integer(forKey: "soundMode")) ?? .all
        for node in [music, rumble] {
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
        }
        for _ in 0..<10 {
            let voice = AVAudioPlayerNode()
            engine.attach(voice)
            engine.connect(voice, to: engine.mainMixerNode, format: format)
            voices.append(voice)
        }
        for effect in Effect.allCases { buffers[effect] = buffer(Synth.effect(effect)) }
        musicBuffer = buffer(Synth.music())
        let rumbleBuffer = buffer(Synth.rumble())

        do { try engine.start() } catch { return }
        rumble.volume = 0
        rumble.scheduleBuffer(rumbleBuffer, at: nil, options: .loops)
        rumble.play()
        applyMode()
    }

    private func buffer(_ samples: [Float]) -> AVAudioPCMBuffer {
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(max(1, samples.count)))!
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source in
            if let base = source.baseAddress { buffer.floatChannelData![0].update(from: base, count: samples.count) }
        }
        return buffer
    }

    func play(_ effect: Effect, volume: Float = 1) {
        guard mode != .muted, engine.isRunning, let buffer = buffers[effect] else { return }
        let voice = voices[nextVoice]
        nextVoice = (nextVoice + 1) % voices.count
        voice.stop()
        voice.volume = volume
        voice.scheduleBuffer(buffer, at: nil)
        voice.play()
    }

    func startMusic() {
        guard engine.isRunning, let musicBuffer, !musicPlaying else { return }
        music.scheduleBuffer(musicBuffer, at: nil, options: .loops)
        music.play()
        musicPlaying = true
    }

    func stopMusic() {
        music.stop()
        musicPlaying = false
    }

    func pauseMusic(_ paused: Bool) {
        guard musicPlaying else { return }
        if paused { music.pause() } else { music.play() }
    }

    /// 0…1, driven by how close the avalanche is.
    func setRumble(_ level: Float) {
        rumble.volume = mode == .muted ? 0 : level * 0.8
    }

    /// Dev aid: silence the snapshot run without touching the saved mode.
    func silenceOutput() {
        engine.mainMixerNode.outputVolume = 0
    }

    private func applyMode() {
        music.volume = mode == .all ? 0.4 : 0
        if mode == .muted { rumble.volume = 0 }
    }
}

/// Tiny offline synthesizer: oscillators, filtered noise and a sequencer for the music loop.
enum Synth {
    static let rate = 44_100.0

    enum Wave { case sine, square, triangle, saw }

    static func osc(_ wave: Wave, _ phase: Double) -> Double {
        let p = phase - floor(phase)
        switch wave {
        case .sine: return sin(2 * .pi * p)
        case .square: return p < 0.5 ? 1 : -1
        case .triangle: return 4 * abs(p - 0.5) - 1
        case .saw: return 2 * p - 1
        }
    }

    /// One note, sweeping exponentially from `f0` to `f1`, with a quick attack and a power-curve decay.
    static func tone(_ wave: Wave, _ duration: Double, from f0: Double, to f1: Double, volume: Double,
                     attack: Double = 0.005, curve: Double = 3, tremolo: Double = 0) -> [Float] {
        let n = Int(duration * rate)
        var out = [Float](repeating: 0, count: n)
        var phase = 0.0
        for i in 0..<n {
            let t = Double(i) / Double(n)
            phase += f0 * pow(f1 / f0, t) / rate
            var env = min(1, Double(i) / rate / attack) * pow(1 - t, curve)
            if tremolo > 0 { env *= 0.6 + 0.4 * sin(2 * .pi * tremolo * Double(i) / rate) }
            out[i] = Float(osc(wave, phase) * env * volume)
        }
        return out
    }

    /// Noise through a one-pole low-pass; `smooth` near 1 is darker (rumbles, thuds), near 0 is hiss.
    static func noise(_ duration: Double, volume: Double, smooth: Double, curve: Double = 2, seed: UInt64 = 1) -> [Float] {
        var rng = SeededRandom(seed: seed)
        let n = Int(duration * rate)
        let gain = sqrt((1 + smooth) / (1 - smooth))
        var out = [Float](repeating: 0, count: n)
        var y = 0.0
        for i in 0..<n {
            y = smooth * y + (1 - smooth) * Double.random(in: -1...1, using: &rng)
            let t = Double(i) / Double(n)
            out[i] = Float(y * gain * pow(1 - t, curve) * volume)
        }
        return out
    }

    static func silence(_ duration: Double) -> [Float] { [Float](repeating: 0, count: Int(duration * rate)) }

    static func mix(_ parts: [Float]...) -> [Float] {
        var out = [Float](repeating: 0, count: parts.map(\.count).max() ?? 0)
        for part in parts { for (i, v) in part.enumerated() { out[i] += v } }
        return out
    }

    static func concat(_ parts: [Float]...) -> [Float] { parts.flatMap { $0 } }

    static func note(_ midi: Int) -> Double { 440 * pow(2, Double(midi - 69) / 12) }

    static func effect(_ effect: Sound.Effect) -> [Float] {
        switch effect {
        case .jump:
            return tone(.square, 0.16, from: 280, to: 820, volume: 0.16, curve: 1.5)
        case .land:
            return mix(tone(.sine, 0.14, from: 140, to: 55, volume: 0.6), noise(0.08, volume: 0.2, smooth: 0.7))
        case .trick:
            return concat(tone(.square, 0.07, from: 1047, to: 1047, volume: 0.13, curve: 0.5),
                          tone(.square, 0.07, from: 1319, to: 1319, volume: 0.13, curve: 0.5),
                          tone(.square, 0.22, from: 1568, to: 1568, volume: 0.13, curve: 2))
        case .crash:
            return mix(noise(0.45, volume: 0.5, smooth: 0.6, curve: 2.5, seed: 2), tone(.sine, 0.25, from: 110, to: 40, volume: 0.7))
        case .gate:
            return mix(tone(.sine, 0.5, from: 1320, to: 1320, volume: 0.3, curve: 4), tone(.sine, 0.5, from: 1980, to: 1980, volume: 0.12, curve: 6))
        case .comboUp:
            return concat(tone(.triangle, 0.06, from: 880, to: 880, volume: 0.3, curve: 0.5),
                          tone(.triangle, 0.12, from: 1175, to: 1175, volume: 0.3))
        case .comboLost:
            return tone(.triangle, 0.35, from: 520, to: 200, volume: 0.3, curve: 1)
        case .clear:
            return tone(.triangle, 0.18, from: 600, to: 1400, volume: 0.25, curve: 1)
        case .warn:
            return concat(tone(.square, 0.09, from: 988, to: 988, volume: 0.12, curve: 0.3), silence(0.06),
                          tone(.square, 0.09, from: 988, to: 988, volume: 0.12, curve: 0.3))
        case .toss:
            return tone(.sine, 0.22, from: 520, to: 240, volume: 0.25, curve: 1.5)
        case .splat:
            return noise(0.18, volume: 0.45, smooth: 0.75, curve: 3, seed: 6)
        case .yeti:
            return mix(tone(.saw, 0.9, from: 95, to: 70, volume: 0.3, attack: 0.08, curve: 1.2, tremolo: 22),
                       noise(0.9, volume: 0.18, smooth: 0.85, curve: 1.2, seed: 3))
        case .penguin:
            return concat(tone(.sine, 0.12, from: 1100, to: 1700, volume: 0.28, curve: 0.8),
                          tone(.sine, 0.16, from: 1600, to: 1000, volume: 0.28, curve: 1))
        case .bear:
            return mix(tone(.saw, 1.0, from: 140, to: 75, volume: 0.28, attack: 0.1, curve: 1),
                       noise(1.0, volume: 0.28, smooth: 0.9, curve: 1, seed: 4))
        case .narwhal:
            return mix(noise(0.7, volume: 0.35, smooth: 0.3, curve: 3, seed: 5),
                       concat(silence(0.05), tone(.sine, 0.3, from: 300, to: 700, volume: 0.3, curve: 1.5)))
        case .prize:
            let notes = [76, 81, 84, 88, 93].map { tone(.triangle, 0.07, from: note($0), to: note($0), volume: 0.26, curve: 0.6) }
            return mix(concat(notes[0], notes[1], notes[2], notes[3], notes[4]),
                       concat(silence(0.2), tone(.sine, 0.45, from: note(100), to: note(100), volume: 0.1, curve: 3)))
        case .buried:
            return concat(tone(.square, 0.18, from: 523, to: 523, volume: 0.15, curve: 0.6),
                          tone(.square, 0.18, from: 392, to: 392, volume: 0.15, curve: 0.6),
                          tone(.square, 0.18, from: 311, to: 311, volume: 0.15, curve: 0.6),
                          tone(.square, 0.6, from: 262, to: 196, volume: 0.15, curve: 1.5))
        case .blip:
            return tone(.square, 0.05, from: 660, to: 660, volume: 0.12, curve: 1)
        case .highScore:
            let notes = [72, 76, 79, 84].map { tone(.triangle, 0.1, from: note($0), to: note($0), volume: 0.3, curve: 0.4) }
            return concat(notes[0], notes[1], notes[2], notes[3],
                          mix(tone(.triangle, 0.5, from: note(84), to: note(84), volume: 0.3, curve: 1.5),
                              tone(.square, 0.5, from: note(79), to: note(79), volume: 0.08, curve: 1.5)))
        }
    }

    /// Low rolling rumble. Every component completes whole cycles in 2 s, so the loop is seamless.
    static func rumble() -> [Float] {
        let n = Int(2 * rate)
        var rng = SeededRandom(seed: 9)
        let partials = [31.0, 36.5, 42, 47.5, 55, 61.5].map { ($0, Double.random(in: 0..<1, using: &rng)) }
        return (0..<n).map { i in
            let t = Double(i) / rate
            var body = 0.0
            for (frequency, offset) in partials { body += sin(2 * Double.pi * (frequency * t + offset)) }
            body /= Double(partials.count)
            let swell = 0.65 + 0.35 * sin(2 * .pi * 1.5 * t) * sin(2 * .pi * 0.5 * t)
            return Float(body * swell * 0.9)
        }
    }

    /// A 16-bar loop at 136 bpm in A minor: bass, arpeggio, drums and a seeded pentatonic lead.
    static func music() -> [Float] {
        let step = 60.0 / 136 / 4  // one sixteenth note
        let bars = 16
        let n = Int(Double(bars * 16) * step * rate)
        var out = [Float](repeating: 0, count: n)
        func add(_ samples: [Float], at time: Double) {
            let start = Int(time * rate)
            for (i, v) in samples.enumerated() where start + i < n { out[start + i] += v }
        }

        // Am  F  C  G  Am  Dm  F  E
        let chords: [(root: Int, tones: [Int])] = [
            (45, [57, 60, 64]), (41, [57, 60, 65]), (48, [55, 60, 64]), (43, [55, 59, 62]),
            (45, [57, 60, 64]), (38, [57, 62, 65]), (41, [57, 60, 65]), (40, [56, 59, 64]),
        ]
        let bassPattern = [0, 0, 12, 0, 0, 7, 12, 7]
        let scale = [69, 72, 74, 76, 79, 81, 84]
        let rhythms: [[Int]] = [  // lead note lengths in eighths, summing to 8
            [2, 1, 1, 2, 2], [3, 1, 2, 2], [1, 1, 2, 1, 1, 2], [4, 2, 2], [2, 2, 1, 1, 2],
        ]
        var rng = SeededRandom(seed: 2026)

        let kick = tone(.sine, 0.18, from: 150, to: 45, volume: 0.5, curve: 1.5)
        let snare = mix(noise(0.15, volume: 0.2, smooth: 0.4, curve: 2.5, seed: 11), tone(.triangle, 0.08, from: 220, to: 180, volume: 0.15))
        let hat = noise(0.035, volume: 0.05, smooth: 0.0, curve: 2, seed: 12)

        for bar in 0..<bars {
            let chord = chords[bar % chords.count]
            let barStart = Double(bar * 16) * step

            for (i, offset) in bassPattern.enumerated() {
                let f = note(chord.root + offset)
                add(tone(.triangle, step * 1.8, from: f, to: f, volume: 0.26, curve: 0.8), at: barStart + Double(i * 2) * step)
            }

            if bar >= 4 {
                for i in 0..<16 {
                    let tones = chord.tones
                    let pick = [0, 1, 2, 1][i % 4]
                    let f = note(tones[pick] + 12)
                    add(tone(.square, step * 0.9, from: f, to: f, volume: 0.035, curve: 1.2), at: barStart + Double(i) * step)
                }
            }

            if bar >= 2 {
                for beat in 0..<4 {
                    let t = barStart + Double(beat * 4) * step
                    add(beat % 2 == 0 ? kick : snare, at: t)
                    add(hat, at: t)
                    add(hat, at: t + step * 2)
                }
            }

            if bar >= 8 {
                var slot = 0
                for (i, length) in rhythms[Int.random(in: 0..<rhythms.count, using: &rng)].enumerated() {
                    // Chord tones on the downbeat, free pentatonic movement elsewhere.
                    let midi = i == 0 ? chord.tones[Int.random(in: 0..<3, using: &rng)] + 12 : scale[Int.random(in: 0..<scale.count, using: &rng)]
                    let f = note(midi)
                    let duration = Double(length) * step * 2 * 0.95
                    add(mix(tone(.square, duration, from: f, to: f, volume: 0.06, attack: 0.01, curve: 0.9),
                            tone(.triangle, duration, from: f, to: f, volume: 0.1, attack: 0.01, curve: 0.9)),
                        at: barStart + Double(slot) * step * 2)
                    slot += length
                }
            }
        }

        let peak = out.map(abs).max() ?? 1
        if peak > 0.9 { out = out.map { $0 * 0.9 / peak } }
        return out
    }
}

/// Small deterministic generator (splitmix64) for repeatable shapes and sounds.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
