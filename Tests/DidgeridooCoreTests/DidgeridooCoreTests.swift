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
