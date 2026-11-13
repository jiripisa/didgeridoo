# Phase 04 — Version 0.5.0 — Verification (2026-11-13)

The first release. The version is 0.5.0 because the author asked for 0.5;
the skeleton had carried 0.1.0.

| Check | Result |
|---|---|
| `swift test` | 30 tests in 9 suites pass |
| `./build.sh dist` | `status: Accepted` twice, ends with `Done!` |
| `spctl -a -vv` on the app and on the DMG | accepted, `source=Notarized Developer ID` |
| `stapler validate` on the app and on the DMG | both valid |
| `docs/appcast.xml` | version 0.5.0, the URL `…/v0.5.0/Didgeridoo-0.5.0.dmg`, a length equal to the DMG's size; `sign_update --verify` accepts its signature for the DMG |
| The DMG mounted | the app (0.5.0, valid signature, the component inside) and the Applications link |
| The notarized app started | runs under the hardened runtime; the window is the one on the website, so no new screenshot |
| The component copied out with a quarantine attribute, as from a downloaded app | `auval`: AU VALIDATION SUCCEEDED |
| Versions in the bundle | app and component 0.5.0; Audio Unit version 1280 |

## Not verified

- An installed older version offering this update: there is no older version.
- The hands-on checks of phases 02 and 03 are still open.

## Noted

- On macOS 27 `hdiutil create` prints that it is deprecated in favour of
  `diskutil image create`; `build.sh dist` still uses it and it still works.
