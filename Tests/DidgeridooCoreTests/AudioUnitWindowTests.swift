import AudioToolbox
import Foundation
import Testing
import DidgeridooAU
import DidgeridooAUView
@testable import DidgeridooCore

/// The Audio Unit itself, registered with this process only (no component
/// bundle) under a subtype of its own, so that an installed copy stays out of it.
@MainActor
private enum PlugIn {

    static let component: AudioComponent = {
        var description = AudioComponentDescription(componentType: kAudioUnitType_MusicDevice,
                                                    componentSubType: 0x4469_6474,          // 'Didt'
                                                    componentManufacturer: 0x4A50_6973,     // 'JPis'
                                                    componentFlags: 0, componentFlagsMask: 0)
        let factory = unsafeBitCast(DidgeridooAUFactory as @convention(c) (UnsafePointer<AudioComponentDescription>?) -> UnsafeMutableRawPointer?,
                                    to: AudioComponentFactoryFunction.self)
        return AudioComponentRegister(&description, "Didgeridoo under test" as CFString, 0, factory)
    }()

    static func make() throws -> AudioUnit {
        var unit: AudioUnit?
        try #require(AudioComponentInstanceNew(component, &unit) == noErr)
        let made = try #require(unit)
        try #require(AudioUnitInitialize(made) == noErr)
        return made
    }
}

/// What a host's listener heard, in order. The listener runs on its own queue.
private final class Heard: @unchecked Sendable {
    private let lock = NSLock()
    private var events: [String] = []

    func add(_ event: String) { lock.withLock { events.append(event) } }
    var all: [String] { lock.withLock { events } }
}

/// The model behind the plug-in's window (`AudioUnitModel`), driving the real
/// Audio Unit the way the window's knobs and a host do.
@Suite("The plug-in's window")
@MainActor
struct AudioUnitWindowTests {

    /// The Audio Unit's own value of a parameter, as a host reads it.
    private func value(of identifier: String, in unit: AudioUnit) throws -> Float {
        let parameter = try #require(Parameters.named(identifier))
        var value: AudioUnitParameterValue = 0
        try #require(AudioUnitGetParameter(unit, AudioUnitParameterID(parameter.index), kAudioUnitScope_Global, 0, &value) == noErr)
        return value
    }

    private func presentPreset(of unit: AudioUnit) throws -> Int {
        var preset = AUPreset()
        var size = UInt32(MemoryLayout<AUPreset>.size)
        try #require(AudioUnitGetProperty(unit, kAudioUnitProperty_PresentPreset, kAudioUnitScope_Global, 0, &preset, &size) == noErr)
        preset.presetName?.release()
        return Int(preset.presetNumber)
    }

    @Test("Turning a knob sets the Audio Unit's parameter")
    func knobSetsParameter() throws {
        let unit = try PlugIn.make()
        defer { AudioComponentInstanceDispose(unit) }
        let model = AudioUnitModel(unit: unit)
        let tone = try #require(Parameters.named("tone"))

        model.setPosition(1, of: tone)
        #expect(try value(of: "tone", in: unit) == 8000)
        #expect(model.position(of: tone) == 1)
    }

    @Test("A parameter the host changes shows on its knob at the next refresh")
    func hostChangeShows() throws {
        let unit = try PlugIn.make()
        defer { AudioComponentInstanceDispose(unit) }
        let model = AudioUnitModel(unit: unit)
        let vowel = try #require(Parameters.named("vowel"))
        #expect(abs(model.value(of: vowel) - 30) < 0.001)

        AudioUnitSetParameter(unit, AudioUnitParameterID(vowel.index), kAudioUnitScope_Global, 0, 100, 0)
        model.refresh()
        #expect(model.position(of: vowel) == 1)
    }

