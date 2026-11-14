# Phase 12 — Version 1.0.1 — Verification (2026-11-14)

A patch version: the fix of phase 11 (a press on the name of a key C2 to C6
plays the key). The author asked for it to be released.

| Check | Result |
|---|---|
| `swift test` | 51 tests in 11 suites pass |
| `./build.sh dist` | `status: Accepted` for the app and for the DMG, ends with `Done!`; its only warning is `hdiutil`'s own, that its command line is deprecated |
| `spctl -a -vv` on the app and on the DMG | accepted, `source=Notarized Developer ID` |
| `stapler validate` on the app and on the DMG | both valid |
| `docs/appcast.xml` | version 1.0.1, the URL `…/v1.0.1/Didgeridoo-1.0.1.dmg`, a length equal to the DMG's size (10 169 077 bytes), the release note of this version; `sign_update --verify` accepts its signature for the DMG |
| The DMG mounted | the app (1.0.1, valid signature, hardened runtime, the component 1.0.1 inside) and the Applications link |
| The notarized component copied out with a quarantine attribute | `auval`: AU VALIDATION SUCCEEDED with 33 parameters, ten factory presets and its custom UI; the minimal host gets the 1100 × 680 window from it (0 pixels differ from the manual's picture) and closes it without a crash |
| English and Czech pages | the same structure, tag by tag; no screenshot changed (the window looks as it did) |

## Not verified

- **The notarized app was not started.** The system's output was the USB
  interface "M4" at the time, and starting the app opens a stream there. The
  fix itself was checked in phase 11 on the same source file, in the scratch
  app; that the released binary carries it follows from the build, not from
  a click in it.
- The author's own click on a key's name in the released app.
- Everything earlier phases left open.
