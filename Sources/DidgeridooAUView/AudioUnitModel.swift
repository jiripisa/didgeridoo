import AudioToolbox
import DidgeridooCore
import DidgeridooUI
import Observation

/// The panel's model in a host: it reads and writes the Audio Unit's
/// parameters and factory presets. Parameter values of the Audio Unit are the
/// engine's plain values, and a parameter's index is its ID.
///
/// The player's own presets are files the app shares with the plug-in
/// (`PresetLibrary`). One in use is the unit's present preset by name, with
/// the number -1 a host's own presets have: the host shows that name and
/// saves it with its project.
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
    /// The presets and the one in use.
    private var shelf: PresetShelf
    /// The name of the unit's present preset when it is not a factory one, as
    /// of the last look: the shelf is asked again only when it changes.
    @ObservationIgnored private var presentName: String?
    /// The built-in program the sound last came from: what a preset saved
    /// from here grows from.
    @ObservationIgnored private var base: Int
    /// The MIDI controller of each parameter by index, -1 for none, and the
    /// parameter that is learning, as the unit had them at the last look.
    private var controllers: [Int32]
    public private(set) var learning: Parameter?

    public init(unit: AudioUnit, presets library: PresetLibrary = .standard) {
        self.unit = unit
        positions = Parameters.all.map { Self.position(of: $0, in: unit) }
        let present = Self.presentPreset(of: unit)
        program = present.number
        base = Programs.names.indices.contains(present.number) ? present.number : 0
        presentName = present.number < 0 ? present.name : nil
        shelf = PresetShelf(library: library, inUse: presentName)
        controllers = Self.controllers(of: unit)
        learning = Self.learning(in: unit)
    }

    /// Takes over whatever the host changed since the last time.
    public func refresh() {
        for parameter in Parameters.all {
            let position = Self.position(of: parameter, in: unit)
            if position != positions[parameter.index] { positions[parameter.index] = position }
        }
        let present = Self.presentPreset(of: unit)
        if present.number != program { program = present.number }
        if Programs.names.indices.contains(present.number) { base = present.number }
        let name = present.number < 0 ? present.name : nil
        if name != presentName {
            presentName = name
            shelf.follow(name)
        }
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
        let plain = shelf.value(of: parameter)
            ?? (Programs.names.indices.contains(program) ? Programs.value(program: program, parameter: parameter)
                                                         : parameter.defaultValue)
        beginEditing(parameter)
        setPosition(parameter.normalised(plain), of: parameter)
        endEditing(parameter)
    }

    public func loadProgram(_ index: Int) {
        guard Programs.names.indices.contains(index), setPresentPreset(number: index, name: Programs.names[index]) else { return }
        everythingMoved()
    }

    // MARK: Presets

    public var presets: [String] { shelf.names }
    public var preset: String? { shelf.inUse }
    public var presetLibrary: PresetLibrary { shelf.library }

    public func loadPreset(_ name: String) throws {
        let state = try shelf.load(name)
        // Its program first, as the app does: that cuts a sounding note off, and a parameter
        // the preset does not know gets its program's value.
        if Programs.names.indices.contains(state.program) {
            setPresentPreset(number: state.program, name: Programs.names[state.program])
            base = state.program
        }
        for parameter in Parameters.all {
            guard let value = state.values[parameter.identifier] else { continue }
            AudioUnitSetParameter(unit, AudioUnitParameterID(parameter.index), kAudioUnitScope_Global, 0,
                                  min(max(value, parameter.range.lowerBound), parameter.range.upperBound), 0)
        }
        nameThePresentPreset()
        everythingMoved()
    }

    public func savePreset(as name: String) throws {
        var values: [String: Float] = [:]
        for parameter in Parameters.all { values[parameter.identifier] = Self.value(of: parameter, in: unit) }
        try shelf.save(SynthState(program: base, values: values), as: name)
        nameThePresentPreset()
        refresh()
    }

    public func deletePreset(_ name: String) throws {
        try shelf.delete(name)
    }

    public func lookAtPresets() {
        var looked = shelf              // the model changes only when the folder did
        guard looked.look() else { return }
        if looked.inUse == nil { looked.follow(presentName) }
        shelf = looked
    }

    /// Makes the preset in use the unit's present preset: a host shows its
    /// name and saves it with the project.
    private func nameThePresentPreset() {
        guard let name = shelf.inUse else { return }
        setPresentPreset(number: -1, name: name)
        presentName = name
    }

    /// Every parameter may have moved: tell the host's listeners, then read them back.
    private func everythingMoved() {
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
        parameter.normalised(value(of: parameter, in: unit))
    }

    /// A parameter's plain value in the unit.
    private static func value(of parameter: Parameter, in unit: AudioUnit) -> Float {
        var plain: AudioUnitParameterValue = 0
        guard AudioUnitGetParameter(unit, AudioUnitParameterID(parameter.index), kAudioUnitScope_Global, 0, &plain) == noErr else {
            return parameter.defaultValue
        }
        return plain
    }

    /// The unit's present preset: the number of the factory preset in use, or
    /// -1 and a name for one that is not the unit's own (a host's, or one of
    /// the player's).
    private static func presentPreset(of unit: AudioUnit) -> (number: Int, name: String?) {
        var preset = AUPreset()
        var size = UInt32(MemoryLayout<AUPreset>.size)
        guard AudioUnitGetProperty(unit, kAudioUnitProperty_PresentPreset, kAudioUnitScope_Global, 0, &preset, &size) == noErr else {
            return (-1, nil)
        }
        let name = preset.presetName?.takeRetainedValue() as String?    // the property hands its name over retained
        return (Int(preset.presetNumber), name)
    }

    /// Chooses a factory preset by its number, or names a preset that is not
    /// the unit's own (number -1). The unit keeps the name, so it has to live
    /// through the call.
    @discardableResult
    private func setPresentPreset(number: Int, name: String) -> Bool {
        let held = name as CFString
        return withExtendedLifetime(held) {
            var preset = AUPreset(presetNumber: Int32(number), presetName: Unmanaged.passUnretained(held))
            return AudioUnitSetProperty(unit, kAudioUnitProperty_PresentPreset, kAudioUnitScope_Global, 0,
                                        &preset, UInt32(MemoryLayout<AUPreset>.size)) == noErr
        }
    }
}
