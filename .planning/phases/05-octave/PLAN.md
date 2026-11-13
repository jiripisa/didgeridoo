# Phase 05 — Octave

## Goal

Played from an ordinary keyboard the instrument sits two octaves too high: a
didgeridoo's range is two octaves below middle C. Lower the instrument by two
octaves and give the player a knob to move it.

## Acceptance criteria

- [x] A new parameter "Octave" (−2 to +2, at 0 by default), the 26th, in the
      app and in the Audio Unit.
- [x] At Octave 0 a key sounds two octaves lower than it did in 0.5.0; at +2
      it sounds as it did.
- [x] With the test phrase played two octaves higher, the engine renders the
      very samples it rendered before: the sound references do not change.
- [x] Turning Octave while a note sounds slides it to the new octave.
- [x] Loading a program leaves Octave where the player put it.
- [x] The keyboard strip shows C2–C6, so its keys sound as they did.
- [x] The manual in both languages, the website's screenshot, the README and
      the CHANGELOG describe it.
- [x] `swift test`, `swift test --sanitize=thread`, `./build.sh debug`,
      `./build.sh release` and `auval` succeed.

## Decisions

- **A knob, not a fixed shift**, and its 0 is the new pitch, two octaves
  below the old one (the author's choice). The alternative was to lower every
  note for good, without a control.
- **The range is −2 to +2** (my call). +2 is the old pitch, for pads and
  keyboards that start low; the other side is for keyboards set high.
- **The shift is added to the note number when a note starts**, not to the
  pitch afterwards. That keeps every sample of a phrase played two octaves
  higher identical to what the engine rendered before.
- **A sounding note slides to the new octave** at the Glide time, so the
  knob answers at once and without a jump.
- **Programs do not touch Octave** (my call). It describes the player's
  keyboard, not the sound, so choosing another program must not undo it.
- **The knob sits in the Rhythm panel next to Bend Range**: the panel with
  room, and both are about pitch.
