// DidgeridooAU.cpp - the Didgeridoo instrument as an Audio Unit (AUv2 music device).
//
// SPDX-License-Identifier: MIT
//
// A thin layer over the sound engine (DidgeridooDSP): it publishes the engine's parameters
// and built-in programs to the host, forwards MIDI and the host's tempo, and renders.
// Audio Unit parameter values are the engine's "plain" values (Hz, ms, dB, %, an index), so
// automation and saved host projects read naturally. Built on Apple's AudioUnitSDK.

#include "DidgeridooAU.h"
#include "DidgeridooDSP.h"

#include <AudioUnitSDK/MusicDeviceBase.h>

#include <vector>

namespace {

// Groups shown by hosts that draw a generic parameter view: the same three pages as the app.
enum Clump : UInt32 { kClumpMouth = 1, kClumpLips, kClumpRhythm };

Clump clumpOf(const char* identifier)
{
    static const char* const mouth[] = { "volume", "vowel", "formant", "reso", "tone", "wobblerate", "wobbledepth", "wheelvowel" };
    static const char* const rhythm[] = { "rhythmdiv", "rhydepth", "rhyvowel", "rhydecay", "bendrange" };
    for (const char* id : mouth) if (!std::strcmp(id, identifier)) return kClumpMouth;
    for (const char* id : rhythm) if (!std::strcmp(id, identifier)) return kClumpRhythm;
    return kClumpLips;
}

AudioUnitParameterUnit unitOf(const DidgeParamInfo& info)
{
    if (info.kind == DIDGE_KIND_CHOICE) return kAudioUnitParameterUnit_Indexed;
    if (!std::strcmp(info.unit, "Hz")) return kAudioUnitParameterUnit_Hertz;
    if (!std::strcmp(info.unit, "dB")) return kAudioUnitParameterUnit_Decibels;
    if (!std::strcmp(info.unit, "ms")) return kAudioUnitParameterUnit_Milliseconds;
    if (!std::strcmp(info.unit, "%"))  return kAudioUnitParameterUnit_Percent;
    if (!std::strcmp(info.unit, "st")) return kAudioUnitParameterUnit_RelativeSemiTones;
    return kAudioUnitParameterUnit_Generic;
}

// The built-in programs as AUPresets. The table lives for the life of the process.
const std::vector<AUPreset>& factoryPresets()
{
    static const std::vector<AUPreset> presets = [] {
        std::vector<AUPreset> v;
        for (int i = 0; i < didge_num_programs(); ++i)
            v.push_back(AUPreset{ i, CFStringCreateWithCString(nullptr, didge_program_name(i), kCFStringEncodingUTF8) });
        return v;
    }();
    return presets;
}

} // namespace

class DidgeridooAU : public ausdk::MusicDeviceBase {
    using Base = ausdk::MusicDeviceBase;

public:
    explicit DidgeridooAU(AudioComponentInstance instance) : Base{ instance, 0, 1 }, engine_(didge_create())
    {
        CreateElements();
        const int count = didge_num_params();
        Globals()->UseIndexedParameters(static_cast<UInt32>(count));
        applied_.resize(static_cast<size_t>(count));
        for (int i = 0; i < count; ++i)
        {
            DidgeParamInfo info{};
            didge_param_info(i, &info);
            Globals()->SetParameter(static_cast<AudioUnitParameterID>(i), info.defaultValue);
            applied_[static_cast<size_t>(i)] = info.defaultValue;
        }
        SetAFactoryPresetAsCurrent(factoryPresets().front());
    }

    ~DidgeridooAU() override { didge_destroy(engine_); }

    // ----- formats --------------------------------------------------------------------------
    bool StreamFormatWritable(AudioUnitScope, AudioUnitElement) override { return !IsInitialized(); }
    bool CanScheduleParameters() const noexcept AUSDK_RTSAFE override { return false; }

    UInt32 SupportedNumChannels(const AUChannelInfo** outInfo) override
    {
        static const AUChannelInfo configurations[] = { { 0, 2 }, { 0, 1 } };   // no input; stereo or mono out
        if (outInfo) *outInfo = configurations;
        return 2;
    }

    OSStatus Initialize() override
    {
        const AudioStreamBasicDescription& format = Output(0).GetStreamFormat();
        if (format.mChannelsPerFrame < 1 || format.mChannelsPerFrame > 2) return kAudioUnitErr_FormatNotSupported;
        didge_prepare(engine_, format.mSampleRate);
        didge_reset(engine_);
        return noErr;
    }

    OSStatus Reset(AudioUnitScope scope, AudioUnitElement element) override
    {
        didge_reset(engine_);
        return Base::Reset(scope, element);
    }

    // ----- parameters -----------------------------------------------------------------------
    OSStatus GetParameterInfo(AudioUnitScope scope, AudioUnitParameterID id, AudioUnitParameterInfo& out) override
    {
        if (scope != kAudioUnitScope_Global) return kAudioUnitErr_InvalidScope;
        if (id >= static_cast<AudioUnitParameterID>(didge_num_params())) return kAudioUnitErr_InvalidParameter;
        DidgeParamInfo info{};
        didge_param_info(static_cast<int>(id), &info);

        out.flags = kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable;
        FillInParameterName(out, CFStringCreateWithCString(nullptr, info.name, kCFStringEncodingUTF8), true);
        HasClump(out, clumpOf(info.identifier));
        out.unit = unitOf(info);
        out.minValue = info.minValue;
        out.maxValue = info.maxValue;
        out.defaultValue = info.defaultValue;
        if (info.logarithmic) out.flags |= kAudioUnitParameterFlag_DisplayLogarithmic;
        return noErr;
    }

