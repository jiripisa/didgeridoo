import Foundation
import Testing
@testable import DidgeridooCore

/// The two LFOs and the amounts by which they move the knobs. Most tests
/// watch Volume: its knob is linear in decibels, so the level of a steady
/// note follows the LFO's shape as it is.
@Suite("LFOs")
struct LFOTests {

    private static let sampleRate = 44100.0
    /// Volume's travel is 46 dB, so an amount of 25 % swings the level by 11.5 dB either way.
    private static let swing = 11.5

    /// A steady note with Volume in the middle of its travel and nothing else moving.
    private func synth(_ values: [String: Float] = [:]) throws -> Synth {
        let synth = Synth(sampleRate: Self.sampleRate)
        var all: [String: Float] = ["drift": 0, "lfo1vowel": 0, "breath": 0, "volume": -17, "attack": 5]
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

    /// The level in dB of every 20 ms of a held note, from one second in, for `seconds`.
    /// (Key 86 sounds D4: 20 ms hold nearly six of its periods.)
    private func levels(_ values: [String: Float], seconds: Double = 2) throws -> [Double] {
        let synth = try synth(values)
        synth.noteOn(86)
        let samples = render(synth, seconds: 1 + seconds + 0.1)
        let window = Int(0.02 * Self.sampleRate)
        return (0..<Int(seconds / 0.02)).map { index in
            let start = Int(Self.sampleRate) + index * window
            let energy = samples[start..<(start + window)].reduce(0.0) { $0 + Double($1) * Double($1) }
            return 10 * log10(energy / Double(window) + 1e-12)
        }
    }

    private func range(_ values: [Double]) -> Double { (values.max() ?? 0) - (values.min() ?? 0) }

    // MARK: Moving a knob

    @Test("An LFO moves the knob it has an amount on, by that part of the knob's travel")
    func lfoMovesAKnob() throws {
        #expect(range(try levels(["lfo1rate": 2])) < 0.5)
        let moved = range(try levels(["lfo1rate": 2, "lfo1volume": 25]))
        #expect(moved > 2 * Self.swing - 4 && moved < 2 * Self.swing + 1)
    }

    @Test("The knob itself stays where it was put")
    func lfoDoesNotTurnTheKnob() throws {
        let synth = try synth(["lfo1rate": 2, "lfo1volume": 25])
        synth.noteOn(86)
        _ = render(synth, seconds: 1)
        #expect(abs(synth.value(of: try #require(Parameters.named("volume"))) + 17) < 0.01)
    }

    @Test("A negative amount turns the movement round")
    func signTurnsTheMovementRound() throws {
        let up = try levels(["lfo1rate": 2, "lfo1volume": 25]), down = try levels(["lfo1rate": 2, "lfo1volume": -25])
        #expect(range(up) > 15 && range(down) > 15)
        #expect(range(zip(up, down).map { $0 + $1 }) < 3)          // where one is up the other is down
    }

    @Test("The rate is how often the knob goes round")
    func rateIsTheRate() throws {
        let track = try levels(["lfo1rate": 5, "lfo1volume": 25])
        let middle = track.reduce(0, +) / Double(track.count)
        let rises = zip(track, track.dropFirst()).filter { $0 < middle && $1 >= middle }.count
        #expect((9...11).contains(rises))                          // five times a second, two seconds
    }

    @Test("Both LFOs add up on one knob, each at its own rate")
    func bothAddUp() throws {
        let one = range(try levels(["lfo1rate": 2, "lfo1volume": 10]))
        let both = range(try levels(["lfo1rate": 2, "lfo1volume": 10, "lfo2rate": 7, "lfo2volume": 10]))
        #expect(both > 1.6 * one)
    }

    @Test("The movement stops at the ends of the knob's travel")
    func staysWithinTravel() throws {
        let top = try levels(["volume": 6])
        let pushed = try levels(["volume": 6, "lfo1rate": 2, "lfo1volume": 100])
        #expect((pushed.max() ?? 0) < (top.max() ?? 0) + 0.5)
        #expect(range(pushed) > 20)                                // and it does go down
    }

    @Test("A new note does not start an LFO again")
    func notesDoNotRestart() throws {
        func level(amount: Float) throws -> Double {
            let synth = try synth(["lfo1rate": 1, "lfo1volume": amount])
            synth.noteOn(86)
            _ = render(synth, seconds: 1.0)
            synth.noteOff(86)
            _ = render(synth, seconds: 0.25)
            synth.noteOn(86)
            let samples = render(synth, seconds: 0.3)                // 1.25 to 1.55 s on the LFO's clock
            let slice = samples[Int(0.22 * Self.sampleRate)..<Int(0.28 * Self.sampleRate)]     // around 1.5 s: half a cycle in
            return 10 * log10(slice.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(slice.count) + 1e-12)
        }
        // Half a cycle in, a sine is at its middle. Started again by the second note it would
        // be a quarter of a cycle in, at its top.
        #expect(abs(try level(amount: 25) - level(amount: 0)) < 3)
    }

    // MARK: Shapes

    private func shape(_ name: String) throws -> Float {
        let parameter = try #require(Parameters.named("lfo1shape"))
        guard case .choice(let names) = parameter.kind else { throw Missing.choice }
        return Float(try #require(names.firstIndex(of: name)))
    }

    private enum Missing: Error { case choice }

    private func track(_ name: String, rate: Float = 2, seconds: Double = 2) throws -> [Double] {
        try levels(["lfo1rate": rate, "lfo1volume": 25, "lfo1shape": try shape(name)], seconds: seconds)
    }

    /// The part of a track that lies within 2 dB of its top or its bottom.
    private func atTheEnds(_ track: [Double]) -> Double {
        let top = track.max() ?? 0, bottom = track.min() ?? 0
        return Double(track.filter { $0 > top - 2 || $0 < bottom + 2 }.count) / Double(track.count)
    }

    /// The part of a track's steps that go up.
    private func rising(_ track: [Double]) -> Double {
        Double(zip(track, track.dropFirst()).filter { $1 > $0 + 0.05 }.count) / Double(track.count - 1)
    }

    @Test("The shapes are Sine, Triangle, Ramp Up, Ramp Down, Square, Steps and Wander")
    func shapeNames() throws {
        for identifier in ["lfo1shape", "lfo2shape"] {
            let parameter = try #require(Parameters.named(identifier))
            guard case .choice(let names) = parameter.kind else {
                Issue.record("\(identifier) should be a choice")
                continue
            }
            #expect(names == ["Sine", "Triangle", "Ramp Up", "Ramp Down", "Square", "Steps", "Wander"])
            #expect(parameter.text(parameter.defaultValue) == "Sine")
        }
    }

    // Volume is smoothed over 20 ms, so a jump of the LFO takes a few of the 20 ms stretches to
    // arrive (more on the way down, where the level has 23 dB to fall).

    @Test("A square stands at its top or its bottom; a sine and a triangle pass through")
    func squareHoldsTwoLevels() throws {
        #expect(atTheEnds(try track("Square")) > 0.7)
        #expect(atTheEnds(try track("Sine")) < 0.5)
        #expect(atTheEnds(try track("Triangle")) < 0.3)
    }

    @Test("A triangle rises as long as it falls; the ramps go one way and jump back")
    func rampsGoOneWay() throws {
        let triangle = rising(try track("Triangle"))
        #expect(triangle > 0.4 && triangle < 0.6)
        #expect(rising(try track("Ramp Up")) > 0.8)
        #expect(rising(try track("Ramp Down")) < 0.15)
    }

    @Test("Steps holds a level for a cycle and takes another, never the same row twice")
    func stepsHoldsRandomLevels() throws {
        let steps = try track("Steps", rate: 2, seconds: 4)          // eight cycles
        let still = Double(zip(steps, steps.dropFirst()).filter { abs($1 - $0) < 0.5 }.count) / Double(steps.count - 1)
        #expect(still > 0.75)
        #expect(Set(steps.map { ($0 / 1.5).rounded() }).count >= 5)
    }

    @Test("Wander moves smoothly and does not come round")
    func wanderIsSmoothAndAimless() throws {
        let wander = try track("Wander", rate: 2, seconds: 4)
        #expect(zip(wander, wander.dropFirst()).allSatisfy { abs($1 - $0) < 3 })
        #expect(range(wander) > 8)
        // Where it stands at the start of each cycle (every 25 stretches of 20 ms): no two alike.
        let turns = stride(from: 0, to: wander.count, by: 25).map { (wander[$0] / 1.5).rounded() }
        #expect(Set(turns).count >= 5)
    }

    // MARK: The lips

    @Test("An LFO that jumps does not make the lips click", arguments: ["lfo1buzz", "lfo1drive", "lfo1voice"])
    func lfoOnTheLipsDoesNotClick(identifier: String) throws {
        let target = String(identifier.dropFirst(4))
        func steepest(_ values: [String: Float]) throws -> Float {
            let synth = try synth(values.merging(["volume": 0]) { _, new in new })
            synth.noteOn(62)
            let samples = render(synth, seconds: 1.5)[Int(0.5 * Self.sampleRate)...]
            return zip(samples, samples.dropFirst()).map { abs($1 - $0) }.max() ?? 0
        }
        let moved = try steepest([target: 50, identifier: 40, "lfo1rate": 8, "lfo1shape": try shape("Square")])
        let ends = try [steepest([target: 10]), steepest([target: 90])].max() ?? 0
        #expect(moved < 1.5 * ends)
    }

    // MARK: The table

    private static let targets = ["vowel", "tongue", "volume", "buzz", "drive", "breath", "voice", "rough", "tube", "tone", "flare",
                                  "rhydepth", "rhyvowel", "rhydecay", "rhyaccent", "rhybreath"]

    @Test("There are two LFOs, and sixteen knobs each of them can move")
    func amounts() throws {
        #expect(LFOs.count == 2)
        for lfo in 0..<2 {
            for identifier in Self.targets {
                let knob = try #require(Parameters.named(identifier))
                let amount = try #require(LFOs.amount(of: knob, lfo: lfo), "no amount of LFO \(lfo + 1) on \(identifier)")
                #expect(amount.identifier == "lfo\(lfo + 1)\(identifier)")
                #expect(amount.name == "LFO \(lfo + 1)>\(knob.name)")
                #expect(amount.range == -100...100)
                #expect(amount.unit == "%")
            }
        }
        #expect(Parameters.all.filter { $0.identifier.hasPrefix("lfo") }.count == 4 + 32)
    }

    @Test("Switches, times and the LFOs' own knobs cannot be moved")
    func notTargets() throws {
        for identifier in ["voicepitch", "rhythmdiv", "rhypattern", "octave", "bendrange", "attack", "release", "glide",
                           "wheelvowel", "drift", "lfo1rate", "lfo1shape", "lfo2rate", "lfo2shape"] {
            let knob = try #require(Parameters.named(identifier))
            #expect(LFOs.amount(of: knob, lfo: 0) == nil)
            #expect(LFOs.amount(of: knob, lfo: 1) == nil)
        }
    }

    @Test("Wobble is LFO 1 on Vowel: as the instrument comes, and in the programs")
    func wobbleIsLfoOne() throws {
        #expect(Parameters.named("wobblerate") == nil)
        #expect(Parameters.named("wobbledepth") == nil)
        let rate = try #require(Parameters.named("lfo1rate")), onVowel = try #require(Parameters.named("lfo1vowel"))
        #expect(rate.range == 0.02...20)
        #expect(abs(rate.defaultValue - 0.3) < 0.001)
        #expect(onVowel.defaultValue == 8.75)                       // Wobble Depth 25 % moved the vowel by 8.75 % of its travel
        let vocalWah = try #require(Programs.names.firstIndex(of: "Vocal Wah"))
        #expect(abs(Programs.value(program: vocalWah, parameter: rate) - 1.6) < 0.001)
        #expect(Programs.value(program: vocalWah, parameter: onVowel) == 28)
        for parameter in Parameters.all where parameter.identifier.hasPrefix("lfo") && parameter.identifier != "lfo1vowel"
            && !["lfo1rate", "lfo1shape", "lfo2rate", "lfo2shape"].contains(parameter.identifier) {
            #expect(parameter.defaultValue == 0, "\(parameter.identifier) should rest at 0")
        }
    }

    // MARK: What the panel shows

    @Test("The arc of an amount runs from the knob's position that far either way, within the travel")
    func arc() {
        #expect(LFOs.arc(position: 0.5, amount: 25) == 0.25...0.75)
        #expect(LFOs.arc(position: 0.5, amount: -25) == 0.25...0.75)
        #expect(LFOs.arc(position: 0.9, amount: 25) == 0.65...1)
        #expect(LFOs.arc(position: 0.1, amount: 100) == 0...1)
        #expect(LFOs.arc(position: 0.4, amount: 0) == 0.4...0.4)
    }

    @Test("An amount reads with its sign, and a hair off nothing is nothing")
    func amountText() {
        #expect(LFOs.label(amount: 25) == "+25 %")
        #expect(LFOs.label(amount: -25) == "−25 %")
        #expect(LFOs.label(amount: 8.75) == "+9 %")
        #expect(LFOs.label(amount: 0) == "0 %")
        #expect(LFOs.snapped(amount: 0.6) == 0)
        #expect(LFOs.snapped(amount: -0.9) == 0)
        #expect(LFOs.snapped(amount: 1.4) == 1.4)
        #expect(LFOs.snapped(amount: -30) == -30)
    }
}
