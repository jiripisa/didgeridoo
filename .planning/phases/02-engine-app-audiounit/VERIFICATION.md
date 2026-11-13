# Phase 02 — Verification (2026-11-13)

| Check | Result |
|---|---|
| Engine vs MPC plugin: 5.2 s phrase (notes, legato, mod wheel, pitch bend, hard-hit toot, aftertouch, sustain pedal), 128-frame blocks, all 6 programs, compared sample by sample against the plugin's native build | identical (largest difference 0) |
| Parameter positions and value texts after loading each program, against the plugin | identical |
| `swift test` | 13 tests in 4 suites pass |
| `./build.sh debug`, `./build.sh release` | succeed |
| `auval -v aumu Didg JPis` | AU VALIDATION SUCCEEDED |
| App launches, window drawn with the artwork | checked from a window screenshot |

## Not verified

- Playing the app from a hardware MIDI keyboard, from another application
  through the "Didgeridoo" port, and with the mouse on the keyboard strip and
  knobs.
- Choosing an audio device and a channel pair on a multi-channel interface.
- The Audio Unit in a host (Ableton Live, Logic Pro): loading, automation,
  saving a project, tempo sync of the rhythm pulse.
- `./build.sh dist` (signing and notarization of the app with the embedded
  component). That is the first release.
- Sample rates other than 44.1 kHz by ear. The engine takes the rate into
  account, but the comparison with the plugin ran at 44.1 kHz only.

The comparison harness loaded the MPC plugin's native build and is not part
of this repository; the tests here cover the engine on its own.
