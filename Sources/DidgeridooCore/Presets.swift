import Foundation

/// Why a preset could not be saved, loaded or deleted, in words for the window.
public enum PresetError: Error, Equatable, LocalizedError {
    case noName
    case missing(String)
    case unreadable(String)
    case otherEngine(String)

    public var errorDescription: String? {
        switch self {
        case .noName: "A preset needs a name."
        case .missing(let name): "There is no preset “\(name)” in the folder any more."
        case .unreadable(let name): "“\(name)” is not a Didgeridoo preset, or its file is damaged."
        case .otherEngine(let name): "“\(name)” was saved by another version of Didgeridoo, whose numbers mean something else in this one."
        }
    }
}

/// The player's own presets: one file per preset in a folder, named after the
/// preset, holding a sound as `SynthState` does (the program it grew from and
/// every parameter by its identifier). The app and the plug-in in a host read
/// the same folder, which is how they share presets; files can be copied to
/// another Mac and renamed in the Finder.
public struct PresetLibrary: Sendable {

    public static let fileExtension = "didgeridoo"
    /// The longest name a preset can have.
    public static let longestName = 60

    public let folder: URL
    private let deletesForGood: Bool

    /// `deletesForGood` removes a deleted preset's file instead of moving it to
    /// the Trash (for tests, which have no business in anybody's Trash).
    public init(folder: URL, deletesForGood: Bool = false) {
        self.folder = folder
        self.deletesForGood = deletesForGood
    }

    /// `~/Library/Application Support/Didgeridoo/Presets`: a place every app
    /// may use without asking the system for permission.
    public static let standard: PresetLibrary = {
        let files = FileManager.default
        let support = files.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? files.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        return PresetLibrary(folder: support.appendingPathComponent("Didgeridoo/Presets", isDirectory: true))
    }()

    /// The presets in the folder, as the Finder sorts names. Empty while the
    /// folder is not there.
    public func names() -> [String] {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil,
                                                                  options: [.skipsHiddenFiles])) ?? []
        return files.filter { $0.pathExtension.lowercased() == Self.fileExtension }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    /// A name as a file can carry it: trimmed, "/" and ":" turned into "-",
    /// without a leading dot (the Finder hides such files), not longer than
    /// `longestName`. nil when nothing is left.
    public static func cleaned(_ name: String) -> String? {
        let spaces = CharacterSet.whitespacesAndNewlines
        var cleaned = String(name.map { character -> Character in
            if character == "/" || character == ":" { return "-" }
            return character.isNewline || character == "\t" ? " " : character
        }).trimmingCharacters(in: spaces)
        while cleaned.hasPrefix(".") { cleaned.removeFirst() }
        cleaned = String(cleaned.trimmingCharacters(in: spaces).prefix(longestName)).trimmingCharacters(in: spaces)
        return cleaned.isEmpty ? nil : cleaned
    }

    /// Two names are one preset when they differ in capitals only: the disk
    /// would make one file of them.
    static func same(_ one: String, _ other: String) -> Bool {
        one.compare(other, options: .caseInsensitive) == .orderedSame
    }

    /// Whether saving under a name would replace one of these presets.
    public static func name(_ name: String, isAmong names: [String]) -> Bool {
        guard let cleaned = cleaned(name) else { return false }
        return names.contains { same($0, cleaned) }
    }

    /// Saves a sound under a name, replacing a preset of that name, and returns
    /// the name it was stored under.
    @discardableResult
    public func save(_ state: SynthState, as name: String) throws -> String {
        guard let name = Self.cleaned(name) else { throw PresetError.noName }
        let files = FileManager.default
        try files.createDirectory(at: folder, withIntermediateDirectories: true)
        if let old = spelling(of: name), old != name {
            try files.removeItem(at: file(of: old))         // the same preset with other capitals
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(state).write(to: file(of: name), options: .atomic)
        return name
    }

    /// The sound of a preset. Throws when the preset is gone, when its file
    /// is no preset, and when another engine wrote it.
    public func state(of name: String) throws -> SynthState {
        guard let spelled = spelling(of: name) else { throw PresetError.missing(name) }
        guard let data = try? Data(contentsOf: file(of: spelled)),
              let state = try? JSONDecoder().decode(SynthState.self, from: data) else {
            throw PresetError.unreadable(spelled)
        }
        guard state.model == SynthState.currentModel else { throw PresetError.otherEngine(spelled) }
        return state
    }

    /// Moves a preset's file to the Trash.
    public func delete(_ name: String) throws {
        guard let spelled = spelling(of: name) else { throw PresetError.missing(name) }
        if deletesForGood {
            try FileManager.default.removeItem(at: file(of: spelled))
        } else {
            try FileManager.default.trashItem(at: file(of: spelled), resultingItemURL: nil)
        }
    }

    /// Makes the folder if it is not there yet, for showing it in the Finder.
    public func makeFolder() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    /// A preset's name as the folder spells it.
    func spelling(of name: String) -> String? {
        names().first { Self.same($0, name) }
    }

    private func file(of name: String) -> URL {
        folder.appendingPathComponent(name).appendingPathExtension(Self.fileExtension)
    }
}

