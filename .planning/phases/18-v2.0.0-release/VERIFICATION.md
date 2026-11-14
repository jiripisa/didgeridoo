# Phase 18 — Version 2.0.0 — Verification (2026-11-15)

A major version: phases 15 to 17 (the instrument as one model and no
overblown note, two LFOs that move the knobs, MIDI learn). Sounds stored by
1.0.x and host projects saved with its plug-in do not carry over, which is
why the first number changes. The author asked for it to be released
("Ano, udelej release").

| Check | Result |
|---|---|
| The three phases merged into `main` | one `--no-ff` merge each; the tree of `main` is that of phase 17's branch, to the byte |
| `swift test` | 105 tests in 14 suites pass |
| `./build.sh dist` | `status: Accepted` for the app and for the DMG, ends with `Done!`; its only warning is `hdiutil`'s own, that its command line is deprecated |
| `spctl -a -vv` on the app and on the DMG | accepted, `source=Notarized Developer ID` |
| `stapler validate` on the app and on the DMG | both valid |
| `docs/appcast.xml` | version 2.0.0, the URL `…/v2.0.0/Didgeridoo-2.0.0.dmg`, a length equal to the DMG's size (10 275 812 bytes), the notes of this version (16 items, the model's five under their own); `sign_update --verify` accepts its signature for the DMG |
| The DMG mounted | the app (2.0.0, valid signature, hardened runtime, the component 2.0.0 inside with the Audio Unit version 0x20000) and the Applications link |
| The notarized component copied out with a quarantine attribute | `auval`: AU VALIDATION SUCCEEDED, component version 2.0.0, 62 parameters, its custom UI. The minimal host of phase 17 passes its 13 checks on it: controllers move the unit's parameters, learn, the saved state carries the controllers |
| The notarized app started from the build folder | its window opened within a second and was captured by its window number (2200 × 1572); no crash report. The system's output was the built-in speakers; the app's settings were saved aside before and put back after, and the app was quit |
| The window's picture on the website | is that capture: the real window of 2.0.0, for the first time since 1.0.0 |
| The manual's frames on that picture, and both pages in a browser without a window | the seven frames sit on their areas (frame 2 moved a little left: the real Program menu is wider than the stand-in drew it); the home page shows the new picture and "Version 2.0.0" |
| English and Czech pages | the same structure, tag by tag (329 and 73 tags) |

## Not verified

- **Nothing was clicked or played in the released app.** It was started and
  looked at; the LFO and MIDI buttons, the knobs and the keyboard were not
  used in it.
- **The pictures of the LFO amounts and of MIDI learn in the manual** are
  still the stand-in's drawings under a real title bar: showing them in the
  real app needs clicks. Their Program menu is narrower than the real one.
- **The update from 1.0.2**: that an installed 1.0.2 offers 2.0.0 and
  installs it, and that it then starts with Classic Drone and the
  controllers the knobs come with.
- A real MIDI controller, the plug-in in a real host, the author's ear on
  the LFOs: as phases 16 and 17 list them.
- Everything earlier phases left open.
