# Didgeridoo

A playable synthesized didgeridoo: drone, vowels, overblown toots and breath, as an Audio Unit and a standalone app.

One download contains a standalone macOS app (with its own MIDI input and
audio output settings) and an Audio Unit instrument for Ableton Live, Logic
Pro and other hosts; the app installs the plug-in from its Settings window.
Both share one sound engine with 30 parameters and ten built-in programs.

Native macOS (SwiftUI, macOS 14 or later), built with Swift Package Manager
and shell scripts; no Xcode project. The sound engine is C++. The download is
built for Macs with Apple silicon; a build from source runs on the kind of Mac
that built it.

Website and manual: https://jiripisa.github.io/didgeridoo/

## Build and run

You need the Xcode command line tools.

```
./run.sh            # debug build, runs in the terminal with logs (Ctrl+C quits)
./run.sh release    # optimized build, opens the app
swift test          # tests
./build.sh dist     # signed, notarized DMG (needs a Developer ID, see development_workflow.md)
```

Details: [development_workflow.md](development_workflow.md).

## License

MIT License, see [LICENSE](LICENSE). Third-party code and its licences are
listed in [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).
