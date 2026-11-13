# Phase 05 — Verification (2026-11-13)

| Check | Result |
|---|---|
| The new tests before the engine changed | 10 tests failed: no "octave" parameter, and the phrase played two octaves higher rendered other samples |
| `swift test`, and the same in a release build | 34 tests in 9 suites pass in both |
| `swift test --sanitize=thread` | no report |
| Sound references with the phrase played two octaves higher | unchanged, in a debug and a release build: at Octave 0 the engine renders the samples it rendered before |
| Pitch read from the zero crossings: A2 (220 Hz) from note 81 at Octave 0, 57 at +2, 69 at +1, 93 at −1, 105 at −2 | each within 0.5 Hz |
| Octave turned from 0 to +1 while a note sounds | between the two pitches in the first 50 ms, at 440 Hz after a second |
| A program loaded after Octave was set to +2 | the program's values are in, Octave is still +2 |
| `./build.sh debug`, `./build.sh release` | succeed without compiler warnings; `codesign --verify --deep --strict` passes for both bundles; the component still exports only its factory function |
| `auval -v aumu Didg JPis` | AU VALIDATION SUCCEEDED; 26 parameters, Octave is parameter 25 (−2 to 2, default 0) in the Rhythm group |
| Release app started with default knobs (launch arguments, nothing stored) | the Octave knob sits next to Bend Range and shows 0; the strip is labelled C2–C6. This screenshot is now `docs/assets/didgeridoo-window.png` (same size, so the manual's marks still fit) |
| English and Czech manual | the same structure, tag by tag |

## Not verified

- By ear, and the knob turned with the mouse.
- In a host: a project saved with 0.5.0 should open with Octave at 0, two
  octaves lower than it was.
- The hands-on checks of phases 02 and 03 are still open.
