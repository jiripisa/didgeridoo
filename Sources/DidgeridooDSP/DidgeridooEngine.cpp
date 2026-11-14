// DidgeridooEngine.cpp - the Didgeridoo sound engine and its C interface.
//
// SPDX-License-Identifier: MIT
//
// The synthesis is the same code as the MPC plugin "Didgeridoo" (Jiri Pisa), lifted out of the
// MPC plugin framework so that an Audio Unit and a standalone app can share it. Parameter
// ranges, mappings, display texts and programs are identical to the plugin's.
//
// Signal path:
//
//   lips:   saw + narrow pulse (PolyBLEP, "Buzz" morphs between them)
//             * voice growl (a sine sung into the tube, ring-modulates the buzz)
//             + breath noise (pink)
//                |
//                +--> tone lowpass ("Tone": the tube swallows the highs) ------+
//                +--> formant 1 + formant 2 (band-pass pair = mouth shape,     +--> sum
//                |    "Vowel" morphs u - o - a - e - i)                        |
//   buzz only ---+--> body band-pass at the fundamental ("Body": drone weight) +
//                                                                              |
//   -> amp envelope * velocity * rhythm pulse -> drive (tanh) -> DC blocker -> volume -> L = R
//
// Pitch: last-note priority with glide, pitch bend, slow random drift. "Octave" moves the whole
// instrument: at 0 a key sounds two octaves below its MIDI note, which puts a didgeridoo's range
// around middle C. A hard hit
// (velocity >= "Toot Vel") overblows: the pitch jumps up by "Toot Pitch" semitones and the
// tone turns bright and trumpet-like.
//
// Vowel movement adds up from the Vowel knob, the mod wheel, a slow "Wobble" LFO and the
// tempo-synced rhythm pulse. Channel aftertouch adds growl.
//
// Expensive maths (pow, tan, exp) runs every 16 samples ("control rate"); oscillators,
// filters and envelopes run every sample. Nothing allocates in process().

#include "DidgeridooDSP.h"

#include <atomic>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>

#include "dsp/math.h"
#include "dsp/oscillator.h"
#include "dsp/svf.h"
#include "dsp/adsr.h"
#include "dsp/smoother.h"
#include "dsp/noise.h"
#include "dsp/onepole.h"
#include "dsp/tempo.h"

using namespace mpc::dsp;

namespace {

// ---------------------------------------------------------------------------------------------
// Parameters. The order and the identifiers are permanent: only ever append.
// ---------------------------------------------------------------------------------------------
enum Params
{
    kVolume,        // dB    master volume
    kVowel,         // %     mouth shape, u (0) - o - a - e - i (100)
    kFormant,       // %     how much of the formant pair is mixed in
    kReso,          // %     sharpness of the formants
    kBuzz,          // %     lip source: 0 = round saw, 100 = thin nasal pulse
    kTone,          // Hz    lowpass on the direct sound
    kBody,          // %     resonance at the fundamental (drone weight)
    kDrive,         // %     saturation at the output
    kBreath,        // %     breath noise through the tube
    kGrowl,         // %     voice sung into the tube (rough beating)
    kGrowlPitch,    // st    interval of the sung voice above the drone
    kGlide,         // ms    slide time between notes
    kAttack,        // ms    amp envelope attack
    kRelease,       // ms    amp envelope release
    kTootVel,       // -     velocity at which a note overblows (128 = Off)
    kTootPitch,     // st    how far the overblown note jumps up
    kRhythmDiv,     // -     note division of the rhythm pulse
    kRhyDepth,      // %     how deep the pulse ducks the volume
    kRhyVowel,      // %     how far the pulse pushes the vowel (signed)
    kRhyDecay,      // %     pulse shape: 0 = long swell, 100 = short stab
    kWobbleRate,    // Hz    slow vowel LFO rate
    kWobbleDepth,   // %     slow vowel LFO depth
    kWheelVowel,    // %     how far the mod wheel moves the vowel
    kBendRange,     // st    pitch bend range
    kDrift,         // %     slow random pitch instability
    kOctave,        // -     octave of the whole instrument; 0 = two octaves below the MIDI note
    kTongue,        // %     how hard a raised tongue cuts the bands beside the formant
    kTube,          // %     how much the tube's own resonances colour the sound
    kTootLen,       // ms    length of an overblown stab; 0 = as long as the key is held
    kVoice,         // %     a voice sung through the lips (two valves in a row)
    kRhyPattern,    // -     which steps of the rhythm are accents and which are soft
    kRhyAccent,     // %     surge of an accented step
    kRhyBreath,     // %     in-breath on a soft step
    kNumParams
};

struct Param
{
    const char* id;
    const char* name;
    const char* unit;
    int   kind;                 // DIDGE_KIND_*
    float min, max, def;
    float skew;                 // 1 = linear, < 1 gives more resolution at the low end
    bool  logarithmic;
    int   decimals;

    float toPlain(float norm) const
    {
        norm = clamp(norm, 0.0f, 1.0f);
        if (kind == DIDGE_KIND_CHOICE)
        {
            const int n = (int)max + 1;
            return n < 2 ? 0.0f : (float)clamp((int)std::lround(norm * (float)(n - 1)), 0, n - 1);
        }
        if (kind == DIDGE_KIND_INT) return std::round(min + norm * (max - min));
        if (logarithmic && min > 0.0f && max > 0.0f) return min * std::pow(max / min, norm);
        if (skew != 1.0f) return min + (max - min) * std::pow(norm, 1.0f / skew);
        return min + (max - min) * norm;
    }

