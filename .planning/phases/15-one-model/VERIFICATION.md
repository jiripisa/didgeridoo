# Phase 15 — Verification (2026-11-14)

Every claim about the sound here is a measurement of what the engine
renders, set against measurements of recordings of real instruments. The
author's ear judged the result three times (see the plan): the engine is
"o poznání lepší" than 1.0.2 and "zvuk je parádní"; the overblown note did
not pass in any of its three builds and was taken out.

## The sound against real instruments

**The overblown note, as it was before it was removed** (kept as a record).
Eleven toots in five recordings from Freesound (two
solo players, a duo, two recordings of a held toot alone), found with a pitch
track and measured one by one, against the engine: a drone at velocity 100
and then a hard hit on the same key, in every program.

| | Real toots | 1.0.2 | The first build |
|---|---|---|---|
| Second harmonic against the toot's fundamental | −20 to −37 dB (a close-miked cylinder apart: −16, with odd harmonics at −3 and −6) | about −6 dB | −24 to −28 dB |
| Third harmonic | −22 to −33 dB | about −10 dB | −28 to −33 dB |
| The pitch gets there | in 5 to 10 ms, by a jump | by a slide across 16 semitones | 9 ms after the hit, by a jump |
| Level against the drone before it (eight toots) | +2 to +10 dB, one quieter than the drone | the drone's | +3.3 to +7.4 dB |
| Rise of its level | 40 to 50 ms | at once | about 50 ms |
| The drone's fundamental under a held toot | −42 dB (the one solo player who tooted on a drone) | 3 to 9 dB under it (tube programs) | −37 to −50 dB |
| Length | stabs of 66 to 171 ms, held ones 380 to 635 ms | the key's | 120 ms as it comes (100 to 200 in the programs) |

**The drone.** Sixteen recordings of real drones (Freesound): the strongest
harmonic in each band against the fundamental, median of the sixteen, and
Classic Drone, the instrument as it comes.

| Band | Real drones (median; range) | Classic Drone |
|---|---|---|
| 0.5–0.8 kHz | −21 dB (−8 to −37) | −21 dB |
| 0.8–1.2 kHz | −29 dB (−11 to −41) | −18 dB |
| 1.2–1.6 kHz | −34 dB (−22 to −53) | −32 dB |
| 1.6–2.2 kHz | −37 dB (−23 to −58) | −38 dB |
| 2.2–3 kHz | −42 dB (−31 to −64) | −45 dB |

Harmonics 2 to 8 of Classic Drone lie 11 to 21 dB under the fundamental; in
the recordings harmonics 2 to 5 lie 10 to 27 dB under it where the tube is
not a cylinder. Pipe (a cylinder) has its third, fifth and seventh harmonic
at −10, −15 and −18 dB and the even ones at −22 to −26; the UNSW recording of
a plastic pipe has −11, −16 and −16 dB.

**Inside a toot, likewise a record** (after the author found the first build's toots still
artificial): the same recordings, looked at for what moves inside a toot.

| | Real toots | The first build | The last build |
|---|---|---|---|
| Above 2 kHz, against the toot's fundamental (seven toots) | −21 to −48 dB, median −35 | −17 to −20 dB | −34 to −40 dB |
| Level over the toot's length | moves by 5 to 22 dB | within 2 dB | 7 dB: a peak, then 4 dB lower |
| Pitch at the start (the two toots whose start can be read) | a squeak above, then 10 to 50 cents under the pitch | on the pitch at once | a squeak above, then about 40 cents under |
| Pitch later | wanders over 8 to 64 cents, mostly 20 to 40 | 15 cents | 40 cents |
| Harmonics 2 to 5 together (the cylinder apart) | −12 to −22 dB | −24 dB | −21 dB |

## Checks

