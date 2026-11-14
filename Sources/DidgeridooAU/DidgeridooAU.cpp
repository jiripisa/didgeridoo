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

#include <cstring>
#include <vector>

namespace {

// Groups shown by hosts that draw a generic parameter view ("clumps"): the engine's sections,
// the same as the app's panels. Clump 0 means "no group", so section n is clump n + 1.
UInt32 clumpOf(const DidgeParamInfo& info) { return static_cast<UInt32>(info.section) + 1; }

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
        didge_request_reset(engine_);     // left to the render thread: a host may reset while it renders
        return Base::Reset(scope, element);
    }

    // ----- the window -----------------------------------------------------------------------
    // A host asks for the plug-in's own window through the CocoaUI property: the bundle and the
    // name of a class in it that makes the view (DidgeridooAUViewFactory, Sources/DidgeridooAUView).
    // Without the component bundle (the unit registered in a process by hand) there is none, and
    // the host shows its generic parameter view.
    OSStatus GetPropertyInfo(AudioUnitPropertyID id, AudioUnitScope scope, AudioUnitElement element,
                             UInt32& outDataSize, bool& outWritable) override
    {
        if (id == kAudioUnitProperty_CocoaUI && scope == kAudioUnitScope_Global)
        {
            if (!CFBundleGetBundleWithIdentifier(CFSTR(DIDGERIDOO_AU_BUNDLE_ID))) return kAudioUnitErr_InvalidProperty;
            outDataSize = sizeof(AudioUnitCocoaViewInfo);
            outWritable = false;
            return noErr;
        }
        if (id == kDidgeridooProperty_Controllers && scope == kAudioUnitScope_Global)
        {
            outDataSize = static_cast<UInt32>(sizeof(SInt32) * applied_.size());
            outWritable = true;
            return noErr;
        }
        if (id == kDidgeridooProperty_Learn && scope == kAudioUnitScope_Global)
        {
            outDataSize = sizeof(SInt32);
            outWritable = true;
            return noErr;
        }
        return Base::GetPropertyInfo(id, scope, element, outDataSize, outWritable);
    }

    OSStatus GetProperty(AudioUnitPropertyID id, AudioUnitScope scope, AudioUnitElement element, void* outData) override
    {
        if (id == kAudioUnitProperty_CocoaUI && scope == kAudioUnitScope_Global)
        {
            CFBundleRef bundle = CFBundleGetBundleWithIdentifier(CFSTR(DIDGERIDOO_AU_BUNDLE_ID));
            if (!bundle) return kAudioUnitErr_InvalidProperty;
            auto* info = static_cast<AudioUnitCocoaViewInfo*>(outData);
            info->mCocoaAUViewBundleLocation = CFBundleCopyBundleURL(bundle);       // the host releases both
            info->mCocoaAUViewClass[0] = CFStringCreateWithCString(nullptr, DIDGERIDOO_AU_VIEW_CLASS, kCFStringEncodingUTF8);
            return noErr;
        }
        if (id == kDidgeridooProperty_Controllers && scope == kAudioUnitScope_Global)
        {
            auto* controllers = static_cast<SInt32*>(outData);
            for (int i = 0; i < static_cast<int>(applied_.size()); ++i) controllers[i] = didge_get_controller(engine_, i);
            return noErr;
        }
        if (id == kDidgeridooProperty_Learn && scope == kAudioUnitScope_Global)
        {
            *static_cast<SInt32*>(outData) = didge_learning(engine_);
            return noErr;
        }
        return Base::GetProperty(id, scope, element, outData);
    }

    // ----- MIDI controllers -----------------------------------------------------------------
    // Which controller moves which parameter lives in the engine. The window reads and sets it
    // through two properties of the unit's own, and a host saves it with the project.
    OSStatus SetProperty(AudioUnitPropertyID id, AudioUnitScope scope, AudioUnitElement element,
                         const void* inData, UInt32 inDataSize) override
    {
        if (id == kDidgeridooProperty_Controllers && scope == kAudioUnitScope_Global)
        {
            if (inDataSize != sizeof(SInt32) * applied_.size()) return kAudioUnitErr_InvalidPropertyValue;
            setControllers(static_cast<const SInt32*>(inData), static_cast<int>(applied_.size()));
            return noErr;
        }
        if (id == kDidgeridooProperty_Learn && scope == kAudioUnitScope_Global)
        {
            if (inDataSize != sizeof(SInt32)) return kAudioUnitErr_InvalidPropertyValue;
            didge_learn(engine_, *static_cast<const SInt32*>(inData));
            return noErr;
        }
        return Base::SetProperty(id, scope, element, inData, inDataSize);
    }

    OSStatus SaveState(CFPropertyListRef* outData) override
    {
        const OSStatus status = Base::SaveState(outData);
        if (status != noErr || !outData || !*outData || CFGetTypeID(*outData) != CFDictionaryGetTypeID()) return status;
        std::vector<SInt32> controllers(applied_.size());
        for (size_t i = 0; i < controllers.size(); ++i) controllers[i] = didge_get_controller(engine_, static_cast<int>(i));
        CFDataRef data = CFDataCreate(nullptr, reinterpret_cast<const UInt8*>(controllers.data()),
                                      static_cast<CFIndex>(controllers.size() * sizeof(SInt32)));
        // The base class made this dictionary a moment ago and nobody else holds it yet.
        CFDictionarySetValue(static_cast<CFMutableDictionaryRef>(const_cast<void*>(*outData)), controllersKey(), data);
        CFRelease(data);
        return noErr;
    }

    // State saved before the unit had controllers carries none: they stay as they are. A list
    // from a version with fewer parameters covers the first of them; the table only ever grows
    // at its end.
    OSStatus RestoreState(CFPropertyListRef plist) override
    {
        const OSStatus status = Base::RestoreState(plist);
        if (status != noErr || !plist || CFGetTypeID(plist) != CFDictionaryGetTypeID()) return status;
        const void* stored = CFDictionaryGetValue(static_cast<CFDictionaryRef>(plist), controllersKey());
        if (!stored || CFGetTypeID(stored) != CFDataGetTypeID()) return status;
        const auto data = static_cast<CFDataRef>(stored);
        const int count = static_cast<int>(CFDataGetLength(data) / static_cast<CFIndex>(sizeof(SInt32)));
        setControllers(reinterpret_cast<const SInt32*>(CFDataGetBytePtr(data)), count < static_cast<int>(applied_.size()) ? count : static_cast<int>(applied_.size()));
        return status;
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
        if (info.section >= 0) HasClump(out, clumpOf(info));
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
        if (clump < 1 || clump > static_cast<UInt32>(didge_num_sections())) return kAudioUnitErr_InvalidPropertyValue;
        *outName = CFStringCreateWithCString(nullptr, didge_section_name(static_cast<int>(clump) - 1), kCFStringEncodingUTF8);
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
            if (!didge_program_sets(i)) continue;            // Octave stays where the player put it
            const float value = didge_program_value(number, i);
            Globals()->SetParameter(static_cast<AudioUnitParameterID>(i), value);
            applied_[static_cast<size_t>(i)] = value;
        }
        SetAFactoryPresetAsCurrent(factoryPresets()[static_cast<size_t>(number)]);
        return noErr;
    }

    // ----- MIDI -----------------------------------------------------------------------------
    // Everything goes to the engine as raw MIDI; it knows notes, the mod wheel, the sustain
    // pedal, pitch bend, aftertouch and all-notes-off. A host may call this on the render thread
    // or on another one, so the event is posted, which is safe and lock-free on either.
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

        // A controller moved a knob inside the engine: the unit's own parameters follow, since
        // they are what a host and the window read and what is saved.
        const unsigned changes = didge_changes(engine_);
        if (changes != seenChanges_)
        {
            seenChanges_ = changes;
            for (int i = 0; i < count; ++i)
            {
                const float value = didge_get_plain(engine_, i);
                if (value != applied_[static_cast<size_t>(i)])
                {
                    applied_[static_cast<size_t>(i)] = value;
                    Globals()->SetParameterRT(static_cast<AudioUnitParameterID>(i), value, true);
                }
            }
        }
        return noErr;
    }

private:
    // First the parameters that are to have none, then the others: giving a controller takes
    // it from whoever has it.
    void setControllers(const SInt32* controllers, int count)
    {
        for (int i = 0; i < count; ++i) if (controllers[i] < 0) didge_set_controller(engine_, i, -1);
        for (int i = 0; i < count; ++i) if (controllers[i] >= 0) didge_set_controller(engine_, i, controllers[i]);
    }

    // The key of the controllers in the unit's saved state.
    static CFStringRef controllersKey() { return CFSTR("didgeridoo-controllers"); }

    DidgeEngine* engine_;
    std::vector<float> applied_;     // the plain value last handed to the engine, per parameter
    unsigned seenChanges_ = 0;       // the engine's count of what MIDI changed, as of the last block
};

AUSDK_COMPONENT_ENTRY(ausdk::AUMusicDeviceFactory, DidgeridooAU)