    float toNormalised(float plain) const
    {
        if (kind == DIDGE_KIND_CHOICE)
        {
            const int n = (int)max + 1;
            return n < 2 ? 0.0f : clamp(plain / (float)(n - 1), 0.0f, 1.0f);
        }
        if (max == min) return 0.0f;
        plain = clamp(plain, std::fmin(min, max), std::fmax(min, max));
        if (kind == DIDGE_KIND_FLOAT && logarithmic && min > 0.0f && max > 0.0f)
            return clamp(std::log(plain / min) / std::log(max / min), 0.0f, 1.0f);
        const float lin = (plain - min) / (max - min);
        if (kind == DIDGE_KIND_FLOAT && skew != 1.0f) return clamp(std::pow(lin, skew), 0.0f, 1.0f);
        return clamp(lin, 0.0f, 1.0f);
    }
};

Param floatParam(const char* id, const char* name, float min, float max, float def, const char* unit, int decimals, float skew = 1.0f)
{
    return Param{ id, name, unit, DIDGE_KIND_FLOAT, min, max, def, skew, false, decimals };
}
Param logParam(const char* id, const char* name, float min, float max, float def, const char* unit, int decimals)
{
    return Param{ id, name, unit, DIDGE_KIND_FLOAT, min, max, def, 1.0f, true, decimals };
}
Param intParam(const char* id, const char* name, int min, int max, int def, const char* unit = "")
{
    return Param{ id, name, unit, DIDGE_KIND_INT, (float)min, (float)max, (float)def, 1.0f, false, 0 };
}
Param choiceParam(const char* id, const char* name, int numChoices, int def)
{
    return Param{ id, name, "", DIDGE_KIND_CHOICE, 0.0f, (float)(numChoices - 1), (float)def, 1.0f, false, 0 };
}

// ---------------------------------------------------------------------------------------------
// Rhythm patterns: which steps of the pulse are accents (a surge, the tongue thrown forward) and
// which are soft (the tongue drawn back, and the place for an in-breath). "Even" is every step
// alike, the rhythm as the MPC plugin has it.
// ---------------------------------------------------------------------------------------------
struct Pattern { const char* name; int length; bool accent[6]; };

const Pattern kPatterns[] = {
    { "Even",        1, { true } },
    { "A-b",         2, { true, false } },
    { "A-b-b",       3, { true, false, false } },
    { "A-b-b-A-b-A", 6, { true, false, false, true, false, true } },
};
constexpr int kNumPatterns = (int)(sizeof(kPatterns) / sizeof(kPatterns[0]));

const Param kParams[kNumParams] = {
    floatParam ("volume",      "Volume",       -40.0f, 6.0f, -6.0f, "dB", 1),
    floatParam ("vowel",       "Vowel",        0.0f, 100.0f, 30.0f, "%", 0),
    floatParam ("formant",     "Formant",      0.0f, 100.0f, 70.0f, "%", 0),
    floatParam ("reso",        "Reso",         0.0f, 100.0f, 60.0f, "%", 0),
    floatParam ("buzz",        "Buzz",         0.0f, 100.0f, 50.0f, "%", 0),
    logParam   ("tone",        "Tone",         200.0f, 8000.0f, 1400.0f, "Hz", 0),
    floatParam ("body",        "Body",         0.0f, 100.0f, 50.0f, "%", 0),
    floatParam ("drive",       "Drive",        0.0f, 100.0f, 20.0f, "%", 0),
    floatParam ("breath",      "Breath",       0.0f, 100.0f, 15.0f, "%", 0),
    floatParam ("growl",       "Growl",        0.0f, 100.0f, 0.0f, "%", 0),
    intParam   ("growlpitch",  "Growl Pitch",  0, 24, 7, "st"),
    floatParam ("glide",       "Glide",        0.0f, 1000.0f, 60.0f, "ms", 0, 0.4f),
    logParam   ("attack",      "Attack",       5.0f, 2000.0f, 60.0f, "ms", 0),
    logParam   ("release",     "Release",      10.0f, 3000.0f, 180.0f, "ms", 0),
    intParam   ("tootvel",     "Toot Vel",     64, 128, 115),
    intParam   ("tootpitch",   "Toot Pitch",   7, 24, 16, "st"),
    choiceParam("rhythmdiv",   "Rhythm Div",   kNumDivisions, kDivisionEighth),
    floatParam ("rhydepth",    "Rhy Depth",    0.0f, 100.0f, 0.0f, "%", 0),
    floatParam ("rhyvowel",    "Rhy>Vowel",    -100.0f, 100.0f, 0.0f, "%", 0),
    floatParam ("rhydecay",    "Rhy Decay",    0.0f, 100.0f, 40.0f, "%", 0),
    logParam   ("wobblerate",  "Wobble Rate",  0.05f, 10.0f, 0.4f, "Hz", 2),
    floatParam ("wobbledepth", "Wobble Depth", 0.0f, 100.0f, 20.0f, "%", 0),
    floatParam ("wheelvowel",  "Wheel Vowel",  0.0f, 100.0f, 100.0f, "%", 0),
    intParam   ("bendrange",   "Bend Range",   0, 12, 2, "st"),
    floatParam ("drift",       "Drift",        0.0f, 100.0f, 30.0f, "%", 0),
    intParam   ("octave",      "Octave",       -2, 2, 0),
    floatParam ("tongue",      "Tongue",       0.0f, 100.0f, 0.0f, "%", 0),
    floatParam ("tube",        "Tube",         0.0f, 100.0f, 0.0f, "%", 0),
    floatParam ("tootlen",     "Toot Len",     0.0f, 1000.0f, 0.0f, "ms", 0, 0.4f),
    floatParam ("voice",       "Voice",        0.0f, 100.0f, 0.0f, "%", 0),
    choiceParam("rhypattern",  "Pattern",      kNumPatterns, 0),
    floatParam ("rhyaccent",   "Accent",       0.0f, 100.0f, 0.0f, "%", 0),
    floatParam ("rhybreath",   "Breath In",    0.0f, 100.0f, 0.0f, "%", 0),
};

// ---------------------------------------------------------------------------------------------
// Sections: the groups the parameters are shown in (the app's panels, the Audio Unit's parameter
// groups) and the order inside each. Every parameter belongs to exactly one section.
// ---------------------------------------------------------------------------------------------
struct Section { const char* name; std::vector<int> params; };

const std::vector<Section>& sections()
{
    static const std::vector<Section> table = {
        { "Mouth",  { kVowel, kFormant, kReso, kTongue, kTone, kWobbleRate, kWobbleDepth, kWheelVowel, kVolume } },
        { "Lips",   { kBuzz, kBody, kDrive, kBreath, kDrift, kGrowl, kGrowlPitch, kVoice, kAttack, kRelease } },
        { "Tube",   { kTube, kTootVel, kTootPitch, kTootLen, kGlide, kBendRange, kOctave } },
        { "Rhythm", { kRhythmDiv, kRhyPattern, kRhyDepth, kRhyVowel, kRhyDecay, kRhyAccent, kRhyBreath } },
    };
    return table;
}

int sectionOf(int param)
{
    for (size_t s = 0; s < sections().size(); ++s)
        for (int p : sections()[s].params) if (p == param) return (int)s;
    return -1;
}

// ---------------------------------------------------------------------------------------------
// Built-in programs: the defaults with a few values overridden.
// ---------------------------------------------------------------------------------------------
struct Program { const char* name; float values[kNumParams]; };

struct Override { int param; float value; };

Program makeProgram(const char* name, std::initializer_list<Override> overrides)
{
    Program p; p.name = name;
    for (int i = 0; i < kNumParams; ++i) p.values[i] = kParams[i].def;
    for (const Override& o : overrides) p.values[o.param] = o.value;
    return p;
}

const std::vector<Program>& programs()
{
    static const std::vector<Program> table = {
        makeProgram("Classic Drone", {}),
        makeProgram("Deep Earth",    {{kVowel, 10}, {kFormant, 45}, {kBuzz, 25}, {kTone, 700}, {kBody, 85},
                                      {kBreath, 8}, {kWobbleRate, 0.15f}, {kWobbleDepth, 12}, {kAttack, 150}}),
        makeProgram("Vocal Wah",     {{kVowel, 45}, {kFormant, 95}, {kReso, 80}, {kBuzz, 65}, {kTone, 1100},
                                      {kWobbleRate, 1.6f}, {kWobbleDepth, 70}}),
        makeProgram("Growler",       {{kGrowl, 70}, {kGrowlPitch, 7}, {kDrive, 55}, {kBuzz, 70}, {kVowel, 40},
                                      {kBreath, 25}, {kDrift, 50}}),
        makeProgram("Rhythm Breath", {{kRhyDepth, 70}, {kRhyVowel, 80}, {kRhyDecay, 55}, {kRhythmDiv, (float)kDivisionEighth},
                                      {kVowel, 15}, {kFormant, 90}, {kReso, 70}, {kWobbleDepth, 0}, {kBreath, 30}}),
        makeProgram("Gallop",        {{kRhyDepth, 85}, {kRhyVowel, -60}, {kRhyDecay, 75}, {kRhythmDiv, (float)kDivisionSixteenth},
                                      {kVowel, 70}, {kFormant, 85}, {kBuzz, 60}, {kDrive, 35}, {kWobbleDepth, 10}}),
        // The programs below play the instrument as it was measured on real ones: the tube's
        // own resonances, the tongue that takes sound away, a steady pitch, the toot as a stab.
        makeProgram("Eucalyptus",    {{kTube, 70}, {kTongue, 60}, {kFormant, 30}, {kVowel, 45}, {kBuzz, 60}, {kBody, 30},
                                      {kBreath, 12}, {kWobbleRate, 0.25f}, {kWobbleDepth, 35}, {kDrift, 12}, {kBendRange, 1},
                                      {kTootLen, 150}}),
        makeProgram("Hard Tongue",   {{kTube, 60}, {kTongue, 80}, {kFormant, 35}, {kVowel, 35}, {kBuzz, 60}, {kBody, 30},
                                      {kWobbleDepth, 0}, {kDrift, 10}, {kBendRange, 1}, {kTootLen, 120},
                                      {kRhythmDiv, (float)kDivisionEighth}, {kRhyPattern, 3}, {kRhyDepth, 45}, {kRhyVowel, 60},
                                      {kRhyDecay, 50}, {kRhyAccent, 80}, {kRhyBreath, 60}}),
        makeProgram("Pipe",          {{kTube, 100}, {kTootPitch, 19}, {kTongue, 40}, {kFormant, 40}, {kVowel, 35}, {kBuzz, 55},
                                      {kBody, 20}, {kWobbleDepth, 15}, {kDrift, 10}, {kBendRange, 1}, {kTootLen, 200}}),
        makeProgram("Singer",        {{kTube, 60}, {kTongue, 50}, {kFormant, 40}, {kVowel, 50}, {kBuzz, 55}, {kDrive, 25},
                                      {kVoice, 60}, {kGrowlPitch, 7}, {kWobbleRate, 0.3f}, {kWobbleDepth, 30}, {kDrift, 15},
                                      {kBendRange, 1}, {kTootLen, 150}}),
    };
    return table;
}

// The ratio of a sung interval: the simple ratio where there is one, so that the voice locks to
// the lips and its sums and differences with the drone fall on a steady series.
float justRatio(int semitones)
{
    switch (semitones)
    {
        case 0:  return 1.0f;
        case 3:  return 6.0f / 5.0f;
        case 4:  return 5.0f / 4.0f;
        case 5:  return 4.0f / 3.0f;
        case 7:  return 3.0f / 2.0f;
        case 9:  return 5.0f / 3.0f;
        case 12: return 2.0f;
        case 16: return 5.0f / 2.0f;
        case 19: return 3.0f;
        case 24: return 4.0f;
        default: return semitonesToRatio((float)semitones);
    }
}

// Octave belongs to the player's keyboard, not to a sound: a program leaves it alone.
bool programSets(int param) { return param != kOctave; }

// One resonance of the vocal tract as the lip flow meets it: a band-pass (a trapezoidal
// state-variable filter) whose answer is split into what follows its input at once (`now`) and
// what comes from its state (`held`). Three of them load one flow, so the flow has to be solved
// with all three in the same sample; the split makes that one division.
struct TractResonance
{
    void set(float hz, float q, float sampleRate)
    {
        const float g = std::tan(kPi * hz / sampleRate);
        k = 1.0f / q;
        a1 = 1.0f / (1.0f + g * (g + k)); a2 = g * a1; a3 = g * a2;
    }
    float now() const { return k * a2; }                            // per unit of input
    float held() const { return k * (a1 * ic1 - a2 * ic2); }
    void step(float x)
    {
        const float v3 = x - ic2, v1 = a1 * ic1 + a2 * v3, v2 = ic2 + a2 * ic1 + a3 * v3;
        ic1 = 2.0f * v1 - ic1; ic2 = 2.0f * v2 - ic2;
    }
    void reset() { ic1 = ic2 = 0.0f; }

