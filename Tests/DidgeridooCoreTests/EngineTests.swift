import Foundation
import Testing
import DidgeridooDSP
@testable import DidgeridooCore

/// What the sound engine promises beyond its samples: how it behaves across
/// threads and sample rates.
@Suite("Engine")
struct EngineTests {

    /// Renders `frames` samples of one engine and returns the peak level.
    private func peak(of engine: OpaquePointer, frames: Int) -> Float {
        var left = [Float](repeating: 0, count: frames)
        left.withUnsafeMutableBufferPointer { didge_process(engine, $0.baseAddress, nil, Int32(frames)) }
        return left.map(abs).max() ?? 0
    }

    @Test("A requested reset silences the voice at the start of the next block")
    func requestedReset() {
        let engine = didge_create()!
        defer { didge_destroy(engine) }
        didge_post_midi(engine, 0x90, 62, 100, 0)
        #expect(peak(of: engine, frames: 22050) > 0.05)

        didge_request_reset(engine)             // what a host's AudioUnitReset does, from any thread
        #expect(peak(of: engine, frames: 128) == 0)
        #expect(peak(of: engine, frames: 8820) == 0)    // the held note is forgotten too
    }

    @Test("The MIDI queue keeps working after it was full and after it wraps around")
    func queueFullAndWrap() {
        let engine = didge_create()!
        defer { didge_destroy(engine) }

        // More than the queue holds, with nobody reading: the surplus is dropped, nothing breaks.
        for _ in 0..<2000 { didge_post_midi(engine, 0x90, 62, 100, 0) }
        #expect(peak(of: engine, frames: 22050) > 0.05)
        didge_post_midi(engine, 0x80, 62, 0, 0)
        _ = peak(of: engine, frames: 44100)
        #expect(peak(of: engine, frames: 4410) == 0)

        // Many times round the queue: every note still starts and ends.
        for _ in 0..<3000 {
            didge_post_midi(engine, 0x90, 64, 100, 0)
            _ = peak(of: engine, frames: 16)
            didge_post_midi(engine, 0x80, 64, 0, 0)
            _ = peak(of: engine, frames: 16)
        }
        _ = peak(of: engine, frames: 44100)
        #expect(peak(of: engine, frames: 4410) == 0)
        didge_post_midi(engine, 0x90, 64, 100, 0)
        #expect(peak(of: engine, frames: 22050) > 0.05)
    }

    /// An engine handed to other threads, which only post MIDI to it.
    private struct Posting: @unchecked Sendable {
        let engine: OpaquePointer
    }

