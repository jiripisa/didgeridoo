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
        Reference(program: 0, sampleRate: 44100, fingerprint: 0x2F90178C6A792B37, levels: [0.111587, 0.10413, 0.107059, 0.122597, 0.066491, 0.0]),
        Reference(program: 1, sampleRate: 44100, fingerprint: 0x4A9DC71661E9621F, levels: [0.127432, 0.115589, 0.075668, 0.124466, 0.077954, 0.0]),
        Reference(program: 2, sampleRate: 44100, fingerprint: 0x84722BCBABE3468A, levels: [0.10186, 0.095268, 0.10288, 0.113628, 0.067921, 0.0]),
        Reference(program: 3, sampleRate: 44100, fingerprint: 0x2B63EFF3ABCC69A8, levels: [0.102047, 0.095405, 0.092531, 0.108578, 0.062436, 0.0]),
        Reference(program: 4, sampleRate: 44100, fingerprint: 0xE908D8244A79EBFB, levels: [0.071825, 0.066546, 0.055456, 0.082095, 0.048876, 0.0]),
        Reference(program: 5, sampleRate: 44100, fingerprint: 0x8BFA9F31C4A064FC, levels: [0.051964, 0.0505, 0.060395, 0.061437, 0.033516, 0.0]),
        Reference(program: 6, sampleRate: 44100, fingerprint: 0x9D1186E49A9CF65, levels: [0.110967, 0.101511, 0.108926, 0.127813, 0.069461, 0.0]),
        Reference(program: 7, sampleRate: 44100, fingerprint: 0xCE6B8C6EC965A0CD, levels: [0.064424, 0.063562, 0.055068, 0.069592, 0.044065, 0.0]),
        Reference(program: 8, sampleRate: 44100, fingerprint: 0xF5EB10501D1B5559, levels: [0.129662, 0.119645, 0.159571, 0.168261, 0.07951, 0.0]),
        Reference(program: 9, sampleRate: 44100, fingerprint: 0xD7B64F941F399103, levels: [0.10463, 0.099605, 0.103444, 0.11541, 0.06155, 0.0]),
        Reference(program: 0, sampleRate: 48000, fingerprint: 0xBD126DA445A56E54, levels: [0.111406, 0.104132, 0.107551, 0.121027, 0.066701, 0.0]),
        Reference(program: 1, sampleRate: 48000, fingerprint: 0xEA1BEB3D600EE373, levels: [0.12747, 0.115496, 0.075685, 0.124578, 0.077938, 0.0]),
        Reference(program: 2, sampleRate: 48000, fingerprint: 0xE21B86CAB13A7585, levels: [0.101384, 0.095407, 0.103585, 0.113079, 0.068066, 0.0]),
        Reference(program: 3, sampleRate: 48000, fingerprint: 0x98A6D154A334C1B, levels: [0.1012, 0.095721, 0.093342, 0.106942, 0.063719, 0.0]),
        Reference(program: 4, sampleRate: 48000, fingerprint: 0xA6C79A9032CBF85A, levels: [0.071484, 0.066194, 0.055696, 0.081094, 0.048153, 0.0]),
        Reference(program: 5, sampleRate: 48000, fingerprint: 0x95C1E341227D1160, levels: [0.051982, 0.05109, 0.061674, 0.061345, 0.033044, 0.0]),
        Reference(program: 6, sampleRate: 48000, fingerprint: 0x391750537CAD93D7, levels: [0.110698, 0.101158, 0.108935, 0.124862, 0.06942, 0.0]),
        Reference(program: 7, sampleRate: 48000, fingerprint: 0xF4CCDAE9FDE8C45, levels: [0.064296, 0.062764, 0.055236, 0.069003, 0.044152, 0.0]),
        Reference(program: 8, sampleRate: 48000, fingerprint: 0x874271256C98E27D, levels: [0.129717, 0.119573, 0.159631, 0.167026, 0.079498, 0.0]),
        Reference(program: 9, sampleRate: 48000, fingerprint: 0xFBBF9DF5AAB8E45F, levels: [0.104799, 0.099195, 0.105077, 0.117276, 0.058358, 0.0]),
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