    float k = 0.1f, a1 = 1.0f, a2 = 0.0f, a3 = 0.0f, ic1 = 0.0f, ic2 = 0.0f;
};

struct MidiEvent
{
    int sampleOffset;
    uint8_t status, data1, data2;

    uint8_t kind() const { return status & 0xF0; }
    bool isNoteOn() const { return kind() == 0x90 && data2 != 0; }
    bool isNoteOff() const { return kind() == 0x80 || (kind() == 0x90 && data2 == 0); }
    bool isController() const { return kind() == 0xB0; }
    bool isPitchBend() const { return kind() == 0xE0; }
    bool isAftertouch() const { return kind() == 0xD0; }
    bool isAllNotesOff() const { return isController() && (data1 == 123 || data1 == 120); }
    int  pitchBend() const { return (data1 | (data2 << 7)) - 8192; }
};

} // namespace

// ---------------------------------------------------------------------------------------------
// The engine
// ---------------------------------------------------------------------------------------------
struct DidgeEngine
{
    DidgeEngine()
    {
        for (int i = 0; i < kNumParams; ++i) values_[i].store(kParams[i].toNormalised(kParams[i].def));
        for (uint32_t i = 0; i < kPostSize; ++i) posted_[i].turn.store(i, std::memory_order_relaxed);
        prepare(44100.0);
        reset();
    }

    // ----- parameters (any thread) --------------------------------------------------------
    float getNormalised(int i) const { return values_[i].load(std::memory_order_relaxed); }
    float get(int i) const { return kParams[i].toPlain(getNormalised(i)); }
    int   getInt(int i) const { return (int)std::lround(get(i)); }
    void  setNormalised(int i, float v) { values_[i].store(clamp(v, 0.0f, 1.0f), std::memory_order_relaxed); }
    void  set(int i, float plain) { setNormalised(i, kParams[i].toNormalised(plain)); }

