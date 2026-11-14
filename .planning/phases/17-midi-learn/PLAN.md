# Phase 17 — MIDI learn

## Goal

The author: "Udelej tam prosim jeste funkci midi learn, aby bylo mozno
namapovat knoby na midi kontroler a bylo mozno je ovladat pres CC. A navrhni
i sam defaultni hodnoty CC pro jednotlive parametry."

Every knob listens to a MIDI controller (a CC number), comes with one that
makes sense, and can be taught another by moving a control.

This phase stands on phase 16 (`feature/16-lfo`); phases 15 and 16 are not
merged or released yet.

## Acceptance criteria

- [x] **A controller moves its knob**: a control change on a knob's
      controller puts the knob where the controller's value says (0 the
      bottom of its travel, 127 the top, 64 the middle of a knob that has
      one; switches take the nearest step).
      The knob in the window follows, and the value is stored like any other.
- [x] **Every one of the 30 knobs comes with a controller**, the standard
      one where MIDI has one (Volume 7, Glide 5, Tone 74, Attack 73,
      Release 72 …), no two alike, none that MIDI reserves.
- [x] **Learn**: with the MIDI button in the header on, the knobs show
      their controllers; a click on a knob and a move of a control gives
      that control to the knob. A controller serves one knob: the knob that
      had it before has none. A knob's controller can be taken away or put
      back to the one it came with, and all of them at once.
- [x] **The mod wheel, the sustain pedal and the other controllers MIDI
      gives a fixed meaning cannot be learnt**; the wheel and the pedal do
      what they did.
- [x] **The same in the plug-in**: the Audio Unit answers the controllers
      a host passes to it, its parameters follow (so the host and the
      plug-in's window see the knob move), and the window has the same MIDI
      button.
- [x] **Stored**: the app remembers which controller moves which knob
      between launches; a host saves it with the project. A program does not
      change it.
- [x] The manual in both languages (with the table of controllers), the
      website, the README and the CHANGELOG describe it.
- [x] `swift test` (debug and release), `swift test --sanitize=thread`,
      `./build.sh debug`, `./build.sh release` and `auval` succeed.

## The controllers the knobs come with

Where MIDI names a controller for the thing, the knob has it; the others
fill the numbers MIDI leaves undefined, group by group.

| Knob | CC | Why |
|---|---|---|
| Volume | 7 | Channel Volume |
| Glide | 5 | Portamento Time |
| Vowel | 11 | Expression: a pedal that opens the mouth |
| Drive | 2 | Breath Controller: how hard the lips are blown |
| Buzz | 70 | Sound Variation |
| Tongue | 71 | Timbre / Resonance |
| Release | 72 | Release Time |
| Attack | 73 | Attack Time |
| Tone | 74 | Brightness |
| LFO 1 Rate | 76 | Vibrato Rate |
| Wheel Vowel, LFO 1 Shape, LFO 2 Rate, LFO 2 Shape | 20 to 23 | undefined in MIDI |
| Breath, Drift, Voice, Voice Pitch, Rough | 24 to 28 | undefined |
| Tube, Flare, Bend Range | 29 to 31 | undefined |
| Rhythm Div, Pattern, Rhy Depth, Rhy>Vowel, Rhy Decay, Accent | 85 to 90 | undefined |
| Breath In, Octave | 102, 103 | undefined |

Never given to a knob: 0 and 32 (bank select), 1 (the mod wheel, which
moves the vowel by Wheel Vowel), 6 and 38 (data entry), 64 (the sustain
pedal), 96 to 101 (data increment and decrement, parameter numbers), 120 to
127 (channel mode).

## Decisions

- **The map lives in the engine**, not in the app: the app and the plug-in
  must behave alike, MIDI reaches the engine in both, and a controller then
  moves a knob within the block it arrives in. The alternative, mapping in
  the app's MIDI input, would leave the plug-in without it.
- **In the plug-in the Audio Unit's parameters follow the engine**: after a
  block in which a controller moved a knob, the unit copies the engine's
  values into its own parameters, which is where a host and the plug-in's
  window read them. A host does not record this as automation (there is no
  gesture to it); it has its own MIDI mapping for that.
- **A controller serves one knob.** Two knobs on one control are a mistake
  far more often than a wish, and learn would otherwise leave the old knob
  moving along.
- **A knob jumps to the controller's value** when the control is first
  moved. A soft takeover (waiting until the control passes the knob's
  place) would need the hardware's position, which only a move tells.
- **64 is the middle of a knob that has one** (Rhy>Vowel, -100 … 100 %).
  A value over 127 never comes to a half, so 63 and 64 would stand 0.8 %
  either side of 0 and no value on it. Found while writing the controllers
  down for the OXI E16, whose definition wants each knob's default as a
  controller value.
- **The LFOs' amounts have no controllers** in this step: the MIDI button
  shows the knobs, and an amount is not a knob.
- **The map is not part of a sound**: programs leave it alone, and it is
  stored beside the sound (the app's settings; the Audio Unit's state).

## Not in this phase

- Controllers for the LFOs' amounts; soft takeover; 14-bit controllers and
  NRPN; sending the knobs' values back to a controller.
