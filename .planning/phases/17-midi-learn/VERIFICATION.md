# Phase 17 — Verification (2026-11-15)

No real controller was moved and no hand has used the MIDI button: every
control change here was sent by a test or by a scratch program, and the
panel was drawn into pictures and looked at. Nothing was judged by ear;
this phase changes no sound.

| Check | Result |
|---|---|
| The controller tests before the code existed (`ControllerTests`) | did not build: "cannot find 'Controllers' in scope" |
| The Audio Unit's four new tests against the unit's code of phase 16 (put back for one run) | three fail: the unit's parameter does not follow a controller, a request to learn is not taken, the saved state holds no controllers. The fourth guards the new copying against overwriting what a host set, and so passes without that code |
| `swift test`, and the same in a release build | 105 tests in 14 suites pass in both, without a compiler warning |
| `swift test --sanitize=thread` | no report |
| A controller moves its knob | CC 74 at 127 puts Tone at 8000 Hz, at 0 at 200 Hz, at 64 at 64/127 of its travel, and no other knob moves; a switch (Pattern, four steps) takes the nearest step; the engine counts each such change and nothing for a controller nobody listens to |
| A knob with a middle | Rhy>Vowel (−100 … 100 %) stands at 0 % at 64, at −0.79 % at 63 and above 0 at 65. Before the fix 64 gave +0.79 % and no value gave 0: the test failed first |
| The controllers the knobs come with | 30 knobs, 30 different controllers, none that MIDI reserves; Volume 7, Glide 5, Vowel 11, Drive 2, Buzz 70, Tongue 71, Release 72, Attack 73, Tone 74, LFO 1 Rate 76; an LFO's amount has none |
| Learn | the knob that is learning takes the next controller that moves and that controller's value; the knob that had the controller is left with none; the mod wheel and the pedal do not end it, and it can be called off; a controller can be taken away, given by hand and all put back |
| The wheel and the pedal | do what they did and move no knob. The controllers MIDI keeps (0, 1, 6, 32, 38, 64, 96 to 101, 120 to 127; the tests try eleven of them) count as reserved, and a knob that is learning does not take the wheel or the pedal |
| Stored | the map survives the form it is stored in, a knob without a controller included; a knob the stored map does not know keeps the one it came with; a program leaves the map alone |
| The app's own remembering, with the real `AppModel` made, taught, thrown away and made again (a silent stand-in for audio and MIDI, settings of its own) | a learnt controller, a knob without one and the places the controllers put the knobs are there after the next launch; after Defaults the next launch has the controllers the knobs come with |
| The sound | the references of `SoundRegressionTests` are those of phase 16, untouched |
| `./build.sh debug`, `./build.sh release` | succeed without compiler warnings; `codesign --verify --deep --strict` passes for both bundles |
| `auval -v aumu Didg JPis` on the release build's component | AU VALIDATION SUCCEEDED: 62 parameters, "Cocoa Views Available: 1" |
| A minimal host (a scratch program) with that component installed, passing controllers on as a host does and rendering into memory | the unit reports a controller for each of its 62 parameters (the 32 amounts: none); CC 74 at 0 puts the unit's Tone parameter at 200 Hz, CC 7 at 127 Volume at 6 dB, CC 11 at 127 Vowel at 100 %, CC 88 at 64 Rhy>Vowel at 0 %; the wheel and the pedal move nothing; a request to learn for Tube is taken and CC 40 becomes Tube's; Volume learns CC 74 and Tone is left with none; a second unit given the first one's saved state has the same controllers. The window (1100 × 680, with LFO 1, LFO 2 and MIDI in its header) shows the knobs where the controllers put them; closing and disposing does not crash |
| The panel, drawn by a silent stand-in of the app (the real `ContentView`, `InstrumentPanel` and `AppModel`) | the header reads Program, LFO 1, LFO 2, MIDI, Tempo, Settings; with MIDI on, every knob shows "CC" and its number under it and Defaults stands next to the button; a knob that is listening has a dashed ring and reads "move a control" |
| English and Czech manual and home page | the same structure, tag by tag (329 and 73 tags); every link inside the manuals has its target; the 30 controllers listed in both manuals are the engine's, compared by a script; the English section was rendered by a browser without a window and looked at |

## Not verified

- **A real controller.** MIDI from a device reaches the engine the way
  notes, the wheel and the pedal already do (the app's `MIDIInput` posts
  every message to the synth), but nobody has turned a control and watched a
  knob.
- **The gestures in MIDI mode**: the click that starts and ends listening,
  the double click, the secondary click's menu, Defaults. They are the
  panel's code and no test or hand has used them.
- **The real app was not started**: it shares its settings with the
  installed 1.0.2 (the same bundle identifier), and nobody was there to
  click in it. The pictures on the website and in the manual are the
  stand-in's drawings under the title bar of an earlier picture; the
  plug-in's picture is the minimal host's.
- **The plug-in in a real host**: whether Live or Logic pass controllers on
  to an instrument untouched (a host may keep some for itself or for its own
  MIDI mapping), and how a host shows a parameter that a controller moved.
- The Czech manual in a browser; the home pages in a browser.
- The component installed on this Mac is the released 1.0.2 again
  (signature checked after putting it back).
- Everything earlier phases left open.

## Beside the repository

An instrument definition for the OXI E16 (`Didgeridoo.oxiindef`: the 30
knobs with these controllers and the controller value of each knob's default
place, plus the mod wheel and the sustain pedal) was written from the
engine's table by a scratch program and put with the author's other
definitions in `~/Documents/OXI E16/Instrument Definitions/`. It has the
keys, their order and the value types of the definitions the OXI App wrote
there; nobody has imported it into the OXI App or sent it to an E16.

The scratch tools (the stand-in of the app, the minimal host, the generator
of the definition) are not part of this repository.
