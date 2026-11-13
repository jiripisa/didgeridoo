import Testing
@testable import DidgeridooCore

/// Guards the sound itself. Phase 02 compared the engine sample by sample with
/// the MPC plugin; the references below were taken from that engine, so a change
/// in `DidgeridooDSP` that alters a single sample fails here.
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
    /// the fall back to the held one, pitch bend, a release, an overblown note
    /// from silence and one played legato, aftertouch and the sustain pedal.
    private static let phrase: [Event] = [
        Event(0.00, 0x90, 38, 100),     // the drone
        Event(0.60, 0xB0, 1, 40),       // mod wheel up…
        Event(0.80, 0xB0, 1, 90),
        Event(1.00, 0xB0, 1, 127),
        Event(1.20, 0x90, 43, 90),      // legato: the pitch slides up
        Event(1.40, 0xB0, 1, 0),        // …and back down
        Event(1.60, 0x80, 43, 0),       // falls back to the held note
        Event(1.90, 0xE0, 0, 0x60),     // pitch bend half way up
        Event(2.30, 0xE0, 0, 0x40),     // and centred
        Event(2.40, 0x80, 38, 0),       // release
        Event(2.80, 0x90, 36, 127),     // hard hit from silence: overblown
        Event(3.20, 0xD0, 100, 0),      // aftertouch adds growl
        Event(3.40, 0x90, 41, 127),     // hard hit while a note sounds
        Event(3.50, 0xD0, 0, 0),
        Event(3.70, 0xB0, 64, 127),     // sustain pedal down
        Event(3.80, 0x80, 36, 0),
        Event(3.80, 0x80, 41, 0),       // both keys up: the pedal holds the note
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

    /// The 44.1 kHz lines were taken on 2026-11-13 from the engine of phase 02,
    /// which was verified identical to the MPC plugin at that rate. The 48 kHz
    /// lines are from phase 03, which gave the pitch drift the same speed at
    /// every sample rate; 48 kHz was never compared with the plugin.
    private static let references: [Reference] = [
        Reference(program: 0, sampleRate: 44100, fingerprint: 0x8B745F4646867801, levels: [0.120198, 0.124292, 0.116127, 0.211169, 0.138925, 0.0]),
        Reference(program: 1, sampleRate: 44100, fingerprint: 0xFEDDD1BB3179D75B, levels: [0.116259, 0.119507, 0.102175, 0.184046, 0.125087, 0.0]),
        Reference(program: 2, sampleRate: 44100, fingerprint: 0x67D07AFA53833282, levels: [0.149203, 0.150765, 0.132479, 0.230336, 0.154741, 0.0]),
        Reference(program: 3, sampleRate: 44100, fingerprint: 0xA700D3DE067B8EC9, levels: [0.126883, 0.133553, 0.102627, 0.166546, 0.105774, 0.0]),
        Reference(program: 4, sampleRate: 44100, fingerprint: 0xBC2ADEF803228146, levels: [0.058466, 0.061773, 0.058769, 0.13848, 0.100131, 0.0]),
        Reference(program: 5, sampleRate: 44100, fingerprint: 0x8E767AACC78225AA, levels: [0.054149, 0.056498, 0.057981, 0.113571, 0.077528, 0.0]),
        Reference(program: 0, sampleRate: 48000, fingerprint: 0x6F16A93F8755FF2, levels: [0.120468, 0.124535, 0.11583, 0.211722, 0.138523, 0.0]),
        Reference(program: 1, sampleRate: 48000, fingerprint: 0x1E7413AE9E3F93C9, levels: [0.115905, 0.11943, 0.101988, 0.184145, 0.125073, 0.0]),
        Reference(program: 2, sampleRate: 48000, fingerprint: 0x9736BF000CD1E029, levels: [0.148625, 0.151501, 0.132646, 0.230297, 0.154133, 0.0]),
        Reference(program: 3, sampleRate: 48000, fingerprint: 0xE8ADB3E6B6071E83, levels: [0.127398, 0.1348, 0.102905, 0.165961, 0.106753, 0.0]),
        Reference(program: 4, sampleRate: 48000, fingerprint: 0x50A0B0765E4BFBB8, levels: [0.058908, 0.062696, 0.05883, 0.139418, 0.099974, 0.0]),
        Reference(program: 5, sampleRate: 48000, fingerprint: 0xDA8181386EB95D68, levels: [0.054461, 0.057059, 0.058069, 0.113547, 0.077785, 0.0]),
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

    @Test("Every program sounds as it did when it was compared with the MPC plugin",
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
