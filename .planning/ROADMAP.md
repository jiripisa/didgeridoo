# Didgeridoo — Roadmap

Phases, newest first. One phase = one folder in `phases/`, one branch, one
`--no-ff` merge.

| Phase | Goal | Status |
|---|---|---|
| 19-e16-definition | The instrument definition for the OXI E16 as a download in the manual's MIDI section, held to the engine's table by a test; `CLAUDE.md` says what the instrument is since 2.0.0 — 2026-11-15 | ✅ |
| 18-v2.0.0-release | Version 2.0.0: phases 15 to 17 released — 2026-11-15 | ✅ |
| 17-midi-learn | MIDI learn: every knob listens to a MIDI controller, comes with one (Volume 7, Tone 74, Vowel 11 …) and learns another with the MIDI button in the header and a move of a control. The same in the plug-in; the app remembers the controllers and a host saves them with the project. Released in 2.0.0 — 2026-11-15 | ✅ |
| 16-lfo | Two LFOs (rate, shape) and an amount for each on sixteen knobs, set on the knobs themselves with a button per LFO in the header; Wobble became LFO 1 on Vowel. Released in 2.0.0 — 2026-11-14 | ✅ |
| 15-one-model | One model of the instrument in place of two: lips as a valve, the tongue alone as the mouth, the tube's eight resonances, one voice. The author's ear approved the sound; the overblown note failed it three times and was removed. 28 knobs then. Released in 2.0.0 — 2026-11-14 | ✅ |
| 14-v1.0.2-release | Version 1.0.2: phase 13 released — 2026-11-14 | ✅ |
| 13-overblow-band | The keys of the app's keyboard show a band at their lower end: a click there overblows, a click anywhere else never does; the names sit above it — 2026-11-14 | ✅ |
| 12-v1.0.1-release | Version 1.0.1: phase 11 released — 2026-11-14 | ✅ |
| 11-key-name-click | A press on the name of a key of the keyboard strip plays the key; the name used to take it — 2026-11-14 | ✅ |
| 10-v1.0.0-release | Version 1.0.0: phase 09 released — 2026-11-14 | ✅ |
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

- **The overblown note**: removed in phase 15 after three builds the author
  found unnatural, the last one matched to every number measured on real
  toots (`phases/15-one-model/PLAN.md` has the measurements). Worth another
  try only with a recording he finds right, or on the waveguide model below.
- **A waveguide model**: lips as a reed on a waveguide bore, so that the
  pitch, the toot and the tube's pull on the lips come out of one mechanism
  instead of being set (phase 15 took the flow through the lips, the junction
  with the mouth and the tube's resonances from the physics, and kept the
  pitch as an input; the research report lists the published models).
- **More modulation**: LFOs locked to the tempo, an LFO on the pitch, an
  envelope as a third source, a mark on a knob that shows where an LFO is
  (phase 16 built the two free-running LFOs).
- **More of MIDI**: controllers for the LFOs' amounts, a soft takeover
  (a knob waits until its control passes it), the knobs' places sent back to
  a controller that can show them; names for the switches' steps in the
  OXI E16 definition (phase 17 built learn and a controller for every knob,
  phase 19 put the definition on the website).
- **Stereo**: the instrument is mono; a room, width or a doubled voice.
- **User presets**: save, name and recall your own sounds in the app.
- **Computer keyboard** as a MIDI keyboard in the app; an output level meter.
- **Intel build**: `build.sh` builds for the Mac it runs on only, so the
  website says "Apple silicon".
- **Value texts in hosts**: the Audio Unit reports plain numbers, so a host
  shows Toot Vel 128 where the app says "Off".
- **Keyboard and VoiceOver**: ⌘, for Settings; knobs that VoiceOver can turn.
