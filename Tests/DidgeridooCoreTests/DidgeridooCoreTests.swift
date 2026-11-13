import Testing
@testable import DidgeridooCore

@Suite("Parameters")
struct ParameterTests {

    @Test("The table has the MPC plugin's 25 parameters in its order")
    func tableMatchesThePlugin() {
        #expect(Parameters.all.count == 25)
        #expect(Parameters.all.first?.identifier == "volume")
        #expect(Parameters.all.last?.identifier == "drift")
        #expect(Parameters.all.map(\.index) == Array(0..<25))
    }

    @Test("Every parameter sits in exactly one section")
    func sectionsCoverEverything() {
        let placed = ParameterSection.all.flatMap(\.parameters).map(\.identifier)
        #expect(placed.count == 25)
        #expect(Set(placed) == Set(Parameters.all.map(\.identifier)))
    }

    @Test("Plain values survive the trip through the knob position")
    func roundTrip() throws {
        let tone = try #require(Parameters.named("tone"))
        #expect(abs(tone.plain(tone.normalised(1400)) - 1400) < 0.5)
        let glide = try #require(Parameters.named("glide"))
        #expect(abs(glide.plain(glide.normalised(60)) - 60) < 0.01)
    }

    @Test("Values read like on the MPC")
    func displayText() throws {
        let volume = try #require(Parameters.named("volume"))
        #expect(volume.label(-6) == "-6.0 dB")
        let toot = try #require(Parameters.named("tootvel"))
        #expect(toot.text(128) == "Off")
        #expect(toot.text(115) == "115")
        let division = try #require(Parameters.named("rhythmdiv"))
        #expect(division.text(division.defaultValue) == "1/8")
        guard case .choice(let names) = division.kind else {
            Issue.record("Rhythm Div should be a choice")
            return
        }
        #expect(names.count == 17)
    }

    @Test("Only signed amounts are bipolar")
    func bipolar() {
        #expect(Parameters.all.filter(\.isBipolar).map(\.identifier) == ["rhyvowel"])
    }

    @Test("The sections and the order of their knobs are the window's")
    func sectionLayout() {
        #expect(ParameterSection.all.map(\.title) == ["Mouth", "Lips", "Rhythm"])
        #expect(ParameterSection.all[0].parameters.map(\.identifier)
                == ["vowel", "formant", "reso", "tone", "wobblerate", "wobbledepth", "wheelvowel", "volume"])
        #expect(ParameterSection.all[1].parameters.map(\.identifier)
                == ["buzz", "body", "drive", "breath", "growl", "growlpitch", "drift", "glide",
                    "attack", "release", "tootvel", "tootpitch"])
        #expect(ParameterSection.all[2].parameters.map(\.identifier)
                == ["rhythmdiv", "rhydepth", "rhyvowel", "rhydecay", "bendrange"])
    }
}

@Suite("Programs")
struct ProgramTests {

    @Test("The six built-in programs are there")
    func names() {
        #expect(Programs.names == ["Classic Drone", "Deep Earth", "Vocal Wah", "Growler", "Rhythm Breath", "Gallop"])
    }

    @Test("Loading a program overwrites the parameters")
    func loading() throws {
        let synth = Synth()
        let growl = try #require(Parameters.named("growl"))
        #expect(synth.value(of: growl) == 0)
        synth.loadProgram(3)
        #expect(synth.program == 3)
        #expect(synth.value(of: growl) == 70)
        #expect(Programs.value(program: 3, parameter: growl) == 70)
    }
}

@Suite("Synth")
struct SynthTests {

    /// Renders `seconds` of audio in 128-frame blocks and returns the peak level.
    private func peak(of synth: Synth, seconds: Double) -> Float {
        var left = [Float](repeating: 0, count: 128)
        var right = [Float](repeating: 0, count: 128)
        var peak: Float = 0
        for _ in 0..<Int(seconds * 44100 / 128) {
            left.withUnsafeMutableBufferPointer { l in
                right.withUnsafeMutableBufferPointer { r in
                    synth.render(left: l.baseAddress!, right: r.baseAddress!, frames: 128)
                }
            }
            for (l, r) in zip(left, right) {
                #expect(l.isFinite)
                #expect(l == r)                 // the instrument is mono
                peak = max(peak, abs(l))
            }
        }
        return peak
    }

