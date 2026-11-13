# Phase 07 — The Audio Unit's own window

## Goal

In a host the plug-in was a list of 26 sliders, the host's generic view. Give
it a window of its own with the app's panel of knobs.

## Acceptance criteria

- [x] A host that asks the Audio Unit for its window gets the panel: the
      logo, the Program menu and the knobs of Mouth, Lips and Rhythm. No
      tempo, settings or keyboard (the author's choice).
- [x] Turning a knob sets the unit's parameter and tells the host where the
      gesture begins and ends, so that it can record automation.
- [x] A parameter or a preset the host changes shows in the window.
- [x] Choosing a program in the window loads the factory preset; Octave
      stays where it was.
- [x] The app's window looks as it did: it now shows the same panel.
- [x] `swift test`, `swift test --sanitize=thread`, `./build.sh debug`,
      `./build.sh release` and `auval` (with its custom UI check) succeed.

## Decisions

- **One panel for both.** The knobs, the header and the artwork moved from
  the app into `DidgeridooUI`; the app's window and the plug-in's are that
  panel on two models (`AppModel`, `AudioUnitModel`). The alternative, a
  second panel for the plug-in, would drift from the first.
- **An AUv2 Cocoa view inside the component.** The unit names a class of its
  own bundle in its CocoaUI property; that class makes the SwiftUI panel. So
  the component's library now holds Swift code next to the C++ engine.
- **The window asks the unit for its values 25 times a second.** Hosts move
  parameters (automation, their own controls) without telling a view, so
  listening alone would miss changes; asking is cheap and misses nothing.
- **A knob speaks to the host the standard way**: the value through
  `AUParameterSet`, the drag's begin and end as gesture events.
- **The window is as tall as its knobs need** (1100 × 680), measured, not
  written down, so a knob added later cannot be cut off.
- **What the library exports is set on a target of its own**
  (`DidgeridooAUExports`), so that the tests can link the Audio Unit and run
  it in their own process.
- **Built and released without a written design and without a host test**,
  on the author's word: he tries it on another Mac from the released build.
