# Phase 03 — Verification (2026-11-13)

| Check | Result |
|---|---|
| `swift test`, and the same in a release build (`-c release -Xswiftc -enable-testing`) | 30 tests in 9 suites pass in both |
| `swift test --sanitize=thread` | first run: 11 reports, all on the shared sine table of `dsp/oscillator.h` being built by two engines at once (a fault of phase 02); after the guard in `didge_create`: no report. The new lock-free MIDI queue was never reported |
| Sound references (six programs at 44.1 and 48 kHz) in a debug and a release build | the same fingerprints in both; the 44.1 kHz ones did not change through this phase |
| The sound guard itself: engine made 1 % louder | the suite fails for all 12 references (then reverted) |
| New tests against the old code: note and velocity beyond 127, drift speed, a pedal left down by a source that went away | fail without the fix, pass with it |
| Pitch drift at 48 / 88.2 / 96 kHz against 44.1 kHz over 3 s | before: up to 38 / 36 / 35 cents apart; after: 0.4 / 0.03 / 0.15 |
| `AudioOutput` on this Mac's hardware, a silent harness around the real class: default → a device → default; a chosen device missing, appearing and disappearing (an aggregate device private to the harness); an unrelated device appearing and disappearing | plays on the expected device after every step, with the "not connected" text while the device is missing, and does not restart for the unrelated device. The old code stayed on the device after "System default" and said nothing about a missing one |
| `MIDIInput` against CoreMIDI, a harness with virtual sources: Settings opened, an unrelated source appearing and disappearing, the chosen source unplugged and plugged back | notes and controllers are released only when a source that was listened to goes away (the old code sent all-notes-off at every step); notes arrive again after replugging |
| The Tempo field's code in a hosted view, typed into through the field editor, committed with Return and by leaving the field | 900 → 300 (also when the tempo already was 300), 0 → 20, "abc" keeps the tempo, "87,5" → 87.5 |
| `./build.sh debug`, `./build.sh release` | succeed without compiler warnings; `codesign --verify --deep --strict` passes for both bundles |
| Exported symbols of the component (`nm -gU`) | only `_DidgeridooAUFactory` (215 before) |
| `auval -v aumu Didg JPis` | AU VALIDATION SUCCEEDED; the clumps are Mouth, Lips, Rhythm |
| The changed script pieces on their own: `sign` with an unknown identity; `make_appcast.py --check` and its section lookup on sample changelogs | a failed signature stops a `set -e` script; a version without notes is refused (as the present CHANGELOG is, with only "Unreleased"); `## 0.1.0.1` is not taken for `0.1.0` |
| Release app started with `-bpm 87.5 -audioDevice <unknown> -midiSource <unknown>` and with `-bpm 5000` (launch arguments, nothing stored) | runs; the window is drawn as before (screenshot); Tempo shows 87,5 and 120; no crash report |
| English and Czech pages | the same structure, tag by tag |

## Not verified

- The Settings sheet by eye: the rows for a device that is not connected and
  the Channels picker were changed in code only.
- The Tempo field inside the app's own window (the check above ran the same
  field code in a separate hosted view).
- A real change of the system default output (headphones plugged in, another
  output chosen in macOS) and a sample rate changed in Audio MIDI Setup. They
  take the code path the harness exercised, but nothing triggered them.
- Channel pairs on a multi-channel interface, by ear.
- `./build.sh dist` from start to end; only its new check ran, on its own.
- Everything phase 02 left open: a hardware MIDI keyboard, the "Didgeridoo"
  port from another application, the Audio Unit in a host.

The harnesses compiled the app's own `AudioOutput.swift` and `MIDIInput.swift`
with a stand-in for `Synth`; they are not part of this repository.
