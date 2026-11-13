import DidgeridooCore
import Observation

/// What the panel of knobs needs from whoever owns the sound: the standalone
/// app's model, or the plug-in's, which talks to the Audio Unit in a host.
/// Both are observable, so the panel follows their changes.
@MainActor
public protocol InstrumentModel: AnyObject, Observable {

    /// The built-in program in use. Outside `Programs.names` when the sound
    /// did not come from one (a host's own preset).
    var program: Int { get }

    /// Knob position (0...1) of a parameter.
    func position(of parameter: Parameter) -> Float

    /// Turns a knob. Integers and choices snap to their steps.
    func setPosition(_ position: Float, of parameter: Parameter)

    /// Puts a parameter back to the value its program gives it.
    func resetToDefault(_ parameter: Parameter)

    func loadProgram(_ index: Int)

    /// A drag on a knob begins and ends. A host records automation between
    /// the two; the app remembers the sound at the end.
    func beginEditing(_ parameter: Parameter)
    func endEditing(_ parameter: Parameter)
}

public extension InstrumentModel {
    /// Plain (real) value of a parameter.
    func value(of parameter: Parameter) -> Float {
        parameter.plain(position(of: parameter))
    }
}
