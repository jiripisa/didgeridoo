import Testing
@testable import DidgeridooCore

/// Guards the sound itself: the references below were taken from the engine,
/// so a change in `DidgeridooDSP` that alters a single sample fails here.
///
/// Each reference holds two things: a fingerprint of every sample, and the
/// level of each second. They tell two cases apart:
/// - levels differ: the sound really changed;
/// - only fingerprints differ, for every program at once and without a change
///   in the engine: a new compiler or macOS rounds differently.
///
/// When a change of the sound is deliberate, say so in the CHANGELOG, run the
/// suite and copy the lines it prints over `references`.
@Suite("Sound")
struct SoundRegressionTests {

    /// One MIDI message of the phrase, `time` seconds after its start.
    private struct Event {
        let time: Double
        let status: UInt8
        let data1: UInt8
        let data2: UInt8

        init(_ time: Double, _ status: UInt8, _ data1: UInt8, _ data2: UInt8) {
            self.time = time
            self.status = status
            self.data1 = data1
            self.data2 = data2
        }
    }

    /// Everything the engine reacts to: a drone, the mod wheel, a legato note and
    /// the fall back to the held one, pitch bend, a release, the hardest hit
    /// from silence and one played legato, aftertouch and the sustain pedal.
    private static let phrase: [Event] = [
        Event(0.00, 0x90, 62, 100),     // the drone
        Event(0.60, 0xB0, 1, 40),       // mod wheel up…
        Event(0.80, 0xB0, 1, 90),
        Event(1.00, 0xB0, 1, 127),
        Event(1.20, 0x90, 67, 90),      // legato: the pitch slides up
        Event(1.40, 0xB0, 1, 0),        // …and back down
        Event(1.60, 0x80, 67, 0),       // falls back to the held note
        Event(1.90, 0xE0, 0, 0x60),     // pitch bend half way up
        Event(2.30, 0xE0, 0, 0x40),     // and centred
        Event(2.40, 0x80, 62, 0),       // release
        Event(2.80, 0x90, 60, 127),     // the hardest hit from silence
        Event(3.20, 0xD0, 100, 0),      // aftertouch adds the voice
        Event(3.40, 0x90, 65, 127),     // the hardest hit while a note sounds
        Event(3.50, 0xD0, 0, 0),
        Event(3.70, 0xB0, 64, 127),     // sustain pedal down
        Event(3.80, 0x80, 60, 0),
        Event(3.80, 0x80, 65, 0),       // both keys up: the pedal holds the note
        Event(4.40, 0xB0, 64, 0),       // pedal up: release
    ]
    private static let duration = 5.2
    private static let blockSize = 128

    private struct Reference {
        let program: Int
        let sampleRate: Double
        /// FNV-1a over the bits of every sample.
        let fingerprint: UInt64
        /// RMS of each second (the last one is shorter).
        let levels: [Double]

        /// This reference as a line of `references`.
        var sourceLine: String {
            let levelList = levels.map { "\(($0 * 1_000_000).rounded() / 1_000_000)" }.joined(separator: ", ")
            return "Reference(program: \(program), sampleRate: \(Int(sampleRate)), "
                + "fingerprint: 0x\(String(fingerprint, radix: 16, uppercase: true)), levels: [\(levelList)]),"
        }
    }

