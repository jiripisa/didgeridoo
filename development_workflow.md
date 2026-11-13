# Didgeridoo — Development Workflow, Build & Distribution

## 1. Toolchain & Project Layout

- Xcode command line tools (Swift 6), macOS 14+. No Xcode project: Swift
  Package Manager builds the code, `build.sh` assembles the `.app` bundle.

```
didgeridoo/
├── Package.swift
├── Sources/DidgeridooDSP/       # the sound engine: C++ with a C interface
│   ├── include/DidgeridooDSP.h  #   what Swift and the Audio Unit call
│   ├── DidgeridooEngine.cpp     #   synthesis, parameters, programs
│   └── dsp/                     #   oscillators, filters… (MIT, from the MPC Plugin SDK)
├── Sources/DidgeridooAU/        # the Audio Unit (AUv2 instrument), C++
├── Sources/DidgeridooCore/      # Swift layer over the engine, no UI, tested
├── Sources/Didgeridoo/          # SwiftUI app: window, audio out, MIDI in, settings
├── Tests/DidgeridooCoreTests/   # Swift Testing
├── ThirdParty/AudioUnitSDK/     # Apple's AudioUnitSDK (Apache-2.0), vendored
├── Resources/               # Info.plist, AudioUnit-Info.plist, entitlements,
│                            # AppIcon.png (1024 px), Art/ (window artwork)
├── scripts/make_appcast.py  # Sparkle feed, called by build.sh dist
├── docs/                    # GitHub Pages website + manual
├── build.sh                 # debug | release | dist | clean
└── run.sh                   # debug (logs in terminal) | release (open .app)
```

## 2. Build (`build.sh`)

| Command | Result |
|---|---|
| `./build.sh` / `./build.sh debug` | `swift build` → `build/debug/Didgeridoo.app` (ad-hoc signed) |
| `./build.sh release` | same with `-c release` → `build/release/Didgeridoo.app` |
| `./build.sh dist` | release build → **Developer ID signing (hardened runtime)** → notarized + stapled app → **DMG** → notarized + stapled DMG → `docs/appcast.xml` |
| `./build.sh clean` | removes `build/` and `.build/` |

### 2.1 App-bundle assembly (all modes)

Executable → `Contents/MacOS`, `Resources/Info.plist` → `Contents/`,
`Resources/AppIcon.png` → `AppIcon.icns` (sips + iconutil), Sparkle.framework →
`Contents/Frameworks` (XPC services removed; the app is unsandboxed), PkgInfo,
then an ad-hoc signature with the entitlements; a signature that fails stops
the build. New resource files must be copied in `build.sh` explicitly. `Resources/Art/` (background, knob cap, logo)
goes to `Contents/Resources/Art`.

**The Audio Unit** is assembled in the same step: `libDidgeridooAU.dylib` →
`Contents/PlugIns/Didgeridoo.component/Contents/MacOS/Didgeridoo`, with
`Resources/AudioUnit-Info.plist` as its `Info.plist`. The dylib exports only
the factory function `DidgeridooAUFactory` (`Package.swift`), because a
plug-in shares the host's process with other plug-ins. `build.sh` writes the
app's version into that plist (both strings and the numeric
`AudioComponents` version), so the version is bumped in one place. The
component is signed before the app (ad-hoc, or Developer ID + hardened runtime
in `dist`). Users install it from the app: Settings › Install Audio Unit
copies it to `~/Library/Audio/Plug-Ins/Components`.

Check a build of the plug-in with Apple's validator:

```
cp -R build/release/Didgeridoo.app/Contents/PlugIns/Didgeridoo.component ~/Library/Audio/Plug-Ins/Components/
auval -v aumu Didg JPis        # must end with AU VALIDATION SUCCEEDED
```

### 2.2 Distribution (`dist`)

`dist` first asks `scripts/make_appcast.py --check` whether `CHANGELOG.md`
has release notes under `## <version>` for the version in `Info.plist`, and
stops at once if not: the appcast takes its release notes from that section.

