# Didgeridoo — project notes for Claude

A playable synthesized didgeridoo: drone, moving overtones, voice, breath and rhythm, as an Audio Unit and a standalone app.

## Code

- Native macOS app, SwiftUI, macOS 14+. Swift Package Manager plus shell
  scripts; there is no Xcode project, so never add one.
- Six targets, from the sound outwards:
  - `Sources/DidgeridooDSP`: the sound engine in C++ (`DidgeridooEngine.cpp`)
    behind a C interface (`include/DidgeridooDSP.h`). Synthesis, the
    parameter table and the built-in programs live here and nowhere else.
  - `Sources/DidgeridooAU`: the Audio Unit (AUv2 instrument, `aumu` / `Didg` /
    `JPis`), a thin C++ layer over the engine on Apple's AudioUnitSDK
    (vendored in `ThirdParty/AudioUnitSDK`; do not edit it).
  - `Sources/DidgeridooCore`: the Swift layer over the engine (`Synth`,
    `Parameter`, `Programs`, `SynthState`), no SwiftUI/AppKit, covered by
    `swift test` (Swift Testing).
  - `Sources/DidgeridooUI`: the instrument's panel in SwiftUI
    (`InstrumentPanel`, `KnobView`), drawn on a model (`InstrumentModel`).
    The app's window and the plug-in's both show it, so the panel changes
    here and nowhere else.
  - `Sources/DidgeridooAUView`: the plug-in's window in a host: the panel on
    the Audio Unit's parameters (`AudioUnitModel`). The unit names its class
    `DidgeridooAUViewFactory` in its CocoaUI property; the code is linked
    into the component next to `DidgeridooAU`.
  - `Sources/Didgeridoo`: the SwiftUI app (window, audio output, MIDI input,
    settings). It stays a thin layer; new logic goes into the core, test first.

  `Sources/DidgeridooAUExports` holds no code, only the linker setting that
  limits what the component exports.
- **The app and the plug-in must sound the same**: change the sound only in
  `DidgeridooDSP`, never in one front end.
- **Identity is permanent.** Parameter identifiers (`"vowel"`, `"rhydepth"`…),
  their order, and the Audio Unit's type / subtype / manufacturer codes must
  never change: saved app state and host projects rely on them. New
  parameters are appended at the end of the table. (2.0.0 rebuilt the table
  once, at the author's word; what it holds since is permanent.)
- **The audio thread** (`didge_process`, the engine's `render`) must not
  allocate, lock, log or do I/O. Expensive maths runs at control rate (every
  16 samples), as the existing code shows. After changing what threads share
  in the engine, run `swift test --sanitize=thread`; it must report nothing.
- The engine is one model of the instrument, built on measurements of real
  didgeridoos: lips as a valve, the tongue, the tube's resonances, a sung
  voice. It replaced the synthesis of the MPC plugin "Didgeridoo" in 2.0.0,
  and it does not overblow (the overblown note did not pass the author's ear
  and was removed). `SoundRegressionTests` holds the sound as references, so
  a change that alters it fails `swift test`: when it is deliberate, copy
  the lines the suite prints over the references and add the CHANGELOG line.
- Build and run: `./run.sh` (debug, logs in the terminal), `./run.sh release`,
  `./build.sh [debug|release|dist|clean]`. Details in `development_workflow.md`.
- Every user-visible change gets a line under `## Unreleased` in
  `CHANGELOG.md`; the release notes and the update dialog come from it.
- After changing the Audio Unit, validate it: copy
  `build/release/Didgeridoo.app/Contents/PlugIns/Didgeridoo.component` to
  `~/Library/Audio/Plug-Ins/Components/` and run `auval -v aumu Didg JPis`
  (`development_workflow.md` §2.1).
- `Resources/Art/*.png` (window background, knob cap, logo) and
  `Resources/AppIcon.png` were generated with Codex; ask it for matching
  artwork when the window needs more.

## Releases

- Use the project skill `release` (`.claude/skills/release/SKILL.md`) for
  every release; it holds the whole procedure and its checks.
- Signing: Developer ID Application certificate and the `notary`
  notarytool profile live in the login Keychain.
- The Sparkle EdDSA private key lives only in the login Keychain. Never put
  it (or an exported copy) into the repo; `Info.plist` holds only the public
  key (`SUPublicEDKey`).

## Website (`docs/`, GitHub Pages)

- Served from `main` / `docs` at https://jiripisa.github.io/didgeridoo/. The download links and
  version strings on the pages are bumped with every release.
- `docs/manual.html` describes every control of the app. A user-visible
  change is not done until the manual says how to use it; screenshots live
  in `docs/assets/manual/`.
- **The site is bilingual.** Every change to `docs/index.html` or
  `docs/manual.html` must also go into `docs/cs/` (and the other way
  round). Shared styles live in `docs/assets/`.
- `docs/assets/Didgeridoo.oxiindef` is an instrument definition for the OXI
  E16 controller, linked from the manual's MIDI section: the knobs by name,
  the MIDI controller each comes with and the controller value of its
  default place. `E16DefinitionTests` fails when the engine's table and the
  file part ways, and prints what the file should read.

## Planning

- Work runs in phases: `.planning/phases/NN-slug/` with `PLAN.md` and
  `VERIFICATION.md`, one feature branch per phase, merged to `main` with
  `--no-ff`; `ROADMAP.md` and `STATE.md` are updated at the end of each
  phase. See `development_workflow.md` §4.
