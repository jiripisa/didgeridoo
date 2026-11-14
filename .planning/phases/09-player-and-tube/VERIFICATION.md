# Phase 09 — Verification (2026-11-14)

Nothing here was judged by ear. Every claim about the sound is a measurement
of what the engine renders.

| Check | Result |
|---|---|
| The new tests before the code existed (`PlayerAndTubeTests`, the table and section tests) | failed: 50 tests, 17 issues; no such parameters, sections or programs |
| The six earlier programs with the new knobs at rest | `SoundRegressionTests`: the same fingerprints and levels as before at 44.1 and 48 kHz, in debug and in release |
| **Tongue** at 100 %, Vowel 80 %, Drive 0 | the harmonics on the tract's resonances (1633, 2287, 3050 Hz) lose 21 to 23 dB, the band between the first two (1960 Hz) loses 5 dB; at Vowel 10 % the spectrum is the same as without the tongue. With the default Drive the saturation fills the lowest notch by about 5 dB |
| **Pitch** with the tongue raised | the drone stands 35.00 cents above the key (17.50 at Tongue 50 %) |
| **Tube** at 100 % | the second harmonic falls from −6 to −20 dB under the fundamental. Toot Pitch 19 st: the third harmonic at −16 dB with the second at −21 and the fourth at −27; Toot Pitch 16 st: −23 dB, level with its neighbours. Over the knob's travel the loudness rises by 1 to 2 dB (by 11 dB before the level was brought back) |
| **Toot Len** 100 ms, hard hit | the toot's partial stands more than 10 dB above the drone's in the first 90 ms and more than 10 dB under it after 0.6 s; at "Hold" it stays on top |
| **Voice** at 100 %, a fifth | a partial at 1.5 times the drone (the series on half its frequency) appears, less than 25 dB under the fundamental; absent at Voice 0 |
| **Pattern** A-b with Accent 100 % | accented steps are more than 2 dB louder than the soft ones; with "Even" all steps are alike |
| **Breath In** at 100 % | late in the in-breath of a soft step the level is more than 3 dB lower than without it |
| The new programs against the UNSW recording `AT.wav`, harmonics 2 to 8 relative to the fundamental | recording: −11 to −39 dB (low tongue: 3rd −11, 5th −16, 7th −16; high tongue: a band at 1.75 kHz, −34 dB, 10 to 30 dB above its neighbours). Eucalyptus −18 to −33, Hard Tongue −17 to −31, Pipe −19 to −29 with the 3rd on top, Singer −17 to −32; the band left by the tongue at −36 dB with −48 and −60 dB beside it. The six earlier programs: −4 to −30 dB |
| A fault the measurements found | the tube stayed tuned to the first note of a legato phrase (its pitch was never advanced); fixed, `tubeFollowsALegatoNote` covers it |
| A fault in the measuring itself | harmonics were first read at the key's pitch, which the tongue leaves by 35 cents; the tests and the scratch tool now find the drone first |
| `swift test`, and the same in a release build | 51 tests in 11 suites pass in both |
| `swift test --sanitize=thread` | no report |
| Speed | two minutes of sound render in 0.12 s with an old program and in 0.11 s with Hard Tongue |
| `./build.sh debug`, `./build.sh release` | succeed without compiler warnings; `codesign --verify --deep --strict` passes for both bundles; the component exports only `_DidgeridooAUFactory` |
| `auval -v aumu Didg JPis` | AU VALIDATION SUCCEEDED: 33 parameters in four groups, ten factory presets, "Cocoa Views Available: 1" |
| A minimal host (a scratch program): loads the installed component and takes pictures of its window, never shown | the view is 1100 × 680 with the four groups; after the host set Vowel and Octave and chose the preset Gallop the picture shows Gallop's knobs and Octave still at +2; closing and disposing does not crash |
| The app's window, from a silent stand-in: the app's real `Window` scene, `ContentView` and `AppModel`, with stand-ins for `AudioOutput` and `MIDIInput` | 1100 × 758 under the title bar; all 33 knobs, the keyboard no longer cut at the bottom (the window was 720 high whatever its content needed). The same picture from inside a copy of the app's bundle: 0 pixels differ |
| English and Czech manual and home page | the same structure, tag by tag (570 and 130 tags); the seven frames in the window's picture sit on their areas (headless Chrome) |

## Not verified

- **How any of it sounds.** The values of the four new programs, the depth of
  the tongue's notches, the height of the tube's resonances, the size of an
  accent and of an in-breath were all set by measurement. They need the
  author's ear.
- The real app with its audio and MIDI: the picture was taken from the
  stand-in, so that no stream was opened on the system's output (AirPods at
  the time).
- The plug-in in a real host with 33 parameters and the new presets.
- Everything earlier phases left open.

The scratch tools (the spectrum analyser, the minimal host, the silent
stand-in of the app) are not part of this repository. The pictures they took
are `docs/assets/didgeridoo-window.png` and
`docs/assets/manual/plugin-window.png`.
