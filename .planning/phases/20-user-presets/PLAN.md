# Phase 20 — Presets of your own

## Goal

The author: "udelej mi tam moznost ukladani presetu." Until now a sound
could only be kept by the app's memory of the last one, or by a host.

Asked three things, he chose: presets work in **the app and the plug-in**,
a preset remembers **everything that is heard** (every knob, Octave and the
LFOs' amounts included), and they are saved and chosen **in the Program
menu**, as he saw it drawn:

    Program [ Muj dron          v ]
            |   Classic Drone      |
            |   ... (10 built in)  |
            | -------------------- |
            | * Muj dron           |
            |   Nocni rytmus       |
            | -------------------- |
            |   Save Preset...     |
            |   Delete "Muj dron"  |
            |   Show in Finder     |

## Acceptance criteria

- [x] **Save**: Program › Save Preset… asks for a name and stores the sound
      as it stands; the preset is then the one in use. A name that exists is
      replaced, and the window says so before it does.
- [x] **Load**: choosing a preset brings back every parameter, the octave
      and the LFOs' amounts included, on any program. A double click on a
      knob then returns the preset's value.
- [x] **Delete** moves the preset in use to the Trash; the sound stays.
- [x] **The Program menu** lists the ten built-in programs, then the
      presets, and marks what is in use. (Built; the open menu was not seen:
      see the verification.)
- [x] **The app and the plug-in share the presets**: one file per preset in
      one folder, and a preset saved in one window shows up in the other
      without a restart. Show in Finder opens the folder.
- [x] **Kept**: the app shows the preset in use after a new launch; a host's
      project brings its name back.
- [x] A preset that cannot be read, or one of another engine, is not loaded
      and the window says why.
- [x] The rules are in the core, tested first. The manual in both
      languages, the home pages, the README and the CHANGELOG describe it.
- [x] `swift test` (debug and release), `./build.sh debug`,
      `./build.sh release` and `auval` succeed.

## Decisions

- **A preset is a file**: `<name>.didgeridoo` in
  `~/Library/Application Support/Didgeridoo/Presets`, holding what the app
  already remembers between launches (`SynthState`: the engine's number, the
  program it grew from and every parameter by its identifier). Files can be
  copied to another Mac, renamed in the Finder and backed up; a setting in
  the app's preferences could not, and the plug-in in a host could not read
  it. The folder needs no permission from the system, unlike Documents or
  Music.
- **Not Audio Unit preset files** (`.aupreset` in `~/Library/Audio/Presets`).
  Logic lists those by itself, but Live's browser does not (Ableton's help:
  such presets are handled in the plug-in's own window), the app would have
  to write the Audio Unit's binary state without being one, and it could
  not be tried in a host here. The plug-in's window has the menu instead.
- **MIDI controllers and the tempo are not in a preset**: the controllers
  are the player's setup (phase 17), the tempo is the app's or the host's.
- **Loading a preset is loading its program and then its values**, so that
  it cuts a sounding note off as a program does and a parameter a later
  version adds gets its program's value.
- **In the plug-in the preset is the unit's present preset by name** (number
  -1, as a host's own presets are): the host's saved state carries the name,
  and the window shows the preset as in use when its library has that name.
- **Delete goes to the Trash** and asks nothing: it can be taken back.
- **The window looks at the folder every two seconds**, which is how a
  preset saved in the app appears in a host's window.
- **The menu's items are toggles, not a picker**: a picker wants its
  selection among its own items, and the sound comes from one of two lists
  or from neither.
- **The name is the file's name**: trimmed, "/" and ":" become "-", no
  leading dot, 60 characters at most. Capitals do not make another preset.

## Not in this phase

- Folders or tags, a mark for "changed since loaded", presets chosen by MIDI
  program change, a picture of the open menu in the manual, `.aupreset`
  export.