    OSStatus GetParameterValueStrings(AudioUnitScope scope, AudioUnitParameterID id, CFArrayRef* outStrings) override
    {
        if (scope != kAudioUnitScope_Global) return kAudioUnitErr_InvalidScope;
        if (id >= static_cast<AudioUnitParameterID>(didge_num_params())) return kAudioUnitErr_InvalidParameter;
        DidgeParamInfo info{};
        didge_param_info(static_cast<int>(id), &info);
        if (info.numChoices <= 0) return kAudioUnitErr_InvalidProperty;
        if (!outStrings) return noErr;                       // the host only asked whether there are any
        CFMutableArrayRef names = CFArrayCreateMutable(nullptr, info.numChoices, &kCFTypeArrayCallBacks);
        for (int c = 0; c < info.numChoices; ++c)
        {
            CFStringRef name = CFStringCreateWithCString(nullptr, didge_param_choice(static_cast<int>(id), c), kCFStringEncodingUTF8);
            CFArrayAppendValue(names, name);
            CFRelease(name);
        }
        *outStrings = names;
        return noErr;
    }

    OSStatus CopyClumpName(AudioUnitScope, UInt32 clump, UInt32, CFStringRef* outName) override
    {
        switch (clump)
        {
            case kClumpMouth:  *outName = CFSTR("Mouth"); break;
            case kClumpLips:   *outName = CFSTR("Lips"); break;
            case kClumpRhythm: *outName = CFSTR("Rhythm"); break;
            default: return kAudioUnitErr_InvalidPropertyValue;
        }
        CFRetain(*outName);
        return noErr;
    }

    // ----- factory presets (the engine's built-in programs) ---------------------------------
    OSStatus GetPresets(CFArrayRef* outData) const override
    {
        if (!outData) return noErr;
        const std::vector<AUPreset>& presets = factoryPresets();
        CFMutableArrayRef array = CFArrayCreateMutable(nullptr, static_cast<CFIndex>(presets.size()), nullptr);
        for (const AUPreset& p : presets) CFArrayAppendValue(array, &p);
        *outData = array;
        return noErr;
    }

    OSStatus NewFactoryPresetSet(const AUPreset& preset) override
    {
        const SInt32 number = preset.presetNumber;
        if (number < 0 || number >= didge_num_programs()) return kAudioUnitErr_InvalidPropertyValue;
        didge_set_program(engine_, number);                  // also silences the voice
        for (int i = 0; i < didge_num_params(); ++i)
        {
            const float value = didge_program_value(number, i);
            Globals()->SetParameter(static_cast<AudioUnitParameterID>(i), value);
            applied_[static_cast<size_t>(i)] = value;
        }
        SetAFactoryPresetAsCurrent(factoryPresets()[static_cast<size_t>(number)]);
        return noErr;
    }

    // ----- MIDI -----------------------------------------------------------------------------
    // Everything goes to the engine as raw MIDI; it knows notes, the mod wheel, the sustain
    // pedal, pitch bend, aftertouch and all-notes-off.
    OSStatus HandleMIDIEvent(UInt8 status, UInt8 channel, UInt8 data1, UInt8 data2, UInt32 offsetFrames) AUSDK_RTSAFE override
    {
        didge_post_midi(engine_, status | channel, data1, data2, static_cast<int>(offsetFrames));
        return noErr;
    }

    // ----- render ---------------------------------------------------------------------------
    OSStatus Render(AudioUnitRenderActionFlags&, const AudioTimeStamp&, UInt32 frames) AUSDK_RTSAFE override
    {
        // Parameters the host or its automation changed since the last block.
        const int count = static_cast<int>(applied_.size());
        for (int i = 0; i < count; ++i)
        {
            const float value = Globals()->GetParameter(static_cast<AudioUnitParameterID>(i));
            if (value != applied_[static_cast<size_t>(i)])
            {
                applied_[static_cast<size_t>(i)] = value;
                didge_set_plain(engine_, i, value);
            }
        }

        // The host's tempo and song position drive the rhythm pulse.
        Float64 beat = 0.0, tempo = 120.0;
        const bool haveBeat = CallHostBeatAndTempo(&beat, &tempo) == noErr;
        Boolean playing = false;
        const bool haveTransport = CallHostTransportState(&playing, nullptr, nullptr, nullptr, nullptr, nullptr) == noErr;
        didge_set_transport(engine_, haveTransport && playing, tempo, beat, haveBeat);

        AudioBufferList& buffers = Output(0).GetBufferList();
        float* left = static_cast<float*>(buffers.mBuffers[0].mData);
        float* right = buffers.mNumberBuffers > 1 ? static_cast<float*>(buffers.mBuffers[1].mData) : nullptr;
        didge_process(engine_, left, right, static_cast<int>(frames));
        return noErr;
    }

private:
    DidgeEngine* engine_;
    std::vector<float> applied_;     // the plain value last handed to the engine, per parameter
};

AUSDK_COMPONENT_ENTRY(ausdk::AUMusicDeviceFactory, DidgeridooAU)
