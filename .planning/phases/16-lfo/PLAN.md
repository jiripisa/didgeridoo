# Phase 16 — LFOs on the knobs

## Goal

The instrument has one moving part of its own, Wobble: a sine that sways the
vowel. The author wants LFOs that can move its other knobs too ("LFO
parametry", picked from the roadmap's "Modulation"). Two LFOs, and on every
knob that can be moved an amount for each of them.

This phase stands on phase 15 (`feature/15-one-model`), whose sound the
author approved and which is not merged or released yet.

## What the author chose

Asked how an LFO should reach a knob, with three sketches, he took "Míra na
každém knobu": an LFO has only a rate and a shape; two buttons in the
header, LFO 1 and LFO 2, turn the knobs into amounts for that LFO, with an
arc around each knob that shows how far it is moved. Against it stood a
target knob per LFO (one knob moved per LFO, eight more knobs, a taller
window) and one extra LFO beside Wobble.

Told with the question and not objected to: two LFOs; Wobble becomes LFO 1
on Vowel; every continuous knob can be a target, switches cannot; an LFO adds
to a knob's value and does not turn the knob; no tempo sync in this step.

## Acceptance criteria

- [x] **Two LFOs**, each with a rate (0.02 to 20 Hz) and a shape: Sine,
      Triangle, Ramp Up, Ramp Down, Square, Steps (a new random level each
      cycle), Wander (a random level reached smoothly each cycle). They run
      freely; a note does not restart them.
- [x] **An amount per LFO on sixteen knobs**: Vowel, Tongue, Volume, Buzz,
      Drive, Breath, Voice, Rough, Tube, Tone, Flare, Rhy Depth, Rhy>Vowel,
      Rhy Decay, Accent, Breath In. An amount is a part of the knob's travel,
      −100 to +100 %; a negative one turns the movement round. Both LFOs add
      up on a knob, and the sum stays within the knob's travel.
- [x] **Wobble is gone as a pair of knobs**: its rate is LFO 1's, its depth
      is LFO 1's amount on Vowel. The ten programs keep their movement, and
      the sound of phase 15 stays what the author approved.
- [x] **The panel**: LFO 1 Rate, LFO 1 Shape, LFO 2 Rate and LFO 2 Shape
      stand in Mouth where Wobble Rate and Wobble Depth stood; the window
      keeps its size. Two buttons in the header, LFO 1 and LFO 2: with one
      on, dragging a knob sets that LFO's amount on it, shown under the knob
      and as an arc in the LFO's colour; a double click puts the amount back.
      With both off the knobs are what they were, and an arc still shows on
      every knob an LFO moves.
- [x] The amounts are parameters of the engine like any other: stored with
      the sound, set by programs, open to a host's automation. They belong
      to no group of knobs.
- [x] No click when an LFO moves a knob of the lips, and no thread reads
      what another writes without an atomic.
- [x] The manual in both languages, the website, the README and the
      CHANGELOG describe it.
- [x] `swift test` (debug and release), `swift test --sanitize=thread`,
      `./build.sh debug`, `./build.sh release` and `auval` succeed.

## Decisions

- **Amounts are ordinary parameters**, one per LFO and target
  (`lfo1vowel` … `lfo2rhybreath`), 32 in all. The alternative, a table
  beside the parameters, would need its own way into saved state, into the
  Audio Unit's state and to the plug-in's window; as parameters they travel
  every road that exists. The price is 32 more lines in a host's list of
  parameters.
- **An amount is a part of the knob's travel**, not of the value: for Tone,
  whose knob is logarithmic, the same amount is the same musical distance
  anywhere.
- **What an LFO moves is the knob's position as the engine sees it.** The
  position a knob shows, and what is stored, stay where the player put them.
  The engine works out its settings from the moved positions at control rate
  (every 16 samples) while any amount is not zero, and once per block
  otherwise.
- **The LFO knobs live in Mouth**, where Wobble lived, in the order Vowel,
  Tongue, Wheel Vowel, LFO 1 Rate, LFO 1 Shape / LFO 2 Rate, LFO 2 Shape,
  Volume: a group of their own would make the window 53 points taller.
- **Not targets**: the switches (Voice Pitch, Rhythm Div, Pattern, Octave,
  Bend Range), the times (Attack, Release, Glide), Wheel Vowel and Drift,
  which are amounts of something else already, and the LFOs' own knobs.
- **Steps and Wander draw from their own random source**, so that the pitch
  drift's sequence, and with it the approved sound, is untouched.

## Not in this phase

- LFOs locked to the tempo; an LFO on pitch; an envelope as a third source;
  a moving mark that shows where an LFO is.
- Merging or releasing: phase 15 still waits for the author's word.