/// What a window keeps of the presets: the names in the folder, the preset in
/// use and its values. The app's model and the plug-in's both hold one, so
/// the rules are the same in both windows.
public struct PresetShelf: Sendable {

    public let library: PresetLibrary
    /// The presets, in the order the menu shows them.
    public private(set) var names: [String]
    /// The preset the sound came from, nil when it came from a built-in
    /// program or from somewhere else.
    public private(set) var inUse: String?
    private var state: SynthState?

    /// `inUse` is the preset that was in use when the window was last open;
    /// it counts only while the folder still has it.
    public init(library: PresetLibrary, inUse name: String?) {
        self.library = library
        names = library.names()
        follow(name)
    }

    /// The value the preset in use gives a parameter: what a double click on
    /// its knob returns to. nil when no preset is in use.
    public func value(of parameter: Parameter) -> Float? {
        state?.values[parameter.identifier]
    }

    /// Saves a sound under a name and makes it the preset in use.
    public mutating func save(_ state: SynthState, as name: String) throws {
        let stored = try library.save(state, as: name)
        names = library.names()
        inUse = stored
        self.state = state
    }

    /// Hands over a preset's sound and makes it the preset in use. When it
    /// cannot be read, nothing changes.
    public mutating func load(_ name: String) throws -> SynthState {
        let state = try library.state(of: name)
        names = library.names()
        inUse = names.first { PresetLibrary.same($0, name) } ?? name
        self.state = state
        return state
    }

    /// Deletes a preset. The sound is not touched: when it was the preset in
    /// use, none is in use any more.
    public mutating func delete(_ name: String) throws {
        try library.delete(name)
        names = library.names()
        if let inUse, PresetLibrary.same(inUse, name) { leave() }
    }

    /// The sound now comes from somewhere else (a built-in program).
    public mutating func leave() {
        inUse = nil
        state = nil
    }

    /// Reads the folder again: another window may have saved a preset, the
    /// Finder may have taken one away. True when something changed.
    @discardableResult
    public mutating func look() -> Bool {
        let found = library.names()
        var changed = false
        if found != names {
            names = found
            changed = true
        }
        if let inUse, !found.contains(inUse) {
            leave()
            changed = true
        }
        return changed
    }

    /// The preset in use was named from outside (a host's project came back
    /// with it): it is in use when the folder has a readable preset of that
    /// name, and no preset is in use otherwise.
    public mutating func follow(_ name: String?) {
        guard let name, let spelled = names.first(where: { PresetLibrary.same($0, name) }),
              let state = try? library.state(of: spelled) else {
            leave()
            return
        }
        inUse = spelled
        self.state = state
    }
}
