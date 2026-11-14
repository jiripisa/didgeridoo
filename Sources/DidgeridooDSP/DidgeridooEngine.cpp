// DidgeridooEngine.cpp - the Didgeridoo sound engine and its C interface.
//
// SPDX-License-Identifier: MIT
//
// The instrument as the published measurements describe it (see
// .planning/research/reports/Didgeridoo acoustics and playing.md): one air stream through the
// lips, held back by the vocal tract on one side and shaped by the tube on the other. The pitch
// is an input, as a keyboard needs; the rest follows the physics.
//
// Signal path:
//
//   lips:   the flow through a valve that is shut for part of every cycle: a pulse with a sharp
//           opening and a soft closure ("Buzz"), limited by what the pressure allows ("Drive")
//             * the voice: the glottis, a second valve in the same stream ("Voice")
//             + breath noise, which passes only while the lips are open ("Breath")
//                |
//   radiation:   the tube radiates the flow 6 dB per octave more strongly up to a corner
//                ("Tone"): the flow's difference from sample to sample, then a low-pass
//                |
//   mouth:  three resonances of the vocal tract load the flow and cut it where they stand; the
//           band left between them is the formant the ear follows ("Vowel", "Tongue")
//                |
//   tube:   eight resonances beside the direct sound ("Tube"), placed by the bore's flare
//           ("Flare"); the first is tall and narrow and lies just under the drone
//                |
//   -> amp envelope * velocity * rhythm pulse -> DC blocker -> volume -> limiter -> L = R
//
// Pitch: last-note priority with glide, pitch bend, slow random drift. "Octave" moves the whole
// instrument: at 0 a key sounds two octaves below its MIDI note, which puts a didgeridoo's range
// around middle C. The instrument does not overblow: three attempts at the overblown note did
// not pass the author's ear, and a hard hit is a loud drone.
//
// Two LFOs move the knobs: each has a rate and a shape, and every knob that can be moved has an
// amount for each of them. An LFO does not turn the knob; it adds to where the knob stands, for
// the engine only. The vowel also moves with the mod wheel and the tempo-synced rhythm pulse.
// Channel aftertouch adds the voice.
//
// Expensive maths (pow, tan, exp, sin) runs every 16 samples ("control rate"); the lips, the
// filters and the envelope run every sample. Nothing allocates in process().

// A product and a sum stay two operations. Fused into one they round once instead of twice, and
// an optimised build fuses where an unoptimised one does not: without this line two programs
// rendered samples that differed in their last bit between a debug and a release build, and the
// sound's references could hold for one of them only.
#pragma clang fp contract(off)

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
// Parameters, group by group. This is the table of the model that replaced the MPC plugin's
// engine; its identifiers and its order are permanent from here on: only ever append.
// ---------------------------------------------------------------------------------------------
enum Params
{
    // Mouth
    kVowel,         // %     mouth shape: where the tongue leaves its band, and how far it is raised
    kTongue,        // %     how deep the vocal tract's resonances cut into the lip flow
    kWheelVowel,    // %     how far the mod wheel moves the vowel
    kLfo1Rate,      // Hz    how often LFO 1 goes round
    kLfo1Shape,     // -     the shape of its cycle
    kLfo2Rate,      // Hz    the same for LFO 2
    kLfo2Shape,     // -
    kVolume,        // dB    master volume
    // Lips
    kBuzz,          // %     how hard the lips close: 0 = soft and mellow, 100 = hard and bright
    kDrive,         // %     how far the lip valve is driven into its limit
    kBreath,        // %     breath noise carried by the flow through the lips
    kDrift,         // %     slow random pitch instability
    kVoice,         // %     a voice sung through the lips (a second valve in the same stream)
    kVoicePitch,    // -     the interval of the voice above the drone
    kRough,         // %     how far the voice is off its lock, so that it beats
    kAttack,        // ms    amp envelope attack
    kRelease,       // ms    amp envelope release
    // Tube
    kTube,          // %     how strongly the tube's own resonances stand out
    kTone,          // Hz    the corner above which the tube radiates no more strongly
    kFlare,         // %     the tube's shape: 0 = a plain pipe, 100 = a tube that widens to a wide bell
    kGlide,         // ms    slide time between notes
    kBendRange,     // st    pitch bend range
    kOctave,        // -     octave of the whole instrument; 0 = two octaves below the MIDI note
    // Rhythm
    kRhythmDiv,     // -     note division of the rhythm pulse
    kRhyPattern,    // -     which steps of the rhythm are accents and which are soft
    kRhyDepth,      // %     how deep the pulse ducks the volume
    kRhyVowel,      // %     how far the pulse pushes the vowel (signed)
    kRhyDecay,      // %     pulse shape: 0 = long swell, 100 = short stab
    kRhyAccent,     // %     surge of an accented step
    kRhyBreath,     // %     in-breath on a soft step
    kNumKnobs,
    // After the knobs come the LFOs' amounts, one for each LFO and each knob an LFO can move
    // (amountOf): how far that LFO moves that knob, as a part of the knob's travel.
    kNumParams = kNumKnobs + 2 * 16
};

constexpr int kNumLfos = 2;

// The knobs an LFO can move: the continuous ones. Not the switches, not the times, not Wheel
// Vowel and Drift (amounts of something else already), not the LFOs' own knobs.
constexpr int kTargets[] = { kVowel, kTongue, kVolume, kBuzz, kDrive, kBreath, kVoice, kRough, kTube, kTone, kFlare,
                             kRhyDepth, kRhyVowel, kRhyDecay, kRhyAccent, kRhyBreath };
