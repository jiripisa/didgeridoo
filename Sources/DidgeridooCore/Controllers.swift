import DidgeridooDSP

/// MIDI controllers on the knobs. Every knob comes with a controller (a control
/// change number) and can be taught another; a control change then puts the
/// knob where its value says.
public enum Controllers {

    /// The controller a parameter comes with; nil for one that has none (the
    /// LFOs' amounts).
    public static func standard(for parameter: Parameter) -> Int? {
        let controller = Int(didge_standard_controller(Int32(parameter.index)))
        return controller >= 0 ? controller : nil
    }

    /// Whether a controller cannot be given to a knob: MIDI's own (bank
    /// select, data entry, channel mode …), the mod wheel and the sustain pedal.
    public static func isReserved(_ controller: Int) -> Bool {
        didge_controller_reserved(Int32(controller)) != 0
    }

    /// A controller as the panel shows it under a knob.
    public static func label(_ controller: Int?) -> String {
        controller.map { "CC \($0)" } ?? "—"
    }
}

public extension Synth {

    /// The controller that moves a parameter, nil for none.
    func controller(of parameter: Parameter) -> Int? {
        let controller = Int(didge_get_controller(engine, Int32(parameter.index)))
        return controller >= 0 ? controller : nil
    }

    /// Gives a parameter a controller, or takes it away (nil). A controller
    /// serves one parameter: whoever had it before has none. A reserved
    /// controller is not taken.
    func setController(_ controller: Int?, of parameter: Parameter) {
        didge_set_controller(engine, Int32(parameter.index), Int32(controller ?? -1))
    }

    /// Every parameter back to the controller it came with.
    func resetControllers() {
        didge_reset_controllers(engine)
    }

    /// The parameter that takes the next controller that moves; nil while
    /// nobody is learning.
    var learning: Parameter? {
        let index = Int(didge_learning(engine))
        return Parameters.all.indices.contains(index) ? Parameters.all[index] : nil
    }

    /// Starts learning for a parameter, or calls it off (nil).
    func learn(_ parameter: Parameter?) {
        didge_learn(engine, Int32(parameter?.index ?? -1))
    }

    /// Counts what MIDI changed without anyone turning a knob: a knob moved by
    /// its controller, a controller learnt. A window that sees a new number
    /// reads the parameters and the controllers again.
    var changes: UInt32 { UInt32(didge_changes(engine)) }
}

/// Which controller moves which parameter, in a form that can be stored: by
/// the parameter's identifier, -1 for a parameter that has none. It is not
/// part of a sound: programs leave it alone.
public struct ControllerMap: Codable, Equatable, Sendable {

    public var controllers: [String: Int]

    public init(controllers: [String: Int]) {
        self.controllers = controllers
    }

    /// The controllers of a synth as they stand.
    public init(capturing synth: Synth) {
        controllers = Dictionary(uniqueKeysWithValues: Parameters.all.map { ($0.identifier, synth.controller(of: $0) ?? -1) })
    }

    /// Puts this map into a synth. A parameter the map does not mention keeps
    /// the controller it comes with.
    public func apply(to synth: Synth) {
        synth.resetControllers()
        // Those without a controller first: giving a controller takes it from whoever has it.
        for parameter in Parameters.all where (controllers[parameter.identifier] ?? 0) < 0 {
            synth.setController(nil, of: parameter)
        }
        for parameter in Parameters.all {
            if let controller = controllers[parameter.identifier], controller >= 0 {
                synth.setController(controller, of: parameter)
            }
        }
    }
}
