# Phase 21 — Version 2.1.0 — Verification (2026-11-15)

A minor version: presets of your own (phase 20) and the OXI E16 definition
on the website (phase 19). No sound changed, no parameter was added. The
author asked for it to be released ("ano" to the question naming the tag,
the GitHub Release, the push of `main` and the catalog).

## What the release found and fixed

The released app is marked as built for macOS 14 (`LC_BUILD_VERSION`: sdk
14.0, which is what `swift build` writes), so the system draws its controls
in the older style and SwiftUI behaves as on 14. The stand-ins of earlier
phases were built for the Mac they ran on and looked and behaved newer. A
stand-in marked the same way (`vtool -set-build-version macos 14.0 14.0`)
draws the window as the real app does: its picture differs from the real
2.0.0 window only where the Program menu is (10 596 of 3 458 400 pixels, all
in rows 112 to 163 between the logo and the LFO buttons). Driven through the
accessibility interface, it showed three defects of phase 20, fixed in
`1f2f9e1` before anything was published:

- The field Save Preset… opens did not get the keyboard; it stayed on the
  Program menu, and typing went nowhere. The manual says "type a name and
  press Return".
- After Save, the closing field read "Replace" and "will be replaced" for a
  moment.
- The older menu button takes its width from the name, so a preset with a
  long name squeezed the logo and broke "Tempo" in two.

## Checks

| Check | Result |
|---|---|
| `swift test` | 126 tests in 16 suites pass, before and after the fixes |
| `./build.sh dist` (run again after the fixes) | `status: Accepted` for the app and for the DMG, ends with `Done!`; its only warning is `hdiutil`'s own |
| `spctl -a -vv` on the app and on the DMG | accepted, `source=Notarized Developer ID` |
| `stapler validate` on the app and on the DMG | both valid |
| `docs/appcast.xml` | version 2.1.0, the URL `…/v2.1.0/Didgeridoo-2.1.0.dmg`, a length equal to the DMG's size (10 418 504 bytes), this version's three notes; `sign_update --verify` accepts its signature for the DMG |
| The DMG mounted | the app (2.1.0, valid signature, hardened runtime, the component 2.1.0 inside with the Audio Unit version 0x20100) and the Applications link |
| The notarized component copied out with a quarantine attribute | `auval`: AU VALIDATION SUCCEEDED, component version 2.1.0, 62 parameters, its custom UI. The host of phase 17 passes its 13 checks on it; the host of phase 20 sees the preset a project names and one saved while the window is open. The component installed on this Mac is the released 1.0.2 again |
| The open Program menu (stand-in, the app's look and the newer one) | the ten programs with a tick on the one in use; with presets a line, the heading "Your presets", the presets with the tick on the one in use, a line, Save Preset…, Delete "name" (only with a preset in use), Show in Finder. Read item by item and looked at in pictures |
| Save Preset… (stand-in in front, the app's look) | the field opens under the menu and has the keyboard; a typed name lands in it; Return saves the preset, closes the field and makes the preset the one in use |
| The rest of the menu (stand-in in the background, the app's look) | Save Preset… with a preset in use offers its name, says it will be replaced, and Replace replaces it; Cancel closes the field and changes nothing; choosing a preset, then a program, then the preset again loads each; Delete takes the preset in use out of the menu and the folder and leaves the sound; a file that is no preset appears in the menu within three seconds and choosing it shows "Presets: … is not a Didgeridoo preset, or its file is damaged." with OK, the preset in use unchanged |
| After Save, the closing field | still reads "Save" (it read "Replace" before the fix) |
| The header with names of 8, 29 and 60 characters, both looks | the Program menu keeps its width (183 points), a long name ends in "…", nothing else moves; the window keeps its size |
| The website's pictures | the window, the LFO amounts and MIDI learn are the stand-in's window in the app's look, photographed on screen while not in front, under the title bar of the real 2.0.0 window; the plug-in's window is the notarized component's in the scratch host |
| The manual's frames, both pages in a browser without a window | frame 2 moved left to take in the wider menu; the seven frames sit on their areas |
| English and Czech pages | the same tags in the same order (357 and 73) |

## Not verified

- **The released app was not started.** The system's default output was the
  author's audio interface, and his installed 2.0.0 was running on the same
  settings; a second copy would have opened a stream there and written to
  the same settings. Everything above about the window comes from the
  stand-in (the app's own model and views, no audio, no MIDI), which draws
  as the app does but is not the app.
- **The pictures of the window** therefore show the Program menu as it looks
  in a window that is not in front (a grey arrow, no focus ring) under an
  active title bar.
- **Escape** in the name field, and the mouse: the menu and the buttons were
  pressed through the accessibility interface, the name was typed with
  made-up keys.
- **Show in Finder** was not chosen (it would have opened a Finder window in
  front of the author's work).
- With a preset in use VoiceOver reads the Program menu by the preset's
  name, not as "Program" (seen in the accessibility tree in the app's look;
  left as it is).
- **A sandboxed host**, a real host showing the preset's name, a real MIDI
  controller, the update from an installed older version: as before.
- Everything earlier phases left open.
