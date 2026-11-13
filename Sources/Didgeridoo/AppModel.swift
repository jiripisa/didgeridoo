import AppKit
import DidgeridooCore
import Observation

/// The standalone app's state: the synth, its audio and MIDI connections and
/// the settings the user chose. Views read it and call its methods.
@MainActor
@Observable
final class AppModel {

    @ObservationIgnored let synth = Synth()
    @ObservationIgnored private let audio: AudioOutput
    @ObservationIgnored private let midi: MIDIInput
    @ObservationIgnored private let defaults = UserDefaults.standard

    /// Knob positions (0...1) by parameter index, mirrored from the synth for the views.
    private(set) var positions: [Float]
    private(set) var program: Int

    private(set) var midiSources: [MIDISource] = []
    private(set) var audioDevices: [AudioDevice] = []
    private(set) var audioProblem: String?
    private(set) var audioUnitStatus = ""

    var midiSource: MIDISourceChoice {
        didSet {
            guard midiSource != oldValue else { return }
            defaults.set(midiSource.storedValue, forKey: Keys.midiSource)
            defaults.set(midiSources.first { midiSource == .source($0.id) }?.name, forKey: Keys.midiSourceName)
            midi.listen(to: midiSource)
        }
    }
    var midiChannel: MIDIChannelFilter {
        didSet { defaults.set(midiChannel.storedValue, forKey: Keys.midiChannel); midi.channelFilter = midiChannel }
    }
    /// nil = the system default output.
    var audioDeviceUID: String? {
        didSet {
            guard audioDeviceUID != oldValue else { return }
            defaults.set(audioDeviceUID, forKey: Keys.audioDevice)
            defaults.set(audioDevices.first { $0.uid == audioDeviceUID }?.name, forKey: Keys.audioDeviceName)
            // Another device has other outputs: begin on its first pair. Changing
            // the pair restarts audio by itself.
            if audioFirstChannel == 0 { restartAudio() } else { audioFirstChannel = 0 }
        }
    }
    /// 0-based left channel of the output pair on the chosen device.
    var audioFirstChannel: Int {
        didSet { defaults.set(audioFirstChannel, forKey: Keys.audioChannel); restartAudio() }
    }
    /// Tempo of the rhythm pulse (the standalone app has no song to follow).
    private(set) var bpm: Double

    private enum Keys {
        static let state = "synthState", midiSource = "midiSource", midiChannel = "midiChannel"
        static let audioDevice = "audioDevice", audioChannel = "audioFirstChannel", bpm = "bpm"
        /// Names of the chosen devices, to show them while they are not connected.
        static let midiSourceName = "midiSourceName", audioDeviceName = "audioDeviceName"
    }

    init() {
        audio = AudioOutput(synth: synth)
        midi = MIDIInput(synth: synth)

        if let data = defaults.data(forKey: Keys.state),
           let state = try? JSONDecoder().decode(SynthState.self, from: data) {
            state.apply(to: synth)
        }
        positions = Parameters.all.map(synth.normalisedValue(of:))
        program = synth.program

        // These first assignments initialise the properties: their observers do
        // not run, so nothing is saved or restarted yet.
        midiSource = MIDISourceChoice(storedValue: defaults.string(forKey: Keys.midiSource))
        midiChannel = MIDIChannelFilter(storedValue: defaults.integer(forKey: Keys.midiChannel))
        audioDeviceUID = defaults.string(forKey: Keys.audioDevice)
        audioFirstChannel = defaults.integer(forKey: Keys.audioChannel)
        let storedBPM = defaults.double(forKey: Keys.bpm)
        bpm = Tempo.range.contains(storedBPM) ? storedBPM : Tempo.standard

        synth.setTempo(bpm: bpm)
        midi.channelFilter = midiChannel
        midi.onSourcesChanged = { [weak self] in self?.refreshDevices() }
        audio.onHardwareChange = { [weak self] devices in
            guard let self else { return }
            audioDevices = devices
            audioProblem = audio.problem
        }
        refreshDevices()
        restartAudio()
        refreshAudioUnitStatus()
    }

    // MARK: Parameters and programs

    func position(of parameter: Parameter) -> Float { positions[parameter.index] }

    func value(of parameter: Parameter) -> Float { parameter.plain(positions[parameter.index]) }

    func setPosition(_ position: Float, of parameter: Parameter) {
        synth.setNormalisedValue(min(max(position, 0), 1), of: parameter)
        positions[parameter.index] = parameter.normalised(synth.value(of: parameter))   // snapped for steps
    }

