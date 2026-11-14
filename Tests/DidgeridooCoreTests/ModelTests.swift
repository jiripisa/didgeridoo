import Foundation
import Testing
@testable import DidgeridooCore

/// The instrument as the measurements describe it: one air stream through the
/// lips, held back by the vocal tract and shaped by the tube. Each test reads
/// the sound itself. The numbers come from
/// `.planning/research/reports/Didgeridoo acoustics and playing.md` and, for
/// the overblown note, from the recordings measured in
/// `.planning/phases/15-one-model/PLAN.md`.
@Suite("The model")
struct ModelTests {

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

    private func rms(_ samples: [Float], from: Double, to: Double) -> Double {
        let slice = samples[Int(from * Self.sampleRate)..<Int(to * Self.sampleRate)]
        return 10 * log10(slice.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(slice.count) + 1e-12)
    }

    /// The frequency near `expected` (within `span` cents) at which `harmonic` times it fits best.
    private func frequency(_ samples: [Float], near expected: Double, harmonic: Double = 1, span: Double = 60, step: Double = 1,
                           from: Double, to: Double) -> Double {
        var top = -Double.infinity, found = expected
        for cents in stride(from: -span, through: span, by: step) {
            let candidate = expected * pow(2, cents / 1200)
            let fit = level(samples, at: candidate * harmonic, from: from, to: to)
            if fit > top { (top, found) = (fit, candidate) }
        }
        return found
    }

    /// The drone's own frequency in the third second of `samples`. The tongue pulls the drone
    /// up, so its harmonics have to be read where they are, not where the key puts them.
    private func droneFrequency(_ samples: [Float]) -> Double {
        let coarse = frequency(samples, near: Self.drone, harmonic: 8, from: 2, to: 2.5)
        return frequency(samples, near: coarse, harmonic: 24, span: 2, step: 0.1, from: 2, to: 2.5)
    }

    /// Levels in dB of the drone's harmonics `numbers` in the last second of a three-second note.
    private func harmonics(_ synth: Synth, _ numbers: [Int]) -> [Double] {
        synth.noteOn(62)
        let samples = render(synth, seconds: 3)
        let drone = droneFrequency(samples)
        return numbers.map { level(samples, at: drone * Double($0), from: 2, to: 3) }
    }

    /// The lips alone: no tube, no tongue, no breath, the radiation's corner out of the way.
    private static let lipsAlone: [String: Float] = ["tube": 0, "tongue": 0, "breath": 0, "drive": 0, "tone": 8000]

    // MARK: The lips

    @Test("The lips' harmonics fall evenly, by 6 dB per octave, favouring neither odd nor even ones")
    func lipsRadiateEveryHarmonic() throws {
        let numbers = Array(3...16)
        let levels = harmonics(try synth(Self.lipsAlone.merging(["buzz": 100]) { _, new in new }), [1] + numbers)
        // Against 1/n from the third harmonic on.
        let departures = zip(numbers, levels.dropFirst()).map { number, level in level - levels[1] + 20 * log10(Double(number) / 3) }
        #expect(departures.allSatisfy { abs($0) < 6 }, "departures from 1/n: \(departures)")
        let odd = zip(numbers, departures).filter { $0.0 % 2 == 1 }.map(\.1), even = zip(numbers, departures).filter { $0.0 % 2 == 0 }.map(\.1)
        #expect(abs(odd.reduce(0, +) / Double(odd.count) - even.reduce(0, +) / Double(even.count)) < 3)
    }

    @Test("Buzz is how hard the lips close: a soft closure loses the high harmonics")
    func buzzSetsTheClosure() throws {
        func high(_ buzz: Float) throws -> Double {
            let levels = harmonics(try synth(Self.lipsAlone.merging(["buzz": buzz]) { _, new in new }), [1, 24])
            return levels[1] - levels[0]
        }
        #expect(try high(100) - high(0) > 15)
    }

    @Test("Drive belongs to the lips: it adds harmonics and leaves the tongue's cut as deep as it was")
    func driveIsTheValve() throws {
        func high(_ drive: Float) throws -> Double {
            let levels = harmonics(try synth(Self.lipsAlone.merging(["buzz": 30, "drive": drive]) { _, new in new }), [1, 9, 11, 13])
            return levels.dropFirst().reduce(0, +) / 3 - levels[0]
        }
        #expect(try high(100) - high(0) > 4)
        #expect(try formantContrast(["tongue": 100, "drive": 100]) > 12)
    }