    void setProgram(int index)
    {
        if (index < 0 || index >= (int)programs().size()) return;
        program_.store(index, std::memory_order_relaxed);
        const Program& p = programs()[(size_t)index];
        for (int i = 0; i < kNumParams; ++i)
            if (programSets(i)) set(i, p.values[i]);
        resetPending_.store(true, std::memory_order_release);     // silence the voice on the audio thread
    }
    int program() const { return program_.load(std::memory_order_relaxed); }

    void requestReset() { resetPending_.store(true, std::memory_order_release); }   // any thread

    void setTransport(bool playing, double bpm, double ppq, bool ppqValid)
    {
        bpm_.store(bpm, std::memory_order_relaxed);
        transportPpq_.store(ppq, std::memory_order_relaxed);
        transportLocked_.store(playing && ppqValid, std::memory_order_relaxed);
    }

    // ----- MIDI ---------------------------------------------------------------------------
    // Posted MIDI waits in a bounded queue that any number of threads fill and the audio thread
    // empties, without a lock (Dmitry Vyukov's bounded queue). Queue positions count up for
    // ever; a slot's `turn` says which position may use it next: equal to a writer's position
    // when the slot is free for it, one more once the event is in.
    void postMidi(uint8_t status, uint8_t d1, uint8_t d2, int offset)   // any thread
    {
        uint32_t position = postWrite_.load(std::memory_order_relaxed);
        for (;;)
        {
            PostSlot& slot = posted_[position % kPostSize];
            const int32_t ahead = (int32_t)(slot.turn.load(std::memory_order_acquire) - position);
            if (ahead == 0)                 // free for this position: claim it, then fill it
            {
                if (postWrite_.compare_exchange_weak(position, position + 1, std::memory_order_relaxed))
                {
                    slot.event = MidiEvent{ offset < 0 ? 0 : offset, status, d1, d2 };
                    slot.turn.store(position + 1, std::memory_order_release);
                    return;
                }
            }
            else if (ahead < 0) return;     // still unread from a lap ago: the queue is full, the event is dropped
            else position = postWrite_.load(std::memory_order_relaxed);   // another thread took this position
        }
    }

    void midi(uint8_t status, uint8_t d1, uint8_t d2, int offset)   // audio thread
    {
        if (numEvents_ >= kMaxEvents) return;
        int i = numEvents_++;                                       // keep the list sorted by offset
        while (i > 0 && events_[i - 1].sampleOffset > offset) { events_[i] = events_[i - 1]; --i; }
        events_[i] = MidiEvent{ offset < 0 ? 0 : offset, status, d1, d2 };
    }

    // ----- lifecycle ----------------------------------------------------------------------
    void prepare(double sampleRate)
    {
        sr_ = (float)sampleRate;
        saw_.setSampleRate(sampleRate);   saw_.setWave(Wave::Saw);
        pulse_.setSampleRate(sampleRate); pulse_.setWave(Wave::Square);
        voice_.setSampleRate(sampleRate);
        formant1_.setSampleRate(sampleRate);
        formant2_.setSampleRate(sampleRate);
        for (SVF& mode : tube_) mode.setSampleRate(sampleRate);
        body_.setSampleRate(sampleRate);
        env_.setSampleRate(sampleRate);
        dc_.prepare(sampleRate, 20.0f);
        volume_.setTime(20.0f, sampleRate);
        velocity_.setTime(15.0f, sampleRate);
        wheel_.setTime(25.0f, sampleRate);
        bend_.setTime(10.0f, sampleRate);
        pressure_.setTime(40.0f, sampleRate);
        toot_.setTime(12.0f, sampleRate);
        rhythmGain_.setTime(4.0f, sampleRate);
        note_.setTime(60.0f, sampleRate);
        base_.setTime(60.0f, sampleRate);
        glideMs_ = -1.0f;

        // Drift is timed in control ticks. The numbers are the MPC plugin's at 44.1 kHz, where
        // they stay exactly as they were; at other rates they are scaled so that the drift
        // wanders equally fast everywhere.
        driftTickScale_ = sr_ / 44100.0f;
        driftEase_ = sr_ == 44100.0f ? 0.004f : 1.0f - std::pow(1.0f - 0.004f, 44100.0f / sr_);
        breathEase_ = 1.0f - std::exp(-(float)kControlInterval / (0.006f * sr_));      // an in-breath sets in within 6 ms
    }

    void reset()
    {
        saw_.resetPhase(); pulse_.resetPhase(); voice_.resetPhase();
        formant1_.reset(); formant2_.reset(); body_.reset();
        toneLp_.reset(); env_.reset(); dc_.reset(); breathNoise_.reset();
        for (TractResonance& resonance : tract_) resonance.reset();
        for (SVF& mode : tube_) mode.reset();
        numHeld_ = 0; sustain_ = false; sustained_ = false;
        volume_.snap(dbToGain(get(kVolume)));
        velocity_.snap(0.7f);
        wheel_.snap(0.0f); bend_.snap(0.0f); pressure_.snap(0.0f); toot_.snap(0.0f);
        rhythmGain_.snap(1.0f);
        note_.snap(38.0f);
        base_.snap(38.0f);
        tootTicks_ = 0; tongueNow_ = 0.0f; breathing_ = 0.0f;
        drift_ = driftTarget_ = 0.0f; driftCountdown_ = 0;
        wobblePhase_ = 0.0f; rhythmPulse_ = 1.0f;
        ppq_ = 0.0;
        controlCountdown_ = 0;
    }

    void process(float* left, float* right, int frames)
    {
        if (resetPending_.exchange(false, std::memory_order_acq_rel)) reset();

        // MIDI posted from other threads joins this block at its sample offset. Reading stops
        // at the first slot whose event is not in yet, so the order is kept.
        for (;;)
        {
            PostSlot& slot = posted_[postRead_ % kPostSize];
            if (slot.turn.load(std::memory_order_acquire) != postRead_ + 1) break;
            midi(slot.event.status, slot.event.data1, slot.event.data2, slot.event.sampleOffset);
            slot.turn.store(postRead_ + kPostSize, std::memory_order_release);     // free for the next lap
            ++postRead_;
        }

        readBlockSettings();

        // Sample-accurate MIDI: render up to each event, then apply it.
        int pos = 0;
        for (int e = 0; e < numEvents_; ++e)
        {
            const int offset = clamp(events_[e].sampleOffset, 0, frames);
            if (offset > pos) { render(left, right, pos, offset); pos = offset; }
            handleMidi(events_[e]);
        }
        render(left, right, pos, frames);
        numEvents_ = 0;
    }

private:
    static constexpr int kControlInterval = 16;   // samples between control-rate updates
    static constexpr int kMaxHeld = 8;            // notes remembered for last-note priority
    static constexpr int kMaxEvents = 256;
    static constexpr int kOctaveAtRest = -2;      // octaves between a MIDI note and its pitch at Octave 0
    static constexpr uint32_t kPostSize = 512;    // a power of two: positions wrap around cleanly

