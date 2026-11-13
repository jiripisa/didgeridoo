import DidgeridooDSP

/// One Didgeridoo voice: the sound engine with its parameters, MIDI input and
/// audio output.
///
/// Thread rules (the engine's own): `render` belongs to the audio thread;
/// parameters, programs, tempo and `postMIDI` may be used from any thread
/// while audio runs. `prepare` must not run while `render` does.
public final class Synth: @unchecked Sendable {

    private let engine: OpaquePointer

    public init(sampleRate: Double = 44100) {
        engine = didge_create()
        didge_prepare(engine, sampleRate)
        didge_reset(engine)
    }

    deinit {
        didge_destroy(engine)
    }

    /// Call before audio starts and whenever the sample rate changes.
    public func prepare(sampleRate: Double) {
        didge_prepare(engine, sampleRate)
        didge_reset(engine)
    }

    // MARK: Parameters

    /// Plain (real) value of a parameter.
    public func value(of parameter: Parameter) -> Float {
        didge_get_plain(engine, Int32(parameter.index))
    }

    public func setValue(_ plain: Float, of parameter: Parameter) {
        didge_set_plain(engine, Int32(parameter.index), plain)
    }

    /// Knob position, 0...1.
    public func normalisedValue(of parameter: Parameter) -> Float {
        didge_get_normalised(engine, Int32(parameter.index))
    }

    public func setNormalisedValue(_ normalised: Float, of parameter: Parameter) {
        didge_set_normalised(engine, Int32(parameter.index), normalised)
    }

    // MARK: Programs

    public var program: Int { Int(didge_get_program(engine)) }

    /// Loads a built-in program: every parameter is overwritten and a sounding
    /// note is cut off.
    public func loadProgram(_ index: Int) {
        didge_set_program(engine, Int32(index))
    }

    // MARK: Tempo

    /// Tempo for the rhythm pulse. `position` (in quarter notes) locks the pulse
    /// to a running song; without it the pulse free-runs at `bpm`.
    public func setTempo(bpm: Double, playing: Bool = false, position: Double? = nil) {
        didge_set_transport(engine, playing ? 1 : 0, bpm, position ?? 0, position == nil ? 0 : 1)
    }

    // MARK: MIDI

    /// A MIDI channel-voice message from any thread; it plays at the start of
    /// the next rendered block.
    public func postMIDI(status: UInt8, data1: UInt8, data2: UInt8) {
        didge_post_midi(engine, Int32(status), Int32(data1), Int32(data2), 0)
    }

    public func noteOn(_ note: Int, velocity: Int = 100) {
        postMIDI(status: 0x90, data1: UInt8(clamping: note), data2: UInt8(clamping: max(1, velocity)))
    }

    public func noteOff(_ note: Int) {
        postMIDI(status: 0x80, data1: UInt8(clamping: note), data2: 0)
    }

    public func allNotesOff() {
        postMIDI(status: 0xB0, data1: 123, data2: 0)
    }

    // MARK: Audio

    /// Renders `frames` samples. The instrument is mono: both buffers get the
    /// same signal. `right` may be nil. Audio thread only.
    public func render(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>?, frames: Int) {
        didge_process(engine, left, right, Int32(frames))
    }
}
