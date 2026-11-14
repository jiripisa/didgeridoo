# Changelog

## Unreleased

- The instrument is now one model, built on the measurements of real
  didgeridoos, and no longer a synthesizer with those measurements beside
  it. Every program sounds different from 1.0.x. This is a deliberate
  departure from the MPC plugin "Didgeridoo", whose synthesis it replaces.
  - Lips: the source is the air that passes lips which are shut for part of
    every cycle. Buzz sets how hard they close (it used to narrow a pulse);
    Drive is how hard they are blown and works on the lips themselves (it
    used to distort the finished sound, which also filled in the notches of
    the tongue).
  - Mouth: only the tongue is left. Vowel says where the tongue stands and
    Tongue how deep it cuts. Formant and Reso are gone: they added peaks
    where a real mouth takes sound away.
  - Tube: eight resonances, placed by the flare that Toot Pitch implies.
    Body is gone; the tube's first resonance does its work. Tone moved here.
  - Voice: one sung voice with a list of intervals that lock to the drone
    (Voice Pitch: Unison to Twelfth, the tenth as it comes) and a new knob,
    Rough, that pulls it off the lock so that it beats. Growl and Growl
    Pitch are gone; aftertouch now adds Voice.
  - Breath passes the lips, so its noise comes in bursts at the drone's
    pitch.
- The overblown note was measured on recordings of real instruments and
  rebuilt: the drone stops, the pitch jumps there within a hundredth of a
  second without sliding, the tone is nearly plain (it used to be bright and
  buzzing), it is about 6 dB louder than the drone, and it is a short stab
  (Toot Len 120 ms) after which the drone returns. "Hold" is now at the top
  of Toot Len. Toot Pitch runs from 12 to 19 semitones, what tubes do, and
  rests at 17.
- As it comes, the instrument has the tube and the tongue on, Drift at 12 %
  and Bend Range at 1 semitone. Volume rests at 0 dB.
- 30 knobs instead of 33. The ten programs keep their names and were voiced
  again.
- Sounds stored by 1.0.x are not carried over: the app starts with Classic
  Drone, and a host project saved with the 1.0.x plug-in restores wrong
  values, so choose a program again. Several knobs kept their name and
  changed their meaning.
- Turning Buzz, Drive or Voice while a note sounds makes no click.

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
