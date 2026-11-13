# Changelog

## 0.6.0 — 2026-11-14

- The Audio Unit has a window of its own in the host: the app's panel, with
  the Program menu and the knobs of Mouth, Lips and Rhythm. The knobs follow
  the host's automation, and turning one can be recorded as automation.
- New knob Octave (−2 to +2) in the Rhythm panel. At 0, where it rests, the
  instrument plays two octaves lower than version 0.5.0 did, so that a
  didgeridoo's range sits around middle C; +2 is the old pitch. Projects
  saved with 0.5.0 sound two octaves lower until Octave is set to +2. This is
  a deliberate difference from the MPC plugin "Didgeridoo".
- The keyboard strip in the app's window now shows C2–C6.
- The app's icon covers its whole tile; macOS 26 and later no longer put it
  on a light plate.

## 0.5.0 — 2026-11-13

- First version: a synthesized didgeridoo with 25 parameters in three groups
  (Mouth, Lips, Rhythm) and six built-in programs.
- Standalone app with a keyboard strip, a choice of MIDI input device and
  channel, a choice of audio output device and channel pair, and its own MIDI
  port "Didgeridoo" for other applications.
- Audio Unit instrument for Ableton Live, Logic Pro and other hosts,
  installed from the app's Settings window. It uses the host's standard
  parameter view; it has no window of its own yet.
- The app follows the audio hardware: it moves with the system default
  output, and when a chosen device is unplugged it plays on the default until
  the device is back.
- Pitch drift wanders equally fast at every sample rate. This is the one
  deliberate difference from the MPC plugin "Didgeridoo", whose drift speeds
  up with the rate; at 44.1 kHz the two sound identical.
- For Macs with Apple silicon, macOS 14 or later.
