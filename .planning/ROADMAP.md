# Didgeridoo — Roadmap

Phases, newest first. One phase = one folder in `phases/`, one branch, one
`--no-ff` merge.

| Phase | Goal | Status |
|---|---|---|
| 09-player-and-tube | The instrument can behave like the real ones measured in acoustics research: the tongue takes sound away, the tube's own resonances, a toot that is a stab, a locked sung voice, rhythm patterns with accents and in-breaths; four programs use them — 2026-11-14 | ✅ |
| 08-v0.6.0-release | Version 0.6.0: the plug-in's window, Octave, the icon, the website's look — 2026-11-14 | ✅ |
| 07-audiounit-window | The Audio Unit's own window in a host: the app's panel on the unit's parameters — 2026-11-14 | ✅ |
| 06-icon-website | The icon covers its whole tile; the website wears the app's colours, with a dotted graphic behind it — 2026-11-14 | ✅ |
| 05-octave | The instrument plays two octaves lower; a new knob, Octave (−2 to +2), moves it — 2026-11-13 | ✅ |
| 04-v0.5.0-release | Version 0.5.0, the first release — 2026-11-13 | ✅ |
| 03-review-fixes | Fixes from a review of phase 02 (audio output follows the hardware, MIDI input, tempo, the Audio Unit's reset and exports, stricter build scripts), a test that guards the sound, drift independent of the sample rate — 2026-11-13 | ✅ |
| 02-engine-app-audiounit | Sound engine identical to the MPC plugin, standalone app (MIDI in, audio out, settings), Audio Unit instrument installed from the app — 2026-11-13 | ✅ |
| 01-skeleton | Empty app skeleton: SwiftPM, build/run scripts, signing + notarization pipeline, website — created 2026-11-13 | ✅ |

## Ideas for later phases (not planned yet)

- **A physical model**: lips as a valve on a waveguide bore instead of an
  oscillator through filters, so that the toot, the lips' closing and the
  tube's pull on the pitch come from one mechanism (the research report lists
  the published models).
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
