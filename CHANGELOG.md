# Changelog

## 1.0.2 — 2026-11-14

- The keys of the app's keyboard show an ochre band at their lower end. A
  click in the band overblows the note; a click anywhere else on a key never
  does, wherever Toot Vel stands. Before, the lowest part of a key overblew
  without showing it, and the key's name lay right across its edge, so a
  click on the name sometimes played the note 16 semitones too high. The
  names now sit above the band.

## 1.0.1 — 2026-11-14

- A click on the name of a key (C2 to C6) on the app's keyboard now plays
  the key. The name used to take the click, which left a dead spot in the
  lower middle of those keys.

## 1.0.0 — 2026-11-14

- The instrument can now behave like the real ones measured in acoustics
  research. Seven new knobs, all at 0 until you turn them:
  - Tongue (Mouth): a raised tongue takes sound away at three resonances of
    the mouth; the band left between them is the moving overtone. It follows
    Vowel and lifts the drone by up to a third of a semitone.
  - Tube (new panel Tube): the tube's own resonances make the fundamental
    stand out above its harmonics. Toot Pitch says what tube it is: 19 st a
    plain pipe with strong odd harmonics, around 16 st a flared instrument.
  - Toot Len (Tube): an overblown note can be a short stab after which the
    drone comes back, instead of lasting as long as the key.
  - Voice (Lips): a sung voice locked in tune with the drone at the interval
    of Growl Pitch; a fifth or a tenth adds a tone an octave below.
  - Pattern, Accent, Breath In (Rhythm): accented and soft steps, and a quick
    in-breath on the soft ones as in circular breathing.
- Four new programs use them: Eucalyptus, Hard Tongue, Pipe and Singer.
- The window has a fourth panel, Tube, which also holds Toot Vel, Toot Pitch,
  Glide, Bend Range and Octave. The window is a little taller.
- The six earlier programs and saved sounds are unchanged, sample for sample.
  The new knobs and programs are a deliberate difference from the MPC plugin
  "Didgeridoo".

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
