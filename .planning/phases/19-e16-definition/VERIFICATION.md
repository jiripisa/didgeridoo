# Phase 19 — Verification (2026-11-15)

| Check | Result |
|---|---|
| The new tests before the file existed (`E16DefinitionTests`) | all three fail: "The file “Didgeridoo.oxiindef” couldn’t be opened" |
| With the file in place | they pass: the file is, byte for byte, what the test writes down from the engine's table (it is also the file a scratch program wrote from that table in phase 17) |
| With one entry spoiled (Tone on CC 75 with a default of 20) | two of them fail: the text differs, and that default does not put Tone on its default place |
| What the file says | 32 entries: every knob once, the mod wheel and the sustain pedal; short names of up to four letters and digits, no two alike, and no controller twice; every entry a control change over 0 to 127. Sending a knob's default value on its controller puts a continuous knob within half a controller step of its default and a switch on its default step |
| Its shape against the OXI App's own files | the same keys in the same order and the same value types as the eight definitions in the author's folder (compared in phase 17), one line, no line end, ASCII |
| `swift test` | 108 tests in 15 suites pass |
| The file through a web server (the docs folder served locally) | 200, 4118 bytes, the same bytes |
| The manual's entry "OXI E16" in a browser without a window | reads as the other entries of the MIDI section, in English and in Czech; the link's name is the file's |
| English and Czech manual | the same structure, tag by tag (332 tags) |

## Not verified

- **Nobody has imported the file into the OXI App or sent it to an E16.**
  Its shape follows the app's own files; what the E16 does with the default
  values is read off the author's scene file (an encoder holds a
  `defaultValue`), not seen on the device.
- How GitHub Pages serves the file (the type it names for `.oxiindef`) and
  what a browser does with the link there.
- Everything earlier phases left open.
