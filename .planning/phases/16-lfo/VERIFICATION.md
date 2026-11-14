# Phase 16 — Verification (2026-11-14)

Nothing here was judged by ear, and nobody has used the LFO buttons with a
hand on a mouse: the panel was drawn into pictures and looked at.

| Check | Result |
|---|---|
| The new tests before the code existed (`LFOTests`, the table tests) | did not build: no `LFOs`, no such parameters |
| `swift test`, and the same in a release build | 85 tests in 13 suites pass in both; a debug and a release build render the same samples |
| `swift test --sanitize=thread` | no report |
| An LFO moves a knob (Volume, whose travel is linear in decibels) | an amount of 25 % swings the level of a held note by 19 to 24 dB (23 expected); 0.5 dB without it; the knob's own value stays where it was put |
| Sign, rate, sum, ends | a negative amount mirrors the movement; 5 Hz gives 9 to 11 rises in two seconds; two LFOs on one knob reach more than 1.6 times one of them; at the top of the knob's travel the level does not rise further |
| Shapes | a square stands at its ends more than 70 % of the time (a sine under 50 %, a triangle under 30 %); a triangle rises 40 to 60 % of the time, Ramp Up more than 80 %, Ramp Down less than 15 %; Steps holds a level for more than 75 % of its steps and takes at least five different ones in eight cycles; Wander never jumps and does not return to its place. Volume is smoothed over 20 ms, which is why a jump takes a few stretches to arrive |
| A new note | does not start an LFO again: half a cycle after its start a sine stands at its middle |
| A square LFO on Buzz, Drive or Voice at 8 Hz | no click: the steepest step stays under 1.5 times a steady note's |
| The table | 30 knobs group by group, then 32 amounts (`lfo1vowel` … `lfo2rhybreath`), in no group; switches, times, Wheel Vowel, Drift and the LFOs' own knobs have none; LFO 1 on Vowel rests at 8.75 %, every other amount at 0 |
| The sound the author approved | the demo score of phase 15 rendered by this engine differs from phase 15's own render by 110 dB under the signal (rounding); the programs' levels did not change, and four of the twenty references (the two programs without movement) stayed the same to the bit |
| `./build.sh debug`, `./build.sh release` | succeed without compiler warnings; `codesign --verify --deep --strict` passes for both bundles |
| `auval -v aumu Didg JPis` on the release build's component | AU VALIDATION SUCCEEDED: 62 parameters, the 32 amounts outside the four groups, "Cocoa Views Available: 1" |
| A minimal host (a scratch program) with that component | its window is 1100 × 680 with the LFO buttons in the header; closing and disposing does not crash |
| The panel, drawn by a silent stand-in of the app (the real `ContentView`, `InstrumentPanel` and `AppModel`) | 1100 × 758 as before; Mouth holds Vowel, Tongue, Wheel Vowel, LFO 1 Rate, LFO 1 Shape / LFO 2 Rate, LFO 2 Shape, Volume; with LFO 1's button on, the sixteen knobs show its amounts in sage with their arcs, twelve knobs step back and the four LFO knobs stay; with both off, arcs in both colours remain on the knobs that are moved |
| English and Czech manual and home page | the same structure, tag by tag (294 and 73 tags); no Wobble left |
| A demo for the author's ear (`~/Desktop/Didgeridoo-F-lfo.wav`, 0:49), measured after writing | six parts: without an LFO the drone's level and brightness stay within 1.5 dB; a triangle on Tone moves the brightness by 15 dB four times in eight seconds; a square on Volume moves the level by 12 dB at four a second; Steps on Vowel moves the band near 2 kHz by 17 dB; Wander on Breath and Buzz moves the brightness by 10 dB; a ramp on Voice brings its partial up by 39 dB |

## Not verified

- **The gesture.** Dragging a knob with a button on, the double click, the
  snap to nothing within one percent: the code is the knob's own drag with
  another parameter under it, and no test or hand has used it.
- **How it sounds**, and whether the amounts feel right under the hand: an
  amount is a part of the knob's travel, which for Volume (46 dB of travel)
  is a lot per percent.
- **The real app was not started**: the system's output was the USB
  interface "M4". The pictures on the website and in the manual are the
  stand-in's drawings under the title bar of an earlier picture.
- The plug-in in a real host: how its list of parameters reads with 32
  amounts in it, and automation of an amount.
- The component installed on this Mac is the released 1.0.2 again.
- Everything earlier phases left open.

The scratch tools (the stand-in of the app, the minimal host, the demo's
score) are not part of this repository.
