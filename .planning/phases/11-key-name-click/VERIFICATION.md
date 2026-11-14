# Phase 11 — Verification (2026-11-14)

The fault was reproduced and the fix checked with a scratch app: the app's
real `Window` scene, `ContentView`, `KeyboardView` and `AppModel`, with
stand-ins for `AudioOutput` and `MIDIInput`. Opened like an app (so that its
window is the key window), it sends itself mouse events on the keyboard strip
and renders the synth's sound itself to hear whether a note plays. Nothing
sounds on any device.

| Check | Before the fix | After the fix |
|---|---|---|
| A press in the middle of the name of C2, C3, C4, C5, C6 | silent, all five | plays, all five (−20 to −13 dB, as beside the name) |
| A press on the same keys beside the name | plays | plays |
| The whole strip pressed every 3 points (7455 spots) | 63 stay silent, all of them on the five names | 0 stay silent |

Other things tried while looking for the cause, on the code before the fix:

| Tried | Result |
|---|---|
| A double click on a key | the second press plays |
| Press a key, drag to its neighbour, release there, press the first again | plays; nothing stays behind |
| Press a key, release outside the window, press it again | plays |
| A press into the window while it is not the key window | nothing plays (the press only activates the window) |
| Presses of 0, 5, 20, 50, 100, 300 ms | silent, −32, −26, −18, −17, −15 dB at the loudest: a press under about 20 ms is nearly silent |
| The engine's MIDI queue and note handling, read through | nothing that could leave one key silent |

| Check | Result |
|---|---|
| `swift test` | 51 tests in 11 suites pass |
| `./build.sh debug`, `./build.sh release` | succeed without compiler warnings; `codesign --verify --deep --strict` passes for both |

## Not verified

- With a hand on a real mouse in the real app. The author's fault matched
  the names in his example (C2), but he has not confirmed that this was all
  of it.
- Everything earlier phases left open.

The scratch app is not part of this repository.
