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

    /// Renders one block of the unit, as a host does: MIDI it was sent is played in it. `block`
    /// counts the blocks, because a unit renders a point in time only once.
    private func render(_ unit: AudioUnit, block: Int) throws {
        let frames: UInt32 = 256
        var flags = AudioUnitRenderActionFlags()
        var time = AudioTimeStamp()
        time.mFlags = .sampleTimeValid
        time.mSampleTime = Float64(block) * Float64(frames)
        let buffers = AudioBufferList.allocate(maximumBuffers: 2)       // the unit fills buffers of its own
        defer { free(buffers.unsafeMutablePointer) }
        for index in 0..<2 { buffers[index] = AudioBuffer(mNumberChannels: 1, mDataByteSize: frames * 4, mData: nil) }
        try #require(AudioUnitRender(unit, &flags, &time, 0, frames, buffers.unsafeMutablePointer) == noErr)
    }

    /// A control change as a host passes it to the instrument, and the block it is played in.
    private func send(controller: Int, value: Int, to unit: AudioUnit, block: Int) throws {
        try #require(MusicDeviceMIDIEvent(unit, 0xB0, UInt32(controller), UInt32(value), 0) == noErr)
        try render(unit, block: block)
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
        #expect(abs(model.value(of: vowel) - vowel.defaultValue) < 0.001)

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
        let voice = try #require(Parameters.named("voice"))
        model.setPosition(1, of: octave)                    // +2

        model.loadProgram(3)                                // Growler
        #expect(model.program == 3)
        #expect(try presentPreset(of: unit) == 3)
        #expect(try value(of: "voice", in: unit) == 70)
        #expect(abs(model.value(of: voice) - 70) < 0.001)
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
        let voice = try #require(Parameters.named("voice"))
        model.loadProgram(3)
        model.setPosition(0, of: voice)
        #expect(try value(of: "voice", in: unit) == 0)

        model.resetToDefault(voice)
        #expect(try value(of: "voice", in: unit) == 70)
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
    // MARK: MIDI controllers

    @Test("A controller the host passes on moves the knob, and the unit's parameter follows")
    func controllerMovesTheUnitsParameter() throws {
        let unit = try PlugIn.make()
        defer { AudioComponentInstanceDispose(unit) }
        let model = AudioUnitModel(unit: unit)
        let tone = try #require(Parameters.named("tone"))
        #expect(model.controller(of: tone) == 74)

        try send(controller: 74, value: 127, to: unit, block: 1)
        #expect(try value(of: "tone", in: unit) == 8000)                // what a host reads and saves
        model.refresh()
        #expect(model.position(of: tone) == 1)

        try send(controller: 74, value: 0, to: unit, block: 2)
        #expect(try value(of: "tone", in: unit) == 200)
    }

    @Test("A knob the host has set stays there until its controller moves")
    func hostAndControllerTakeTurns() throws {
        let unit = try PlugIn.make()
        defer { AudioComponentInstanceDispose(unit) }
        let tone = try #require(Parameters.named("tone"))
        try send(controller: 74, value: 127, to: unit, block: 1)
        try #require(AudioUnitSetParameter(unit, AudioUnitParameterID(tone.index), kAudioUnitScope_Global, 0, 1000, 0) == noErr)
        try render(unit, block: 2)
        try send(controller: 7, value: 64, to: unit, block: 3)          // another knob's controller
        #expect(try value(of: "tone", in: unit) == 1000)
    }

    @Test("The window teaches a knob a controller")
    func windowLearns() throws {
        let unit = try PlugIn.make()
        defer { AudioComponentInstanceDispose(unit) }
        let model = AudioUnitModel(unit: unit)
        let tube = try #require(Parameters.named("tube")), tone = try #require(Parameters.named("tone"))
        #expect(model.learning == nil)

        model.learn(tube)
        #expect(model.learning == tube)
        try send(controller: 74, value: 127, to: unit, block: 1)        // Tone's controller
        model.refresh()
        #expect(model.learning == nil)
        #expect(model.controller(of: tube) == 74)
        #expect(model.controller(of: tone) == nil)
        #expect(try value(of: "tube", in: unit) == 100)

        model.setController(nil, of: tube)
        #expect(model.controller(of: tube) == nil)
        model.resetControllers()
        #expect(model.controller(of: tube) == 29)
        #expect(model.controller(of: tone) == 74)
    }

    @Test("The host saves the controllers with the project")
    func controllersAreSavedWithTheProject() throws {
        let unit = try PlugIn.make()
        defer { AudioComponentInstanceDispose(unit) }
        let tube = try #require(Parameters.named("tube")), tone = try #require(Parameters.named("tone"))
        let model = AudioUnitModel(unit: unit)
        model.setController(40, of: tube)
        model.setController(nil, of: tone)

        var state: Unmanaged<CFPropertyList>?
        var size = UInt32(MemoryLayout<Unmanaged<CFPropertyList>?>.size)
        try #require(AudioUnitGetProperty(unit, kAudioUnitProperty_ClassInfo, kAudioUnitScope_Global, 0, &state, &size) == noErr)
        var saved = try #require(state)          // the unit hands its state over retained
        defer { saved.release() }

        let other = try PlugIn.make()
        defer { AudioComponentInstanceDispose(other) }
        try #require(AudioUnitSetProperty(other, kAudioUnitProperty_ClassInfo, kAudioUnitScope_Global, 0, &saved,
                                          UInt32(MemoryLayout<Unmanaged<CFPropertyList>>.size)) == noErr)
        let restored = AudioUnitModel(unit: other)
        #expect(restored.controller(of: tube) == 40)
        #expect(restored.controller(of: tone) == nil)
        #expect(restored.controller(of: try #require(Parameters.named("volume"))) == 7)
    }

    // MARK: Presets

    /// A library in a folder of its own; deleting removes for good, away from anybody's Trash.
    private func library() -> PresetLibrary {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("didgeridoo-unit-presets-\(UUID().uuidString)").appendingPathComponent("Presets")
        return PresetLibrary(folder: folder, deletesForGood: true)
    }

    private func remove(_ library: PresetLibrary) {
        try? FileManager.default.removeItem(at: library.folder.deletingLastPathComponent())
    }

    /// The name of the unit's present preset: what a host shows and saves with its project.
    private func presentPresetName(of unit: AudioUnit) throws -> String? {
        var preset = AUPreset()
        var size = UInt32(MemoryLayout<AUPreset>.size)
        try #require(AudioUnitGetProperty(unit, kAudioUnitProperty_PresentPreset, kAudioUnitScope_Global, 0, &preset, &size) == noErr)
        return preset.presetName?.takeRetainedValue() as String?
    }

    /// Turns three knobs to a sound no program has: Tone 900 Hz, the octave up, LFO 2 on Tone.
    private func makeASound(with model: AudioUnitModel) throws {
        let tone = try #require(Parameters.named("tone")), octave = try #require(Parameters.named("octave"))
        let amount = try #require(Parameters.named("lfo2tone"))
        model.loadProgram(5)
        model.setPosition(tone.normalised(900), of: tone)
        model.setPosition(octave.normalised(1), of: octave)
        model.setPosition(amount.normalised(30), of: amount)
    }

    @Test("The window saves the unit's sound as a preset, and loading it brings every parameter back")
    func windowSavesAndLoadsAPreset() throws {
        let unit = try PlugIn.make()
        defer { AudioComponentInstanceDispose(unit) }
        let library = library()
        defer { remove(library) }
        let model = AudioUnitModel(unit: unit, presets: library)
        let tone = try #require(Parameters.named("tone")), octave = try #require(Parameters.named("octave"))
        #expect(model.presets.isEmpty)
        #expect(model.preset == nil)

        try makeASound(with: model)
        try model.savePreset(as: "Mine")
        #expect(model.presets == ["Mine"])
        #expect(model.preset == "Mine")
        #expect(try presentPreset(of: unit) == -1)                      // not a factory preset any more
        #expect(try presentPresetName(of: unit) == "Mine")              // what the host shows and saves

        model.loadProgram(2)
        model.setPosition(octave.normalised(-1), of: octave)
        #expect(model.preset == nil)
        #expect(abs(try value(of: "tone", in: unit) - 900) > 1)

        try model.loadPreset("Mine")
        #expect(model.preset == "Mine")
        #expect(abs(try value(of: "tone", in: unit) - 900) < 0.5)
        #expect(try value(of: "octave", in: unit) == 1)
        #expect(abs(try value(of: "lfo2tone", in: unit) - 30) < 0.01)
        #expect(abs(model.value(of: tone) - 900) < 0.5)                 // the window's knob too
        #expect(try presentPresetName(of: unit) == "Mine")
    }

    @Test("A double click on a knob returns the value of the preset in use, and a program's after that")
    func resetReturnsThePresetsValue() throws {
        let unit = try PlugIn.make()
        defer { AudioComponentInstanceDispose(unit) }
        let library = library()
        defer { remove(library) }
        let model = AudioUnitModel(unit: unit, presets: library)
        let tone = try #require(Parameters.named("tone"))
        try makeASound(with: model)
        try model.savePreset(as: "Mine")

        model.setPosition(tone.normalised(5000), of: tone)
        model.resetToDefault(tone)
        #expect(abs(try value(of: "tone", in: unit) - 900) < 0.5)

        model.loadProgram(0)
        model.setPosition(tone.normalised(5000), of: tone)
        model.resetToDefault(tone)
        #expect(abs(try value(of: "tone", in: unit) - Programs.value(program: 0, parameter: tone)) < 0.5)
    }

    @Test("A host's project brings the preset's name back, and the window shows it while the folder has it")
    func projectBringsThePresetBack() throws {
        let unit = try PlugIn.make()
        defer { AudioComponentInstanceDispose(unit) }
        let library = library()
        defer { remove(library) }
        let model = AudioUnitModel(unit: unit, presets: library)
        try makeASound(with: model)
        try model.savePreset(as: "Mine")

        var state: Unmanaged<CFPropertyList>?
        var size = UInt32(MemoryLayout<Unmanaged<CFPropertyList>?>.size)
        try #require(AudioUnitGetProperty(unit, kAudioUnitProperty_ClassInfo, kAudioUnitScope_Global, 0, &state, &size) == noErr)
        var saved = try #require(state)
        defer { saved.release() }
        let other = try PlugIn.make()
        defer { AudioComponentInstanceDispose(other) }
        try #require(AudioUnitSetProperty(other, kAudioUnitProperty_ClassInfo, kAudioUnitScope_Global, 0, &saved,
                                          UInt32(MemoryLayout<Unmanaged<CFPropertyList>>.size)) == noErr)

        let reopened = AudioUnitModel(unit: other, presets: library)
        #expect(reopened.preset == "Mine")
        #expect(abs(try value(of: "tone", in: other) - 900) < 0.5)

        // On a Mac whose folder does not have the preset, the sound is there and no preset is in use.
        let elsewhere = self.library()
        defer { remove(elsewhere) }
        #expect(AudioUnitModel(unit: other, presets: elsewhere).preset == nil)

        try library.delete("Mine")                                      // the Finder took it away
        reopened.lookAtPresets()
        #expect(reopened.presets.isEmpty)
        #expect(reopened.preset == nil)
    }

    @Test("A preset saved in another window shows up after a look at the folder")
    func presetsOfAnotherWindow() throws {
        let unit = try PlugIn.make(), other = try PlugIn.make()
        defer { AudioComponentInstanceDispose(unit); AudioComponentInstanceDispose(other) }
        let library = library()
        defer { remove(library) }
        let mine = AudioUnitModel(unit: unit, presets: library), theirs = AudioUnitModel(unit: other, presets: library)
        try makeASound(with: theirs)
        try theirs.savePreset(as: "Shared")
        #expect(mine.presets.isEmpty)
        mine.lookAtPresets()
        #expect(mine.presets == ["Shared"])
        try mine.loadPreset("Shared")
        #expect(abs(try value(of: "tone", in: unit) - 900) < 0.5)
        #expect(try value(of: "octave", in: unit) == 1)
    }

    @Test("Deleting the preset in use leaves the sound and no preset in use; a preset that is gone is not loaded")
    func deletingAPreset() throws {
        let unit = try PlugIn.make()
        defer { AudioComponentInstanceDispose(unit) }
        let library = library()
        defer { remove(library) }
        let model = AudioUnitModel(unit: unit, presets: library)
        try makeASound(with: model)
        try model.savePreset(as: "Mine")
        try model.deletePreset("Mine")
        #expect(model.presets.isEmpty)
        #expect(model.preset == nil)
        #expect(abs(try value(of: "tone", in: unit) - 900) < 0.5)
        model.refresh()                                                 // the unit still names it; the window does not
        #expect(model.preset == nil)
        #expect(throws: PresetError.missing("Mine")) { try model.loadPreset("Mine") }
        #expect(throws: PresetError.noName) { try model.savePreset(as: " ") }
    }
}
