# Phase 06 — Icon and website look

## Goal

The app's icon shows a light border on current macOS, and the website looks
like any other page. Make the icon cover its whole tile and give the website
the instrument's look, with a light ethnic graphic behind it (the author's
request).

## Acceptance criteria

- [x] macOS draws the app's icon across the whole tile, with no light plate
      around it.
- [x] The icon still has the classic rounded shape for macOS 14 and 15, which
      draw an icon as it is.
- [x] The website (overview and manual, English and Czech) wears the app's
      colours and has a dotted graphic in the background; it reads well on a
      wide and on a narrow screen.

## Decisions

- **The icon is the same artwork in Apple's classic tile** (824 px of 1024,
  rounded, soft shadow). The old picture was a tile of a slightly different
  size, which macOS 26 and later do not take for an icon shape and put on a
  light plate. A square covering the whole image was the other candidate; it
  looks the same on macOS 27 but would be a plain square on macOS 14 and 15.
- **One look for the website, the app's own**: dark wood for the ground,
  white clay for text, yellow ochre for what can be pressed. It no longer
  follows the system's light appearance.
- **The background graphic is a sound**: rings of dots spreading from a
  corner, in ochre, red ochre and clay, echoing the rings of the logo. It is
  abstract on purpose and copies no traditional design.
- **Headings use the system's rounded face**, close to the logo's letters;
  the overview's heading is the logo itself.
