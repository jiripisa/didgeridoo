# Phase 19 — The OXI E16 definition on the website

## Goal

After 2.0.0 the author was asked four things and answered "Ano, udelej
vsechny ctyri veci". Two of them are in this repository: put the instrument
definition for his OXI E16 (written in phase 17, beside the repository) on
the website as a download, and bring `CLAUDE.md` up to date, which still
spoke of overblown toots and of an engine bit-identical to the MPC plugin.
(The other two were the repository's description on GitHub and a rule in his
own notes.)

## Acceptance criteria

- [x] `docs/assets/Didgeridoo.oxiindef` is the definition: the 30 knobs in
      the panel's order with the controller each comes with and the
      controller value of its default place, then the mod wheel and the
      sustain pedal.
- [x] A test holds the file to the engine: written first, it fails without
      the file and when an entry is spoiled.
- [x] The manual's MIDI section links the file, in both languages.
- [x] The CHANGELOG has the line.
- [x] `CLAUDE.md` says what the instrument is since 2.0.0 and where the
      definition lives.
- [x] `swift test` succeeds.

## Decisions

- **The file lives in `docs/assets/` and is served by the website**, not
  attached to a release: it follows the engine's table, not a build, and a
  test can read it where it lies.
- **The test writes the file's text down from the engine's table** and
  compares, and prints that text when it differs, the way the sound's
  references are kept. The core gains no exporter: nothing in the app needs
  one.
- **What the file says** is as phase 17 wrote it: every range 0 to 127
  (the engine spreads a knob's travel over a controller's whole range,
  switches included), real default values, "Rhy to Vowel" for Rhy>Vowel
  (no definition OXI ships has a ">"), no value labels (none of the
  author's eight definitions shows what an entry of them looks like).

## Not in this phase

- Value labels for the switches, a definition for other controllers, an
  export from the app.