    func resetToDefault(_ parameter: Parameter) {
        setPosition(parameter.normalised(Programs.value(program: program, parameter: parameter)), of: parameter)
        saveState()
    }

    func loadProgram(_ index: Int) {
        synth.loadProgram(index)
        program = index
        positions = Parameters.all.map(synth.normalisedValue(of:))
        saveState()
    }

    /// Sets the tempo of the rhythm pulse, kept within what the app accepts.
    func setTempo(_ value: Double) {
        bpm = Tempo.clamped(value)
        defaults.set(bpm, forKey: Keys.bpm)
        synth.setTempo(bpm: bpm)
    }

    /// Remembers the sound for the next launch.
    func saveState() {
        if let data = try? JSONEncoder().encode(SynthState(capturing: synth)) {
            defaults.set(data, forKey: Keys.state)
        }
    }

    // MARK: Devices

    func refreshDevices() {
        midiSources = MIDIInput.sources()
        audioDevices = AudioOutput.devices()
        midi.listen(to: midiSource)
    }

    /// Output channels of the chosen device; 0 for the system default output
    /// and for a device that is not connected, which play on their first two.
    private var chosenDeviceChannels: Int {
        audioDevices.first { $0.uid == audioDeviceUID }?.outputChannels ?? 0
    }

    /// The channel pairs the chosen device offers, by their 0-based left channel.
    var audioChannelPairs: [Int] {
        OutputChannels.pairs(deviceChannels: chosenDeviceChannels)
    }

    /// The pair the sound goes to: the stored one, or the first when the
    /// device does not offer it.
    var audioChannelPairInUse: Int {
        OutputChannels.pair(audioFirstChannel, deviceChannels: chosenDeviceChannels)
    }

    /// The name of the chosen MIDI source while it is not connected.
    var missingMIDISourceName: String? {
        guard case .source(let id) = midiSource, !midiSources.contains(where: { $0.id == id }) else { return nil }
        return defaults.string(forKey: Keys.midiSourceName) ?? "MIDI device"
    }

    /// The name of the chosen audio device while it is not connected.
    var missingAudioDeviceName: String? {
        guard let audioDeviceUID, !audioDevices.contains(where: { $0.uid == audioDeviceUID }) else { return nil }
        return defaults.string(forKey: Keys.audioDeviceName) ?? "Audio device"
    }

    private func restartAudio() {
        audio.start(deviceUID: audioDeviceUID, firstChannel: audioFirstChannel)
        audioProblem = audio.problem
    }

    // MARK: Audio Unit

    private var bundledAudioUnit: URL {
        Bundle.main.bundleURL.appendingPathComponent("Contents/PlugIns/Didgeridoo.component")
    }

    private var installedAudioUnit: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Audio/Plug-Ins/Components/Didgeridoo.component")
    }

    private func version(of component: URL) -> String? {
        let plist = component.appendingPathComponent("Contents/Info.plist")
        return (NSDictionary(contentsOf: plist)?["CFBundleShortVersionString"]) as? String
    }

    var canInstallAudioUnit: Bool { FileManager.default.fileExists(atPath: bundledAudioUnit.path) }

    func refreshAudioUnitStatus() {
        guard canInstallAudioUnit else {
            audioUnitStatus = "This copy of the app does not contain the Audio Unit."
            return
        }
        let bundled = version(of: bundledAudioUnit) ?? "?"
        if let installed = version(of: installedAudioUnit) {
            audioUnitStatus = installed == bundled
                ? "Installed (version \(installed))."
                : "Version \(installed) is installed; this app contains \(bundled)."
        } else {
            audioUnitStatus = "Not installed."
        }
    }

    /// Copies the Audio Unit into ~/Library/Audio/Plug-Ins/Components, replacing
    /// an older copy. Hosts see it after they rescan their plug-ins.
    func installAudioUnit() {
        let files = FileManager.default
        do {
            try files.createDirectory(at: installedAudioUnit.deletingLastPathComponent(), withIntermediateDirectories: true)
            if files.fileExists(atPath: installedAudioUnit.path) {
                try files.removeItem(at: installedAudioUnit)
            }
            try files.copyItem(at: bundledAudioUnit, to: installedAudioUnit)
            refreshAudioUnitStatus()
        } catch {
            audioUnitStatus = "Installing failed: \(error.localizedDescription)"
        }
    }
}