    /// Taken on 2026-11-14 from the engine of phase 15, the model that replaced
    /// the MPC plugin's synthesis. Nothing earlier holds: that phase changed
    /// the sound of every program on purpose. A debug build and a release build
    /// rendered the same samples.
    private static let references: [Reference] = [
        Reference(program: 0, sampleRate: 44100, fingerprint: 0xB964C7D3ACC32E7B, levels: [0.111611, 0.104153, 0.070947, 0.136649, 0.082049, 0.0]),
        Reference(program: 1, sampleRate: 44100, fingerprint: 0x6BD8379E31669826, levels: [0.127426, 0.11558, 0.06304, 0.147373, 0.096606, 0.0]),
        Reference(program: 2, sampleRate: 44100, fingerprint: 0xA5D6AB9471CD952C, levels: [0.101876, 0.09528, 0.069558, 0.123466, 0.084419, 0.0]),
        Reference(program: 3, sampleRate: 44100, fingerprint: 0xA992DA25AB7A0C1, levels: [0.102046, 0.095401, 0.084225, 0.125346, 0.07906, 0.0]),
        Reference(program: 4, sampleRate: 44100, fingerprint: 0x1F19B50E43A10B31, levels: [0.071833, 0.066558, 0.040663, 0.09013, 0.060671, 0.0]),
        Reference(program: 5, sampleRate: 44100, fingerprint: 0x6CA0036327A3C65C, levels: [0.051981, 0.050515, 0.042585, 0.061219, 0.042063, 0.0]),
        Reference(program: 6, sampleRate: 44100, fingerprint: 0xBB32299AFD98D174, levels: [0.110982, 0.101528, 0.076993, 0.146425, 0.08578, 0.0]),
        Reference(program: 7, sampleRate: 44100, fingerprint: 0xC84F71D64789195C, levels: [0.064427, 0.06357, 0.040572, 0.082796, 0.054477, 0.0]),
        Reference(program: 8, sampleRate: 44100, fingerprint: 0xE09ECA4CA6E1203B, levels: [0.130178, 0.120098, 0.099518, 0.154848, 0.09948, 0.0]),
        Reference(program: 9, sampleRate: 44100, fingerprint: 0xF85753FFACBBACD5, levels: [0.104708, 0.099677, 0.071786, 0.138522, 0.075844, 0.0]),
        Reference(program: 0, sampleRate: 48000, fingerprint: 0x12449559C8E590C0, levels: [0.111432, 0.104156, 0.073659, 0.136822, 0.081807, 0.0]),
        Reference(program: 1, sampleRate: 48000, fingerprint: 0x5A86826252760384, levels: [0.127464, 0.115487, 0.06452, 0.147868, 0.096446, 0.0]),
        Reference(program: 2, sampleRate: 48000, fingerprint: 0x5BFC0869299829BC, levels: [0.101401, 0.095418, 0.07077, 0.123656, 0.084333, 0.0]),
        Reference(program: 3, sampleRate: 48000, fingerprint: 0x164A447E791CB42B, levels: [0.101197, 0.095714, 0.085523, 0.124391, 0.078281, 0.0]),
        Reference(program: 4, sampleRate: 48000, fingerprint: 0xF04BBF6D0AE93460, levels: [0.071493, 0.066205, 0.041297, 0.090827, 0.060061, 0.0]),
        Reference(program: 5, sampleRate: 48000, fingerprint: 0x89D3E257CDA03A9B, levels: [0.051997, 0.051105, 0.043826, 0.061091, 0.041838, 0.0]),
        Reference(program: 6, sampleRate: 48000, fingerprint: 0x85717DE4FB2D3D74, levels: [0.110713, 0.101176, 0.081087, 0.146936, 0.085749, 0.0]),
        Reference(program: 7, sampleRate: 48000, fingerprint: 0xFA16B13393DD2382, levels: [0.064299, 0.062771, 0.040125, 0.08453, 0.054588, 0.0]),
        Reference(program: 8, sampleRate: 48000, fingerprint: 0xBBE84E18185BA187, levels: [0.130256, 0.120014, 0.100985, 0.154435, 0.099334, 0.0]),
        Reference(program: 9, sampleRate: 48000, fingerprint: 0xFEF619EA6F18E821, levels: [0.104878, 0.099264, 0.073909, 0.139451, 0.076204, 0.0]),
    ]

    private static func render(program: Int, sampleRate: Double) -> [Float] {
        let synth = Synth(sampleRate: sampleRate)
        synth.loadProgram(program)
        let blocks = Int(duration * sampleRate) / blockSize
        var samples: [Float] = []
        samples.reserveCapacity(blocks * blockSize)
        var left = [Float](repeating: 0, count: blockSize)
        var right = [Float](repeating: 0, count: blockSize)
        var next = 0
        for block in 0..<blocks {
            let time = Double(block * blockSize) / sampleRate
            while next < phrase.count, phrase[next].time <= time {
                synth.postMIDI(status: phrase[next].status, data1: phrase[next].data1, data2: phrase[next].data2)
                next += 1
            }
            left.withUnsafeMutableBufferPointer { l in
                right.withUnsafeMutableBufferPointer { r in
                    synth.render(left: l.baseAddress!, right: r.baseAddress!, frames: blockSize)
                }
            }
            #expect(left == right)              // the instrument is mono
            samples.append(contentsOf: left)
        }
        return samples
    }

    private static func fingerprint(of samples: [Float]) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for sample in samples {
            var bits = sample.bitPattern
            for _ in 0..<4 {
                hash = (hash ^ UInt64(bits & 0xFF)) &* 0x0000_0100_0000_01B3
                bits >>= 8
            }
        }
        return hash
    }

    private static func levels(of samples: [Float], sampleRate: Double) -> [Double] {
        let second = Int(sampleRate)
        return stride(from: 0, to: samples.count, by: second).map { start in
            let window = samples[start..<min(start + second, samples.count)]
            let energy = window.reduce(0.0) { $0 + Double($1) * Double($1) }
            return (energy / Double(window.count)).squareRoot()
        }
    }

    @Test("Every program sounds as it did when its reference was taken",
          arguments: Programs.names.indices, [44100.0, 48000.0])
    func unchanged(program: Int, sampleRate: Double) throws {
        let samples = Self.render(program: program, sampleRate: sampleRate)
        let actual = Reference(program: program, sampleRate: sampleRate,
                               fingerprint: Self.fingerprint(of: samples),
                               levels: Self.levels(of: samples, sampleRate: sampleRate))
        let expected = try #require(Self.references.first { $0.program == program && $0.sampleRate == sampleRate },
                                    "no reference yet; add: \(actual.sourceLine)")

        try #require(actual.levels.count == expected.levels.count)
        for (second, (level, reference)) in zip(actual.levels, expected.levels).enumerated() {
            #expect(abs(level - reference) <= max(reference * 0.001, 0.000_001),
                    "\(Programs.names[program]) at \(Int(sampleRate)) Hz: the level of second \(second) changed from \(reference) to \(level)")
        }
        #expect(actual.fingerprint == expected.fingerprint,
                "\(Programs.names[program]) at \(Int(sampleRate)) Hz no longer renders the same samples; now: \(actual.sourceLine)")
    }
}