constexpr int kNumTargets = (int)(sizeof(kTargets) / sizeof(kTargets[0]));
static_assert(kNumParams == kNumKnobs + kNumLfos * kNumTargets, "the amounts do not fill the table");

// The parameter that says how far LFO `lfo` moves `knob`; -1 when it cannot move it.
constexpr int amountOf(int lfo, int knob)
{
    for (int t = 0; t < kNumTargets; ++t) if (kTargets[t] == knob) return kNumKnobs + lfo * kNumTargets + t;
    return -1;
}

// The shapes of an LFO's cycle. Steps takes a new random level each cycle and holds it; Wander
// takes one and moves there smoothly.
enum LfoShape { kLfoSine, kLfoTriangle, kLfoRampUp, kLfoRampDown, kLfoSquare, kLfoSteps, kLfoWander, kNumLfoShapes };
const char* const kLfoShapeNames[kNumLfoShapes] = { "Sine", "Triangle", "Ramp Up", "Ramp Down", "Square", "Steps", "Wander" };

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
// which are soft (the tongue drawn back, and the place for an in-breath).
// ---------------------------------------------------------------------------------------------
struct Pattern { const char* name; int length; bool accent[6]; };

const Pattern kPatterns[] = {
    { "Even",        1, { true } },
    { "A-b",         2, { true, false } },
    { "A-b-b",       3, { true, false, false } },
    { "A-b-b-A-b-A", 6, { true, false, false, true, false, true } },
};
constexpr int kNumPatterns = (int)(sizeof(kPatterns) / sizeof(kPatterns[0]));

// ---------------------------------------------------------------------------------------------
// The voice's intervals above the drone: the simple ratios, because only those lock the voice to
// the lips, so that its sums and differences with the drone fall on one steady series. A fifth
// and a tenth give the tone an octave below the drone; players sing the tenth most.
// ---------------------------------------------------------------------------------------------
struct Interval { const char* name; float ratio; };

const Interval kIntervals[] = {
    { "Unison",  1.0f },
    { "Third",   5.0f / 4.0f },
    { "Fourth",  4.0f / 3.0f },
    { "Fifth",   3.0f / 2.0f },
    { "Octave",  2.0f },
    { "Tenth",   5.0f / 2.0f },
    { "Twelfth", 3.0f },
};
constexpr int kNumIntervals = (int)(sizeof(kIntervals) / sizeof(kIntervals[0]));
constexpr int kIntervalFifth = 3, kIntervalTenth = 5;

const Param kKnobs[kNumKnobs] = {
    floatParam ("vowel",       "Vowel",        0.0f, 100.0f, 45.0f, "%", 0),
    floatParam ("tongue",      "Tongue",       0.0f, 100.0f, 65.0f, "%", 0),
    floatParam ("wheelvowel",  "Wheel Vowel",  0.0f, 100.0f, 100.0f, "%", 0),
    logParam   ("lfo1rate",    "LFO 1 Rate",   0.02f, 20.0f, 0.3f, "Hz", 2),
    choiceParam("lfo1shape",   "LFO 1 Shape",  kNumLfoShapes, kLfoSine),
    logParam   ("lfo2rate",    "LFO 2 Rate",   0.02f, 20.0f, 2.0f, "Hz", 2),
    choiceParam("lfo2shape",   "LFO 2 Shape",  kNumLfoShapes, kLfoSine),
    floatParam ("volume",      "Volume",       -40.0f, 6.0f, 0.0f, "dB", 1),

    floatParam ("buzz",        "Buzz",         0.0f, 100.0f, 75.0f, "%", 0),
    floatParam ("drive",       "Drive",        0.0f, 100.0f, 55.0f, "%", 0),
    floatParam ("breath",      "Breath",       0.0f, 100.0f, 15.0f, "%", 0),
    floatParam ("drift",       "Drift",        0.0f, 100.0f, 12.0f, "%", 0),
    floatParam ("voice",       "Voice",        0.0f, 100.0f, 0.0f, "%", 0),
    choiceParam("voicepitch",  "Voice Pitch",  kNumIntervals, kIntervalTenth),
    floatParam ("rough",       "Rough",        0.0f, 100.0f, 0.0f, "%", 0),
    logParam   ("attack",      "Attack",       5.0f, 2000.0f, 60.0f, "ms", 0),
    logParam   ("release",     "Release",      10.0f, 3000.0f, 180.0f, "ms", 0),

    floatParam ("tube",        "Tube",         0.0f, 100.0f, 60.0f, "%", 0),
    logParam   ("tone",        "Tone",         200.0f, 8000.0f, 3000.0f, "Hz", 0),
    floatParam ("flare",       "Flare",        0.0f, 100.0f, 33.0f, "%", 0),
    floatParam ("glide",       "Glide",        0.0f, 1000.0f, 60.0f, "ms", 0, 0.4f),
    intParam   ("bendrange",   "Bend Range",   0, 12, 1, "st"),
    intParam   ("octave",      "Octave",       -2, 2, 0),

    choiceParam("rhythmdiv",   "Rhythm Div",   kNumDivisions, kDivisionEighth),
    choiceParam("rhypattern",  "Pattern",      kNumPatterns, 0),
    floatParam ("rhydepth",    "Rhy Depth",    0.0f, 100.0f, 0.0f, "%", 0),
    floatParam ("rhyvowel",    "Rhy>Vowel",    -100.0f, 100.0f, 0.0f, "%", 0),
    floatParam ("rhydecay",    "Rhy Decay",    0.0f, 100.0f, 40.0f, "%", 0),
    floatParam ("rhyaccent",   "Accent",       0.0f, 100.0f, 0.0f, "%", 0),
    floatParam ("rhybreath",   "Breath In",    0.0f, 100.0f, 0.0f, "%", 0),
};