    @Test("Choosing a program loads the factory preset and leaves the octave alone")
    func choosingAProgram() throws {
        let unit = try PlugIn.make()
        defer { AudioComponentInstanceDispose(unit) }
        let model = AudioUnitModel(unit: unit)
        let octave = try #require(Parameters.named("octave"))
        let growl = try #require(Parameters.named("growl"))
        model.setPosition(1, of: octave)                    // +2

        model.loadProgram(3)                                // Growler
        #expect(model.program == 3)
        #expect(try presentPreset(of: unit) == 3)
        #expect(try value(of: "growl", in: unit) == 70)
        #expect(abs(model.value(of: growl) - 70) < 0.001)
        #expect(try value(of: "octave", in: unit) == 2)
    }

    @Test("The window shows the program the host chose")
    func hostChoosesAProgram() throws {
        let unit = try PlugIn.make()
        defer { AudioComponentInstanceDispose(unit) }
        let model = AudioUnitModel(unit: unit)
        let depth = try #require(Parameters.named("rhydepth"))

        var preset = AUPreset(presetNumber: 4, presetName: Unmanaged.passUnretained("Rhythm Breath" as CFString))
        try #require(AudioUnitSetProperty(unit, kAudioUnitProperty_PresentPreset, kAudioUnitScope_Global, 0,
                                          &preset, UInt32(MemoryLayout<AUPreset>.size)) == noErr)
        model.refresh()
        #expect(model.program == 4)
        #expect(abs(model.value(of: depth) - 70) < 0.001)
    }

    @Test("A double click puts a knob back to its program's value")
    func resetToTheProgram() throws {
        let unit = try PlugIn.make()
        defer { AudioComponentInstanceDispose(unit) }
        let model = AudioUnitModel(unit: unit)
        let growl = try #require(Parameters.named("growl"))
        model.loadProgram(3)
        model.setPosition(0, of: growl)
        #expect(try value(of: "growl", in: unit) == 0)

        model.resetToDefault(growl)
        #expect(try value(of: "growl", in: unit) == 70)
    }

    /// A host's listener for one parameter. It runs on a queue of its own, so it
    /// is made outside the main actor.
    private nonisolated static func listen(to parameter: Parameter, of unit: AudioUnit, heard: Heard) throws -> AUEventListenerRef {
        var listener: AUEventListenerRef?
        try #require(AUEventListenerCreateWithDispatchQueue(&listener, 0, 0, DispatchQueue(label: "host")) { _, event, _, value in
            switch event.pointee.mEventType {
            case .beginParameterChangeGesture: heard.add("begin")
            case .endParameterChangeGesture: heard.add("end")
            case .parameterValueChange: heard.add("value \(Int(value))")
            default: break
            }
        } == noErr)
        let host = try #require(listener)
        let address = AudioUnitParameter(mAudioUnit: unit, mParameterID: AudioUnitParameterID(parameter.index),
                                         mScope: kAudioUnitScope_Global, mElement: 0)
        for type in [AudioUnitEventType.beginParameterChangeGesture, .parameterValueChange, .endParameterChangeGesture] {
            var event = AudioUnitEvent(mEventType: type, mArgument: .init(mParameter: address))
            try #require(AUEventListenerAddEventType(host, nil, &event) == noErr)
        }
        return host
    }

    @Test("A drag tells the host where it begins, what it sets and where it ends")
    func dragIsHeardByTheHost() async throws {
        let unit = try PlugIn.make()
        defer { AudioComponentInstanceDispose(unit) }
        let model = AudioUnitModel(unit: unit)
        let vowel = try #require(Parameters.named("vowel"))

        // A host listens to the parameter the way it does to record automation.
        let heard = Heard()
        let host = try Self.listen(to: vowel, of: unit, heard: heard)
        defer { AUListenerDispose(host) }

        model.beginEditing(vowel)
        model.setPosition(0.5, of: vowel)
        model.endEditing(vowel)

        for _ in 0..<200 where heard.all.count < 3 {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(heard.all == ["begin", "value 50", "end"])
    }
}
