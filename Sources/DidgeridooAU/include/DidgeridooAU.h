// DidgeridooAU.h - identity of the Didgeridoo Audio Unit.
//
// SPDX-License-Identifier: MIT
//
// These four-character codes are permanent: hosts find the plugin and its saved state by
// them. They must match the AudioComponents entry in Resources/AudioUnit-Info.plist.

#ifndef DIDGERIDOO_AU_H
#define DIDGERIDOO_AU_H

#define DIDGERIDOO_AU_TYPE          'aumu'   // music device (instrument)
#define DIDGERIDOO_AU_SUBTYPE       'Didg'
#define DIDGERIDOO_AU_MANUFACTURER  'JPis'

// The component bundle's identifier (CFBundleIdentifier in Resources/AudioUnit-Info.plist) and
// the class in it that makes the plug-in's window (Sources/DidgeridooAUView).
#define DIDGERIDOO_AU_BUNDLE_ID     "io.jp4.didgeridoo.audiounit"
#define DIDGERIDOO_AU_VIEW_CLASS    "DidgeridooAUViewFactory"

#include <AudioToolbox/AudioToolbox.h>

#ifdef __cplusplus
extern "C" {
#endif

// The factory function a host looks up by name (AudioUnit-Info.plist, factoryFunction). It is
// defined by AUSDK_COMPONENT_ENTRY in DidgeridooAU.cpp; declared here for code that registers the
// Audio Unit with its own process, as the tests do.
void* DidgeridooAUFactory(const AudioComponentDescription* inDesc);

#ifdef __cplusplus
}
#endif

#endif // DIDGERIDOO_AU_H
