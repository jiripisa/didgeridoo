import AudioToolbox
import DidgeridooCore
import DidgeridooUI
import Observation

/// The panel's model in a host: it reads and writes the Audio Unit's
/// parameters and factory presets. Parameter values of the Audio Unit are the
/// engine's plain values, and a parameter's index is its ID.
///
/// A host changes parameters without telling a view (automation, its own
/// controls), so the window asks for the present values many times a second:
/// see `refresh`.
@MainActor
@Observable
public final class AudioUnitModel: InstrumentModel {

    @ObservationIgnored private let unit: AudioUnit

    /// Knob positions (0...1) by parameter index.
    private var positions: [Float]
    public private(set) var program: Int
    /// The MIDI controller of each parameter by index, -1 for none, and the
    /// parameter that is learning, as the unit had them at the last look.
    private var controllers: [Int32]
    public private(set) var learning: Parameter?

    public init(unit: AudioUnit) {
        self.unit = unit
        positions = Parameters.all.map { Self.position(of: $0, in: unit) }
        program = Self.presentPreset(of: unit)
        controllers = Self.controllers(of: unit)
        learning = Self.learning(in: unit)
    }

    /// Takes over whatever the host changed since the last time.
    public func refresh() {
        for parameter in Parameters.all {
            let position = Self.position(of: parameter, in: unit)
            if position != positions[parameter.index] { positions[parameter.index] = position }
        }
        let preset = Self.presentPreset(of: unit)
        if preset != program { program = preset }
        // A controller may have been learnt on the render thread.
        let controllers = Self.controllers(of: unit)
        if controllers != self.controllers { self.controllers = controllers }
        let learning = Self.learning(in: unit)
        if learning != self.learning { self.learning = learning }
    }

    // MARK: InstrumentModel

    public func position(of parameter: Parameter) -> Float { positions[parameter.index] }

    public func setPosition(_ position: Float, of parameter: Parameter) {
        let plain = parameter.plain(min(max(position, 0), 1))
        var address = address(of: parameter)
        AUParameterSet(nil, nil, &address, plain, 0)        // sets the value and tells the host's listeners
        positions[parameter.index] = parameter.normalised(plain)
    }

    public func resetToDefault(_ parameter: Parameter) {
        let plain = Programs.names.indices.contains(program)
            ? Programs.value(program: program, parameter: parameter)
            : parameter.defaultValue
        beginEditing(parameter)
        setPosition(parameter.normalised(plain), of: parameter)
        endEditing(parameter)
    }

    public func loadProgram(_ index: Int) {
        guard Programs.names.indices.contains(index) else { return }
        var preset = AUPreset(presetNumber: Int32(index), presetName: Unmanaged.passUnretained(Programs.names[index] as CFString))
        guard AudioUnitSetProperty(unit, kAudioUnitProperty_PresentPreset, kAudioUnitScope_Global, 0,
                                   &preset, UInt32(MemoryLayout<AUPreset>.size)) == noErr else { return }
        // Every parameter may have moved: tell the host's listeners, then read them back.
        var all = AudioUnitParameter(mAudioUnit: unit, mParameterID: kAUParameterListener_AnyParameter,
                                     mScope: kAudioUnitScope_Global, mElement: 0)
        AUParameterListenerNotify(nil, nil, &all)
        refresh()
    }

    public func beginEditing(_ parameter: Parameter) { notify(.beginParameterChangeGesture, parameter) }
    public func endEditing(_ parameter: Parameter) { notify(.endParameterChangeGesture, parameter) }

    // MARK: MIDI controllers

    public func controller(of parameter: Parameter) -> Int? {
        let controller = controllers[parameter.index]
        return controller >= 0 ? Int(controller) : nil
    }

    public func setController(_ controller: Int?, of parameter: Parameter) {
        var wanted = Self.controllers(of: unit)
        if let controller {
            guard !Controllers.isReserved(controller) else { return }
            for index in wanted.indices where wanted[index] == Int32(controller) { wanted[index] = -1 }     // it serves one parameter
        }
        wanted[parameter.index] = Int32(controller ?? -1)
        send(wanted)
    }

    public func resetControllers() {
        send(Parameters.all.map { Int32(Controllers.standard(for: $0) ?? -1) })
    }

    public func learn(_ parameter: Parameter?) {
        var index = Int32(parameter?.index ?? -1)
        AudioUnitSetProperty(unit, Self.learnProperty, kAudioUnitScope_Global, 0, &index, UInt32(MemoryLayout<Int32>.size))
        learning = Self.learning(in: unit)
    }

    private func send(_ wanted: [Int32]) {
        var wanted = wanted
        AudioUnitSetProperty(unit, Self.controllersProperty, kAudioUnitScope_Global, 0, &wanted,
                             UInt32(MemoryLayout<Int32>.size * wanted.count))
        controllers = Self.controllers(of: unit)
    }

    // MARK: The Audio Unit

    /// The unit's own properties for its controllers. The numbers are those of
    /// `kDidgeridooProperty_Controllers` and `kDidgeridooProperty_Learn` in
    /// DidgeridooAU.h and must stay in step with them.
    private static let controllersProperty: AudioUnitPropertyID = 64001
    private static let learnProperty: AudioUnitPropertyID = 64002

    private static func controllers(of unit: AudioUnit) -> [Int32] {
        var controllers = [Int32](repeating: -1, count: Parameters.all.count)
        var size = UInt32(MemoryLayout<Int32>.size * controllers.count)
        guard AudioUnitGetProperty(unit, controllersProperty, kAudioUnitScope_Global, 0, &controllers, &size) == noErr else {
            return Parameters.all.map { Int32(Controllers.standard(for: $0) ?? -1) }
        }
        return controllers
    }

    private static func learning(in unit: AudioUnit) -> Parameter? {
        var index: Int32 = -1
        var size = UInt32(MemoryLayout<Int32>.size)
        guard AudioUnitGetProperty(unit, learnProperty, kAudioUnitScope_Global, 0, &index, &size) == noErr,
              Parameters.all.indices.contains(Int(index)) else { return nil }
        return Parameters.all[Int(index)]
    }

    private func address(of parameter: Parameter) -> AudioUnitParameter {
        AudioUnitParameter(mAudioUnit: unit, mParameterID: AudioUnitParameterID(parameter.index),
                           mScope: kAudioUnitScope_Global, mElement: 0)
    }

    /// A host records automation between the begin and the end of a gesture.
    private func notify(_ type: AudioUnitEventType, _ parameter: Parameter) {
        var event = AudioUnitEvent(mEventType: type, mArgument: .init(mParameter: address(of: parameter)))
        AUEventListenerNotify(nil, nil, &event)
    }

    private static func position(of parameter: Parameter, in unit: AudioUnit) -> Float {
        var plain: AudioUnitParameterValue = 0
        guard AudioUnitGetParameter(unit, AudioUnitParameterID(parameter.index), kAudioUnitScope_Global, 0, &plain) == noErr else {
            return parameter.normalised(parameter.defaultValue)
        }
        return parameter.normalised(plain)
    }

    /// The number of the factory preset in use, -1 for a preset of the host's.
    private static func presentPreset(of unit: AudioUnit) -> Int {
        var preset = AUPreset()
        var size = UInt32(MemoryLayout<AUPreset>.size)
        guard AudioUnitGetProperty(unit, kAudioUnitProperty_PresentPreset, kAudioUnitScope_Global, 0, &preset, &size) == noErr else {
            return -1
        }
        preset.presetName?.release()        // the property hands its name over retained
        return Int(preset.presetNumber)
    }
}
