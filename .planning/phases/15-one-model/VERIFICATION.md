# Phase 15 — Verification (2026-11-14)

Nothing here was judged by ear. Every claim about the sound is a measurement
of what the engine renders, set against measurements of recordings of real
instruments. The author listens to three demo files before anything is
released (see the end).

## The sound against real instruments

**The overblown note.** Eleven toots in five recordings from Freesound (two
solo players, a duo, two recordings of a held toot alone), found with a pitch
track and measured one by one, against the engine: a drone at velocity 100
and then a hard hit on the same key, in every program.

| | Real toots | 1.0.2 | This phase |
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

**Inside a toot** (after the author found the first build's toots still
artificial): the same recordings, looked at for what moves inside a toot.

| | Real toots | The first build | Now |
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
| `swift test`, and the same in a release build | 77 tests in 12 suites pass in both |
| A debug and a release build | render the same samples (the suite's references hold for both). They did not at first: an optimised build turned a power of 8 into `exp2` of a product, which rounds differently |
| `swift test --sanitize=thread` | no report |
| Lips (`ModelTests`) | harmonics 3 to 16 follow 1/n within 6 dB, odd and even alike within 3 dB; Buzz 0 loses more than 15 dB at the 24th harmonic against Buzz 100; Drive adds harmonics and leaves the tongue's notches more than 12 dB deep; the breath's noise is more than 8 dB stronger while the lips are open |
| Turning Buzz, Drive or Voice while a note sounds | no click: the steepest step in the 50 ms after the turn stays under 1.5 times the steady sound's. Before the shape was held until the lips are shut, all four cases failed |
| Tongue | the band stands more than 12 dB above the harmonics on the tract's resonances; no band with an open mouth; the drone rises 28 to 42 cents |
| Tube | the fundamental gains more than 8 dB on its neighbours; a cylinder favours the odd harmonics by more than 5 dB over a flared tube; the tube follows a legato note |
| Toot | second and third harmonic more than 18 dB under its fundamental; 40 ms after the hit nothing at a pitch between drone and toot (more than 18 dB under the toot); 3 to 9 dB louder than the drone; the drone more than 20 dB under a held toot; a stab by default, held with Toot Len at Hold; the drone after a stab within 1 dB of the drone before it |
| Inside a toot (`ModelTests`) | what lies above 2 kHz is more than 30 dB under its fundamental; its first tenth of a second is 2 to 8 dB louder than what follows; 30 to 70 ms in, its pitch is 8 to 70 cents under where it settles; four stabs in a row differ in level by 0.3 to 4 dB. All four tests failed on the first build |
| Voice | a fifth adds the tone an octave below the drone; aftertouch brings it in; locked it stands still (under 1 dB), with Rough at 60 % the tone under the drone wanders by more than 3 dB |
| The loudest setting | Volume at +6 dB, a hit at 110 and a toot on it, in every program: the output stays within full scale. It did not while the limiter stood before the volume |
| Stored state | round-trips through its stored form; state stored by 1.0.x (no model number) is not applied, the app starts with Classic Drone |
| Anything in the sound that is not a harmonic (keys 62, 86, and 84 at Octave +2; 44.1, 48 and 96 kHz) | at least 76 dB under the fundamental, the same at every rate |
| Breath at 15 % | its noise lies 16.0 dB under the tone (14.8 dB in 1.0.2) |
| Loudness of the ten programs, a drone at velocity 100 | −17.3 to −19.6 dBFS, Rhythm Breath and Gallop apart (their Volume is +3 and +5 dB for the pulse that ducks them); 1.0.2 at its Volume of −6 dB: −18.4 dBFS for Classic Drone |
| Speed, optimised | two minutes of sound render in 0.15 to 0.19 s (0.11 to 0.12 s in 1.0.2) |
| `./build.sh debug`, `./build.sh release` | succeed without compiler warnings; `codesign --verify --deep --strict` passes for both bundles; the component exports only `_DidgeridooAUFactory` |
| `auval -v aumu Didg JPis` on the release build's component | AU VALIDATION SUCCEEDED: 30 parameters in four groups, factory presets, "Cocoa Views Available: 1" |
| A minimal host (a scratch program) with that component | its window is 1100 × 680 with the 30 knobs; closing and disposing does not crash |
| The app's window, from a silent stand-in (the app's real `ContentView` and `AppModel`, stand-ins for `AudioOutput` and `MIDIInput`) | 1100 × 758 as before, 30 knobs in the four groups, Volume drawn as an ordinary knob |
| English and Czech manual and home page | the same structure, tag by tag (277 and 73 tags); no control of 1.0.x is left in them |
| The demo of the new toots, measured after writing | 21 toots: each within 0.7 semitones of its pitch (the lips land under it), second and third harmonic more than 15 dB under it, 2.6 to 9.7 dB louder than its part's drone, the drone more than 20 dB under the held ones |

## Not verified

- **How any of it sounds.** The shape of the lips' pulse, the breath's
  colour, the tube's upper resonances, the toot's level and rise, and every
  program's values were set by measurement. The author heard the first
  build (`~/Desktop/Didgeridoo-A-old-1.0.2.wav`, `Didgeridoo-B-new.wav`,
  `Didgeridoo-C-new-toots.wav`): the engine "zní o poznání lépe", the toots
  still "nepřirozeně a uměle". For the toots as they are now he has
  `Didgeridoo-D-toots-2.wav`, and `Didgeridoo-E-toots-2-horn.wav` with a
  richer tone that is not in the engine (the lips close harder on the toot:
  second and third harmonic at −15 and −20 dB), to say which way to go.
- **The real app was not started**, and nothing was played: the system's
  output was the USB interface "M4". The window's picture on the website is
  the stand-in's drawing under the title bar of the earlier picture.
- The plug-in in a real host. A project saved with 1.0.x restores its 33
  values into the 30 new parameters by number, which is wrong for most of
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