    // Parameters read once per block.
    struct Settings
    {
        float vowel, formant, formantK, formantGain, buzz, tone, body, breath, growl, growlRatio;
        float drivePre, drivePost, tootPitch, rhyBeats, rhyDepth, rhyVowel, rhyRate;
        float wobbleInc, wobbleDepth, wheelVowel, bendRange, drift;
        float tongue, tube, tootRatio, tootLen, voice, voiceRatio, accent, breathIn;
        int   tootVel, pattern;
        double ppqPerSample;
    };

    void readBlockSettings()
    {
        Settings& s = s_;
        s.vowel   = get(kVowel) * 0.01f;
        s.formant = get(kFormant) * 0.01f;
        const float reso = 0.55f + 0.4f * get(kReso) * 0.01f;        // 0.55..0.95 into the SVF
        formantReso_ = reso;
        s.formantK = 2.0f - 1.98f * reso;                            // the SVF's 1/Q: makes the peak gain 1
        s.formantGain = s.formant * 3.0f;
        s.buzz    = get(kBuzz) * 0.01f;
        s.tone    = get(kTone);
        s.body    = get(kBody) * 0.01f * 0.9f;
        s.breath  = get(kBreath) * 0.01f * 1.6f;
        s.growl   = get(kGrowl) * 0.01f;
        s.growlRatio = semitonesToRatio(get(kGrowlPitch) + 0.08f);   // slightly sharp, so it beats
        const float drive = get(kDrive) * 0.01f;
        s.drivePre  = 1.0f + 5.0f * drive;
        s.drivePost = 1.0f / std::pow(s.drivePre, 0.6f);             // keep the loudness roughly level
        s.tootVel   = getInt(kTootVel);
        s.tootPitch = get(kTootPitch);
        s.rhyBeats  = divisionBeats(getInt(kRhythmDiv));
        s.rhyDepth  = get(kRhyDepth) * 0.01f;
        s.rhyVowel  = get(kRhyVowel) * 0.01f * 0.6f;
        s.rhyRate   = 1.5f + 9.0f * get(kRhyDecay) * 0.01f;
        s.wobbleInc = get(kWobbleRate) * (float)kControlInterval / sr_;
        s.wobbleDepth = get(kWobbleDepth) * 0.01f * 0.35f;
        s.wheelVowel  = get(kWheelVowel) * 0.01f;
        s.bendRange = get(kBendRange);
        s.drift     = get(kDrift) * 0.01f * 0.3f;                    // up to +-30 cents
        s.tongue    = get(kTongue) * 0.01f;
        s.tube      = get(kTube) * 0.01f;
        s.tootRatio = semitonesToRatio(s.tootPitch);                 // the tube's second resonance is where its toot sounds
        s.tootLen   = get(kTootLen);
        s.voice     = get(kVoice) * 0.01f;
        s.voiceRatio = justRatio(getInt(kGrowlPitch));               // players lock the voice to the lips: no beating
        s.pattern   = clamp(getInt(kRhyPattern), 0, kNumPatterns - 1);
        s.accent    = get(kRhyAccent) * 0.01f;
        s.breathIn  = get(kRhyBreath) * 0.01f;

        volume_.setTarget(dbToGain(get(kVolume)));
        env_.set(get(kAttack), 1.0f, 1.0f, get(kRelease));
        const float glide = get(kGlide);
        if (glide != glideMs_) { glideMs_ = glide; if (!tootActive_) note_.setTime(glide, sr_); }

        // Octave. The shift is part of the note number, not added to the pitch afterwards, so a
        // phrase played two octaves higher gives the very samples the engine gave before it had
        // an octave. A sounding note slides to a new octave.
        const int shift = 12 * (getInt(kOctave) + kOctaveAtRest);
        if (shift != noteShift_)
        {
            if (env_.isActive())
            {
                note_.setTarget(note_.target() + (float)(shift - noteShift_));
                base_.setTarget(base_.target() + (float)(shift - noteShift_));
            }
            noteShift_ = shift;
        }

        // Rhythm clock: follow the song while it plays, free-run at the tempo otherwise.
        s.ppqPerSample = (double)safeBpm(bpm_.load(std::memory_order_relaxed)) / 60.0 / (double)sr_;
        if (transportLocked_.load(std::memory_order_relaxed)) ppq_ = transportPpq_.load(std::memory_order_relaxed);
    }

    void handleMidi(const MidiEvent& ev)
    {
        if (ev.isNoteOn())
        {
            removeHeld(ev.data1);
            if (numHeld_ == kMaxHeld) { for (int i = 1; i < kMaxHeld; ++i) held_[i - 1] = held_[i]; --numHeld_; }
            held_[numHeld_++] = ev.data1;
            startNote(ev.data1, ev.data2, true);
        }
        else if (ev.isNoteOff())
        {
            const bool wasSounding = numHeld_ > 0 && held_[numHeld_ - 1] == ev.data1;
            removeHeld(ev.data1);
            if (numHeld_ == 0)
            {
                if (sustain_) sustained_ = true; else env_.noteOff();
            }
            else if (wasSounding) startNote(held_[numHeld_ - 1], -1, false);   // fall back to the held note
        }
        else if (ev.isAllNotesOff())
        {
            numHeld_ = 0; sustained_ = false;
            env_.noteOff();
        }
        else if (ev.isController())
        {
            if (ev.data1 == 1) wheel_.setTarget(ev.data2 / 127.0f);
            else if (ev.data1 == 64)
            {
                sustain_ = ev.data2 >= 64;
                if (!sustain_ && sustained_) { sustained_ = false; if (numHeld_ == 0) env_.noteOff(); }
            }
        }
        else if (ev.isPitchBend())  bend_.setTarget((float)ev.pitchBend() / 8192.0f);
        else if (ev.isAftertouch()) pressure_.setTarget(ev.data1 / 127.0f);
    }

