# Phase 13 — Verification (2026-11-14)

Checked with the scratch app of phase 11 (the app's real `Window` scene,
`ContentView`, `KeyboardView` and `AppModel`, stand-in audio and MIDI): it
clicks on the real strip and renders the synth itself, then looks at which
partial is there, the drone's or the one 16 semitones above it. Nothing
sounds on any device.

## The cause

| Check | Result |
|---|---|
| Version 1.0.1: C3 pressed every 3 points down its 64 points | the drone down to 54 points (velocity 113); from 57 points on (velocity 117) the overblown note and no drone at all. The key's name sits 51 to 60 points down |
| The engine, 2000 random runs with Glide at 60 ms or less: something played, one to six knobs moved, then C3, C2, C3 | in none of the 1522 runs where the second C3 clearly sounds at its key's pitch did the first C3 sound at another |
| The same with any Glide | 5 of 1536: all with a Glide of 235 to 893 ms and a note let go 20 ms before, the pitch still sliding to C3 |
| The code, read: what can move a note's pitch | the note, an overblown hit, Glide, pitch bend, Drift, the tongue (35 cents), Octave; nothing else |

## The band

| Check | Result |
|---|---|
| `KeyStripTests`, written before `KeyStrip` existed | did not build; now 5 tests pass: the band is velocity 127 at every Toot Vel; above the band every velocity stays under every Toot Vel (64 to 128); soft at the top (40), firmer further down, 105 to 110 just above the band; a key without a band; a press dragged off the key |
| The real strip at Toot Vel 115, 80 and 64: C3 and C#3 pressed every 2 points down | the drone everywhere above the band, the overblown note in the lowest 10 points, on the white key and on the black one, the same at all three settings |
| The same at Toot Vel "Off" | the drone everywhere |
| The whole strip pressed every 3 points (7455 spots) | none stays silent |
| The window's content drawn offscreen | an ochre band along the lower end of the white keys and of the black keys; the names C2 to C6 above it |
| `swift test`, and the same in a release build | 56 tests in 12 suites pass in both |
| `./build.sh debug`, `./build.sh release` | succeed without compiler warnings; `codesign --verify --deep --strict` passes for both |
| English and Czech manual | the same structure, tag by tag |

## The website's picture

`docs/assets/didgeridoo-window.png` is the picture of the real 1.0.0 window
with the 132 rows of the keys replaced by the same rows of the stand-in's
drawing; everything else is unchanged, pixel for pixel. The real app was not
started: the system's output was the USB interface "M4". The stand-in draws
the keys as the real app does (in the 1.0.0 pictures 407 of 290 400 pixels of
those rows differ). The next release should take the picture from the real
app again if the output allows.

## Not verified

- With a hand on a real mouse in the real app, and by ear.
- Everything earlier phases left open.

The scratch tools are not part of this repository.
