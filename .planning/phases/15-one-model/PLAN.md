# Phase 15 — One model

## Goal

Since phase 09 the engine has carried two instruments at once: the MPC
plugin's (a saw and a narrow pulse through two speech formants, a band-pass
on the fundamental, a sine that roughens the lips) and the measured one beside
it (a tongue that takes sound away, a tube with its own resonances, a locked
voice), the second resting at 0 so that the first kept sounding as it did.
The author is the only one who plays the instrument so far and has lifted
that condition: build the instrument as the measurements describe it, and
drop what has no counterpart in them.

"Correct" is the conclusion of
`.planning/research/reports/Didgeridoo acoustics and playing.md`: one air
stream through the lips, held back by the vocal tract on one side and shaped
by the tube on the other. The author chose this scope himself ("Jen skutečný
model") after being told that Vocal Wah, Rhythm Breath and Gallop stand on
the parts that go and will sound different.

## What the author's ear said

He heard the demo of 1.0.2 and rejected the overblown notes; asked what was
wrong with them, he ticked every fault offered: they sound like a
synthesizer, the pitch or the jump is wrong, they are too long or too loud,
and "they just do not fit". Everything else he called "super".

## What real toots measure

Nobody has published a toot's spectrum, so this phase measured them:
recordings from Freesound, a pitch track (YIN) and the harmonics of each
overblown note. Eleven toots from five recordings (two solo players, one duo,
two recordings of a held toot alone):

| | Real toots | The engine of 1.0.2 |
|---|---|---|
| Harmonics 2 and 3 against the toot's fundamental | −20 to −37 dB and −22 to −33 dB: nearly a plain tone (one close-miked cylinder: odd harmonics at −3 and −6 dB) | a saw and a narrowed pulse, brightened further: about −6 and −10 dB |
| How the pitch gets there | a jump within 5 to 10 ms, no slide through the pitches between | a slide of 12 ms time constant across 16 semitones |
| Level against the drone before it (eight toots) | +2 to +10 dB, one quieter than the drone; after a dip of 5 to 10 dB that lasts 30 to 60 ms | the drone's level |
| Rise of its level | 40 to 50 ms | at once |
| Length of a stab | 66 to 171 ms; held ones 380 to 635 ms | as long as the key unless Toot Len is set |
| The drone under it (the one solo player who tooted on a drone) | −42 dB under the toot | 3 to 9 dB under it in the programs with the tube |
| Interval | 18.4 to 19.7 semitones in these recordings; 15 to 19 in the literature | 16, equal-tempered |

## The author's second verdict, and what a closer look found

He heard the first build of this phase: "Tak ten novy engine zni o poznani
lepe. Prefuky jsou lepsi, ale stale jsou ve stavu, kdy bych je nepouzival,
protoze zneji neprirozene a umele." The engine as a whole passed his ear;
the toot did not.

The first table measured what a toot is. A second look measured what goes on
inside one, in the same recordings, and found the rebuilt toot a plain tone
that stood still with the breath's hiss on it:

| Inside a toot | Real toots | The first build | Now |
|---|---|---|---|
| What lies above 2 kHz, against the fundamental (seven toots) | −21 to −48 dB, median −35 | −17 to −20 dB: the breath, which grew with the toot's flow | −34 to −40 dB |
| Its level over its length | moves by 5 to 22 dB: a peak that settles, or a swell | within 2 dB | a peak that settles 4 dB lower |
| Its pitch at the start (the two toots whose start can be read) | a squeak of 1.5 and 4 semitones above for 5 to 15 ms, then 10 to 50 cents under the pitch, found within a few tenths of a second | on the pitch at once | a squeak of 1.5 to 3 semitones, then 25 to 60 cents under |
| Its pitch later | wanders over 8 to 64 cents, mostly 20 to 40 | over 15 cents | over 40 cents |
| Harmonics 2 to 5 together (the cylinder apart) | −12 to −22 dB | −24 dB | −21 dB |
| One toot against the next | each different | the same every time | level and pitch differ a little |

Two families of tone are in the recordings: four have the nearly plain tone
this phase builds, one (a close-miked cylinder) has strong odd harmonics, a
horn. Which the author means by an authentic toot is his to say: he gets
both to hear (the horn as a scratch variant, not in the engine).

## Acceptance criteria

- [x] **Lips.** The source is the flow through a valve that is shut for part
      of every cycle: a pulse with a sharp opening and a soft closure, whose
      radiated harmonics fall as 1/n without favouring odd or even ones.
      Buzz sets how hard the lips close; Drive is the valve's own saturation
      (the flow cannot exceed what the pressure allows), no longer a
      distortion after the filters.
- [x] **Mouth.** Only the tongue: Vowel says where the band between the
      tract's resonances sits and how far the tongue is raised, Tongue how
      deep the resonances cut. Formant and Reso are gone.
- [x] **Tube.** Eight resonances placed by the flare that Toot Pitch
      implies (a cylinder at 19 semitones: 1, 3, 5 … times the first), the
      first tall and narrow just under the drone. Body is gone.
- [x] **Voice.** One voice: a second valve in the same air stream, on a
      just interval (fourth, fifth, octave, tenth, twelfth and others),
      with Rough to pull it off the lock so that it beats. Growl is gone;
      aftertouch adds voice.
- [x] **Breath.** The noise passes the lips, so it is chopped at the
      drone's rate.
- [x] **Toot.** A hard hit makes the lips jump to the tube's second
      resonance: the drone stops, the pitch is there within 10 ms, the tone
      is nearly plain (second and third harmonic at least 18 dB under its
      fundamental on a flared tube), it is 3 to 9 dB louder than the drone
      and lasts Toot Len (a stab by default; "Hold" at the top of the knob).
      Toot Pitch runs from 12 to 19 semitones.
- [x] **Defaults** are the measured instrument: the tube and the tongue on,
      a small drift, a bend of one semitone.
- [x] The ten programs keep their names and are voiced again on the model.
- [x] 30 parameters in four groups; the table is ordered by group.
      Identifiers that keep their meaning keep their name.
- [x] State saved by 1.0.x does not load into the new parameters (the
      meaning of several changed): the app starts with the default program.
- [x] The manual in both languages, the website, the README and the
      CHANGELOG describe it.
- [x] `swift test` (debug and release), `swift test --sanitize=thread`,
      `./build.sh debug`, `./build.sh release` and `auval` succeed.
- [x] A demo that plays the same score on 1.0.2 and on this engine, and one
      of the new toots, for the author's ear. Nothing is released before he
      has heard them.

## Decisions

- **A hybrid, not a full physical model.** The pitch stays an input (an
  oscillator's phase), as a keyboard needs; from the physical model come the
  flow through the lips, the junction with the tract and the tube's
  resonances. The research report rates a waveguide lip-reed model as
  fragile: its pitch is an outcome, and it needs a threshold pressure to
  start. It stays an idea in the roadmap.
- **The radiated sound is the flow differentiated.** The lip opening's
  harmonics fall as 1/n² and the tube radiates them 6 dB per octave more
  strongly up to a corner, so the source is the flow's difference from sample
  to sample, scaled by the pitch, through a one-pole low-pass. That corner is
  what Tone always was.
- **The toot's tone comes from the model, not from a setting.** The lips at
  high tension barely close (a nearly sinusoidal flow), and the tube supports
  the toot's fundamental on its second resonance and none of its harmonics,
  unless the tube is a cylinder, where the odd ones meet resonances. The
  earlier brightening rested on sellers' words.
- **The first resonance is damped while the lips toot.** A filter of Q 25
  rings on for a quarter of a second; in the recordings the drone is gone
  under a toot. The damping is a measurement, not a derivation.
- **Voice Pitch is a list of just intervals**, not a number of semitones:
  only those lock, and the tenth (5:2) is the commonest according to the
  literature.
- **The amplitude envelope stays at the output.** Driving the lips with it
  and letting the tube ring out would be closer, but a voice that is never
  quite silent is a worse instrument.
- **No compatibility with 1.0.x**: the author's decision. Parameter
  identifiers and their order change; the Audio Unit's codes do not.
- **What shapes the lips' pulse changes only while the lips are shut.** The
  radiated sound is the flow's rate of change, scaled up a hundredfold at a
  low drone, so a knob that moved the flow in mid-cycle clicked. At the
  bottom of the lips' swing the flow is nothing whatever the shape.
- **Drive rests in the middle.** The measurements call the lip valve
  strongly non-linear, and with the valve at its limit the band near 2 kHz
  stands where 16 recordings of real drones have it (37 dB under the
  fundamental, median); without it the band lay 8 dB lower.
- **Volume rests at 0 dB.** The model's peaks are no longer flattened by a
  distortion at the output, so the sum is kept lower inside and the knob
  makes up for it: a drone is as loud as in 1.0.x. The limiter leaves
  everything under 60 % of full scale alone.
- **The drone after a stab is as loud as the drone before it.** A hard hit
  is the toot's force, not a new level for the drone.
- **Rhythm Breath and Gallop set Volume to +3 and +5 dB**: the pulse ducks
  the level between its steps.
- **Mine, set by measurement and unheard:** the pulse's shape (shut for 60 %
  of the cycle, sharp opening, soft closure), the breath's colour (pink
  noise thinned above 1.5 kHz; nobody has published its spectrum), the
  heights and widths of the tube's upper resonances, and every program's
  values.

## Not in this phase

- A release. The author listens first.
- A waveguide model, stereo, user presets (roadmap).