// The whole table: the knobs, then the amounts, named after their LFO and their knob
// ("lfo1vowel", "LFO 1>Vowel"). As the instrument comes, LFO 1 sways the vowel a little.
char amountIds[kNumLfos * kNumTargets][24], amountNames[kNumLfos * kNumTargets][40];

const Param* makeParams()
{
    static Param table[kNumParams];
    for (int i = 0; i < kNumKnobs; ++i) table[i] = kKnobs[i];
    for (int lfo = 0; lfo < kNumLfos; ++lfo)
        for (int t = 0; t < kNumTargets; ++t)
        {
            const int slot = lfo * kNumTargets + t;
            std::snprintf(amountIds[slot], sizeof amountIds[slot], "lfo%d%s", lfo + 1, kKnobs[kTargets[t]].id);
            std::snprintf(amountNames[slot], sizeof amountNames[slot], "LFO %d>%s", lfo + 1, kKnobs[kTargets[t]].name);
            const float atRest = lfo == 0 && kTargets[t] == kVowel ? 8.75f : 0.0f;
            table[kNumKnobs + slot] = floatParam(amountIds[slot], amountNames[slot], -100.0f, 100.0f, atRest, "%", 0);
        }
    return table;
}
const Param* const kParams = makeParams();

// ---------------------------------------------------------------------------------------------
// Sections: the groups the parameters are shown in (the app's panels, the Audio Unit's parameter
// groups) and the order inside each. Every parameter belongs to exactly one section, and the
// table above lists them in this very order.
// ---------------------------------------------------------------------------------------------
struct Section { const char* name; std::vector<int> params; };

const std::vector<Section>& sections()
{
    static const std::vector<Section> table = {
        { "Mouth",  { kVowel, kTongue, kWheelVowel, kLfo1Rate, kLfo1Shape, kLfo2Rate, kLfo2Shape, kVolume } },
        { "Lips",   { kBuzz, kDrive, kBreath, kDrift, kVoice, kVoicePitch, kRough, kAttack, kRelease } },
        { "Tube",   { kTube, kTone, kFlare, kGlide, kBendRange, kOctave } },
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
        // A wide, dark tube under an open mouth: weight and no formant.
        makeProgram("Deep Earth",    {{kVowel, 12}, {kTongue, 40}, {kBuzz, 35}, {kDrive, 35}, {kTone, 1100}, {kTube, 90}, {kFlare, 62},
                                      {kBreath, 8}, {kLfo1Rate, 0.15f}, {amountOf(0, kVowel), 4.2f}, {kAttack, 150}}),
        // The tongue rises and falls with LFO 1: the band comes, climbs and goes.
        makeProgram("Vocal Wah",     {{kVowel, 50}, {kTongue, 100}, {kBuzz, 90}, {kTone, 4000}, {kTube, 45},
                                      {kLfo1Rate, 1.6f}, {amountOf(0, kVowel), 28}}),
        // A voice a fifth up, off its lock: the tone an octave down, beating.
        makeProgram("Growler",       {{kVoice, 70}, {kVoicePitch, (float)kIntervalFifth}, {kRough, 27}, {kDrive, 80}, {kBuzz, 85},
                                      {kVowel, 40}, {kBreath, 25}, {kDrift, 25}}),
        // The pulse ducks the level between its steps, so these two are turned up a little.
        makeProgram("Rhythm Breath", {{kVolume, 3}, {kRhyDepth, 70}, {kRhyVowel, 80}, {kRhyDecay, 55}, {kRhythmDiv, (float)kDivisionEighth},
                                      {kVowel, 25}, {kTongue, 90}, {amountOf(0, kVowel), 0}, {kBreath, 30}}),
        makeProgram("Gallop",        {{kVolume, 5}, {kRhyDepth, 85}, {kRhyVowel, -60}, {kRhyDecay, 75}, {kRhythmDiv, (float)kDivisionSixteenth},
                                      {kVowel, 75}, {kTongue, 85}, {kBuzz, 85}, {kDrive, 70}, {amountOf(0, kVowel), 3.5f}}),
        // A termite-hollowed tube that players would rank high: a strong, narrow fundamental
        // and a tongue that does the rest.
        makeProgram("Eucalyptus",    {{kTube, 85}, {kFlare, 48}, {kTongue, 85}, {kVowel, 50}, {kBuzz, 70}, {kBreath, 12},
                                      {kLfo1Rate, 0.25f}, {amountOf(0, kVowel), 12.25f}, {kDrift, 10}}),
        // The Yolngu way: a pitch that does not move, accents and in-breaths.
        makeProgram("Hard Tongue",   {{kTube, 70}, {kFlare, 48}, {kTongue, 90}, {kVowel, 40}, {amountOf(0, kVowel), 0}, {kDrift, 8},
                                      {kRhythmDiv, (float)kDivisionEighth}, {kRhyPattern, 3}, {kRhyDepth, 45},
                                      {kRhyVowel, 60}, {kRhyDecay, 50}, {kRhyAccent, 80}, {kRhyBreath, 60}}),
        // A plastic pipe: a cylinder, which favours the odd harmonics.
        makeProgram("Pipe",          {{kTube, 100}, {kFlare, 0}, {kTongue, 55}, {kVowel, 40}, {kBuzz, 65}, {amountOf(0, kVowel), 5.25f},
                                      {kDrift, 8}}),
        // A voice locked a tenth above the drone.
        makeProgram("Singer",        {{kVoice, 45}, {kVoicePitch, (float)kIntervalTenth}, {kTongue, 60}, {kVowel, 50},
                                      {kLfo1Rate, 0.3f}, {amountOf(0, kVowel), 10.5f}}),
    };
    return table;
}