    @Test("MIDI posted from several threads while audio renders arrives in each thread's order")
    func concurrentPosting() {
        for round in 0..<50 {
            let engine = didge_create()!
            defer { didge_destroy(engine) }
            let posting = Posting(engine: engine)

            // Each thread plays its own note 30 times: 240 events, fewer than one block takes.
            let producers = DispatchGroup()
            for thread in 0..<4 {
                DispatchQueue.global().async(group: producers) {
                    for _ in 0..<30 {
                        didge_post_midi(posting.engine, 0x90, Int32(60 + thread), 100, 0)
                        didge_post_midi(posting.engine, 0x80, Int32(60 + thread), 0, 0)
                    }
                }
            }
            // The audio thread's part, while the others post.
            var finished = false
            while !finished {
                finished = producers.wait(timeout: .now()) == .success
                _ = peak(of: engine, frames: 32)
            }
            _ = peak(of: engine, frames: 22050)             // let every release finish
            #expect(peak(of: engine, frames: 2205) == 0,
                    "round \(round): a note hangs, so a note-off was lost or overtook its note-on")
        }
    }

    /// A synth set to a plain, steady tone, whose pitch can be read from its
    /// zero crossings.
    private func plainSynth(sampleRate: Double = 44100, drift: Float = 0, octave: Float = 0) throws -> Synth {
        let synth = Synth(sampleRate: sampleRate)
        let plain: [String: Float] = ["drift": drift, "octave": octave, "tube": 0, "tongue": 0, "breath": 0, "voice": 0,
                                      "wobbledepth": 0, "drive": 0, "buzz": 0, "tone": 300, "attack": 5, "tootvel": 128]
        for (identifier, value) in plain {
            synth.setValue(value, of: try #require(Parameters.named(identifier)))
        }
        return synth
    }

    /// Renders `seconds` of a synth and returns its frequency in Hz for every
    /// 50 ms, measured between the rising zero crossings.
    private func frequencies(of synth: Synth, sampleRate: Double = 44100, seconds: Double) throws -> [Double] {
        var samples: [Float] = []
        var block = [Float](repeating: 0, count: 128)
        while Double(samples.count) < seconds * sampleRate {
            block.withUnsafeMutableBufferPointer { synth.render(left: $0.baseAddress!, right: nil, frames: 128) }
            samples.append(contentsOf: block)
        }

        var crossings: [Double] = []            // in seconds, between samples
        for index in 1..<samples.count where samples[index - 1] < 0 && samples[index] >= 0 {
            let fraction = Double(-samples[index - 1]) / Double(samples[index] - samples[index - 1])
            crossings.append((Double(index - 1) + fraction) / sampleRate)
        }

        let window = 0.05
        var track: [Double] = []
        for step in 0..<Int(seconds / window) {
            let start = Double(step) * window
            let inside = crossings.filter { $0 >= start && $0 < start + window }
            try #require(inside.count > 2)
            track.append(Double(inside.count - 1) / (inside[inside.count - 1] - inside[0]))
        }
        return track
    }

    @Test("At Octave 0 a key sounds two octaves below its MIDI note, and each step moves it by one octave",
          arguments: zip([81, 57, 69, 93, 105], [0, 2, 1, -1, -2]))
    func octave(note: Int, octave: Int) throws {
        let synth = try plainSynth(octave: Float(octave))
        synth.noteOn(note)
        let frequency = try #require(frequencies(of: synth, seconds: 0.5).last)
        #expect(abs(frequency - 220) < 0.5, "note \(note) at octave \(octave) sounds at \(frequency) Hz, not at the 220 Hz of A2")
    }

    @Test("Turning Octave while a note sounds slides it to the new octave")
    func octaveWhileSounding() throws {
        let synth = try plainSynth()
        synth.setValue(100, of: try #require(Parameters.named("glide")))
        synth.noteOn(81)
        let before = try #require(frequencies(of: synth, seconds: 0.5).last)
        #expect(abs(before - 220) < 0.5)

        synth.setValue(1, of: try #require(Parameters.named("octave")))
        let track = try frequencies(of: synth, seconds: 1)
        #expect(track[0] > 225 && track[0] < 420, "the first 50 ms are on the way: \(track[0]) Hz")
        #expect(abs(try #require(track.last) - 440) < 1)
    }

    /// The pitch of a steady A2 with full drift, in cents above 220 Hz, for
    /// every 50 ms after the attack.
    private func driftTrack(sampleRate: Double, seconds: Double) throws -> [Double] {
        let synth = try plainSynth(sampleRate: sampleRate, drift: 100)
        synth.noteOn(81)                        // A2 at Octave 0
        return try frequencies(of: synth, sampleRate: sampleRate, seconds: seconds).dropFirst(4).map { 1200 * log2($0 / 220) }
    }

    @Test("Pitch drift wanders at the same speed at every sample rate", arguments: [48000.0, 88200.0, 96000.0])
    func driftSpeed(sampleRate: Double) throws {
        let reference = try driftTrack(sampleRate: 44100, seconds: 3)
        let track = try driftTrack(sampleRate: sampleRate, seconds: 3)
        #expect((reference.max() ?? 0) - (reference.min() ?? 0) > 10, "the drift should move the pitch audibly")
        let largest = zip(reference, track).map { abs($0 - $1) }.max() ?? .infinity
        #expect(largest < 2, "at \(Int(sampleRate)) Hz the pitch strays up to \(largest) cents from where it is at 44.1 kHz")
    }
}