    @Test("Silent until a note arrives, then it sounds, then it stops")
    func noteLifecycle() {
        let synth = Synth()
        #expect(peak(of: synth, seconds: 0.2) == 0)
        synth.noteOn(38)
        let sounding = peak(of: synth, seconds: 1)
        #expect(sounding > 0.05)
        #expect(sounding < 1)
        synth.noteOff(38)
        _ = peak(of: synth, seconds: 2)         // let the release finish
        #expect(peak(of: synth, seconds: 0.2) == 0)
    }

    @Test("Every program plays without clipping")
    func programsPlay() {
        for program in Programs.names.indices {
            let synth = Synth()
            synth.loadProgram(program)
            synth.noteOn(38, velocity: 127)
            let level = peak(of: synth, seconds: 1)
            #expect(level > 0.02, "program \(program) is silent")
            #expect(level <= 1, "program \(program) clips")
        }
    }

    /// Renders `seconds` of audio in 128-frame blocks and returns the left channel.
    private func samples(of synth: Synth, seconds: Double) -> [Float] {
        var left = [Float](repeating: 0, count: 128)
        var samples: [Float] = []
        for _ in 0..<Int(seconds * 44100 / 128) {
            left.withUnsafeMutableBufferPointer { l in
                synth.render(left: l.baseAddress!, right: nil, frames: 128)
            }
            samples.append(contentsOf: left)
        }
        return samples
    }

    @Test("A velocity beyond 127 is the hardest hit, not a note-off")
    func velocityBeyondTheRange() {
        let synth = Synth()
        synth.noteOn(38, velocity: 128)
        #expect(peak(of: synth, seconds: 0.5) > 0.05)

        let hardest = Synth()
        hardest.noteOn(38, velocity: 127)
        let beyond = Synth()
        beyond.noteOn(38, velocity: 1000)
        #expect(samples(of: beyond, seconds: 0.5) == samples(of: hardest, seconds: 0.5))
    }

    @Test("A note beyond 127 is the highest note, not a wrapped one")
    func noteBeyondTheRange() {
        let highest = Synth()
        highest.noteOn(127)
        let beyond = Synth()
        beyond.noteOn(200)
        #expect(samples(of: beyond, seconds: 0.5) == samples(of: highest, seconds: 0.5))

        beyond.noteOff(200)
        _ = peak(of: beyond, seconds: 2)        // let the release finish
        #expect(peak(of: beyond, seconds: 0.2) == 0)
    }

    @Test("Letting go of everything also lifts a sustain pedal that was left down")
    func releaseAll() {
        let synth = Synth()
        synth.postMIDI(status: 0xB0, data1: 64, data2: 127)     // the pedal goes down…
        synth.noteOn(38)
        #expect(peak(of: synth, seconds: 0.5) > 0.05)
        synth.releaseAll()                                      // …and its keyboard is unplugged
        _ = peak(of: synth, seconds: 2)
        #expect(peak(of: synth, seconds: 0.2) == 0)

        synth.noteOn(40)                                        // a note from somewhere else
        #expect(peak(of: synth, seconds: 0.5) > 0.05)
        synth.noteOff(40)
        _ = peak(of: synth, seconds: 2)
        #expect(peak(of: synth, seconds: 0.2) == 0)             // it ends: the pedal is up
    }

    @Test("State round-trips through a snapshot")
    func stateRoundTrip() throws {
        let synth = Synth()
        synth.loadProgram(2)
        let vowel = try #require(Parameters.named("vowel"))
        synth.setValue(77, of: vowel)
        let state = SynthState(capturing: synth)

        let other = Synth()
        state.apply(to: other)
        #expect(other.program == 2)
        #expect(abs(other.value(of: vowel) - 77) < 0.001)
        #expect(SynthState(capturing: other) == state)
    }
}

@Suite("MIDI channel filter")
struct MIDIChannelFilterTests {

    @Test("Omni takes every channel, a channel only its own")
    func channels() {
        #expect(MIDIChannelFilter.omni.accepts(status: 0x95))
        #expect(MIDIChannelFilter.channel(6).accepts(status: 0x95))
        #expect(!MIDIChannelFilter.channel(1).accepts(status: 0x95))
    }

