# Didgeridoo — Roadmap

Phases, newest first. One phase = one folder in `phases/`, one branch, one
`--no-ff` merge.

| Phase | Goal | Status |
|---|---|---|
| 03-review-fixes | Fixes from a review of phase 02 (audio output follows the hardware, MIDI input, tempo, the Audio Unit's reset and exports, stricter build scripts), a test that guards the sound, drift independent of the sample rate — 2026-11-13 | ✅ |
| 02-engine-app-audiounit | Sound engine identical to the MPC plugin, standalone app (MIDI in, audio out, settings), Audio Unit instrument installed from the app — 2026-11-13 | ✅ |
| 01-skeleton | Empty app skeleton: SwiftPM, build/run scripts, signing + notarization pipeline, website — created 2026-11-13 | ✅ |

## Ideas for later phases (not planned yet)

- **Own window for the Audio Unit**: the app's knob panel inside the host
  instead of the host's generic parameter view.
- **Modulation**: LFOs (and perhaps an envelope) assignable to individual
  parameters.
- **Stereo**: the instrument is mono; a room, width or a doubled voice.
- **User presets**: save, name and recall your own sounds in the app.
- **Computer keyboard** as a MIDI keyboard in the app; an output level meter.
- **Intel build**: `build.sh` builds for the Mac it runs on only, so the
  website says "Apple silicon".
- **Value texts in hosts**: the Audio Unit reports plain numbers, so a host
  shows Toot Vel 128 where the app says "Off".
- **Keyboard and VoiceOver**: ⌘, for Settings; knobs that VoiceOver can turn.