    // velocity < 0 means "returning to a note that is still held": keep the level, never toot.
    void startNote(int note, int velocity, bool fresh)
    {
        const bool toot = fresh && s_.tootVel <= 127 && velocity >= s_.tootVel;
        const float target = (float)(note + noteShift_) + (toot ? s_.tootPitch : 0.0f);
        const bool silent = !env_.isActive();

        tootActive_ = toot;
        // A toot with a length is a stab: after it the lips fall back to the drone (updateControl).
        tootTicks_ = toot && s_.tootLen >= 0.5f ? 1 + (int)(s_.tootLen * 0.001f * sr_ / (float)kControlInterval) : 0;     // under 0.5 the knob reads "Hold"
        base_.setTime(glideMs_, sr_);
        toot_.setTarget(toot ? 1.0f : 0.0f);
        note_.setTime(toot ? 12.0f : glideMs_, sr_);   // an overblown note snaps up fast
        if (silent)
        {
            note_.snap(target);                         // no slide into the first note
            base_.snap((float)(note + noteShift_));
            toot_.snap(toot ? 1.0f : 0.0f);
            saw_.resetPhase(); pulse_.resetPhase(); voice_.resetPhase();
        }
        else
        {
            note_.setTarget(target);
            base_.setTarget((float)(note + noteShift_));
        }

        if (velocity >= 0) velocity_.setTarget(0.35f + 0.65f * (float)velocity / 127.0f);
        if (silent) velocity_.snap(velocity_.target());
        sustained_ = false;
        env_.noteOn();
        controlCountdown_ = 0;                          // pick up the new pitch immediately
    }

    void removeHeld(int note)
    {
        int w = 0;
        for (int i = 0; i < numHeld_; ++i) if (held_[i] != note) held_[w++] = held_[i];
        numHeld_ = w;
    }

    // Vowel table: first and second formant in Hz for u, o, a, e, i.
    static void vowelFormants(float position, float& f1, float& f2)
    {
        static const float kF1[5] = { 300.0f, 450.0f, 700.0f, 500.0f, 300.0f };
        static const float kF2[5] = { 650.0f, 850.0f, 1150.0f, 1750.0f, 2250.0f };
        const float p = clamp(position, 0.0f, 1.0f) * 4.0f;
        int i = (int)p; if (i > 3) i = 3;
        const float f = p - (float)i;
        f1 = kF1[i] + (kF1[i + 1] - kF1[i]) * f;
        f2 = kF2[i] + (kF2[i + 1] - kF2[i]) * f;
    }

    // Everything that needs pow / tan / exp, every kControlInterval samples.
    void updateControl()
    {
        const Settings& s = s_;
        // A toot that is a stab ends here: back to the drone while the key is still held.
        if (tootActive_ && tootTicks_ > 0 && --tootTicks_ == 0)
        {
            tootActive_ = false;
            toot_.setTarget(0.0f);
            note_.setTime(25.0f, sr_);
            note_.setTarget(base_.target());
        }
        const float toot = toot_.value();

        // Slow random pitch drift: a new random target a few times a second, eased in.
        if (--driftCountdown_ <= 0)
        {
            const int ticks = 600 + (int)(rng_.nextFloat() * 900.0f);    // control ticks at 44.1 kHz: ~0.2-0.55 s
            driftCountdown_ = (int)((float)ticks * driftTickScale_);
            driftTarget_ = rng_.nextBipolar();
        }
        drift_ += driftEase_ * (driftTarget_ - drift_);

        // A raised tongue lifts the drone by about a third of a semitone (measured: 34 cents).
        const float pitch = note_.value() + bend_.value() * s.bendRange + drift_ * s.drift + 0.35f * tongueNow_;
        const float hz = clamp(midiToHz(pitch), 16.0f, 4000.0f);
        saw_.setFrequency(hz);
        pulse_.setFrequency(hz);
        voice_.setFrequency(clamp(hz * (s.voice > 0.0f ? s.voiceRatio : s.growlRatio), 16.0f, 8000.0f));

        // Lip shape: more buzz (and an overblown note) means a narrower pulse.
        // Rhythm: where in its step the pulse is, and what kind of step it is.
        const float phase = ppqPhase(ppq_, s.rhyBeats);
        rhythmPulse_ = std::exp(-phase * s.rhyRate);
        const Pattern& pattern = kPatterns[s.pattern];
        const long long step = (long long)std::floor(ppq_ / (double)s.rhyBeats);
        const bool accented = pattern.accent[(int)(((step % pattern.length) + pattern.length) % pattern.length)];
        // An accent is a surge of the belly with the tongue thrown forward, and a flash of the
        // overblown tone's brightness; a soft step draws the tongue back.
        const float colour = accented ? 1.0f : -1.0f;
        const float surge = accented ? 1.0f + 0.8f * s.accent * rhythmPulse_ : 1.0f - 0.3f * s.accent;
        const float bright = toot + (accented ? 0.5f * s.accent * rhythmPulse_ * rhythmPulse_ * rhythmPulse_ * rhythmPulse_ : 0.0f);
        // An in-breath takes the first fifth of a second of a soft step: the level drops and keeps
        // falling, and only the closed mouth is left behind the lips.
        float breath = 0.0f;
        if (!accented && s.breathIn > 0.0f)
        {
            const float seconds = phase * s.rhyBeats / (float)(s.ppqPerSample * (double)sr_);
            if (seconds < 0.2f) breath = s.breathIn * (0.35f + 0.65f * seconds / 0.2f);
        }
        breathing_ += breathEase_ * (breath - breathing_);

        breathNow_ = s.breath * (1.0f + 3.0f * breathing_);                 // the in-breath is heard

        buzzNow_ = clamp(s.buzz + 0.3f * bright, 0.0f, 1.0f);
        const float pw = 0.5f - 0.38f * buzzNow_;
        pulse_.setPulseWidth(pw);
        pulseDc_ = 2.0f * pw - 1.0f;

        // Rhythm pulse: 1 at the start of each division, decaying towards 0.
        rhythmGain_.setTarget((1.0f - s.rhyDepth * (1.0f - rhythmPulse_)) * surge * (1.0f - 0.6f * breathing_));

        // Vowel position from the knob, the wheel, the wobble LFO, the rhythm and the toot.
        wobblePhase_ = wrapPhase(wobblePhase_ + s.wobbleInc);
        const float vowel = s.vowel + wheel_.value() * s.wheelVowel + fastSin01(wobblePhase_) * s.wobbleDepth
                          + rhythmPulse_ * (s.rhyVowel * colour) + bright * 0.35f;
        float f1, f2;
        vowelFormants(vowel, f1, f2);
        formant1_.set(f1, formantReso_);
        formant2_.set(f2, formantReso_);
        body_.set(hz, 0.8f);
        toneLp_.setCutoff(clamp(s.tone * (1.0f + 2.0f * bright), 100.0f, 0.45f * sr_), sr_);

        // The tongue. A real vocal tract takes energy out: with the tongue raised it resonates
        // near 0.83, 1.17 and 1.56 times a centre frequency, and where it resonates it holds the
        // lip flow back (about 20 dB). Between two resonances their pulls cancel, the flow passes,
        // and that band is the formant the ear follows (1 to 2.2 kHz). Only closed mouth shapes
        // raise the tongue, and an in-breath drops it.
        const float shape = clamp(vowel, 0.0f, 1.0f);
        const float raised = clamp((shape - 0.25f) / 0.55f, 0.0f, 1.0f);
        tongueNow_ = s.tongue * raised * raised * (3.0f - 2.0f * raised) * (1.0f - breathing_);
        if (s.tongue > 0.0f)
        {
            const float centre = 1000.0f + 1200.0f * shape;
            static const float kRatio[3] = { 0.833f, 1.167f, 1.556f };
            float now = 0.0f;
            for (int i = 0; i < 3; ++i)
            {
                tract_[i].set(clamp(centre * kRatio[i], 100.0f, 0.45f * sr_), 24.0f, sr_);
                now += tract_[i].now();
            }
            tractLoad_ = 12.0f * tongueNow_;                 // the resonances' height, in lip resistances
            tractNow_ = 1.0f / (1.0f + tractLoad_ * now);
        }

        // The tube. Its first resonance is tall and narrow and lies 2.5 % under the drone; the
        // second is where the toot sounds, and the next two follow from it: 3, 5, 7 times the
        // first for a cylinder (toot a twelfth up), closer together and weaker for a flared tube.
        if (s.tube > 0.0f)
        {
            static const float kQ[4] = { 25.0f, 14.0f, 10.0f, 8.0f };
            static const float kGain[4] = { 8.0f, 3.0f, 1.0f, 0.6f };
            const float first = clamp(midiToHz(base_.value()) / 1.025f, 16.0f, 2000.0f);
            const float flare = 3.0f - clamp(s.tootRatio, 2.0f, 3.0f);                   // 0 = cylinder
            const float ratio[4] = { 1.0f, s.tootRatio, 5.0f - 1.833f * flare, 7.0f - 2.667f * flare };
            for (int m = 0; m < 4; ++m)
            {
                const float k = 1.0f / kQ[m];
                tube_[m].set(clamp(first * ratio[m], 16.0f, 0.45f * sr_), (2.0f - k) / 1.98f);
                tubeGain_[m] = s.tube * kGain[m] * k * (m == 0 ? 1.0f : 1.0f - 0.8f * flare);
            }
            tubeLevel_ = 1.0f / (1.0f + 2.45f * s.tube);     // the tube shapes the sound, it does not make it louder
        }

        growlNow_ = clamp(s.growl + pressure_.value() * 0.6f, 0.0f, 1.0f);
    }

