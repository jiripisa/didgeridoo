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

/// Which MIDI channels the standalone app listens to.
public enum MIDIChannelFilter: Hashable, Sendable {
    case omni
    case channel(Int)     // 1...16

    /// Stored form: 0 = omni, 1...16 = that channel.
    public init(storedValue: Int) {
        self = (1...16).contains(storedValue) ? .channel(storedValue) : .omni
    }

    public var storedValue: Int {
        switch self {
        case .omni: 0
        case .channel(let channel): channel
        }
    }

    /// Whether a message with this status byte should reach the instrument.
    /// System messages (0xF0 and above) never do.
    public func accepts(status: UInt8) -> Bool {
        guard status >= 0x80, status < 0xF0 else { return false }
        switch self {
        case .omni: return true
        case .channel(let channel): return Int(status & 0x0F) + 1 == channel
        }
    }
}
