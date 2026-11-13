# Phase 03 — Review fixes

## Goal

Fix what a review of phase 02 found and put a test around the sound, before
the first release and before later phases build on the engine.

## Acceptance criteria

- [ ] A test fails when the engine renders different samples than it did in
      phase 02 (all six programs, at 44.1 and 48 kHz).
- [ ] Choosing "System default" moves the sound back to the default output;
      the app follows a changed default output, a changed sample rate and a
      chosen device that is unplugged or plugged back in.
- [ ] A MIDI setup change or opening Settings does not cut off a sounding note.
- [ ] The tempo stays within 20–300 BPM however it is entered.
- [ ] A channel pair applies only to the device it was chosen for.
- [ ] `Synth.noteOn` plays for every note and velocity it is given.
- [ ] The Audio Unit's Reset cannot run while the engine renders; the
      component exports only its factory function.
- [ ] Pitch drift has the same speed at every sample rate (44.1 kHz unchanged).
- [ ] The Mouth / Lips / Rhythm grouping exists once, in the engine.
- [ ] `build.sh` stops when a signature fails; `dist` stops before building
      when the CHANGELOG has no section for the version.
- [ ] The website and the README say which Macs the download runs on.
- [ ] `swift test`, `./build.sh debug`, `./build.sh release` and `auval` succeed.

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
- **The lock in `didge_post_midi` stays.** It guards the queue between posting
  threads; `didge_process` never takes it. The Audio Unit can take it on the
  render thread, where nothing else contends for it. A lock-free queue for
  several producers was not worth its risk here.
- **Intel support stays a roadmap idea.** `build.sh` still builds for the Mac
  it runs on; the website now says "Apple silicon".
- **Drift at other sample rates is a deliberate departure** from the MPC
  plugin, whose drift ran faster the higher the rate. At 44.1 kHz, where the
  two were compared, every sample stays the same.
