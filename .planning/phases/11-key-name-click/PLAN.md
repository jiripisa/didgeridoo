# Phase 11 — A click on a key's name

## Goal

The author reported that a key of the app's keyboard strip is sometimes dead
under the mouse, "for example C2", and plays only after a neighbouring key
was played. Find out why and fix it.

## Acceptance criteria

- [x] The cause is found by reproducing the fault, not by guessing.
- [x] A press anywhere on a key of the strip plays that key.
- [x] The CHANGELOG says so. The manual needs no change: no control changed.
- [x] `swift test`, `./build.sh debug` and `./build.sh release` succeed.

## What it was

The keys C2 to C6 carry their name at the bottom. The name lay on top of the
key as a view of its own, outside the key's gesture, so a press on the name
(about 12 × 9 points, in the lower middle of the key, where one aims for a
firm hit) reached the name and not the key. Every other spot of the strip
played. A neighbouring key has no name, so it always played; going back to
the C key the pointer then landed beside the name.

## Decisions

- **The name lets presses through** (`allowsHitTesting(false)`), the smallest
  change that removes the cause. The name stays where it is.
- **No automatic test in the suite.** A gesture answers only in the key
  window of an active app, which `swift test` does not have. The fault and
  the fix were checked with a scratch app that clicks on the real strip
  (`VERIFICATION.md`).

## Not in this phase

Two things the reproduction showed that are how the strip is meant to work
today, left for the author to decide:

- A press into a window that is not the active one only activates it, as
  everywhere on the Mac; the key plays from the second press.
- A note lasts as long as the mouse button is down. A press shorter than
  about 20 ms (a tap on a trackpad set to "tap to click") is nearly silent:
  the note is let go before its attack has risen.
