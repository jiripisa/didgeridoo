import Foundation
import Testing
@testable import DidgeridooCore

/// MIDI controllers on the knobs: each knob comes with one, a control change
/// moves the knob, and a knob can be taught another.
@Suite("Controllers")
struct ControllerTests {

    private func knob(_ identifier: String) throws -> Parameter { try #require(Parameters.named(identifier)) }

    /// Lets the engine take in what was posted: MIDI is read at the start of a block.
    private func run(_ synth: Synth) {
        var block = [Float](repeating: 0, count: 64)
        block.withUnsafeMutableBufferPointer { synth.render(left: $0.baseAddress!, right: nil, frames: 64) }
    }

    private func send(_ synth: Synth, controller: Int, value: Int) {
        synth.postMIDI(status: 0xB0, data1: UInt8(controller), data2: UInt8(value))
        run(synth)
    }

    // MARK: What the knobs come with

    @Test("Every knob comes with a controller of its own, and none that MIDI reserves")
    func standardControllers() {
        let knobs = ParameterSection.all.flatMap(\.parameters)
        let controllers = knobs.compactMap { Controllers.standard(for: $0) }
        #expect(controllers.count == knobs.count)
        #expect(Set(controllers).count == controllers.count)
        #expect(controllers.allSatisfy { (0...127).contains($0) && !Controllers.isReserved($0) })
    }

    @Test("Where MIDI names a controller for the thing, the knob has it")
    func midiConventions() throws {
        let expected = ["volume": 7, "glide": 5, "vowel": 11, "drive": 2, "buzz": 70, "tongue": 71,
                        "release": 72, "attack": 73, "tone": 74, "lfo1rate": 76]
        for (identifier, controller) in expected {
            #expect(Controllers.standard(for: try knob(identifier)) == controller, "\(identifier)")
            #expect(Synth().controller(of: try knob(identifier)) == controller, "\(identifier) on a new synth")
        }
    }

    @Test("The wheel, the pedal and MIDI's own controllers are reserved; an LFO's amount has no controller")
    func reserved() throws {
        for controller in [0, 1, 6, 32, 38, 64, 96, 101, 120, 123, 127] { #expect(Controllers.isReserved(controller)) }
        for controller in [2, 5, 7, 11, 20, 74, 102, 119] { #expect(!Controllers.isReserved(controller)) }
        #expect(Controllers.standard(for: try knob("lfo1vowel")) == nil)
        #expect(Synth().controller(of: try knob("lfo1vowel")) == nil)
    }

    // MARK: Moving a knob

    @Test("A controller puts its knob where its value says: 0 the bottom, 127 the top")
    func controllerMovesItsKnob() throws {
        let synth = Synth()
        let tone = try knob("tone")
        send(synth, controller: 74, value: 127)
        #expect(abs(synth.value(of: tone) - 8000) < 1)
        send(synth, controller: 74, value: 0)
        #expect(abs(synth.value(of: tone) - 200) < 0.1)
        send(synth, controller: 74, value: 64)
        #expect(abs(synth.normalisedValue(of: tone) - 64.0 / 127) < 0.001)
        #expect(abs(synth.value(of: try knob("vowel")) - 45) < 0.01)          // nobody else moved
    }

    @Test("A switch takes the step nearest to the controller's value")
    func controllerOnASwitch() throws {
        let synth = Synth()
        let pattern = try knob("rhypattern")                                   // four patterns, controller 86
        send(synth, controller: 86, value: 127)
        #expect(pattern.text(synth.value(of: pattern)) == "A-b-b-A-b-A")
        send(synth, controller: 86, value: 0)
        #expect(pattern.text(synth.value(of: pattern)) == "Even")
        send(synth, controller: 86, value: 50)                                 // 0.39 of the way: the second of four
        #expect(pattern.text(synth.value(of: pattern)) == "A-b")
    }

    @Test("A knob with a middle stands on it at 64, the middle of a controller's travel")
    func middle() throws {
        let synth = Synth()
        let vowel = try knob("rhyvowel")                                       // -100 … 100 %, controller 88
        send(synth, controller: 88, value: 64)
        #expect(abs(synth.value(of: vowel)) < 0.0001)
        send(synth, controller: 88, value: 63)
        #expect(synth.value(of: vowel) < -0.5)
        send(synth, controller: 88, value: 65)
        #expect(synth.value(of: vowel) > 0.5)
        send(synth, controller: 88, value: 0)
        #expect(abs(synth.value(of: vowel) + 100) < 0.0001)
        send(synth, controller: 88, value: 127)
        #expect(abs(synth.value(of: vowel) - 100) < 0.0001)
    }

    @Test("The engine counts what MIDI changed, so that a window knows when to look")
    func changesAreCounted() throws {
        let synth = Synth()
        let before = synth.changes
        synth.noteOn(62)
        run(synth)
        #expect(synth.changes == before)                                       // a note changes no knob
        send(synth, controller: 74, value: 100)
        #expect(synth.changes != before)
        let moved = synth.changes
        send(synth, controller: 119, value: 100)                               // nobody listens to 119
        #expect(synth.changes == moved)
    }

    @Test("The mod wheel and the sustain pedal do what they did, and move no knob")
    func wheelAndPedal() throws {
        let synth = Synth()
        let values = Parameters.all.map(synth.value(of:))
        send(synth, controller: 1, value: 127)
        send(synth, controller: 64, value: 127)
        #expect(Parameters.all.map(synth.value(of:)) == values)
    }

    // MARK: Learn

    @Test("A knob that is learning takes the next controller that moves, and that controller's value")
    func learn() throws {
        let synth = Synth()
        let tube = try knob("tube")
        #expect(synth.learning == nil)
        synth.learn(tube)
        #expect(synth.learning == tube)
        send(synth, controller: 40, value: 127)
        #expect(synth.learning == nil)
        #expect(synth.controller(of: tube) == 40)
        #expect(abs(synth.value(of: tube) - 100) < 0.01)
        send(synth, controller: 29, value: 0)                                  // the controller it came with
        #expect(abs(synth.value(of: tube) - 100) < 0.01)                       // no longer moves it
    }

    @Test("A controller serves one knob: learnt by another, the first knob has none")
    func oneKnobPerController() throws {
        let synth = Synth()
        let tube = try knob("tube"), tone = try knob("tone")
        synth.learn(tube)
        send(synth, controller: 74, value: 10)                                 // Tone's controller
        #expect(synth.controller(of: tube) == 74)
        #expect(synth.controller(of: tone) == nil)
        let toneBefore = synth.value(of: tone)
        send(synth, controller: 74, value: 120)
        #expect(synth.value(of: tone) == toneBefore)
    }

    @Test("Learning can be called off, and a reserved controller does not end it")
    func learnIgnoresReserved() throws {
        let synth = Synth()
        let tube = try knob("tube")
        synth.learn(tube)
        send(synth, controller: 1, value: 90)                                  // the mod wheel
        send(synth, controller: 64, value: 127)                                // the pedal
        #expect(synth.learning == tube)
        #expect(synth.controller(of: tube) == 29)
        synth.learn(nil)
        #expect(synth.learning == nil)
        send(synth, controller: 40, value: 127)
        #expect(synth.controller(of: tube) == 29)
    }

    @Test("A knob's controller can be taken away, given by hand, and all put back")
    func setAndReset() throws {
        let synth = Synth()
        let tube = try knob("tube"), tone = try knob("tone")
        synth.setController(nil, of: tone)
        #expect(synth.controller(of: tone) == nil)
        synth.setController(74, of: tube)
        #expect(synth.controller(of: tube) == 74)
        synth.setController(64, of: tone)                                      // reserved: not taken
        #expect(synth.controller(of: tone) == nil)
        synth.resetControllers()
        #expect(synth.controller(of: tube) == 29)
        #expect(synth.controller(of: tone) == 74)
    }

    @Test("A program leaves the controllers alone")
    func programsKeepControllers() throws {
        let synth = Synth()
        let tube = try knob("tube")
        synth.setController(40, of: tube)
        synth.loadProgram(3)
        #expect(synth.controller(of: tube) == 40)
    }

    // MARK: Storing

    @Test("The controllers round-trip through the form they are stored in, a knob without one included")
    func mapSurvivesStorage() throws {
        let synth = Synth()
        synth.setController(40, of: try knob("tube"))
        synth.setController(nil, of: try knob("tone"))
        let stored = try JSONEncoder().encode(ControllerMap(capturing: synth))

        let other = Synth()
        try JSONDecoder().decode(ControllerMap.self, from: stored).apply(to: other)
        #expect(other.controller(of: try knob("tube")) == 40)
        #expect(other.controller(of: try knob("tone")) == nil)
        #expect(other.controller(of: try knob("volume")) == 7)
        #expect(ControllerMap(capturing: other) == ControllerMap(capturing: synth))
    }

    @Test("A knob the stored map does not know keeps the controller it came with")
    func mapFromAnEarlierVersion() throws {
        let other = Synth()
        ControllerMap(controllers: ["tube": 40]).apply(to: other)
        #expect(other.controller(of: try knob("tube")) == 40)
        #expect(other.controller(of: try knob("tone")) == 74)
    }

    // MARK: What the panel shows

    @Test("A controller reads as CC and its number; none as a dash")
    func labels() {
        #expect(Controllers.label(74) == "CC 74")
        #expect(Controllers.label(nil) == "—")
    }
}