| Check | Result |
|---|---|
| The new tests before the engine changed | failed: 68 tests, 44 issues (no such parameters; the old toot, lips and voice) |
| `swift test`, and the same in a release build | 67 tests in 12 suites pass in both |
| A debug and a release build | render the same samples (the suite's references hold for both). Twice they did not: an optimised build turned a power of 8 into `exp2` of a product, which rounds differently; and after the toot was removed it fused products and sums that the debug build kept apart (Vocal Wah and Hard Tongue differed in their last bit). The engine now says `exp2` itself and keeps products and sums unfused |
| `swift test --sanitize=thread` | no report |
| Lips (`ModelTests`) | harmonics 3 to 16 follow 1/n within 6 dB, odd and even alike within 3 dB; Buzz 0 loses more than 15 dB at the 24th harmonic against Buzz 100; Drive adds harmonics and leaves the tongue's notches more than 12 dB deep; the breath's noise is more than 8 dB stronger while the lips are open |
| Turning Buzz, Drive or Voice while a note sounds | no click: the steepest step in the 50 ms after the turn stays under 1.5 times the steady sound's. Before the shape was held until the lips are shut, all four cases failed |
| Tongue | the band stands more than 12 dB above the harmonics on the tract's resonances; no band with an open mouth; the drone rises 28 to 42 cents |
| Tube | the fundamental gains more than 8 dB on its neighbours; a cylinder favours the odd harmonics by more than 5 dB over a flared tube; the tube follows a legato note |
| Voice | a fifth adds the tone an octave below the drone; aftertouch brings it in; locked it stands still (under 1 dB), with Rough at 60 % the tone under the drone wanders by more than 3 dB |
| No overblown note (`ModelTests`, `KeyStripTests`) | the hardest hit, from silence and on a sounding drone, is a drone on the key's pitch: nothing between its second and third harmonic comes within 20 dB of the fundamental, and it is louder than a softer hit. A press on the app's keyboard runs from 40 at the top of a key to 127 at its bottom without a jump |
| The sound the author approved | the score of the file he heard (`Didgeridoo-B-new.wav`), rendered by the engine without the toot: the difference lies 46.8 dB under the signal (33 dB in the worst second, a release tail). It is the tubes' flare rounded to whole percent |
| The loudest setting | Volume at +6 dB, a hit at 110 and the hardest hit on it, in every program: the output stays within full scale. It did not while the limiter stood before the volume |
| Stored state | round-trips through its stored form; state stored by 1.0.x (no model number) is not applied, the app starts with Classic Drone |
| Anything in the sound that is not a harmonic (keys 62, 86, and 84 at Octave +2; 44.1, 48 and 96 kHz) | at least 76 dB under the fundamental, the same at every rate |
| Breath at 15 % | its noise lies 16.0 dB under the tone (14.8 dB in 1.0.2) |
| Loudness of the ten programs, a drone at velocity 100 | −17.3 to −19.6 dBFS, Rhythm Breath and Gallop apart (their Volume is +3 and +5 dB for the pulse that ducks them); 1.0.2 at its Volume of −6 dB: −18.4 dBFS for Classic Drone |
| Speed, optimised | two minutes of sound render in 0.15 to 0.19 s (0.11 to 0.12 s in 1.0.2) |
| `./build.sh debug`, `./build.sh release` | succeed without compiler warnings; `codesign --verify --deep --strict` passes for both bundles; the component exports only `_DidgeridooAUFactory` |
| `auval -v aumu Didg JPis` on the release build's component | AU VALIDATION SUCCEEDED: 28 parameters in four groups, factory presets, "Cocoa Views Available: 1" |
| A minimal host (a scratch program) with that component | its window is 1100 × 680 with the 28 knobs; closing and disposing does not crash |
| The app's window, from a silent stand-in (the app's real `ContentView` and `AppModel`, stand-ins for `AudioOutput` and `MIDIInput`) | 1100 × 758 as before, 28 knobs in the four groups, the keyboard without its band, Volume drawn as an ordinary knob |
| English and Czech manual and home page | the same structure, tag by tag (267 and 73 tags); no control of 1.0.x and no word of the overblown note is left in them |

## Not verified

- **The values nobody has heard one by one.** The author heard the ten
  programs in one score and approved the sound as a whole. The shape of the
  lips' pulse, the breath's colour, the tube's upper resonances and each
  program's values were set by measurement, and no knob was judged by ear
  across its travel.
- **The real app was not started**, and nothing was played: the system's
  output was the USB interface "M4". The window's picture on the website is
  the stand-in's drawing under the title bar of the earlier picture.
- The plug-in in a real host. A project saved with 1.0.x restores its 33
  values into the 28 new parameters by number, which is wrong for most of
  them; nothing guards against it.
- The recordings behind the tables are what Freesound offers under the word
  "didgeridoo": mostly unknown instruments and players, MP3 previews at
  128 kbit/s, none of them Yolŋu playing. They say what didgeridoos commonly
  sound like, not what a good yidaki does.
- The component installed on this Mac is the released 1.0.2 again; the new
  one was put there only for `auval` and the minimal host.
- Everything earlier phases left open.

The scratch tools (the toot finder, the spectrum measurements, the demo
scores, the minimal host, the stand-in of the app) are not part of this
repository.
