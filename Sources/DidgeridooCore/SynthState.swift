/// Everything worth remembering about the instrument between launches: the
/// program and each parameter's plain value, keyed by the parameter's stable
/// identifier so that later versions can add parameters.
public struct SynthState: Codable, Equatable, Sendable {

    public var program: Int
    public var values: [String: Float]

    public init(program: Int, values: [String: Float]) {
        self.program = program
        self.values = values
    }

    /// The current state of a synth.
    public init(capturing synth: Synth) {
        program = synth.program
        values = Dictionary(uniqueKeysWithValues: Parameters.all.map { ($0.identifier, synth.value(of: $0)) })
    }

    /// Puts this state into a synth. Parameters the state does not mention keep
    /// the value the program gives them.
    public func apply(to synth: Synth) {
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
