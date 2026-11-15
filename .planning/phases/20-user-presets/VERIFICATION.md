# Phase 20 — Verification (2026-11-15)

Nobody has opened the Program menu. SwiftUI draws it itself, so there is no
AppKit menu a program could read, and the system twice refused to bring a
stand-in of the app to the front for a made-up click. What the menu's items
do was run through the models they call; the header and the name field were
drawn into pictures and looked at. The engine is untouched: no sound
changed.

| Check | Result |
|---|---|
| The core's tests before the code existed (`PresetTests`) | did not build: no `PresetLibrary`, `PresetShelf`, `PresetError` |
| The plug-in window's tests before its model knew presets | did not build: `AudioUnitModel` had no `preset` and took no `presets:` |
| `swift test`, and the same in a release build | 126 tests in 16 suites pass in both, without a compiler warning |
| `swift test --sanitize=thread` | no report |
| The files (`PresetLibrary`) | a folder that is not there lists nothing and the first save makes it; a preset is `<name>.didgeridoo`; the list is sorted as the Finder sorts and leaves other files out; "in/out: 2" is stored as "in-out- 2", leading dots go, 60 characters at most, an empty name is refused; a name that exists replaces that preset whatever its capitals; a preset that is gone cannot be deleted or read; a file that is no preset and one without the engine's number (as 1.0.x wrote state) are refused, each with its own reason |
| A preset brings everything back | saved on Gallop with the octave up, LFO 2 on Tone and the vowel moved, loaded on Deep Earth: each of the 62 parameters within 0.001 of what was saved, and the program it grew from |
| What a window keeps (`PresetShelf`) | it starts with the folder's presets and the one it was told was in use, if that is still there; saving and loading make a preset the one in use, under the folder's spelling; a built-in program ends that; deleting the one in use leaves none; a look finds what another window saved and what the Finder took away; a name from outside counts only while the folder has it |
| The plug-in's window on the unit, inside the tests | saving makes the preset the unit's present preset by name (number -1); a factory preset ends that; loading puts Tone, Octave and an LFO amount back into the unit's parameters and the window's knobs; a double click returns the preset's value, a program's after that; the unit's saved state restored into a second unit brings the name back, and its window shows the preset while its folder has it and none with another folder; two windows on one folder see each other's presets after a look; deleting the preset in use leaves the sound |
| The app's own part, with the real `AppModel` made, used, thrown away and made again (silent stand-in for audio and MIDI, settings and folder of its own) | 16 checks pass: a preset saved as " Můj / dron " is "Můj - dron" and in use; the next launch shows it in use with the sound as it was left; a double click returns the preset's value; Classic Drone ends it and leaves the octave; loading in other capitals brings back Tone, Octave, the LFO amount and the program, in the synth too; a preset another window saved appears after a look; one that is not there gives a reason in words; deleting leaves the sound and the third launch has none in use |
| The Trash | a preset deleted through a library that does not delete for good lay in `~/.Trash` (and was taken out again by the check) |
| The release build's component installed, in a minimal host, with two presets written into the real folder (which was not there before, and is not there after) | the window opens on "Classic Drone"; when the host names the unit's present preset "Self-test A 20", the menu shows that name; a preset written while the window is open and then named shows within three seconds, so the window does look at the folder in a host. Closing and disposing does not crash |
| `auval -v aumu Didg JPis` on that component | AU VALIDATION SUCCEEDED: 62 parameters, "Cocoa Views Available: 1". The minimal host of phase 17 still passes its 13 checks |
| `./build.sh debug`, `./build.sh release` | succeed without compiler warnings; `codesign --verify --deep --strict` passes for both bundles |
| The header, drawn by a silent stand-in of the app | "Program" and the menu showing "Můj dron", one width for every name; with MIDI on and Defaults in the header everything still fits. The first drawing showed the word "Program" broken over two lines: the group was given its own size and drawn again |
| The name field, drawn on its own | empty, Save is greyed out; "noční RYTMUS" with a preset "Noční rytmus" there reads "A preset of this name exists and will be replaced." and the button reads Replace; Return asks to save once |
| English and Czech manual and home page | the same structure, tag by tag (357 and 73 tags); every link inside the manuals has its target |

## Not verified

- **The open menu**: the order of its items, the ticks, the heading "Your
  presets", the lines between the groups. Never seen.
- **Save Preset… opening the field** under the menu, in the app's window and
  in a host's; the field having the keyboard as it opens; the message when
  something fails; Show in Finder.
- **A host that is sandboxed** (GarageBand, perhaps others from the App
  Store): there the folder would be the host's own, and the app's presets
  would not be seen. Not tried.
- The real app was not started; the plug-in was not in a real host: whether
  Live and Logic show the preset's name where they show a plug-in's preset.
- The pictures on the website still show the Program menu of 2.0.0 (a pop-up
  with two arrows); it is a pull-down with one now. They are taken again at
  the next release.
- The component installed on this Mac is the released 1.0.2 again.
- Everything earlier phases left open.

The scratch tools (the stand-ins of the app, the minimal hosts) are not part
of this repository.
