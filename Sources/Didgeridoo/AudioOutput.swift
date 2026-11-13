import AVFoundation
import CoreAudio
import DidgeridooCore

/// An audio device that can play sound.
struct AudioDevice: Identifiable, Hashable {
    let id: AudioDeviceID
    /// Stable across restarts, unlike `id`; this is what the settings remember.
    let uid: String
    let name: String
    let outputChannels: Int
}

/// Plays the synth through an output device: the system default, or one the
/// user picked, on a chosen pair of its channels.
@MainActor
final class AudioOutput {

    private let engine = AVAudioEngine()
    private var source: AVAudioSourceNode?
    private let synth: Synth

    /// Why the last `start` failed, for the settings window; nil when audio runs.
    private(set) var problem: String?

    init(synth: Synth) {
        self.synth = synth
    }

    /// (Re)starts audio. `deviceUID` nil means the system default output;
    /// `firstChannel` is the 0-based left channel of the stereo pair to use.
    func start(deviceUID: String?, firstChannel: Int) {
        engine.stop()
        if let source {
            engine.detach(source)
            self.source = nil
        }
        problem = nil

        let output = engine.outputNode
        if let deviceUID, let device = Self.devices().first(where: { $0.uid == deviceUID }), let unit = output.audioUnit {
            var id = device.id
            let status = AudioUnitSetProperty(unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0,
                                              &id, UInt32(MemoryLayout<AudioDeviceID>.size))
            if status != noErr { problem = "Could not switch to \(device.name) (error \(status)); using the default output." }
        }

        let deviceFormat = output.outputFormat(forBus: 0)
        guard deviceFormat.sampleRate > 0, deviceFormat.channelCount > 0,
              let format = AVAudioFormat(standardFormatWithSampleRate: deviceFormat.sampleRate, channels: 2) else {
            problem = "The audio output has no usable format."
            return
        }
        synth.prepare(sampleRate: format.sampleRate)       // safe: the engine is stopped

        let node = Self.makeSource(synth: synth, format: format)
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        source = node
        applyChannelMap(firstChannel: firstChannel, deviceChannels: Int(deviceFormat.channelCount))

        do {
            try engine.start()
        } catch {
            problem = "Audio did not start: \(error.localizedDescription)"
        }
    }

    /// The render block runs on the audio thread, so it is built outside the main actor.
    private nonisolated static func makeSource(synth: Synth, format: AVAudioFormat) -> AVAudioSourceNode {
        AVAudioSourceNode(format: format) { _, _, frameCount, bufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
            guard let left = buffers[0].mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            let right = buffers.count > 1 ? buffers[1].mData?.assumingMemoryBound(to: Float.self) : nil
            synth.render(left: left, right: right, frames: Int(frameCount))
            return noErr
        }
    }

    /// Routes the stereo signal to the chosen pair of a multi-channel device.
    /// Each entry of the map names the source channel that feeds that device
    /// channel, or -1 for silence.
    private func applyChannelMap(firstChannel: Int, deviceChannels: Int) {
        guard deviceChannels > 2, let unit = engine.outputNode.audioUnit else { return }
        let first = min(max(0, firstChannel), deviceChannels - 2)
        var map = [Int32](repeating: -1, count: deviceChannels)
        map[first] = 0
        map[first + 1] = 1
        AudioUnitSetProperty(unit, kAudioOutputUnitProperty_ChannelMap, kAudioUnitScope_Output, 0,
                             &map, UInt32(MemoryLayout<Int32>.size * map.count))
    }

    // MARK: Device list

    /// Every device with at least one output channel.
    static func devices() -> [AudioDevice] {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.compactMap { id in
            let channels = outputChannelCount(of: id)
            guard channels > 0,
                  let name = string(of: id, selector: kAudioObjectPropertyName),
                  let uid = string(of: id, selector: kAudioDevicePropertyDeviceUID) else { return nil }
            return AudioDevice(id: id, uid: uid, name: name, outputChannels: channels)
        }
    }

    private static func string(of device: AudioDeviceID, selector: AudioObjectPropertySelector) -> String? {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }

    private static func outputChannelCount(of device: AudioDeviceID) -> Int {
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreamConfiguration,
                                                 mScope: kAudioDevicePropertyScopeOutput,
                                                 mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size) == noErr, size > 0 else { return 0 }
        let storage = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { storage.deallocate() }
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, storage) == noErr else { return 0 }
        let list = UnsafeMutableAudioBufferListPointer(storage.assumingMemoryBound(to: AudioBufferList.self))
        return list.reduce(0) { $0 + Int($1.mNumberChannels) }
    }
}