1. Sign Sparkle's parts inside-out, then the app with the first "Developer ID
   Application" identity in the Keychain, hardened runtime, timestamp.
2. Notarize the zipped app (`notarytool --keychain-profile notary --wait`), staple it.
3. Build `build/Didgeridoo.dmg` (app + Applications symlink), sign, notarize, staple.
4. `scripts/make_appcast.py` signs the stapled DMG with Sparkle's `sign_update`
   (EdDSA private key from the login Keychain) and writes `docs/appcast.xml`:
   version, release notes from the CHANGELOG section, the GitHub Release
   download URL, length and signature. Create the GitHub Release (DMG uploaded
   as `Didgeridoo-<version>.dmg`) **before** pushing the appcast, so the feed
   never points at a missing file.

A notarization `HTTP status code: 403. A required agreement is missing or has
expired` is an account issue: accept the updated agreement at
developer.apple.com/account.

### 2.3 One-time signing setup (per machine)

1. A **Developer ID Application** certificate in the login keychain.
2. A stored notarization profile named `notary` (or set `NOTARY_PROFILE`):
   ```
   xcrun notarytool store-credentials notary \
     --apple-id <apple-id-email> --team-id <TEAMID> --password <app-specific-password>
   ```
3. The Sparkle EdDSA key: `.build/artifacts/sparkle/Sparkle/bin/generate_keys`
   keeps the private key in the login Keychain and prints the public key that
   lives in `Info.plist` (`SUPublicEDKey`). Back it up
   (`generate_keys -x <file>`, kept offline): without it no update can ever be
   signed for existing installs again.

### 2.4 Entitlements & sandbox policy

The app ships **unsandboxed** (`com.apple.security.app-sandbox = false`),
which is fine for Developer ID / DMG distribution; Gatekeeper needs the
hardened runtime and notarization. Add entitlements to
`Resources/Didgeridoo.entitlements` only when a feature needs them.

## 3. Run (`run.sh`)

- `./run.sh debug` *(default)* — rebuilds when a source, a resource or
  `Package.swift` is newer than the binary, registers the bundle with Launch
  Services, then runs the binary in the terminal: logs stream live, Ctrl+C quits.
- `./run.sh release` — rebuilds on the same condition, then `open`s the app.

## 4. Development Methodology

- Sound goes into `DidgeridooDSP` (C++), everything else without UI into
  `DidgeridooCore`, test first (`swift test`); the UI is checked by running
  the app, the plug-in with `auval` and in a host.
- The sound is guarded: `SoundRegressionTests` holds a fingerprint and the
  levels of every program at 44.1 and 48 kHz, so a change in `DidgeridooDSP`
  that alters one sample fails `swift test`. When the change is deliberate,
  say so in the CHANGELOG and copy the lines the suite prints over its
  references.
- After a change in what threads share in the engine, also run
  `swift test --sanitize=thread`; it must report nothing.
- Conventional Commits with a scope: `feat(core): …`, `fix(ui): …`,
  `docs(manual): …`, `chore(release): v1.2.0 — …`.
- `main` is always green: builds, tests pass, the app launches.

### Phases

- `.planning/ROADMAP.md` lists phases (newest first) with status;
  `.planning/STATE.md` says where work stands and what comes next.
- One phase = `.planning/phases/NN-slug/` (`PLAN.md`, `VERIFICATION.md`) =
  one branch `feature/NN-slug` = one `--no-ff` merge into `main`.
- Definition of done: acceptance criteria checked, `swift test` green, app
  built and run, CHANGELOG and manual updated, ROADMAP/STATE updated.

### Versioning & releases

- The version lives in `Resources/Info.plist` (`CFBundleShortVersionString`
  and `CFBundleVersion`), semantic versioning; the first release was 0.5.0.
- Releases follow the project skill `.claude/skills/release/SKILL.md`.
- Pushes to GitHub happen only after explicit confirmation.
