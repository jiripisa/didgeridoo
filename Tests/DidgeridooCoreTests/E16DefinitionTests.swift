import Foundation
import Testing
@testable import DidgeridooCore

/// The instrument definition for the OXI E16 on the website
/// (`docs/assets/Didgeridoo.oxiindef`, a file of the OXI App): the knobs by
/// name, each with the controller it comes with and the controller value of
/// its default place. It has to say what the engine does, so these tests
/// write it down from the engine's table and compare.
@Suite("E16 definition")
struct E16DefinitionTests {

    /// What the E16 shows where a name does not fit: four characters at most.
    private static let short: [String: String] = [
        "vowel": "Vowl", "tongue": "Tong", "wheelvowel": "WhVw", "lfo1rate": "L1Rt", "lfo1shape": "L1Sh",
        "lfo2rate": "L2Rt", "lfo2shape": "L2Sh", "volume": "Vol",
        "buzz": "Buzz", "drive": "Driv", "breath": "Brth", "drift": "Drft", "voice": "Voic",
        "voicepitch": "VcPt", "rough": "Roug", "attack": "Atk", "release": "Rel",
        "tube": "Tube", "tone": "Tone", "flare": "Flar", "glide": "Glid", "bendrange": "BnRg", "octave": "Oct",
        "rhythmdiv": "RhDv", "rhypattern": "Patt", "rhydepth": "RhDp", "rhyvowel": "RhVw", "rhydecay": "RhDc",
        "rhyaccent": "Acnt", "rhybreath": "BrIn",
    ]

    /// A name the file writes otherwise than the panel: ">" is in none of the definitions OXI ships.
    private static func name(of knob: Parameter) -> String { knob.identifier == "rhyvowel" ? "Rhy to Vowel" : knob.name }

    private static let knobs = ParameterSection.all.flatMap(\.parameters)

    /// The file as the OXI App writes one: a single line, the keys in its order, no line end.
    private static func expected() throws -> String {
        var entries: [String] = []
        func entry(_ name: String, _ short: String, value: Int, controller: Int) {
            entries.append(#"{"type":"cc","name":"\#(name)","abbr":"\#(short)","minimum":0,"maximum":127,"default_value":\#(value),"nr1":\#(controller),"nr2":0,"value_labels":[]}"#)
        }
        for knob in knobs {
            // A controller's value puts a knob at value / 127 of its travel: the default is the nearest of those places.
            let value = Int((knob.normalised(knob.defaultValue) * 127).rounded())
            entry(name(of: knob), try #require(short[knob.identifier]), value: value, controller: try #require(Controllers.standard(for: knob)))
        }
        entry("Mod Wheel", "ModW", value: 0, controller: 1)             // what the instrument answers besides its knobs
        entry("Sustain", "Sust", value: 0, controller: 64)
        return #"{"id":"jiri_pisa_didgeridoo","name":"Didgeridoo","abbr":"Didg","manufacturer":"Jiri Pisa","parameters":[\#(entries.joined(separator: ","))],"script":null}"#
    }

    private struct Definition: Decodable {
        struct Entry: Decodable {
            let type: String, name: String, abbr: String
            let minimum: Int, maximum: Int, default_value: Int, nr1: Int, nr2: Int
        }
        let name: String
        let parameters: [Entry]
    }

    private static func file() throws -> Data {
        let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try Data(contentsOf: repository.appendingPathComponent("docs/assets/Didgeridoo.oxiindef"))
    }

    @Test("The file on the website is what the engine's table says")
    func fileIsTheEngines() throws {
        let expected = try Self.expected()
        let found = String(decoding: try Self.file(), as: UTF8.self)
        if found != expected {
            print("docs/assets/Didgeridoo.oxiindef should read (one line, no line end):\n\(expected)")
        }
        #expect(found == expected)
    }

    @Test("Every knob is in it once, with the wheel and the pedal, under a short name of its own")
    func everyKnob() throws {
        let entries = try JSONDecoder().decode(Definition.self, from: try Self.file()).parameters
        #expect(entries.count == 32)
        #expect(Set(entries.map(\.name)) == Set(Self.knobs.map(Self.name(of:)) + ["Mod Wheel", "Sustain"]))
        #expect(Set(entries.map(\.abbr)).count == entries.count)
        #expect(Set(entries.map(\.nr1)).count == entries.count)
        let plain = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        for entry in entries {
            #expect((1...4).contains(entry.abbr.count) && entry.abbr.allSatisfy(plain.contains), "\(entry.abbr)")
            #expect(entry.name.allSatisfy { plain.contains($0) || $0 == " " }, "\(entry.name)")
            // The whole travel of a knob, switches included: the engine spreads it over 0 to 127.
            #expect(entry.type == "cc" && entry.minimum == 0 && entry.maximum == 127 && entry.nr2 == 0, "\(entry.name)")
        }
    }

    @Test("Sending a knob's default value on its controller puts the knob on its default place")
    func defaultsLand() throws {
        let entries = try JSONDecoder().decode(Definition.self, from: try Self.file()).parameters
        for knob in Self.knobs {
            let entry = try #require(entries.first { $0.name == Self.name(of: knob) }, "\(knob.identifier)")
            let synth = Synth()
            synth.setValue(knob.range.lowerBound, of: knob)             // away from its default (or at the bottom, which is one)
            synth.postMIDI(status: 0xB0, data1: UInt8(entry.nr1), data2: UInt8(entry.default_value))
            var block = [Float](repeating: 0, count: 64)
            block.withUnsafeMutableBufferPointer { synth.render(left: $0.baseAddress!, right: nil, frames: 64) }
            if case .continuous = knob.kind {
                // The nearest of a controller's 128 places: within half a step of the default.
                #expect(abs(synth.normalisedValue(of: knob) - knob.normalised(knob.defaultValue)) <= 0.5 / 127 + 0.0001, "\(knob.identifier)")
            } else {
                #expect(synth.value(of: knob) == knob.defaultValue, "\(knob.identifier)")
            }
        }
    }
}
