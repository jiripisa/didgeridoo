import Foundation
import Testing
@testable import DidgeridooCore

/// What phase 09 added to make the instrument behave like a real didgeridoo,
/// each tested on the sound itself. The numbers come from the measurements in
/// `.planning/research/reports/Didgeridoo acoustics and playing.md`.
@Suite("Player and tube")
struct PlayerAndTubeTests {

    private static let sampleRate = 44100.0
    /// D2, the drone of key 62 at Octave 0.
    private static let drone = 440.0 * pow(2.0, Double(38 - 69) / 12.0)

    /// A synth that holds still (no drift, wobble or rhythm), with `values` set.
    private func synth(_ values: [String: Float] = [:]) throws -> Synth {
        let synth = Synth(sampleRate: Self.sampleRate)
        var all: [String: Float] = ["drift": 0, "wobbledepth": 0]
        all.merge(values) { _, new in new }
        for (identifier, value) in all {
            synth.setValue(value, of: try #require(Parameters.named(identifier)))
        }
        return synth
    }

    private func render(_ synth: Synth, seconds: Double) -> [Float] {
        var samples: [Float] = []
        var block = [Float](repeating: 0, count: 128)
        while Double(samples.count) < seconds * Self.sampleRate {
            block.withUnsafeMutableBufferPointer { synth.render(left: $0.baseAddress!, right: nil, frames: 128) }
            samples.append(contentsOf: block)
        }
        return samples
    }

    /// Level in dB of the partial at `hz` in `samples[from..<to]` (seconds), Hann window.
    private func level(_ samples: [Float], at hz: Double, from: Double, to: Double) -> Double {
        let start = Int(from * Self.sampleRate), count = Int((to - from) * Self.sampleRate)
        var re = 0.0, im = 0.0, norm = 0.0
        for i in 0..<count {
            let window = 0.5 - 0.5 * cos(2 * Double.pi * Double(i) / Double(count - 1))
            let phase = 2 * Double.pi * hz * Double(i) / Self.sampleRate
            re += window * Double(samples[start + i]) * cos(phase)
            im += window * Double(samples[start + i]) * sin(phase)
            norm += window
        }
        return 20 * log10(2 * (re * re + im * im).squareRoot() / norm + 1e-12)
    }

    /// Level in dB of harmonic `number` of the drone in the last second of a three-second note.
    private func harmonics(_ synth: Synth, _ numbers: [Int]) -> [Double] {
        synth.noteOn(62)
        let samples = render(synth, seconds: 3)
        return numbers.map { level(samples, at: Self.drone * Double($0), from: 2, to: 3) }
    }

    private func rms(_ samples: [Float], from: Double, to: Double) -> Double {
        let slice = samples[Int(from * Self.sampleRate)..<Int(to * Self.sampleRate)]
        return 10 * log10(slice.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(slice.count) + 1e-12)
    }

    /// Frequency in Hz of a plain tone in `samples[from..<to]` (seconds), from its rising zero crossings.
    private func frequency(_ samples: [Float], from: Double, to: Double) throws -> Double {
        var crossings: [Double] = []
        for index in max(1, Int(from * Self.sampleRate))..<Int(to * Self.sampleRate) where samples[index - 1] < 0 && samples[index] >= 0 {
            let fraction = Double(-samples[index - 1]) / Double(samples[index] - samples[index - 1])
            crossings.append((Double(index - 1) + fraction) / Self.sampleRate)
        }
        try #require(crossings.count > 2)
        return Double(crossings.count - 1) / (crossings[crossings.count - 1] - crossings[0])
    }

    /// A tone plain enough to read its pitch from zero crossings.
    private static let plain: [String: Float] = ["formant": 0, "body": 0, "breath": 0, "drive": 0, "buzz": 0, "tone": 300, "attack": 5]

    // MARK: The tongue

    /// The drone's own frequency in the third second of `samples`: the best fit of its 8th
    /// harmonic, then of its 24th. The tongue pulls the drone up, so its harmonics have to be
    /// read where they are, not where the key puts them.
    private func droneFrequency(_ samples: [Float]) -> Double {
        func bestFit(harmonic: Double, around centre: Double, span: Double, step: Double) -> Double {
            var top = -Double.infinity, found = centre
            for cents in stride(from: -span, through: span, by: step) {
                let candidate = centre * pow(2, cents / 1200)
                let fit = level(samples, at: candidate * harmonic, from: 2, to: 2.5)
                if fit > top { (top, found) = (fit, candidate) }
            }
            return found
        }
        let coarse = bestFit(harmonic: 8, around: Self.drone, span: 60, step: 1)
        return bestFit(harmonic: 24, around: coarse, span: 2, step: 0.1)
    }

    /// The band the tongue leaves between two resonances of the tract, against the harmonics
    /// that fall on those resonances, in dB.
    private func formantContrast(tongue: Float) throws -> Double {
        // Vowel 80 % puts the band at 1960 Hz and the resonances beside it at 1633 and 2287 Hz.
        let synth = try synth(["tongue": tongue, "formant": 0, "vowel": 80])
        synth.noteOn(62)
        let samples = render(synth, seconds: 3)
        let drone = droneFrequency(samples)
        /// The two harmonics next to `hz`.
        func harmonics(beside hz: Double) -> [Double] {
            [(hz / drone).rounded(.down), (hz / drone).rounded(.up)].map { level(samples, at: drone * $0, from: 2, to: 3) }
        }
        let band = harmonics(beside: 1960).max() ?? 0
        let held = [1633.0, 2287].map { harmonics(beside: $0).min() ?? 0 }
        return band - (held[0] + held[1]) / 2
    }

    @Test("A high tongue leaves a band near 2 kHz standing well above the harmonics the tract holds back")
    func tongueMakesAFormant() throws {
        #expect(try formantContrast(tongue: 100) > 12)
        #expect(abs(try formantContrast(tongue: 0)) < 4)
    }

    @Test("An open mouth shape has no such band, however high the Tongue knob")
    func openVowelHasNoFormant() throws {
        let levels = harmonics(try synth(["tongue": 100, "formant": 0, "vowel": 10]), [12, 13, 14, 16, 17, 18, 19, 20, 21])
        let spread = (levels.max() ?? 0) - (levels.min() ?? 0)
        #expect(spread < 10)            // only the source's own slope over these harmonics
    }

    @Test("A high tongue raises the drone by about a third of a semitone")
    func tongueRaisesThePitch() throws {
        var values = Self.plain
        values["vowel"] = 100
        let low = try synth(values), high = try synth(values.merging(["tongue": 100]) { _, new in new })
        low.noteOn(81)
        high.noteOn(81)
        let cents = 1200 * log2(try frequency(render(high, seconds: 1), from: 0.5, to: 1) / frequency(render(low, seconds: 1), from: 0.5, to: 1))
        #expect(cents > 28 && cents < 42)
    }

    // MARK: The tube

    @Test("The tube makes the fundamental stand out against the harmonics next to it")
    func tubeFavoursTheFundamental() throws {
        let without = harmonics(try synth(["formant": 0, "body": 0]), [1, 2, 4])
        let with = harmonics(try synth(["formant": 0, "body": 0, "tube": 100]), [1, 2, 4])
        #expect((with[0] - with[1]) - (without[0] - without[1]) > 8)
        #expect((with[0] - with[2]) - (without[0] - without[2]) > 8)
    }

    @Test("A tube that overblows a twelfth, a cylinder, favours the third harmonic; one that overblows a tenth does not")
    func cylinderFavoursOddHarmonics() throws {
        func third(_ tootPitch: Float) throws -> Double {
            let levels = harmonics(try synth(["formant": 0, "body": 0, "tube": 100, "tootpitch": tootPitch]), [2, 3, 4])
            return levels[1] - (levels[0] + levels[2]) / 2
        }
        #expect(try third(19) - third(16) > 5)
    }

    @Test("The tube follows the drone to a note played legato")
    func tubeFollowsALegatoNote() throws {
        let synth = try synth(["formant": 0, "body": 0, "tube": 100])
        synth.noteOn(62)
        _ = render(synth, seconds: 0.5)
        synth.noteOn(69)                                    // a fifth up, slid to
        let samples = render(synth, seconds: 3)
        let fifth = Self.drone * pow(2, 7.0 / 12)
        // As on a first note: without the tube the fundamental stands 6 dB above the second harmonic.
        #expect(level(samples, at: fifth, from: 2, to: 3) - level(samples, at: 2 * fifth, from: 2, to: 3) > 15)
    }

    // MARK: The toot

    @Test("With a toot length, a hard hit is a stab that falls back to the drone while the key is held")
    func tootIsAStab() throws {
        var values = Self.plain
        values["tootlen"] = 100
        let stab = try synth(values)
        stab.noteOn(81, velocity: 127)
        let toot = 220 * pow(2, 16.0 / 12)
        /// How far the toot's own partial stands above the drone's, in dB.
        func tootOverDrone(_ samples: [Float], from: Double, to: Double) -> Double {
            level(samples, at: toot, from: from, to: to) - level(samples, at: 220, from: from, to: to)
        }
        let samples = render(stab, seconds: 1)
        #expect(tootOverDrone(samples, from: 0.02, to: 0.09) > 10)
        #expect(tootOverDrone(samples, from: 0.6, to: 1) < -10)

        let held = try synth(Self.plain)                    // Toot Len 0: as long as the key
        held.noteOn(81, velocity: 127)
        #expect(tootOverDrone(render(held, seconds: 1), from: 0.6, to: 1) > 10)
    }

    // MARK: The voice

    @Test("A voice a fifth above the drone adds the tone an octave below it")
    func voiceGivesTheSubOctave() throws {
        func subOctave(voice: Float) throws -> Double {
            let synth = try synth(["formant": 0, "voice": voice, "growlpitch": 7])
            synth.noteOn(62)
            let samples = render(synth, seconds: 3)
            return level(samples, at: Self.drone * 1.5, from: 2, to: 3) - level(samples, at: Self.drone, from: 2, to: 3)
        }
        #expect(try subOctave(voice: 100) > -25)            // the 3/2 partial of the series on half the drone
        #expect(try subOctave(voice: 0) < -50)
    }

    // MARK: The rhythm

    /// Loudness of each of the first eight steps (1/8 at 120 BPM: 0.25 s each).
    private func steps(_ values: [String: Float]) throws -> [Double] {
        let synth = try synth(values.merging(["rhythmdiv": 7, "attack": 5]) { old, _ in old })
        synth.noteOn(62)
        let samples = render(synth, seconds: 2.25)
        return (1..<9).map { rms(samples, from: Double($0) * 0.25, to: Double($0) * 0.25 + 0.25) }
    }

    @Test("In the pattern A-b the accented steps are louder than the ones between them")
    func patternHasTwoKindsOfStep() throws {
        let levels = try steps(["rhypattern": 1, "rhyaccent": 100, "rhydepth": 40])
        // Steps 1…8 after the first: b A b A b A b A.
        for pair in stride(from: 0, to: 8, by: 2) {
            #expect(levels[pair + 1] - levels[pair] > 2)
        }
        let even = try steps(["rhypattern": 0, "rhyaccent": 100, "rhydepth": 40])
        #expect((even.max() ?? 0) - (even.min() ?? 0) < 0.5)
    }

    @Test("An in-breath on a soft step lets the level fall during its first fifth of a second")
    func breathDropsTheLevel() throws {
        func softStep(breath: Float) throws -> Double {
            let synth = try synth(["rhythmdiv": 10, "rhypattern": 1, "rhybreath": breath, "attack": 5])     // 1/4: steps of 0.5 s
            synth.noteOn(62)
            let samples = render(synth, seconds: 1.75)
            return rms(samples, from: 1.62, to: 1.68) - rms(samples, from: 1.15, to: 1.2)      // late in a soft step's breath against the accented step before
        }
        #expect(try softStep(breath: 100) - softStep(breath: 0) < -3)
    }

    // MARK: The table

    @Test("The new knobs rest where they change nothing")
    func newParametersRestAtZero() throws {
        for identifier in ["tongue", "tube", "tootlen", "voice", "rhypattern", "rhyaccent", "rhybreath"] {
            let parameter = try #require(Parameters.named(identifier))
            #expect(parameter.defaultValue == 0)
            #expect(parameter.index >= 26)
        }
        #expect(try #require(Parameters.named("tootlen")).label(0) == "Hold")
        #expect(try #require(Parameters.named("tootlen")).label(120) == "120 ms")
    }
}
