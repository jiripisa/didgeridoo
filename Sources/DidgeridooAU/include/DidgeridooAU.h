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

#endif // DIDGERIDOO_AU_H
