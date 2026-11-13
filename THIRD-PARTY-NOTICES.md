# Third-party code

Didgeridoo itself is MIT-licensed (see `LICENSE`). It includes:

## MPC Plugin SDK DSP helpers

`Sources/DidgeridooDSP/dsp/*.h` (oscillators, filters, envelope, smoothing,
noise, tempo helpers), copied unchanged from the MPC Plugin SDK.
MIT License, Copyright (c) 2026 inMusic Brands, Inc. The licence text is in
`Sources/DidgeridooDSP/dsp/LICENSE-MPC-SDK.txt`. The state variable filter in
`svf.h` implements Andy Simper's (Cytomic) design.

## Apple AudioUnitSDK

`ThirdParty/AudioUnitSDK/` (version 1.4.0), the base classes the Audio Unit is
built on. Apache License 2.0, Copyright Apple Inc. The licence text is in
`ThirdParty/AudioUnitSDK/LICENSE.txt`. The sources are unmodified.

## Sparkle

Auto-update framework, fetched by Swift Package Manager and embedded in the
app. MIT-style licence, see https://github.com/sparkle-project/Sparkle.
