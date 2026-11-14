# Phase 14 — Version 1.0.2 — Verification (2026-11-14)

A patch version: the overblow band of phase 13 (a click in the band at the
lower end of a key overblows the note, a click anywhere else never does).
The author asked for it to be released.

| Check | Result |
|---|---|
| `swift test` | 56 tests in 12 suites pass |
| `./build.sh dist` | `status: Accepted` for the app and for the DMG, ends with `Done!`; its only warning is `hdiutil`'s own, that its command line is deprecated |
| `spctl -a -vv` on the app and on the DMG | accepted, `source=Notarized Developer ID` |
| `stapler validate` on the app and on the DMG | both valid |
| `docs/appcast.xml` | version 1.0.2, the URL `…/v1.0.2/Didgeridoo-1.0.2.dmg`, a length equal to the DMG's size (10 175 301 bytes), the release note of this version; `sign_update --verify` accepts its signature for the DMG |
| The DMG mounted | the app (1.0.2, valid signature, hardened runtime, the component 1.0.2 inside) and the Applications link |
| The released binary | carries the symbols of `KeyStrip`, the rule the band follows |
| The notarized component copied out with a quarantine attribute | `auval`: AU VALIDATION SUCCEEDED with 33 parameters and its custom UI. The plug-in itself did not change in this version |
| English and Czech pages | the same structure, tag by tag (73 and 292 tags) |

## Not verified

- **The notarized app was not started.** The system's output was the USB
  interface "M4" at the time, and starting the app opens a stream there. The
  band was checked in phase 13 on the same source files, in the scratch app;
  that the released binary carries it follows from the build and from its
  symbols, not from a click in it.
- **The window's picture on the website is still the composite of phase 13**
  (the real window of 1.0.0 with the rows of the keys from the scratch app's
  render), for the same reason. Take it from the real app at the next
  release if the output allows.
- The author's own click in the band and above it in the released app.
- Everything earlier phases left open.
