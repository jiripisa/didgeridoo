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

    /// The player's own presets, in the order the menu shows them.
    var presets: [String] { get }

    /// The preset the sound came from; nil when it came from a built-in
    /// program or from a host.
    var preset: String? { get }

    /// Where the presets are kept, for showing the folder.
    var presetLibrary: PresetLibrary { get }

    /// Knob position (0...1) of a parameter.
    func position(of parameter: Parameter) -> Float

    /// Turns a knob. Integers and choices snap to their steps.
    func setPosition(_ position: Float, of parameter: Parameter)

    /// Puts a parameter back to the value its program gives it, or the
    /// preset in use.
    func resetToDefault(_ parameter: Parameter)

    func loadProgram(_ index: Int)

    /// Loads a preset: every parameter, the octave included.
    func loadPreset(_ name: String) throws

    /// Saves the sound as it stands under a name, replacing a preset of that
    /// name, and makes it the preset in use.
    func savePreset(as name: String) throws

    /// Moves a preset to the Trash. The sound stays as it is.
    func deletePreset(_ name: String) throws

    /// Reads the presets' folder again: another window may have saved one.
    func lookAtPresets()

    /// A drag on a knob begins and ends. A host records automation between
    /// the two; the app remembers the sound at the end.
    func beginEditing(_ parameter: Parameter)
    func endEditing(_ parameter: Parameter)

    /// The MIDI controller that moves a parameter, nil for none.
    func controller(of parameter: Parameter) -> Int?

    /// Gives a parameter a controller, or takes it away (nil). A controller
    /// serves one parameter.
    func setController(_ controller: Int?, of parameter: Parameter)

    /// Every parameter back to the controller it came with.
    func resetControllers()

    /// The parameter that takes the next controller that moves.
    var learning: Parameter? { get }

    /// Starts learning for a parameter, or calls it off (nil).
    func learn(_ parameter: Parameter?)
}

public extension InstrumentModel {
    /// Plain (real) value of a parameter.
    func value(of parameter: Parameter) -> Float {
        parameter.plain(position(of: parameter))
    }
}
