# Phase 09 — Player and tube

## Goal

The engine is a synthesizer's idea of a didgeridoo: a buzz through two speech
formants. A study of the published acoustics
(`.planning/research/reports/Didgeridoo acoustics and playing.md`) and a
measurement of a real recording against the engine showed six places where
the real instrument works differently. Give the instrument all six, so that
it can be played as the real one sounds, without changing what it has been
so far.

## Acceptance criteria

- [x] **Tongue.** A raised tongue takes sound away at three resonances of
      the mouth (about −20 dB) and leaves a band between them, which follows
      the vowel between 1 and 2.2 kHz. An open mouth shape has no such band.
- [x] **Tube.** The tube's own resonances: the first just under the drone,
      so that the fundamental stands well above its harmonics; the next ones
      follow the overblown note. A plain pipe (toot a twelfth up) favours
      the odd harmonics, a flared tube does not. The loudness stays.
- [x] **Pitch.** A raised tongue lifts the drone by about a third of a
      semitone (34 cents were measured).
- [x] **Toot.** An overblown note can be a stab of a set length, after which
      the drone of the same key returns while the key is held.
- [x] **Voice.** A sung voice that shares the air stream with the lips and is
      locked in tune with them; a fifth gives the tone an octave below.
- [x] **Rhythm.** Patterns of accented and soft steps, an accent that is a
      surge with a brighter start, and an in-breath of a fifth of a second on
      soft steps.
- [x] Seven new parameters appended to the table (`tongue`, `tube`,
      `tootlen`, `voice`, `rhypattern`, `rhyaccent`, `rhybreath`), all at 0 by
      default. With them at 0 the six programs render the very samples they
      rendered before: their sound references do not change.
- [x] Four new programs that use them (Eucalyptus, Hard Tongue, Pipe, Singer),
      with sound references of their own.
- [x] The panel shows 33 knobs in four groups (Mouth, Lips, Tube, Rhythm), in
      the app and in the plug-in alike.
- [x] The manual in both languages, the website, the README and the
      CHANGELOG describe it.
- [x] `swift test` (debug and release), `swift test --sanitize=thread`,
      `./build.sh debug`, `./build.sh release` and `auval` succeed.

## Decisions

- **New knobs beside the old ones, at rest at 0** (my recommendation; the
  author asked for all six points and left the way open). Saved sounds and
  host projects keep sounding as they did, and the more faithful sound comes
  as new programs. The alternative, changing the engine's defaults, would
  have changed every existing sound.
- **The tongue loads the lip flow; it is not three notch filters.** Three
  resonances stand in the way of one flow and are solved together in each
  sample (`TractResonance`). Between two of them their pulls cancel, so the
  band in the middle keeps nearly its full level (−4 dB) while the harmonics
  on the resonances lose 22 dB. Three separate notches wide enough to be
  heard removed the band as well.
- **The tongue follows the Vowel knob** and whatever moves it (wheel, wobble,
  rhythm): no second control for the same gesture. Below 25 % of Vowel the
  tongue is low and does nothing, as measured with a low tongue.
- **The tube is four band-passes beside the direct sound**, with the level
  brought back so that the knob shapes the sound without making it louder.
  Their places come from Toot Pitch: a real tube overblows on its second
  resonance, so one knob says both where the toot sounds and what kind of
  tube it is.
- **Toot Len 0 means "Hold"**: the toot lasts as long as the key, as before.
- **Voice shares Growl Pitch** and plays the simple ratio of that interval
  (3:2 for a fifth), not the tempered one: players lock the voice to the
  lips, and only then do the undertones stand still.
- **Four fixed patterns** (Even, A-b, A-b-b, A-b-b-A-b-A) instead of a step
  editor: enough for the common traditional figures, and one knob.
- **The panel has four groups, five knobs in a row.** The new group Tube
  takes Toot Vel, Toot Pitch and Glide from Lips, and Bend Range and Octave
  from Rhythm: all of them are about the pitch the tube gives.
- **The new programs' values were set by measurement**, against the spectrum
  of the UNSW recording, not by ear: nobody has listened to them yet.

## Not in this phase

- A physical model of the lips and the bore (a waveguide). The source stays
  an oscillator; the tube and the mouth are filters on it.
- Changes to the six programs taken over from the MPC plugin.
