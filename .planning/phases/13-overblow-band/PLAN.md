# Phase 13 — The overblow band

## Goal

The author reported that after moving knobs a click on C3 sometimes sounds
far too high ("like C4"), and that C3 is right again after another key was
played. Find out why and make the keyboard strip behave so that this cannot
surprise anyone.

## What it was

Not the knobs. The lowest 9 of a key's 64 points were the hardest hit
(velocity 115 and more), which overblows the note: 16 semitones up, and no
drone. Nothing on the key showed it, and the key's name lay across the edge
of that zone (51 to 60 points down). Until 1.0.0 a click on the name did
nothing; since 1.0.1 it plays, and its lower half overblew.

A random search of the engine (2000 runs: play something, move one to six
knobs, play C3, C2, C3) found no case in which the first C3 sounded at
another pitch than the second, apart from a long Glide sliding in from a note
that was still dying away, which is what Glide is for.

## Acceptance criteria

- [x] The cause is found by reproducing it, on the real strip and in the
      engine.
- [x] Every key shows a band at its lower end. A click in the band always
      overblows (the hardest hit), a click anywhere above it never does,
      wherever Toot Vel stands.
- [x] Above the band the height of the click still sets how firm the hit is.
- [x] The keys' names sit above the band.
- [x] With Toot Vel at "Off" nothing overblows and the keys show no band.
- [x] The rule is in the core, tested first; the manual in both languages,
      the website's picture and the CHANGELOG describe it.
- [x] `swift test`, `./build.sh debug` and `./build.sh release` succeed.

## Decisions

- **A visible band** (the author's choice among four: the band, Shift-click,
  no overblowing by mouse, or only moving the names).
- **The band is the hardest hit, 127; above it the hit runs from 40 to 110
  and stays under Toot Vel** (`KeyStrip.velocity`). The knob still decides
  where overblowing starts for a MIDI keyboard; on the strip the band decides,
  so that what the key shows is what it does.
- **The band is 10 points high on white and on black keys alike**, an eye's
  width for the mouse; on a black key it is the lower quarter.
- **No band when Toot Vel is "Off"**: there is nothing to overblow, and a
  band that does nothing would be a lie.

## Not in this phase

- A first click into a window that is not active, and clicks shorter than
  about 20 ms (phase 11's notes): unchanged.