    void render(float* outL, float* outR, int from, int to)
    {
        const Settings& s = s_;
        const float bodyK = 2.0f - 1.98f * 0.8f;

        for (int i = from; i < to; ++i)
        {
            // Smoothers and clocks run even while silent so nothing jumps on the next note.
            note_.process(); base_.process(); bend_.process(); wheel_.process(); pressure_.process(); toot_.process();
            const float volume = volume_.process();
            const float velocity = velocity_.process();
            const float rhythm = rhythmGain_.process();
            ppq_ += s.ppqPerSample;
            if (--controlCountdown_ <= 0) { controlCountdown_ = kControlInterval; updateControl(); }

            float y = 0.0f;
            if (env_.isActive())
            {
                const float env = env_.process();

                // Lips: saw <-> narrow pulse, roughened by the sung voice.
                const float saw = saw_.process();
                const float pulse = pulse_.process() - pulseDc_;
                float buzz = saw + (pulse - saw) * buzzNow_;
                const float sung = voice_.process();
                buzz *= 1.0f - 0.5f * growlNow_ + 1.3f * growlNow_ * sung;
                // Voice: the glottis is a second valve in the same air stream, open half its cycle.
                if (s.voice > 0.0f) buzz *= 1.0f - s.voice + 2.0f * s.voice * (sung > 0.0f ? sung : 0.0f);

                // Breath joins the buzz on its way through the mouth.
                float excite = buzz + breathNoise_.process() * breathNow_;
                if (s.tongue > 0.0f)
                {
                    excite = (excite - tractLoad_ * (tract_[0].held() + tract_[1].held() + tract_[2].held())) * tractNow_;
                    for (TractResonance& resonance : tract_) resonance.step(excite);
                }

                const float direct = toneLp_.process(excite);
                const float mouth = (formant1_.process(excite, SVF::Mode::Bandpass)
                                   + 0.7f * formant2_.process(excite, SVF::Mode::Bandpass)) * s.formantK;
                const float body = body_.process(buzz, SVF::Mode::Bandpass) * bodyK;

                y = direct * (1.0f - 0.5f * s.formant) + mouth * s.formantGain + body * s.body;
                if (s.tube > 0.0f)
                {
                    for (int m = 0; m < 4; ++m) y += tubeGain_[m] * tube_[m].process(excite, SVF::Mode::Bandpass);
                    y *= tubeLevel_;
                }
                y *= env * velocity * rhythm * 0.75f;
                y = fastTanh(y * s.drivePre) * s.drivePost;
                y = dc_.process(y) * volume;
            }
            outL[i] = y;
            if (outR) outR[i] = y;
        }
    }

    // --- parameters and cross-thread state -------------------------------------------------
    std::atomic<float>  values_[kNumParams];
    std::atomic<int>    program_{0};
    std::atomic<bool>   resetPending_{false};
    std::atomic<double> bpm_{120.0}, transportPpq_{0.0};
    std::atomic<bool>   transportLocked_{false};

    MidiEvent events_[kMaxEvents];
    int       numEvents_ = 0;
    struct PostSlot { std::atomic<uint32_t> turn; MidiEvent event; };
    PostSlot  posted_[kPostSize];
    std::atomic<uint32_t> postWrite_{0};    // next position to write: shared by the posting threads
    uint32_t  postRead_ = 0;                // next position to read: the audio thread's own

    // --- DSP -------------------------------------------------------------------------------
    PolyBlepOsc   saw_, pulse_;
    WavetableSine voice_;
    PinkNoise     breathNoise_;
    Xorshift32    rng_{0x51D6E21Du};
    OnePoleLP     toneLp_;
    SVF           formant1_, formant2_, body_;
    SVF           tube_[4];
    TractResonance tract_[3];
    ADSR          env_;
    DCBlocker     dc_;
    Smoother      volume_, velocity_, wheel_, bend_, pressure_, toot_, rhythmGain_, note_;
    Smoother      base_;                          // the drone's note without a toot: what the tube is tuned to