    @Test("System messages never pass")
    func systemMessages() {
        #expect(!MIDIChannelFilter.omni.accepts(status: 0xF8))
        #expect(!MIDIChannelFilter.omni.accepts(status: 0x40))
    }

    @Test("Stored values map to filters and back")
    func storage() {
        #expect(MIDIChannelFilter(storedValue: 0) == .omni)
        #expect(MIDIChannelFilter(storedValue: 10) == .channel(10))
        #expect(MIDIChannelFilter(storedValue: 99) == .omni)
        #expect(MIDIChannelFilter.channel(3).storedValue == 3)
    }
}

@Suite("MIDI source choice")
struct MIDISourceChoiceTests {

    @Test("Stored values map to choices and back")
    func storage() {
        #expect(MIDISourceChoice(storedValue: nil) == MIDISourceChoice.all)
        #expect(MIDISourceChoice(storedValue: "all") == MIDISourceChoice.all)
        #expect(MIDISourceChoice(storedValue: "none") == MIDISourceChoice.none)
        #expect(MIDISourceChoice(storedValue: "-1234") == MIDISourceChoice.source(-1234))
        #expect(MIDISourceChoice(storedValue: "keyboard") == MIDISourceChoice.all)
        #expect(MIDISourceChoice.source(77).storedValue == "77")
        #expect(MIDISourceChoice.none.storedValue == "none")
        #expect(MIDISourceChoice.all.storedValue == "all")
    }

    @Test("All takes every source, none takes none, a source only itself")
    func sources() {
        #expect(MIDISourceChoice.all.includes(5))
        #expect(!MIDISourceChoice.none.includes(5))
        #expect(MIDISourceChoice.source(5).includes(5))
        #expect(!MIDISourceChoice.source(5).includes(6))
    }
}

@Suite("Tempo")
struct TempoTests {

    @Test("A tempo outside 20–300 BPM is pulled to the nearest limit")
    func clamping() {
        #expect(Tempo.clamped(120) == 120)
        #expect(Tempo.clamped(87.5) == 87.5)
        #expect(Tempo.clamped(5) == 20)
        #expect(Tempo.clamped(900) == 300)
        #expect(Tempo.clamped(-40) == 20)
    }

    @Test("Something that is not a number becomes the standard tempo")
    func notANumber() {
        #expect(Tempo.clamped(.nan) == 120)
        #expect(Tempo.standard == 120)
    }
}

@Suite("Output channels")
struct OutputChannelsTests {

    @Test("A device offers its channels in pairs")
    func pairs() {
        #expect(OutputChannels.pairs(deviceChannels: 2) == [0])
        #expect(OutputChannels.pairs(deviceChannels: 4) == [0, 2])
        #expect(OutputChannels.pairs(deviceChannels: 5) == [0, 2])
        #expect(OutputChannels.pairs(deviceChannels: 1) == [])
        #expect(OutputChannels.pairs(deviceChannels: 0) == [])
    }

    @Test("The map sends left and right to the chosen pair and silence elsewhere")
    func map() {
        #expect(OutputChannels.map(firstChannel: 2, deviceChannels: 4) == [-1, -1, 0, 1])
        #expect(OutputChannels.map(firstChannel: 0, deviceChannels: 6) == [0, 1, -1, -1, -1, -1])
        #expect(OutputChannels.map(firstChannel: 2, deviceChannels: 5) == [-1, -1, 0, 1, -1])
    }

    @Test("The pair in use is the chosen one, or the first when the device lacks it")
    func pairInUse() {
        #expect(OutputChannels.pair(2, deviceChannels: 4) == 2)
        #expect(OutputChannels.pair(6, deviceChannels: 4) == 0)
        #expect(OutputChannels.pair(1, deviceChannels: 4) == 0)
        #expect(OutputChannels.pair(0, deviceChannels: 2) == 0)
    }

    @Test("A pair the device does not have falls back to the first")
    func fallback() {
        #expect(OutputChannels.map(firstChannel: 6, deviceChannels: 4) == [0, 1, -1, -1])
        #expect(OutputChannels.map(firstChannel: 1, deviceChannels: 4) == [0, 1, -1, -1])
        #expect(OutputChannels.map(firstChannel: -2, deviceChannels: 4) == [0, 1, -1, -1])
    }
}
