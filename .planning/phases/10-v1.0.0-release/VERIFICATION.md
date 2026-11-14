# Phase 10 — Version 1.0.0 — Verification (2026-11-14)

The author named the version: 1.0.0. It carries phase 09 (the tongue, the
tube, the toot's length, the locked voice, the rhythm's patterns, four new
programs, the fourth panel). He tries it on another Mac from the download;
nobody has listened to phase 09 yet.

| Check | Result |
|---|---|
| `swift test` | 51 tests in 11 suites pass |
| `./build.sh dist` | `status: Accepted` for the app and for the DMG, ends with `Done!`; its only warning is `hdiutil`'s own, that its command line is deprecated |
| `spctl -a -vv` on the app and on the DMG | accepted, `source=Notarized Developer ID` |
| `stapler validate` on the app and on the DMG | both valid |
| `docs/appcast.xml` | version 1.0.0, the URL `…/v1.0.0/Didgeridoo-1.0.0.dmg`, a length equal to the DMG's size (10 168 414 bytes), nine entries of release notes with the nested list closed; `sign_update --verify` accepts its signature for the DMG |
| The DMG mounted | the app (1.0.0, valid signature, hardened runtime, the component 1.0.0 with its artwork inside) and the Applications link |
| The notarized component copied out with a quarantine attribute | `auval`: AU VALIDATION SUCCEEDED with 33 parameters, ten factory presets and its custom UI; the minimal host gets the 1100 × 680 window from it (0 pixels differ from the manual's picture) and closes it without a crash |
| The notarized app started (its sound went to the MacBook's speakers, silence only) | runs under the hardened runtime and quits when asked; its window shows the four panels with 33 knobs and the whole keyboard |
| The website's screenshot | replaced by the picture of that window. The silent stand-in of phase 09 had drawn a title bar 4 points higher than the real app's, so the manual's frames were placed again (headless Chrome: each sits on its area) |
| English and Czech manual and home page | the same structure, tag by tag |

## Not verified

- How phase 09 sounds: see `phases/09-player-and-tube/VERIFICATION.md`.
- The plug-in in a real host, and everything else the earlier phases list as
  not verified.
- An installed 0.6.0 offering this update (the author's other Mac will show).