// ---------------------------------------------------------------------------------------------
// The tube's resonances. For a bore that flares a little, resonance n lies at
//   (n - 1/2) * (1 + sqrt(1 + s / (n - 1/2)^2))     times c / 4L
// where s grows with the flare (Fletcher et al. 2006): 1, 3, 5 ... for a cylinder (s = 0), closer
// together for a flared tube. Flare runs from the cylinder to the tube whose second resonance
// stands an octave above its first.
// ---------------------------------------------------------------------------------------------
constexpr int kNumModes = 8;

float modePlace(int n, float s)
{
    const float h = (float)n - 0.5f;
    return h * (1.0f + std::sqrt(1.0f + s / (h * h)));
}

// The flare whose second resonance stands `ratio` (2 to 3) above its first.
float flareFor(float ratio)
{
    float low = 0.0f, high = 1.2f;                          // ratios 3.0 and 1.97
    for (int i = 0; i < 24; ++i)
    {
        const float middle = 0.5f * (low + high);
        if (modePlace(2, middle) / modePlace(1, middle) > ratio) low = middle; else high = middle;
    }
    return 0.5f * (low + high);
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

// A point going round the unit circle: the cosine and sine of an oscillator's phase, exact and
// without a trigonometric call per sample. The lip flow is differentiated and scaled by the
// pitch, which would bring out the steps of a sine table.
struct Phasor
{
    void setIncrement(double cyclesPerSample)
    {
        stepC = std::cos(2.0 * 3.14159265358979323846 * cyclesPerSample);
        stepS = std::sin(2.0 * 3.14159265358979323846 * cyclesPerSample);
    }
    void reset(double phase01)
    {
        c = std::cos(2.0 * 3.14159265358979323846 * phase01);
        s = std::sin(2.0 * 3.14159265358979323846 * phase01);
    }
    void step()
    {
        const double next = c * stepC - s * stepS;
        s = s * stepC + c * stepS;
        c = next;
    }
    void normalise()                                        // keeps rounding from changing its length
    {
        const double length = std::sqrt(c * c + s * s);
        if (length > 0.0) { c /= length; s /= length; }
    }

    double c = 1.0, s = 0.0, stepC = 1.0, stepS = 0.0;
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
        for (SVF& mode : tube_) mode.setSampleRate(sampleRate);
        env_.setSampleRate(sampleRate);
        dc_.prepare(sampleRate, 20.0f);
        breathLp_.setCutoff(1500.0f, sampleRate);
        volume_.setTime(20.0f, sampleRate);
        velocity_.setTime(15.0f, sampleRate);
        wheel_.setTime(25.0f, sampleRate);
        bend_.setTime(10.0f, sampleRate);
        pressure_.setTime(40.0f, sampleRate);
        rhythmGain_.setTime(4.0f, sampleRate);
        base_.setTime(60.0f, sampleRate);
        glideMs_ = -1.0f;

        // Drift is timed in control ticks, scaled so that it wanders equally fast at every
        // sample rate.
        driftTickScale_ = sr_ / 44100.0f;
        driftEase_ = sr_ == 44100.0f ? 0.004f : 1.0f - std::pow(1.0f - 0.004f, 44100.0f / sr_);
        breathEase_ = 1.0f - std::exp(-(float)kControlInterval / (0.006f * sr_));      // an in-breath sets in within 6 ms
    }

    void reset()
    {
        lips_.reset(0.5); glottis_.reset(0.0);
        toneLp_.reset(); breathLp_.reset(); env_.reset(); dc_.reset(); breathNoise_.reset();
        for (TractResonance& resonance : tract_) resonance.reset();
        for (SVF& mode : tube_) mode.reset();
        numHeld_ = 0; sustain_ = false; sustained_ = false;
        volume_.snap(dbToGain(get(kVolume)));
        velocity_.snap(0.7f);
        wheel_.snap(0.0f); bend_.snap(0.0f); pressure_.snap(0.0f);
        rhythmGain_.snap(1.0f);
        base_.snap(38.0f);
        flowBefore_ = noiseBefore_ = 0.0f; primeFlow_ = latch_ = true; sineBefore_ = 0.0f;
        tongueNow_ = 0.0f; breathing_ = 0.0f;
        drift_ = driftTarget_ = 0.0f; driftCountdown_ = 0;
        for (int lfo = 0; lfo < kNumLfos; ++lfo) lfoPhase_[lfo] = lfoValue_[lfo] = lfoFrom_[lfo] = lfoTo_[lfo] = 0.0f;
        rhythmPulse_ = 1.0f;
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

    static constexpr float kFirstQ = 25.0f;       // the first resonance: measured 12 to 86
    static constexpr float kLevel = 0.2f;         // brings the sum to the level the limiter leaves alone

    // Parameters read once per block.
    struct Settings
    {
        float vowel, tongue, buzz, drive, tone, breath, voice, voiceRatio;
        float rhyBeats, rhyDepth, rhyVowel, rhyRate;
        float wheelVowel, bendRange, drift;
        float tube, flare, modeRatio[kNumModes], accent, breathIn;
        int   pattern;
        double ppqPerSample;
    };

    // Where a knob stands for the engine right now: where it was put, and what the LFOs add.
    float plain(int knob) const { return kParams[knob].toPlain(now_[knob]); }
    int   choice(int knob) const { return (int)std::lround(plain(knob)); }

    void readBlockSettings()
    {
        for (int i = 0; i < kNumParams; ++i) knob_[i] = getNormalised(i);
        for (int i = 0; i < kNumKnobs; ++i) now_[i] = knob_[i];
        moving_ = false;
        for (int lfo = 0; lfo < kNumLfos; ++lfo)
        {
            for (int t = 0; t < kNumTargets; ++t)
            {
                const int index = kNumKnobs + lfo * kNumTargets + t;
                amount_[lfo][t] = kParams[index].toPlain(knob_[index]) * 0.01f;
                if (amount_[lfo][t] != 0.0f) moving_ = true;
            }
            lfoInc_[lfo] = plain(kLfo1Rate + 2 * lfo) * (float)kControlInterval / sr_;
            lfoShape_[lfo] = clamp(choice(kLfo1Shape + 2 * lfo), 0, (int)kNumLfoShapes - 1);
        }
        if (moving_) moveKnobs();
        deriveSettings();

        env_.set(plain(kAttack), 1.0f, 1.0f, plain(kRelease));
        const float glide = plain(kGlide);
        if (glide != glideMs_) { glideMs_ = glide; base_.setTime(glide, sr_); }

        // Octave. The shift is part of the note number, so a sounding note slides to a new octave.
        const int shift = 12 * (choice(kOctave) + kOctaveAtRest);
        if (shift != noteShift_)
        {
            if (env_.isActive()) base_.setTarget(base_.target() + (float)(shift - noteShift_));
            noteShift_ = shift;
        }

        // Rhythm clock: follow the song while it plays, free-run at the tempo otherwise.
        s_.ppqPerSample = (double)safeBpm(bpm_.load(std::memory_order_relaxed)) / 60.0 / (double)sr_;
        if (transportLocked_.load(std::memory_order_relaxed)) ppq_ = transportPpq_.load(std::memory_order_relaxed);
    }

    // The LFOs go round, one step of the control rate at a time, whether a note sounds or not.
    void turnLfos()
    {
        for (int lfo = 0; lfo < kNumLfos; ++lfo)
        {
            float phase = lfoPhase_[lfo] + lfoInc_[lfo];
            if (phase >= 1.0f)                                   // a new cycle: Steps and Wander take a new level
            {
                phase = wrapPhase(phase);
                lfoFrom_[lfo] = lfoTo_[lfo];
                lfoTo_[lfo] = lfoRng_.nextBipolar();
            }
            lfoPhase_[lfo] = phase;
            float value = 0.0f;
            switch (lfoShape_[lfo])
            {
                case kLfoSine:     value = fastSin01(phase); break;
                case kLfoTriangle: value = phase < 0.25f ? 4.0f * phase : (phase < 0.75f ? 2.0f - 4.0f * phase : 4.0f * phase - 4.0f); break;
                case kLfoRampUp:   value = 2.0f * phase - 1.0f; break;
                case kLfoRampDown: value = 1.0f - 2.0f * phase; break;
                case kLfoSquare:   value = phase < 0.5f ? 1.0f : -1.0f; break;
                case kLfoSteps:    value = lfoTo_[lfo]; break;
                default:           value = lfoFrom_[lfo] + (lfoTo_[lfo] - lfoFrom_[lfo]) * phase * phase * (3.0f - 2.0f * phase); break;
            }
            lfoValue_[lfo] = value;
        }
    }

    // The knobs an LFO has an amount on, moved to where they stand at this moment. A knob stops
    // at the ends of its travel.
    void moveKnobs()
    {
        for (int t = 0; t < kNumTargets; ++t)
        {
            float position = knob_[kTargets[t]];
            for (int lfo = 0; lfo < kNumLfos; ++lfo) position += amount_[lfo][t] * lfoValue_[lfo];
            now_[kTargets[t]] = clamp(position, 0.0f, 1.0f);
        }
    }

    // What the knobs mean for the sound. Once a block, and at the control rate while an LFO
    // moves a knob.
    void deriveSettings()
    {
        Settings& s = s_;
        s.vowel   = plain(kVowel) * 0.01f;
        s.tongue  = plain(kTongue) * 0.01f;
        s.buzz    = plain(kBuzz) * 0.01f;
        s.drive   = plain(kDrive) * 0.01f;
        s.tone    = plain(kTone);
        s.breath  = plain(kBreath) * 0.01f * kBreathLevel;
        s.voice   = plain(kVoice) * 0.01f;
        // Rough pulls the voice up to 30 cents off its lock.
        s.voiceRatio = kIntervals[clamp(choice(kVoicePitch), 0, kNumIntervals - 1)].ratio * centsToRatio(0.3f * plain(kRough));
        s.rhyBeats  = divisionBeats(choice(kRhythmDiv));
        s.rhyDepth  = plain(kRhyDepth) * 0.01f;
        s.rhyVowel  = plain(kRhyVowel) * 0.01f * 0.6f;
        s.rhyRate   = 1.5f + 9.0f * plain(kRhyDecay) * 0.01f;
        s.wheelVowel  = plain(kWheelVowel) * 0.01f;
        s.bendRange = plain(kBendRange);
        s.drift     = plain(kDrift) * 0.01f * 0.3f;                  // up to +-30 cents
        s.pattern   = clamp(choice(kRhyPattern), 0, kNumPatterns - 1);
        s.accent    = plain(kRhyAccent) * 0.01f;
        s.breathIn  = plain(kRhyBreath) * 0.01f;

        // The tube: how much it flares says where its second resonance stands (three times the
        // first for a pipe, twice for the widest bell), and with that where the others lie.
        s.tube = plain(kTube) * 0.01f;
        const float second = 3.0f - plain(kFlare) * 0.01f;
        if (second != second_)
        {
            second_ = second;
            const float flare = flareFor(second);
            s.flare = clamp(3.0f - second, 0.0f, 1.0f);              // 0 = a cylinder, 1 = a cone
            for (int m = 0; m < kNumModes; ++m) s.modeRatio[m] = modePlace(m + 1, flare) / modePlace(1, flare);
        }

        volume_.setTarget(dbToGain(plain(kVolume)));
    }

    void handleMidi(const MidiEvent& ev)
    {
        if (ev.isNoteOn())
        {
            removeHeld(ev.data1);
            if (numHeld_ == kMaxHeld) { for (int i = 1; i < kMaxHeld; ++i) held_[i - 1] = held_[i]; --numHeld_; }
            held_[numHeld_++] = ev.data1;
            startNote(ev.data1, ev.data2);
        }
        else if (ev.isNoteOff())
        {
            const bool wasSounding = numHeld_ > 0 && held_[numHeld_ - 1] == ev.data1;
            removeHeld(ev.data1);
            if (numHeld_ == 0)
            {
                if (sustain_) sustained_ = true; else env_.noteOff();
            }
            else if (wasSounding) startNote(held_[numHeld_ - 1], -1);   // fall back to the held note
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

    // velocity < 0 means "returning to a note that is still held": keep the level.
    void startNote(int note, int velocity)
    {
        const float target = (float)(note + noteShift_);
        const bool silent = !env_.isActive();
        if (silent)                                     // from silence: no slide into the note
        {
            base_.snap(target);
            lips_.reset(0.5); glottis_.reset(0.0);      // the lips start shut
            primeFlow_ = latch_ = true;
        }
        else base_.setTarget(target);

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

    // Everything that needs pow / tan / exp / sin, every kControlInterval samples.
    void updateControl()
    {
        turnLfos();
        if (moving_) { moveKnobs(); deriveSettings(); }
        const Settings& s = s_;

        // Slow random pitch drift: a new random target a few times a second, eased in.
        if (--driftCountdown_ <= 0)
        {
            const int span = 600 + (int)(rng_.nextFloat() * 900.0f);     // control ticks at 44.1 kHz: ~0.2-0.55 s
            driftCountdown_ = (int)((float)span * driftTickScale_);
            driftTarget_ = rng_.nextBipolar();
        }
        drift_ += driftEase_ * (driftTarget_ - drift_);

        // Pitch. A raised tongue lifts the drone by about a third of a semitone (measured: 34 cents).
        const float drone = base_.value() + bend_.value() * s.bendRange + drift_ * s.drift;
        const float hz = clamp(midiToHz(drone + 0.35f * tongueNow_), 16.0f, 4000.0f);
        const float inc = clamp(hz / sr_, 1.0e-5f, 0.45f);
        lips_.setIncrement((double)inc);
        lips_.normalise();
        radiate_ = 1.0f / (kTwoPi * inc);                // the flow's difference, per cycle: the same level at every pitch
        glottis_.setIncrement((double)clamp(hz * s.voiceRatio / sr_, 1.0e-5f, 0.45f));
        glottis_.normalise();

        // Rhythm: where in its step the pulse is, and what kind of step it is.
        const float phase = ppqPhase(ppq_, s.rhyBeats);
        rhythmPulse_ = std::exp(-phase * s.rhyRate);
        const Pattern& pattern = kPatterns[s.pattern];
        const long long step = (long long)std::floor(ppq_ / (double)s.rhyBeats);
        const bool accented = pattern.accent[(int)(((step % pattern.length) + pattern.length) % pattern.length)];
        // An accent is a surge of the belly with the tongue thrown forward and, for a moment,
        // lips that close harder; a soft step draws the tongue back.
        const float colour = accented ? 1.0f : -1.0f;
        const float surge = accented ? 1.0f + 0.8f * s.accent * rhythmPulse_ : 1.0f - 0.3f * s.accent;
        const float flash = accented ? 0.5f * s.accent * rhythmPulse_ * rhythmPulse_ * rhythmPulse_ * rhythmPulse_ : 0.0f;
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

        // Rhythm pulse: 1 at the start of each division, decaying towards 0.
        rhythmGain_.setTarget((1.0f - s.rhyDepth * (1.0f - rhythmPulse_)) * surge * (1.0f - 0.6f * breathing_));

        // The lips. They are shut for a good half of every cycle; the opening is sharp and the
        // closure soft, and how soft is what Buzz sets. The softness never falls under what the
        // sample rate can carry at this pitch.
        const float softness = clamp(0.7f * (1.0f - s.buzz) - 0.25f * flash, 0.0f, 1.0f);
        const float floorSoftness = 2.0f * kTwoPi * inc;
        wanted_.softOpen = std::fmax(0.02f * std::pow(50.0f, softness), floorSoftness);
        // (exp2 of a product, not a power of 8: an optimised build turns that power into this and an
        // unoptimised one does not, the two round differently, and the builds would no longer render
        // the same samples.)
        wanted_.softClose = std::fmax(0.5f * std::exp2(3.0f * softness), floorSoftness);      // 0.5 to 4
        wanted_.shut = 0.3f;                             // the part of the cycle's swing the lips spend shut
        // What the soft closure leaves open at the bottom of the swing is taken off, so that
        // softly closing lips still close.
        const float bottom = -1.0f - wanted_.shut, softBottom = 0.5f * (wanted_.softOpen + wanted_.softClose);
        wanted_.closed = 0.5f * (bottom + std::sqrt(bottom * bottom + softBottom * softBottom));
        // The valve: the flow cannot grow beyond what the blowing pressure drives through the
        // tube's resistance, so a wide opening flattens the pulse. The level is brought back.
        wanted_.valve = 3.0f * s.drive;
        // The opening is measured against its widest, so that every setting lets the same peak
        // flow through and the knobs change the tone, not the loudness.
        const float top = 1.0f - wanted_.shut;
        // (A soft closure puts more of that flow into the fundamental, hence the last factor.)
        wanted_.widest = 1.0f / ((0.5f * (top + std::sqrt(top * top + softBottom * softBottom)) - wanted_.closed) * (1.0f + 0.6f * softness));
        wanted_.flowLevel = 1.0f / (std::sqrt(wanted_.valve * wanted_.valve + 1.0f) - wanted_.valve);

        // The voice, and what aftertouch adds to it.
        wanted_.voice = clamp(s.voice + pressure_.value() * 0.6f, 0.0f, 1.0f);

        // Vowel position from the knob (and the LFOs on it), the wheel and the rhythm.
        const float vowel = s.vowel + wheel_.value() * s.wheelVowel + rhythmPulse_ * (s.rhyVowel * colour) + flash * 0.35f;
        toneLp_.setCutoff(clamp(s.tone * (1.0f + flash), 100.0f, 0.45f * sr_), sr_);

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
        // others stand where the flare puts them, lower and (for a flared tube) much weaker.
        if (s.tube > 0.0f)
        {
            const float first = clamp(midiToHz(base_.value()) / 1.025f, 16.0f, 2000.0f);
            for (int m = 0; m < kNumModes; ++m)
            {
                const float place = first * s.modeRatio[m];
                const float spread = std::sqrt(std::sqrt(s.modeRatio[m]));                 // ratio^(1/4)
                const float q = m == 0 ? kFirstQ : kFirstQ * spread;
                const float height = m == 0 ? 1.0f : (1.0f - 0.8f * s.flare) / spread;
                const float k = 1.0f / q;
                tube_[m].set(clamp(place, 16.0f, 0.45f * sr_), (2.0f - k) / 1.98f);
                tubeGain_[m] = place < 0.45f * sr_ ? 8.0f * s.tube * height * k : 0.0f;
            }
            tubeLevel_ = 1.0f / (1.0f + kTubeLoudness * s.tube);     // the tube shapes the sound, it does not make it louder
        }
    }

    // The peaks are left alone up to 0.6 and bent towards 1 above it.
    static float limit(float y)
    {
        const float size = std::fabs(y);
        if (size <= 0.6f) return y;
        const float bent = 0.6f + 0.4f * fastTanh((size - 0.6f) * 2.5f);
        return y < 0.0f ? -bent : bent;
    }

    void render(float* outL, float* outR, int from, int to)
    {
        const Settings& s = s_;

        for (int i = from; i < to; ++i)
        {
            // Smoothers and clocks run even while silent so nothing jumps on the next note.
            base_.process(); bend_.process(); wheel_.process(); pressure_.process();
            const float volume = volume_.process();
            const float velocity = velocity_.process();
            const float rhythm = rhythmGain_.process();
            ppq_ += s.ppqPerSample;
            if (--controlCountdown_ <= 0) { controlCountdown_ = kControlInterval; updateControl(); }

            float y = 0.0f;
            if (env_.isActive())
            {
                const float env = env_.process();

                // Lips: the opening, soft where it closes, and the flow the valve lets through it.
                lips_.step();
                // What shapes the flow changes only at the bottom of the lips' swing, where they are
                // shut and the flow is nothing whatever the shape: a step in the flow would come
                // out of the radiation as a click.
                const float sine = (float)lips_.s;
                if (latch_ || (sine < 0.0f && sineBefore_ >= 0.0f)) { lip_ = wanted_; latch_ = false; }
                sineBefore_ = sine;
                const float swing = (float)lips_.c - lip_.shut;
                const float soft = lip_.softOpen + (lip_.softClose - lip_.softOpen) * 0.5f * (1.0f + sine);
                const float opening = (0.5f * (swing + std::sqrt(swing * swing + soft * soft)) - lip_.closed) * lip_.widest;
                float flow = opening * (std::sqrt(lip_.valve * lip_.valve * opening * opening + 1.0f) - lip_.valve * opening) * lip_.flowLevel;
                // Breath is noise carried by that flow: none passes shut lips. Turbulence is taken
                // to thin out above 1.5 kHz; nobody has published its spectrum.
                const float noise = breathLp_.process(breathNoise_.process()) * flow;
                // Voice: the glottis is a second valve in the same air stream, open half its cycle.
                glottis_.step();
                // It can only take from the flow; the last factor gives back some of the loudness.
                if (lip_.voice > 0.0f)
                {
                    const float sung = (float)glottis_.s;
                    const float glottis = 0.5f * (sung + std::sqrt(sung * sung + 0.0025f));      // 0 to 1
                    flow *= (1.0f - lip_.voice + lip_.voice * glottis) / (1.0f - 0.3f * lip_.voice);
                }

                // Radiation: the tube radiates the flow's rate of change, up to the corner Tone sets.
                if (primeFlow_) { flowBefore_ = flow; noiseBefore_ = noise; primeFlow_ = false; }
                float excite = (flow - flowBefore_) * radiate_ + (noise - noiseBefore_) * breathNow_;
                flowBefore_ = flow; noiseBefore_ = noise;
                excite = toneLp_.process(excite);

                // Mouth: the tract's resonances hold the flow back where they stand.
                if (s.tongue > 0.0f)
                {
                    excite = (excite - tractLoad_ * (tract_[0].held() + tract_[1].held() + tract_[2].held())) * tractNow_;
                    for (TractResonance& resonance : tract_) resonance.step(excite);
                }

                // Tube: its resonances beside the direct sound.
                y = excite;
                if (s.tube > 0.0f)
                {
                    for (int m = 0; m < kNumModes; ++m) y += tubeGain_[m] * tube_[m].process(excite, SVF::Mode::Bandpass);
                    y *= tubeLevel_;
                }
                // The limiter comes last, after the volume: what leaves the instrument stays within
                // full scale wherever the knob stands.
                y = limit(dc_.process(y * env * velocity * rhythm * kLevel) * volume);
            }
            outL[i] = y;
            if (outR) outR[i] = y;
        }
    }

    static constexpr float kBreathLevel = 150.0f;      // Breath at 100 %, against the lips' own sound
    static constexpr float kTubeLoudness = 2.0f;      // how much louder the tube at 100 % would make the sound

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
    Phasor        lips_, glottis_;
    PinkNoise     breathNoise_;
    Xorshift32    rng_{0x51D6E21Du};
    OnePoleLP     toneLp_, breathLp_;
    SVF           tube_[kNumModes];
    TractResonance tract_[3];
    ADSR          env_;
    DCBlocker     dc_;
    Smoother      volume_, velocity_, wheel_, bend_, pressure_, rhythmGain_;
    Smoother      base_;                          // the drone's note: what the keys ask for and what the tube is tuned to

    // --- state -----------------------------------------------------------------------------
    Settings s_{};
    float  sr_ = 44100.0f;
    float  glideMs_ = -1.0f;
    // The shape of the lips' pulse and the depth of the voice: as the knobs want them, and as
    // they are during the cycle that is sounding.
    struct Lip { float softOpen = 0.05f, softClose = 0.5f, shut = 0.3f, closed = 0.0f, widest = 1.0f, valve = 0.0f, flowLevel = 1.0f, voice = 0.0f; };
    Lip    wanted_, lip_;
    float  radiate_ = 1.0f, sineBefore_ = 0.0f;
    float  flowBefore_ = 0.0f, noiseBefore_ = 0.0f;
    float  drift_ = 0.0f, driftTarget_ = 0.0f;
    float  driftTickScale_ = 1.0f, driftEase_ = 0.004f, breathEase_ = 0.02f;
    float  rhythmPulse_ = 1.0f;
    // The knobs as they were put (all parameters), as they stand with the LFOs on them (the
    // knobs only), and the LFOs: their amounts on the knobs they can move, and where they are.
    float  knob_[kNumParams] = {}, now_[kNumKnobs] = {};
    float  amount_[kNumLfos][kNumTargets] = {};
    float  lfoInc_[kNumLfos] = {}, lfoPhase_[kNumLfos] = {}, lfoValue_[kNumLfos] = {}, lfoFrom_[kNumLfos] = {}, lfoTo_[kNumLfos] = {};
    int    lfoShape_[kNumLfos] = {};
    Xorshift32 lfoRng_{0x2F6E2B11u};                // Steps and Wander draw here, so the drift's sequence is its own
    float  second_ = -1.0f;                        // the tube's second resonance the mode ratios were worked out for
    bool   moving_ = false;                        // an LFO has an amount on some knob
    double ppq_ = 0.0;
    int    driftCountdown_ = 0, controlCountdown_ = 0;
    int    held_[kMaxHeld] = {};
    int    numHeld_ = 0;
    int    noteShift_ = 12 * kOctaveAtRest;      // semitones from a MIDI note to the note that sounds
    float  tongueNow_ = 0.0f, breathing_ = 0.0f, breathNow_ = 0.0f, tractLoad_ = 0.0f, tractNow_ = 1.0f;
    float  tubeGain_[kNumModes] = {}, tubeLevel_ = 1.0f;
    bool   primeFlow_ = true, latch_ = true;
    bool   sustain_ = false, sustained_ = false;
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
    if (index == kVoicePitch) return kIntervals[clamp(choice, 0, kNumIntervals - 1)].name;
    if (index == kLfo1Shape || index == kLfo2Shape) return kLfoShapeNames[clamp(choice, 0, (int)kNumLfoShapes - 1)];
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
    if (index == kOctave && plain >= 0.5f) std::snprintf(buffer, (size_t)bufferSize, "+%d", (int)std::lround(plain));
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

int didge_num_lfos(void) { return kNumLfos; }
int didge_lfo_amount(int lfo, int param) { return lfo >= 0 && lfo < kNumLfos && validParam(param) ? amountOf(lfo, param) : -1; }

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
