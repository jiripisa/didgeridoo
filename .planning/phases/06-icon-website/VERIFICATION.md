# Phase 06 — Verification (2026-11-14)

| Check | Result |
|---|---|
| The icon macOS 27 shows for the app (rendered through `NSWorkspace`), before | the artwork small on a light rounded plate: the border the author saw |
| The same for three candidates in test bundles: a square covering the whole image, the classic tile, the classic tile with its shadow | all three fill the tile with no plate |
| The same for `build/release/Didgeridoo.app` built with the new `Resources/AppIcon.png` | fills the tile, no plate |
| The new icon file itself | 1024 px, the classic rounded tile with transparent margins and a soft shadow |
| The website in headless Chrome: overview and manual at 1440 px, the Czech overview at 500 px | dark ground, dotted rings from the top right corner and from the foot of the page, readable text, no overflow on the narrow screen |
| English and Czech pages | the same structure, tag by tag |

## Not verified

- The icon on macOS 14 and 15 (it has their standard shape, but no such Mac
  was at hand).
- The website in Safari and on a phone.
