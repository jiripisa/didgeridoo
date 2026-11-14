// DidgeridooDSP.h - C interface to the Didgeridoo sound engine.
//
// SPDX-License-Identifier: MIT
//
// One engine = one monophonic instrument. The Audio Unit (C++) and the standalone app
// (Swift, through DidgeridooCore) both drive it through these functions.
//
// Threads:
//   * didge_process() and didge_midi() belong to the audio thread.
//   * didge_post_midi(), the parameter setters/getters, didge_set_program(),
//     didge_request_reset() and didge_set_transport() may be called from any thread while
//     audio runs, the audio thread included: none of them locks or allocates.
//   * didge_prepare() and didge_reset() must not run concurrently with didge_process().
//
// Parameter values come in two forms: "plain" (the real value: Hz, ms, dB, %, an index)
// and "normalised" (0..1, what a knob position is). The engine stores normalised values.

#ifndef DIDGERIDOO_DSP_H
#define DIDGERIDOO_DSP_H

#ifdef __cplusplus
extern "C" {
#endif

typedef struct DidgeEngine DidgeEngine;

enum { DIDGE_KIND_FLOAT = 0, DIDGE_KIND_INT = 1, DIDGE_KIND_CHOICE = 2 };

typedef struct DidgeParamInfo
{
    const char* identifier;   // stable name used in saved state; never changes
    const char* name;         // shown to the user
    const char* unit;         // "Hz", "ms", "dB", "%", "st" or ""
    int   kind;               // DIDGE_KIND_*
    float minValue, maxValue, defaultValue;   // plain values
    int   logarithmic;        // 1 = the knob travels logarithmically (frequencies, times)
    int   numChoices;         // > 0 only for DIDGE_KIND_CHOICE
    int   section;            // the section it is shown in (see didge_num_sections), -1 if none
} DidgeParamInfo;

// ----- parameter, section and program tables (the same for every engine) --------------------
int         didge_num_params(void);
void        didge_param_info(int index, DidgeParamInfo* out);
const char* didge_param_choice(int index, int choice);
float       didge_param_to_plain(int index, float normalised);
float       didge_param_to_normalised(int index, float plain);
// Text for a plain value, without the unit ("1400", "-6.0", "1/8", "Off"). Returns buffer.
const char* didge_param_display(int index, float plain, char* buffer, int bufferSize);

// The sections the parameters are shown in ("Mouth", "Lips", "Tube", "Rhythm") and the parameters of
// each in the order they are shown: the app's panels and the Audio Unit's parameter groups.
int         didge_num_sections(void);
const char* didge_section_name(int section);
int         didge_section_size(int section);
int         didge_section_param(int section, int position);   // a parameter index, -1 if none

// The LFOs. Each has an amount on every knob it can move: a parameter of its own, shown in no
// section. didge_lfo_amount gives its index, or -1 for a knob an LFO cannot move.
int         didge_num_lfos(void);
int         didge_lfo_amount(int lfo, int param);

int         didge_num_programs(void);
const char* didge_program_name(int program);
float       didge_program_value(int program, int param);   // plain
int         didge_program_sets(int param);                 // 0 for "octave", which programs leave alone

// ----- one engine ---------------------------------------------------------------------------
DidgeEngine* didge_create(void);
void         didge_destroy(DidgeEngine* engine);
void         didge_prepare(DidgeEngine* engine, double sampleRate);
void         didge_reset(DidgeEngine* engine);
// The same reset, done by the audio thread at the start of its next didge_process() call.
void         didge_request_reset(DidgeEngine* engine);

float didge_get_plain(const DidgeEngine* engine, int index);
float didge_get_normalised(const DidgeEngine* engine, int index);
void  didge_set_plain(DidgeEngine* engine, int index, float plain);
void  didge_set_normalised(DidgeEngine* engine, int index, float normalised);

// Loads a built-in program: every parameter but "octave" is overwritten and the voice is
// silenced. The octave belongs to the player's keyboard, not to the sound.
void didge_set_program(DidgeEngine* engine, int program);
int  didge_get_program(const DidgeEngine* engine);

// Tempo and song position for the rhythm pulse. With playing == 0 (or ppqValid == 0) the
// pulse free-runs at the given tempo.
void didge_set_transport(DidgeEngine* engine, int playing, double bpm, double ppqPosition, int ppqValid);

// MIDI controllers on the parameters. Every knob comes with a controller (a control change
// number) and can be given another; a control change then puts the knob where its value says
// (0 the bottom of its travel, 127 the top, and 64 the middle of a parameter that has a middle:
// -100 … 100 %). A controller serves one parameter. All of these
// may be called from any thread while audio runs.
int  didge_standard_controller(int param);                 // what a parameter comes with; -1 for none
int  didge_controller_reserved(int controller);            // 1 for one that MIDI or the engine keeps for itself
int  didge_get_controller(const DidgeEngine* engine, int param);            // -1 for none
void didge_set_controller(DidgeEngine* engine, int param, int controller);  // -1 takes it away; a reserved one is not taken
void didge_reset_controllers(DidgeEngine* engine);         // back to what the parameters come with
// Learn: the parameter takes the next controller that moves (and goes where it says). -1 calls it off.
void didge_learn(DidgeEngine* engine, int param);
int  didge_learning(const DidgeEngine* engine);            // the parameter that is learning, -1 for none
// Counts what MIDI changed without the caller: a knob moved by its controller, a controller
// learnt. A window compares it with what it saw last to know when to read the engine again.
unsigned didge_changes(const DidgeEngine* engine);

// MIDI from any thread; played in the next didge_process() call, sampleOffset frames into it
// (0 = at its start).
void didge_post_midi(DidgeEngine* engine, int status, int data1, int data2, int sampleOffset);
// MIDI from the audio thread with a sample offset into the next didge_process() call.
void didge_midi(DidgeEngine* engine, int status, int data1, int data2, int sampleOffset);

// Renders `frames` samples. The instrument is mono: left and right receive the same signal.
// `right` may be NULL.
void didge_process(DidgeEngine* engine, float* left, float* right, int frames);

#ifdef __cplusplus
}
#endif

#endif // DIDGERIDOO_DSP_H
