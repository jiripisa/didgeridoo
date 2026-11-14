# Didgeridoo — State

- 2026-11-15 — phase 17 done on `feature/17-midi-learn` (which stands on
  phase 16's branch): MIDI learn and a controller on every knob, in the app
  and in the plug-in. Not merged, not released; no real controller has been
  moved. See `phases/17-midi-learn/VERIFICATION.md`. An instrument
  definition for the author's OXI E16 with these controllers lies with his
  other definitions, outside this repository.
- 2026-11-14 — phase 16 done on `feature/16-lfo` (which stands on phase 15's
  branch): two LFOs that move the knobs, with an amount per LFO on sixteen
  of them. Not merged, not released, not heard.
  See `phases/16-lfo/VERIFICATION.md`.
- 2026-11-14 — phase 15 done on its branch, not merged and not released:
  the engine is one model of the instrument (lips, tongue, tube, voice),
  built without compatibility with 1.0.x at the author's word. His ear
  approved it ("zvuk je parádní"). The overblown note did not pass in three
  builds and was removed; he wants to work on other things next.
  See `phases/15-one-model/VERIFICATION.md`.
- 2026-11-14 — phase 14: version 1.0.2 released (phase 13). See
  `phases/14-v1.0.2-release/VERIFICATION.md`.
- 2026-11-14 — phase 13 done: the overblow band on the keys of the app's
  keyboard. A click on a key's name had sometimes overblown the note since
  1.0.1. See `phases/13-overblow-band/VERIFICATION.md`.
- 2026-11-14 — phase 12: version 1.0.1 released (phase 11). See
  `phases/12-v1.0.1-release/VERIFICATION.md`.
- 2026-11-14 — phase 11 done: the dead spot on the names of the keys C2 to
  C6 is gone. See `phases/11-key-name-click/VERIFICATION.md`.
- 2026-11-14 — phase 10: version 1.0.0 released (phase 09). See
  `phases/10-v1.0.0-release/VERIFICATION.md`. The author tries it on another
  Mac from the download; nobody has listened to the new sound yet.
- 2026-11-14 — phase 09 done: seven new knobs (Tongue, Tube, Toot Len,
  Voice, Pattern, Accent, Breath In), a fourth panel (Tube) and four programs
  built on a study of the real instrument
  (`research/reports/Didgeridoo acoustics and playing.md`). The earlier
  programs are unchanged, sample for sample. Nothing was judged by ear: see
  "Not verified" in `phases/09-player-and-tube/VERIFICATION.md`.
- 2026-11-14 — phase 08: version 0.6.0 released (phases 05 to 07). See
  `phases/08-v0.6.0-release/VERIFICATION.md`. The author tries it on another
  Mac from the download; the plug-in's window has not been in a host yet.
- 2026-11-14 — phase 07 done: the Audio Unit has its own window. See
  `phases/07-audiounit-window/VERIFICATION.md`.
- 2026-11-14 — phase 06 done: the icon without its light border and the
  website's new look.
- 2026-11-13 — phase 05 done: the Octave knob; at 0 the instrument plays two
  octaves lower than in 0.5.0. See `phases/05-octave/VERIFICATION.md`.
- 2026-11-13 — phase 04: version 0.5.0, the first release. See
  `phases/04-v0.5.0-release/VERIFICATION.md`.
- 2026-11-13 — phase 03 done: fixes from a review of phase 02 and a test
  that guards the sound (`SoundRegressionTests`). See
  `phases/03-review-fixes/VERIFICATION.md`; its "Not verified" list adds a few
  hands-on checks to those of phase 02.
- 2026-11-13 — phase 02 done: the sound engine (bit-identical to the MPC
  plugin), the standalone app and the Audio Unit. See
  `phases/02-engine-app-audiounit/VERIFICATION.md` for what was and was not
  verified; the hands-on checks listed there under "Not verified" are still
  open.
- 2026-11-13 — skeleton created (phase 01): `build.sh` / `run.sh`,
  Developer ID + notarization pipeline, Sparkle auto-update, website on
  GitHub Pages.
- Open: phases 15 to 17 wait on their branches for the author's word to
  merge and release them (a major version: saved sounds and host projects of
  1.0.x do not carry over). He tries builds from the released download, so
  he cannot try the LFO buttons or MIDI learn before a release.
