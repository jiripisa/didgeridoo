/// Everything worth remembering about the instrument between launches: the
/// program and each parameter's plain value, keyed by the parameter's stable
/// identifier so that later versions can add parameters.
public struct SynthState: Codable, Equatable, Sendable {

    /// The engine whose numbers these are. The model that replaced the MPC
    /// plugin's synthesis is 2: several knobs kept their name and changed
    /// their meaning, so state from before it says nothing about this engine.
    public static let currentModel = 2

    public var model: Int
    public var program: Int
    public var values: [String: Float]

    public init(program: Int, values: [String: Float]) {
        self.model = Self.currentModel
        self.program = program
        self.values = values
    }

    /// The current state of a synth.
    public init(capturing synth: Synth) {
        model = Self.currentModel
        program = synth.program
        values = Dictionary(uniqueKeysWithValues: Parameters.all.map { ($0.identifier, synth.value(of: $0)) })
    }

    /// State stored before `model` existed belongs to the first engine.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        model = try container.decodeIfPresent(Int.self, forKey: .model) ?? 1
        program = try container.decode(Int.self, forKey: .program)
        values = try container.decode([String: Float].self, forKey: .values)
    }

    /// Puts this state into a synth. Parameters the state does not mention keep
    /// the value the program gives them. State of another engine is left
    /// alone: the synth stays as it is.
    public func apply(to synth: Synth) {
        guard model == Self.currentModel else { return }
        if Programs.names.indices.contains(program) {
            synth.loadProgram(program)
        }
        for parameter in Parameters.all {
            if let value = values[parameter.identifier] {
                synth.setValue(value, of: parameter)
            }
        }
    }
}
