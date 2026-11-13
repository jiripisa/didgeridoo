# Phase 08 — Version 0.6.0 — Verification (2026-11-14)

A minor version: it adds the plug-in's own window and the Octave knob
(phases 05 to 07). The author asked for it to be built and released in one
go; he tries it on another Mac from the download.

| Check | Result |
|---|---|
| `swift test` | 40 tests in 10 suites pass |
| `./build.sh dist` | `status: Accepted` twice, ends with `Done!` |
| `spctl -a -vv` on the app and on the DMG | accepted, `source=Notarized Developer ID` |
| `stapler validate` on the app and on the DMG | both valid |
| `docs/appcast.xml` | version 0.6.0, the URL `…/v0.6.0/Didgeridoo-0.6.0.dmg`, a length equal to the DMG's size; `sign_update --verify` accepts its signature for the DMG |
| The DMG mounted | the app (0.6.0, valid signature, the component with its artwork inside) and the Applications link |
| The notarized component copied out with a quarantine attribute | `auval`: AU VALIDATION SUCCEEDED with 26 parameters and its custom UI; the minimal host of phase 07 gets the 1100 × 680 window from it and closes it without a crash |
| The notarized app started | runs under the hardened runtime; its window matches the website's screenshot (11 of 3.3 million pixels differ), so no new screenshot |
| The icon macOS shows for the notarized app | fills its tile, no light plate |

## Not verified

- The plug-in's window in a real host, and everything else the earlier
  phases list as not verified.
- An installed 0.5.0 offering this update (the author's other Mac will show).
