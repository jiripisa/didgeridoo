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
    /// the fall back to the held one, pitch bend, a release, an overblown note
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
        Event(2.80, 0x90, 60, 127),     // hard hit from silence: overblown
        Event(3.20, 0xD0, 100, 0),      // aftertouch adds the voice
        Event(3.40, 0x90, 65, 127),     // hard hit while a note sounds
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
        Reference(program: 0, sampleRate: 44100, fingerprint: 0xE628F8DF21F55265, levels: [0.111587, 0.10413, 0.09758, 0.121984, 0.065655, 0.0]),
        Reference(program: 1, sampleRate: 44100, fingerprint: 0x642D47FEBF0ABC89, levels: [0.127432, 0.115589, 0.070862, 0.122319, 0.077353, 0.0]),
        Reference(program: 2, sampleRate: 44100, fingerprint: 0xB451DD7EDDB3A38F, levels: [0.10186, 0.095268, 0.095612, 0.112371, 0.067594, 0.0]),
        Reference(program: 3, sampleRate: 44100, fingerprint: 0x528EFBE3BB44D1EC, levels: [0.102047, 0.095405, 0.090827, 0.108265, 0.063241, 0.0]),
        Reference(program: 4, sampleRate: 44100, fingerprint: 0x7C56D8A31983EA4A, levels: [0.071825, 0.066546, 0.053089, 0.087163, 0.048447, 0.0]),
        Reference(program: 5, sampleRate: 44100, fingerprint: 0xABCF20944A3B88C3, levels: [0.051964, 0.0505, 0.054254, 0.059643, 0.033155, 0.0]),
        Reference(program: 6, sampleRate: 44100, fingerprint: 0x7DEA770385EB9443, levels: [0.110967, 0.101511, 0.098919, 0.124725, 0.068795, 0.0]),
        Reference(program: 7, sampleRate: 44100, fingerprint: 0xFCFBEF8ECA17132B, levels: [0.064424, 0.063562, 0.051394, 0.068008, 0.043514, 0.0]),
        Reference(program: 8, sampleRate: 44100, fingerprint: 0x1A63C54DCAB775EC, levels: [0.129662, 0.119645, 0.136503, 0.156574, 0.079159, 0.0]),
        Reference(program: 9, sampleRate: 44100, fingerprint: 0x6E324CC6ED537F79, levels: [0.10463, 0.099605, 0.0966, 0.11342, 0.055733, 0.0]),
        Reference(program: 0, sampleRate: 48000, fingerprint: 0x60B95CB5DD79DB7C, levels: [0.111406, 0.104132, 0.102244, 0.120566, 0.06564, 0.0]),
        Reference(program: 1, sampleRate: 48000, fingerprint: 0x4AF19DC4C7EF3203, levels: [0.12747, 0.115496, 0.071786, 0.121966, 0.077125, 0.0]),
        Reference(program: 2, sampleRate: 48000, fingerprint: 0x415761B98A0D2260, levels: [0.101384, 0.095407, 0.099981, 0.110882, 0.06744, 0.0]),
        Reference(program: 3, sampleRate: 48000, fingerprint: 0xD313AD7BD0411BC, levels: [0.1012, 0.095721, 0.096352, 0.104006, 0.061081, 0.0]),
        Reference(program: 4, sampleRate: 48000, fingerprint: 0x5DD131BC850E7441, levels: [0.071484, 0.066194, 0.056463, 0.082386, 0.048243, 0.0]),
        Reference(program: 5, sampleRate: 48000, fingerprint: 0x910C6D64B14421CD, levels: [0.051982, 0.05109, 0.059456, 0.060009, 0.033391, 0.0]),
        Reference(program: 6, sampleRate: 48000, fingerprint: 0x6ED00957E92E92B2, levels: [0.110698, 0.101158, 0.101215, 0.123357, 0.068459, 0.0]),
        Reference(program: 7, sampleRate: 48000, fingerprint: 0xF5CCFB5D96DDF204, levels: [0.064296, 0.062764, 0.053009, 0.068386, 0.043409, 0.0]),
        Reference(program: 8, sampleRate: 48000, fingerprint: 0xB0F6EEDD8ED5F760, levels: [0.129717, 0.119573, 0.143624, 0.155726, 0.078797, 0.0]),
        Reference(program: 9, sampleRate: 48000, fingerprint: 0xE617248C6D3374AD, levels: [0.104799, 0.099195, 0.101415, 0.117607, 0.061444, 0.0]),
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
