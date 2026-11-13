# Phase 02 — Sound engine, standalone app, Audio Unit

## Goal

Bring the MPC plugin "Didgeridoo" to the Mac as a standalone app and an Audio
Unit instrument with exactly its sound, parameters and programs, on a
structure that later phases can extend.

## Acceptance criteria

- [x] The engine (`DidgeridooDSP`) renders the same samples as the MPC plugin.
- [x] All 25 parameters and 6 programs exist with the plugin's names, ranges,
      defaults and value texts.
- [x] The app plays from the on-screen keyboard and from MIDI, with a choice
      of MIDI device and channel and of audio output device and channels.
- [x] The Audio Unit passes `auval` and can be installed from the app.
- [x] `swift test`, `./build.sh debug` and `./build.sh release` succeed.

## Decisions

- **AUv2, not AUv3.** A `.component` bundle can be built and signed by
  `build.sh` without an Xcode project, and Ableton Live and Logic load it.
  AUv3 needs an app extension with a sandbox and provisioning.
- **The engine stays C++.** The code is the MPC plugin's, so the sound is the
  same by construction, and the Audio Unit can use it without a Swift runtime
  in the host's process.
- **Audio Unit parameter values are plain values** (Hz, ms, dB, %), so host
  automation lanes read naturally.
- **The plug-in ships inside the app** and is installed from Settings, so one
  DMG and one Sparkle update cover both.