    @Test("The breath passes the lips: its noise comes in bursts at the drone's rate")
    func breathIsChopped() throws {
        // Key 69 is A2, 110 Hz. The same note with and without breath differs by the noise alone.
        let values = Self.lipsAlone.merging(["buzz": 100, "attack": 5]) { _, new in new }
        let quiet = try synth(values), breathy = try synth(values.merging(["breath": 100]) { _, new in new })
        quiet.noteOn(69)
        breathy.noteOn(69)
        let noise = zip(render(breathy, seconds: 2), render(quiet, seconds: 2)).map { Double($0 - $1) }
        var energy = [Double](repeating: 0, count: 8)
        for index in Int(Self.sampleRate)..<noise.count {
            let cycles = Double(index) * 110 / Self.sampleRate
            energy[Int((cycles - cycles.rounded(.down)) * 8)] += noise[index] * noise[index]
        }
        #expect((energy.max() ?? 0) > 0)
        #expect(10 * log10((energy.max() ?? 0) / (energy.min() ?? 1)) > 8)
    }

    @Test("Turning a knob of the lips or the voice while a note sounds does not click",
          arguments: [("voice", Float(100)), ("buzz", 0), ("drive", 0), ("drive", 100)])
    func lipsKnobsDoNotClick(identifier: String, value: Float) throws {
        let synth = try synth(["breath": 0])
        synth.noteOn(62)
        let steady = render(synth, seconds: 1)
        /// The largest step from one sample to the next.
        func steepest(_ samples: ArraySlice<Float>) -> Float {
            zip(samples, samples.dropFirst()).map { abs($1 - $0) }.max() ?? 0
        }
        let before = steepest(steady[(steady.count / 2)...])
        synth.setValue(value, of: try #require(Parameters.named(identifier)))
        let turned = render(synth, seconds: 0.05)                       // the knob takes effect at the first block
        let settled = steepest(render(synth, seconds: 0.5)[...])
        #expect(steepest(turned[...]) < 1.5 * max(before, settled))
    }

    // MARK: The tongue

    /// The band the tongue leaves between two resonances of the tract, against the harmonics
    /// that fall on those resonances, in dB.
    private func formantContrast(_ values: [String: Float]) throws -> Double {
        // Vowel 80 % puts the band at 1960 Hz and the resonances beside it at 1633 and 2287 Hz.
        let synth = try synth(values.merging(["vowel": 80]) { old, _ in old })
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
        #expect(try formantContrast(["tongue": 100]) > 12)
        #expect(abs(try formantContrast(["tongue": 0])) < 4)
    }

    @Test("An open mouth shape has no such band, however high the Tongue knob")
    func openVowelHasNoFormant() throws {
        let levels = harmonics(try synth(["tongue": 100, "vowel": 10, "tube": 0]), [12, 13, 14, 16, 17, 18, 19, 20, 21])
        let spread = (levels.max() ?? 0) - (levels.min() ?? 0)
        #expect(spread < 10)            // only the source's own slope over these harmonics
    }

    @Test("A high tongue raises the drone by about a third of a semitone")
    func tongueRaisesThePitch() throws {
        func pitch(tongue: Float) throws -> Double {
            let synth = try synth(["vowel": 100, "tongue": tongue])
            synth.noteOn(62)
            return droneFrequency(render(synth, seconds: 3))
        }
        let cents = 1200 * log2(try pitch(tongue: 100) / pitch(tongue: 0))
        #expect(cents > 28 && cents < 42)
    }

    // MARK: The tube

    @Test("The tube makes the fundamental stand out against the harmonics next to it")
    func tubeFavoursTheFundamental() throws {
        let without = harmonics(try synth(["tongue": 0, "tube": 0]), [1, 2, 4])
        let with = harmonics(try synth(["tongue": 0, "tube": 100]), [1, 2, 4])
        #expect((with[0] - with[1]) - (without[0] - without[1]) > 8)
        #expect((with[0] - with[2]) - (without[0] - without[2]) > 8)
    }

    @Test("A cylinder, which overblows a twelfth, favours the odd harmonics; a flared tube does not")
    func cylinderFavoursOddHarmonics() throws {
        /// How far harmonics 3, 5 and 7 stand above their even neighbours, in dB.
        func odd(_ tootPitch: Float) throws -> Double {
            let levels = harmonics(try synth(["tongue": 0, "tube": 100, "tootpitch": tootPitch]), [2, 3, 4, 5, 6, 7, 8])
            return (levels[1] + levels[3] + levels[5]) / 3 - (levels[0] + levels[2] + levels[4] + levels[6]) / 4
        }
        #expect(try odd(19) - odd(15) > 5)
    }

    @Test("The tube follows the drone to a note played legato")
    func tubeFollowsALegatoNote() throws {
        func fundamentalOverSecond(tube: Float) throws -> Double {
            let synth = try synth(["tongue": 0, "tube": tube])
            synth.noteOn(62)
            _ = render(synth, seconds: 0.5)
            synth.noteOn(69)                                    // a fifth up, slid to
            let samples = render(synth, seconds: 3)
            let fifth = Self.drone * pow(2, 7.0 / 12)
            return level(samples, at: fifth, from: 2, to: 3) - level(samples, at: 2 * fifth, from: 2, to: 3)
        }
        #expect(try fundamentalOverSecond(tube: 100) - fundamentalOverSecond(tube: 0) > 8)
    }

    // MARK: The toot

    /// A drone held for a second, then a hard hit on the same key; `after` seconds from the hit on.
    private func tootAfterADrone(_ values: [String: Float], after: Double) throws -> (drone: [Float], toot: [Float]) {
        let synth = try synth(values)
        synth.noteOn(62, velocity: 100)
        let drone = render(synth, seconds: 1)
        synth.noteOn(62, velocity: 127)
        return (drone, render(synth, seconds: after))
    }

    private func tootFrequency(_ semitones: Double = 17) -> Double { Self.drone * pow(2, semitones / 12) }

    @Test("An overblown note is nearly a plain tone: its second and third harmonic lie far under its fundamental")
    func tootIsNearlyPlain() throws {
        let synth = try synth(["tootlen": 601])                 // held as long as the key
        synth.noteOn(62, velocity: 127)
        let samples = render(synth, seconds: 1.5)
        let toot = frequency(samples, near: tootFrequency(), from: 0.5, to: 1.5)
        let partials = (1...3).map { level(samples, at: toot * Double($0), from: 0.5, to: 1.5) }
        #expect(partials[1] - partials[0] < -18)
        #expect(partials[2] - partials[0] < -18)
    }

    @Test("The lips jump to the overblown note: the pitch does not slide through the ones between")
    func tootJumps() throws {
        // Two octaves up, so that 40 ms tell the pitches apart: the drone at 294 Hz, the toot at 784 Hz.
        let (_, toot) = try tootAfterADrone(["octave": 2, "tootlen": 601], after: 0.3)
        let there = Self.drone * 4 * pow(2, 17.0 / 12)
        let onTheWay = level(toot, at: 700, from: 0.012, to: 0.052) - level(toot, at: there, from: 0.012, to: 0.052)
        #expect(onTheWay < -18)
        #expect(level(toot, at: there, from: 0.03, to: 0.07) - level(toot, at: Self.drone * 4, from: 0.03, to: 0.07) > 6)
    }

    @Test("An overblown note is louder than the drone it interrupts, and the drone is gone under it")
    func tootIsLouderAndAlone() throws {
        let (drone, toot) = try tootAfterADrone(["tootlen": 601], after: 0.5)
        let louder = rms(toot, from: 0.1, to: 0.4) - rms(drone, from: 0.5, to: 1)
        #expect(louder > 3 && louder < 9)
        let there = frequency(toot, near: tootFrequency(), from: 0.1, to: 0.4)
        #expect(level(toot, at: Self.drone, from: 0.1, to: 0.4) - level(toot, at: there, from: 0.1, to: 0.4) < -20)
    }

    @Test("A hard hit is a stab: the drone of the same key is back while the key is held, unless Toot Len says Hold")
    func tootIsAStab() throws {
        /// How far the toot's own partial stands above the drone's, in dB.
        func tootOverDrone(_ samples: [Float], from: Double, to: Double) -> Double {
            level(samples, at: tootFrequency(), from: from, to: to) - level(samples, at: Self.drone, from: from, to: to)
        }
        let stab = try synth(["attack": 5])                     // Toot Len as the instrument comes
        stab.noteOn(62, velocity: 127)
        let samples = render(stab, seconds: 1.2)
        #expect(tootOverDrone(samples, from: 0.03, to: 0.1) > 10)
        #expect(tootOverDrone(samples, from: 0.7, to: 1.2) < -10)

        let held = try synth(["attack": 5, "tootlen": 601])
        held.noteOn(62, velocity: 127)
        #expect(tootOverDrone(render(held, seconds: 1.2), from: 0.7, to: 1.2) > 10)
    }

    // What follows was measured inside real toots after the author found the rebuilt ones still
    // artificial: a plain tone that stands still, with the breath's hiss on it, is what a
    // synthesizer does.

    @Test("A toot carries little breath: next to nothing of it lies above 2 kHz")
    func tootIsNotHissy() throws {
        let synth = try synth(["tootlen": 601])
        synth.noteOn(62, velocity: 127)
        let samples = render(synth, seconds: 1.5)
        let toot = frequency(samples, near: tootFrequency(), from: 0.5, to: 1.5)
        // Noise is measured in short stretches: 25 ms resolve about 40 Hz, so steps of 40 Hz
        // add up to the power of the whole band. The recordings were measured the same way.
        var above = 0.0
        let starts = stride(from: 0.5, to: 1.4, by: 0.1)
        for start in starts {
            for hz in stride(from: 2000.0, to: 8000.0, by: 40) { above += pow(10, level(samples, at: hz, from: start, to: start + 0.025) / 10) }
        }
        above /= Double(Array(starts).count)
        // Real toots: 30 to 48 dB under the fundamental in clean recordings; this one stood at -19.
        #expect(10 * log10(above) - level(samples, at: toot, from: 0.5, to: 1.5) < -30)
    }

    @Test("A toot peaks and settles: it is louder in its first tenth of a second than later")
    func tootPeaksAndSettles() throws {
        let (_, toot) = try tootAfterADrone(["tootlen": 601], after: 0.8)
        let settled = rms(toot, from: 0.5, to: 0.8)
        #expect(rms(toot, from: 0.04, to: 0.1) - settled > 2)
        #expect(rms(toot, from: 0.04, to: 0.1) - settled < 8)
    }

    @Test("The lips land a little under the toot's pitch and settle onto it")
    func tootSettlesFromBelow() throws {
        // Two octaves up, so that 40 ms measure a pitch to a few cents.
        let (_, toot) = try tootAfterADrone(["octave": 2, "tootlen": 601, "breath": 0], after: 0.8)
        let there = Self.drone * 4 * pow(2, 17.0 / 12)
        let early = frequency(toot, near: there, span: 100, from: 0.03, to: 0.07)
        let late = frequency(toot, near: there, span: 100, from: 0.5, to: 0.8)
        let cents = 1200 * log2(early / late)
        #expect(cents < -8 && cents > -70)
    }

    @Test("No two toots are quite the same")
    func tootsDiffer() throws {
        let synth = try synth(["breath": 0])
        synth.noteOn(62, velocity: 100)
        _ = render(synth, seconds: 0.5)
        var levels: [Double] = []
        for _ in 0..<4 {
            synth.noteOn(62, velocity: 127)
            levels.append(rms(render(synth, seconds: 0.5), from: 0.03, to: 0.12))
        }
        #expect((levels.max() ?? 0) - (levels.min() ?? 0) > 0.3)
        #expect((levels.max() ?? 0) - (levels.min() ?? 0) < 4)
    }

    @Test("After a stab the drone is as loud as it was before, not as loud as the hard hit")
    func droneKeepsItsLevelAfterAStab() throws {
        let synth = try synth(["breath": 0])
        synth.noteOn(62, velocity: 70)
        let before = render(synth, seconds: 1)
        synth.noteOn(62, velocity: 127)
        let after = render(synth, seconds: 1.5)
        #expect(abs(rms(after, from: 1.0, to: 1.5) - rms(before, from: 0.5, to: 1.0)) < 1)
    }

    @Test("The toot's knobs cover what tubes do: 12 to 19 semitones, a stab of 40 to 600 ms or Hold")
    func tootRanges() throws {
        let pitch = try #require(Parameters.named("tootpitch"))
        #expect(pitch.range == 12...19)
        #expect(pitch.defaultValue == 17)
        let length = try #require(Parameters.named("tootlen"))
        #expect(length.range == 40...601)
        #expect(length.label(601) == "Hold")
        #expect(length.label(120) == "120 ms")
        #expect(length.defaultValue < 200)                      // a stab as the instrument comes
    }

    // MARK: The voice

    /// The tone an octave below the drone, against the drone, in dB.
    private func subOctave(_ samples: [Float]) -> Double {
        let drone = droneFrequency(samples)
        return level(samples, at: drone / 2, from: 2, to: 3) - level(samples, at: drone, from: 2, to: 3)
    }

    private func fifth() throws -> Float {
        let pitch = try #require(Parameters.named("voicepitch"))
        guard case .choice(let names) = pitch.kind else { throw Missing.choice }
        return Float(try #require(names.firstIndex(of: "Fifth")))
    }

    private enum Missing: Error { case choice }

    @Test("A voice a fifth above the drone adds the tone an octave below it")
    func voiceGivesTheSubOctave() throws {
        func note(voice: Float) throws -> [Float] {
            let synth = try synth(["voice": voice, "voicepitch": try fifth()])
            synth.noteOn(62)
            return render(synth, seconds: 3)
        }
        #expect(subOctave(try note(voice: 100)) > -30)
        #expect(subOctave(try note(voice: 0)) < -50)
    }

    @Test("Aftertouch adds the voice")
    func aftertouchSings() throws {
        let synth = try synth(["voicepitch": try fifth()])
        synth.noteOn(62)
        synth.postMIDI(status: 0xD0, data1: 127, data2: 0)
        #expect(subOctave(render(synth, seconds: 3)) > -35)
    }

    @Test("A locked voice stands still; Rough pulls it off the lock and the tone under the drone beats")
    func roughBeats() throws {
        /// How far the level of the tone an octave below the drone wanders over two seconds, in dB.
        func wander(rough: Float) throws -> Double {
            let synth = try synth(["voice": 70, "voicepitch": try fifth(), "rough": rough, "breath": 0])
            synth.noteOn(62)
            let samples = render(synth, seconds: 3.3)
            let under = droneFrequency(samples) / 2
            let levels = stride(from: 1.0, to: 3.0, by: 0.05).map { level(samples, at: under, from: $0, to: $0 + 0.2) }
            return (levels.max() ?? 0) - (levels.min() ?? 0)
        }
        #expect(try wander(rough: 0) < 1)
        #expect(try wander(rough: 60) > 3)
    }

    @Test("The voice's intervals are the ones that lock, the tenth among them")
    func voiceIntervals() throws {
        let pitch = try #require(Parameters.named("voicepitch"))
        guard case .choice(let names) = pitch.kind else {
            Issue.record("Voice Pitch should be a choice")
            return
        }
        #expect(names == ["Unison", "Third", "Fourth", "Fifth", "Octave", "Tenth", "Twelfth"])
        #expect(pitch.text(pitch.defaultValue) == "Tenth")
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

    // MARK: The instrument as it comes

    @Test("As it comes, the instrument is the measured one: a tube, a raised tongue, a pitch that holds")
    func defaults() throws {
        func value(_ identifier: String) throws -> Float { try #require(Parameters.named(identifier)).defaultValue }
        #expect(try value("tube") >= 50)
        #expect(try value("tongue") >= 50)
        #expect(try value("drift") <= 15)
        #expect(try value("bendrange") == 1)
        #expect(try value("voice") == 0)
        #expect(try value("rhydepth") == 0)
        for gone in ["formant", "reso", "body", "growl", "growlpitch"] {
            #expect(Parameters.named(gone) == nil)
        }
    }

    @Test("The drone as it comes has the shape of a real one: a strong fundamental over weak neighbours")
    func droneHasTheMeasuredShape() throws {
        // Recordings of seven instruments: harmonics 2 to 5 lie 10 to 27 dB under the fundamental
        // (the odd ones of a cylinder less), harmonics 6 to 12 lower still.
        let levels = harmonics(try synth(), Array(1...12))
        let low = levels[1...4].map { $0 - levels[0] }, high = levels[5...11].map { $0 - levels[0] }
        #expect(low.allSatisfy { $0 < -8 && $0 > -32 }, "harmonics 2 to 5: \(low)")
        #expect(high.reduce(0, +) / Double(high.count) < low.reduce(0, +) / Double(low.count))
    }
}
