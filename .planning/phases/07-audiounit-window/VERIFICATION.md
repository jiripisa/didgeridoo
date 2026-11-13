# Phase 07 — Verification (2026-11-14)

| Check | Result |
|---|---|
| The new tests before the code existed | did not build: no window model, no panel module |
| `AudioUnitWindowTests`: the real Audio Unit, registered inside the test process, driven through the window's model | 6 tests pass: a knob sets the unit's parameter; a host's change shows after a refresh; a program chosen in the window loads the preset and keeps Octave; a preset chosen by the host shows; a double click restores the program's value; a host's listener hears begin, value, end of a drag in that order |
| A fault these tests found | choosing a program before any audio was rendered put Octave back to 0 (the unit read it from the engine, which had not yet been given it); fixed, the test covers it |
| `swift test`, and the same in a release build | 40 tests in 10 suites pass in both |
| `swift test --sanitize=thread` | no report |
| `./build.sh debug`, `./build.sh release` | succeed without compiler warnings; `codesign --verify --deep --strict` passes for both bundles |
| The component | exports only `_DidgeridooAUFactory`; holds the class `DidgeridooAUViewFactory` and `Resources/Art` |
| `auval -v aumu Didg JPis` | AU VALIDATION SUCCEEDED, including "VERIFYING CUSTOM UI: Cocoa Views Available: 1, DidgeridooAUViewFactory, PASS" |
| A minimal host (a scratch program): loads the installed component, asks for the window through the CocoaUI property, puts the view into a window that is never shown and takes pictures | the view is 1100 × 680 with the artwork of the component's bundle; after the host set Vowel and Octave and chose the preset Gallop, the picture shows Gallop's knobs, the name "Gallop" and Octave still at +2; closing the window and disposing the unit does not crash |
| The app's window on the shared panel against the screenshot taken before | 11 of 3.3 million pixels differ |
| English and Czech manual | the same structure, tag by tag |

## Not verified

- In a real host (Ableton Live, Logic Pro): the window opening there,
  turning knobs with the mouse, automation being recorded and played back,
  several instances, closing and reopening the window, Logic's separate
  hosting process. The author tests this from the released build.
- Everything earlier phases left open.

The minimal host and its pictures are not part of this repository; one of
the pictures is `docs/assets/manual/plugin-window.png`.
