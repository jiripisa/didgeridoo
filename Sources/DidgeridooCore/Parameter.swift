import DidgeridooDSP

/// One knob of the instrument. The table comes from the sound engine, so the
/// app, the Audio Unit and the original MPC plugin always agree on it.
public struct Parameter: Identifiable, Sendable, Equatable {

    public enum Kind: Sendable, Equatable {
        case continuous          // a real value: Hz, ms, dB, %
        case integer             // whole steps: semitones, a velocity
        case choice([String])    // one of a list
    }

    /// Position in the engine's table. Permanent: saved state relies on `identifier`,
    /// hosts rely on the index.
    public let index: Int
    /// Stable name used in saved state ("vowel", "rhydepth").
    public let identifier: String
    /// What the user sees ("Vowel", "Rhy Depth").
    public let name: String
    /// "Hz", "ms", "dB", "%", "st" or "".
    public let unit: String
    public let kind: Kind
    /// Plain (real) values.
    public let range: ClosedRange<Float>
    public let defaultValue: Float

    public var id: Int { index }

    /// True when zero sits in the middle of the range (a signed amount).
    public var isBipolar: Bool { range.lowerBound < 0 && range.upperBound > 0 && defaultValue == 0 }

    /// Knob position (0...1) for a plain value.
    public func normalised(_ plain: Float) -> Float {
        didge_param_to_normalised(Int32(index), plain)
    }

    /// Plain value for a knob position (0...1). Integers and choices snap to their steps.
    public func plain(_ normalised: Float) -> Float {
        didge_param_to_plain(Int32(index), normalised)
    }

    /// The value as text without its unit: "1400", "-6.0", "1/8", "Off".
    public func text(_ plain: Float) -> String {
        withUnsafeTemporaryAllocation(of: CChar.self, capacity: 64) { buffer in
            String(cString: didge_param_display(Int32(index), plain, buffer.baseAddress, Int32(buffer.count)))
        }
    }

    /// The value with its unit, as shown under a knob: "1400 Hz", "1/8".
    public func label(_ plain: Float) -> String {
        let value = text(plain)
        return unit.isEmpty || value == "Off" ? value : "\(value) \(unit)"
    }
}

public enum Parameters {

    /// Every parameter, in engine order.
    public static let all: [Parameter] = (0..<Int(didge_num_params())).map { index in
        var info = DidgeParamInfo()
        didge_param_info(Int32(index), &info)
        let kind: Parameter.Kind
        if Int(info.kind) == Int(DIDGE_KIND_CHOICE) {
            let count = Int(info.numChoices)
            kind = .choice((0..<count).map { String(cString: didge_param_choice(Int32(index), Int32($0))) })
        } else if Int(info.kind) == Int(DIDGE_KIND_INT) {
            kind = .integer
        } else {
            kind = .continuous
        }
        return Parameter(index: index,
                         identifier: String(cString: info.identifier),
                         name: String(cString: info.name),
                         unit: String(cString: info.unit),
                         kind: kind,
                         range: info.minValue...info.maxValue,
                         defaultValue: info.defaultValue)
    }

    public static func named(_ identifier: String) -> Parameter? {
        all.first { $0.identifier == identifier }
    }
}

/// A group of controls, as on the MPC plugin's pages: Mouth, Lips, Rhythm.
/// The groups and the order of their parameters come from the sound engine,
/// which also gives them to the Audio Unit.
public struct ParameterSection: Identifiable, Sendable {
    public let title: String
    public let parameters: [Parameter]
    public var id: String { title }

    public static let all: [ParameterSection] = (0..<didge_num_sections()).map { section in
        ParameterSection(title: String(cString: didge_section_name(section)),
                         parameters: (0..<didge_section_size(section)).map { position in
                             Parameters.all[Int(didge_section_param(section, position))]
                         })
    }
}

/// The built-in programs (factory presets).
public enum Programs {
    public static let names: [String] = (0..<Int(didge_num_programs())).map {
        String(cString: didge_program_name(Int32($0)))
    }

    /// The plain value a program gives a parameter.
    public static func value(program: Int, parameter: Parameter) -> Float {
        didge_program_value(Int32(program), Int32(parameter.index))
    }
}
