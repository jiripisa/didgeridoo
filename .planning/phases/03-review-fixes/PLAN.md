# Phase 03 — Review fixes

## Goal

Fix what a review of phase 02 found and put a test around the sound, before
the first release and before later phases build on the engine.

## Acceptance criteria

- [x] A test fails when the engine renders different samples than it did in
      phase 02 (all six programs, at 44.1 and 48 kHz).
- [x] Choosing "System default" moves the sound back to the default output;
      the app follows a changed default output, a changed sample rate and a
      chosen device that is unplugged or plugged back in.
- [x] A MIDI setup change or opening Settings does not cut off a sounding note;
      a MIDI source that goes away leaves no note, pedal or controller hanging.
- [x] The tempo stays within 20–300 BPM however it is entered.
- [x] A channel pair applies only to the device it was chosen for.
- [x] `Synth.noteOn` plays for every note and velocity it is given.
- [x] The Audio Unit's Reset cannot run while the engine renders; the
      component exports only its factory function.
- [x] Nothing a host or the app calls on the audio thread takes a lock:
      posting MIDI is lock-free; `swift test --sanitize=thread` reports nothing.
- [x] Pitch drift has the same speed at every sample rate (44.1 kHz unchanged).
- [x] The Mouth / Lips / Rhythm grouping exists once, in the engine.
- [x] `build.sh` stops when a signature fails; `dist` stops before building
      when the CHANGELOG has no section for the version.
- [x] The website and the README say which Macs the download runs on.
- [x] `swift test`, `./build.sh debug`, `./build.sh release` and `auval` succeed.

## Decisions

- **The sound is guarded by exact fingerprints plus levels.** The project's
  claim is "bit-identical", so the test compares every sample (as a hash); the
  level of each second is stored next to it to tell a real change of the sound
  from a compiler or macOS that rounds differently. Debug and release builds
  give the same fingerprints.
- **A new `AVAudioEngine` for every start.** An engine whose output was once
  pointed at a device stays on it, so "System default" needs a fresh one.
- **Audio restarts only when the change concerns the device in use.** A
  restart resets the voice, so an unrelated device coming or going must not
  interrupt a drone.
- **Posted MIDI goes through a lock-free queue.** The first plan was to keep
  the short lock among posting threads, but the Audio Unit can post on the
  render thread, and the project's rule is that the audio thread never locks.
  The queue is Dmitry Vyukov's bounded one, written by any thread and read by
  the audio thread; tests cover a full queue, wrap-around and four threads
  posting at once, and Thread Sanitizer watched them.
- **The shared sine table is built under a guard in `didge_create`.**
  Thread Sanitizer found that two engines created at the same moment both
  built the table of `dsp/oscillator.h`. That file comes unchanged from the
  MPC Plugin SDK, so the fix sits in front of it, not in it.
- **A finding that was checked and dropped.** The second review expected the
  Tempo field to keep showing an out-of-range number when clamping leaves the
  tempo unchanged. Typing into the same field code in a hosted view showed
  the clamped number in every case, so the field stayed as it was.
- **Intel support stays a roadmap idea.** `build.sh` still builds for the Mac
  it runs on; the website now says "Apple silicon".
- **Drift at other sample rates is a deliberate departure** from the MPC
  plugin, whose drift ran faster the higher the rate. At 44.1 kHz, where the
  two were compared, every sample stays the same.