    // --- state -----------------------------------------------------------------------------
    Settings s_{};
    float  sr_ = 44100.0f;
    float  glideMs_ = -1.0f;
    float  formantReso_ = 0.8f;
    float  buzzNow_ = 0.5f, pulseDc_ = 0.0f, growlNow_ = 0.0f;
    float  drift_ = 0.0f, driftTarget_ = 0.0f;
    float  driftTickScale_ = 1.0f, driftEase_ = 0.004f, breathEase_ = 0.02f;
    float  wobblePhase_ = 0.0f, rhythmPulse_ = 1.0f;
    double ppq_ = 0.0;
    int    driftCountdown_ = 0, controlCountdown_ = 0;
    int    held_[kMaxHeld] = {};
    int    numHeld_ = 0;
    int    noteShift_ = 12 * kOctaveAtRest;      // semitones from a MIDI note to the note that sounds
    float  tongueNow_ = 0.0f, breathing_ = 0.0f, breathNow_ = 0.0f, tractLoad_ = 0.0f, tractNow_ = 1.0f, tubeGain_[4] = {}, tubeLevel_ = 1.0f;
    int    tootTicks_ = 0;                        // control ticks left of a toot that is a stab
    bool   sustain_ = false, sustained_ = false, tootActive_ = false;
};

// ---------------------------------------------------------------------------------------------
// C interface
// ---------------------------------------------------------------------------------------------
static bool validParam(int i) { return i >= 0 && i < kNumParams; }

int didge_num_params(void) { return kNumParams; }

void didge_param_info(int index, DidgeParamInfo* out)
{
    if (!out || !validParam(index)) return;
    const Param& p = kParams[index];
    out->identifier = p.id; out->name = p.name; out->unit = p.unit; out->kind = p.kind;
    out->minValue = p.min; out->maxValue = p.max; out->defaultValue = p.def;
    out->logarithmic = p.logarithmic ? 1 : 0;
    out->numChoices = p.kind == DIDGE_KIND_CHOICE ? (int)p.max + 1 : 0;
    out->section = sectionOf(index);
}

const char* didge_param_choice(int index, int choice)
{
    if (index == kRhyPattern) return kPatterns[clamp(choice, 0, kNumPatterns - 1)].name;
    if (index != kRhythmDiv) return "";
    return divisionName(choice);
}

float didge_param_to_plain(int index, float normalised) { return validParam(index) ? kParams[index].toPlain(normalised) : 0.0f; }
float didge_param_to_normalised(int index, float plain) { return validParam(index) ? kParams[index].toNormalised(plain) : 0.0f; }

const char* didge_param_display(int index, float plain, char* buffer, int bufferSize)
{
    if (!buffer || bufferSize <= 0) return "";
    buffer[0] = 0;
    if (!validParam(index)) return buffer;
    const Param& p = kParams[index];
    if (index == kTootVel && plain >= 127.5f) std::snprintf(buffer, (size_t)bufferSize, "Off");   // top of the range = no overblowing
    else if (index == kTootLen && plain < 0.5f) std::snprintf(buffer, (size_t)bufferSize, "Hold");   // as long as the key
    else if (index == kOctave && plain >= 0.5f) std::snprintf(buffer, (size_t)bufferSize, "+%d", (int)std::lround(plain));
    else if (p.kind == DIDGE_KIND_CHOICE) std::snprintf(buffer, (size_t)bufferSize, "%s", didge_param_choice(index, (int)std::lround(plain)));
    else if (p.kind == DIDGE_KIND_INT) std::snprintf(buffer, (size_t)bufferSize, "%d", (int)std::lround(plain));
    else
    {
        std::snprintf(buffer, (size_t)bufferSize, "%.*f", p.decimals, (double)plain);
        if (buffer[0] == '-')     // turn "-0.0" into "0.0"
        {
            bool allZero = true;
            for (const char* q = buffer + 1; *q; ++q) if (*q != '0' && *q != '.') { allZero = false; break; }
            if (allZero) std::memmove(buffer, buffer + 1, std::strlen(buffer));
        }
    }
    return buffer;
}

static bool validSection(int s) { return s >= 0 && s < (int)sections().size(); }

int didge_num_sections(void) { return (int)sections().size(); }
const char* didge_section_name(int section) { return validSection(section) ? sections()[(size_t)section].name : ""; }
int didge_section_size(int section) { return validSection(section) ? (int)sections()[(size_t)section].params.size() : 0; }
int didge_section_param(int section, int position)
{
    return position >= 0 && position < didge_section_size(section) ? sections()[(size_t)section].params[(size_t)position] : -1;
}

int didge_num_programs(void) { return (int)programs().size(); }
const char* didge_program_name(int program) { return program >= 0 && program < didge_num_programs() ? programs()[(size_t)program].name : ""; }
int didge_program_sets(int param) { return validParam(param) && programSets(param) ? 1 : 0; }
float didge_program_value(int program, int param)
{
    return program >= 0 && program < didge_num_programs() && validParam(param) ? programs()[(size_t)program].values[param] : 0.0f;
}

DidgeEngine* didge_create(void)
{
    // The sine table in dsp/oscillator.h is shared by all engines and built on first use with
    // no guard. Build it here once, under the guard C++ gives the initialiser of a static, so
    // that engines created on different threads at the same moment cannot build it twice.
    static const bool sineTableBuilt = (WavetableSine(), true);
    (void)sineTableBuilt;
    return new DidgeEngine();
}
void didge_destroy(DidgeEngine* engine) { delete engine; }
void didge_prepare(DidgeEngine* engine, double sampleRate) { engine->prepare(sampleRate); }
void didge_reset(DidgeEngine* engine) { engine->reset(); }
void didge_request_reset(DidgeEngine* engine) { engine->requestReset(); }

float didge_get_plain(const DidgeEngine* engine, int index) { return validParam(index) ? engine->get(index) : 0.0f; }
float didge_get_normalised(const DidgeEngine* engine, int index) { return validParam(index) ? engine->getNormalised(index) : 0.0f; }
void didge_set_plain(DidgeEngine* engine, int index, float plain) { if (validParam(index)) engine->set(index, plain); }
void didge_set_normalised(DidgeEngine* engine, int index, float normalised) { if (validParam(index)) engine->setNormalised(index, normalised); }

void didge_set_program(DidgeEngine* engine, int program) { engine->setProgram(program); }
int didge_get_program(const DidgeEngine* engine) { return engine->program(); }

void didge_set_transport(DidgeEngine* engine, int playing, double bpm, double ppqPosition, int ppqValid)
{
    engine->setTransport(playing != 0, bpm, ppqPosition, ppqValid != 0);
}

void didge_post_midi(DidgeEngine* engine, int status, int data1, int data2, int sampleOffset)
{
    engine->postMidi((uint8_t)status, (uint8_t)(data1 & 0x7F), (uint8_t)(data2 & 0x7F), sampleOffset);
}

void didge_midi(DidgeEngine* engine, int status, int data1, int data2, int sampleOffset)
{
    engine->midi((uint8_t)status, (uint8_t)(data1 & 0x7F), (uint8_t)(data2 & 0x7F), sampleOffset);
}

void didge_process(DidgeEngine* engine, float* left, float* right, int frames)
{
    if (left && frames > 0) engine->process(left, right, frames);
}
