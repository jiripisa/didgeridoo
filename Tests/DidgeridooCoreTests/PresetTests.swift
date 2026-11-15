import Foundation
import Testing
@testable import DidgeridooCore

/// The player's own presets: one file per preset in a folder, and what a
/// window keeps of them (the names, the one in use, its values).
@Suite("Presets")
struct PresetTests {

    /// A library in a folder of its own that is not there yet. Deleting removes for good here:
    /// the tests have no business in anybody's Trash.
    private func library() -> PresetLibrary {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("didgeridoo-presets-\(UUID().uuidString)").appendingPathComponent("Presets")
        return PresetLibrary(folder: folder, deletesForGood: true)
    }

    private func remove(_ library: PresetLibrary) {
        try? FileManager.default.removeItem(at: library.folder.deletingLastPathComponent())
    }

    private func knob(_ identifier: String) throws -> Parameter { try #require(Parameters.named(identifier)) }

    /// A sound nobody would mistake for a program's: Gallop with the octave up, an LFO on Tone and the vowel moved.
    private func sound() throws -> Synth {
        let synth = Synth()
        synth.loadProgram(try #require(Programs.names.firstIndex(of: "Gallop")))
        synth.setValue(1, of: try knob("octave"))
        synth.setValue(30, of: try knob("lfo2tone"))
        synth.setValue(77, of: try knob("vowel"))
        return synth
    }

    // MARK: The files

    @Test("A folder that is not there yet lists nothing, and the first save makes it")
    func folderIsMade() throws {
        let library = library()
        defer { remove(library) }
        #expect(library.names().isEmpty)
        try library.save(SynthState(capturing: Synth()), as: "First")
        #expect(library.names() == ["First"])
        #expect(FileManager.default.fileExists(atPath: library.folder.appendingPathComponent("First.didgeridoo").path))
    }

    @Test("A preset brings back every knob, the octave and the LFOs' amounts, on any program")
    func everythingComesBack() throws {
        let library = library()
        defer { remove(library) }
        let saved = try sound()
        try library.save(SynthState(capturing: saved), as: "Mine")

        let other = Synth()
        other.loadProgram(try #require(Programs.names.firstIndex(of: "Deep Earth")))
        try library.state(of: "Mine").apply(to: other)
        for parameter in Parameters.all {
            #expect(abs(other.value(of: parameter) - saved.value(of: parameter)) < 0.001, "\(parameter.identifier)")
        }
        #expect(other.value(of: try knob("octave")) == 1)
        #expect(abs(other.value(of: try knob("lfo2tone")) - 30) < 0.001)
        #expect(other.program == saved.program)
    }

    @Test("Presets are listed as the Finder sorts names; other files are left out")
    func listing() throws {
        let library = library()
        defer { remove(library) }
        let state = SynthState(capturing: Synth())
        for name in ["b 10", "b 2", "Ábel", "a"] { try library.save(state, as: name) }
        try Data("notes".utf8).write(to: library.folder.appendingPathComponent("read me.txt"))
        #expect(library.names() == ["a", "Ábel", "b 2", "b 10"])
    }

    @Test("A name becomes a file's name: trimmed, without separators or a leading dot, not too long")
    func names() throws {
        #expect(PresetLibrary.cleaned("  Můj dron \n") == "Můj dron")
        #expect(PresetLibrary.cleaned("in/out: 2") == "in-out- 2")
        #expect(PresetLibrary.cleaned("..hidden") == "hidden")
        #expect(PresetLibrary.cleaned("   ") == nil)
        #expect(PresetLibrary.cleaned(".") == nil)
        #expect(PresetLibrary.cleaned(String(repeating: "x", count: 200))?.count == 60)

        let library = library()
        defer { remove(library) }
        #expect(throws: PresetError.noName) { try library.save(SynthState(capturing: Synth()), as: "  ") }
        #expect(try library.save(SynthState(capturing: Synth()), as: " in/out ") == "in-out")
        #expect(library.names() == ["in-out"])
    }

    @Test("Saving under a name that exists replaces that preset, however it is capitalised")
    func replacing() throws {
        let library = library()
        defer { remove(library) }
        try library.save(SynthState(capturing: Synth()), as: "Drone")
        try library.save(SynthState(capturing: try sound()), as: "drone")
        #expect(library.names() == ["drone"])
        #expect(try library.state(of: "DRONE").values["vowel"] == 77)
        #expect(PresetLibrary.name("dRoNe ", isAmong: library.names()))
        #expect(!PresetLibrary.name("drones", isAmong: library.names()))
    }

    @Test("Deleting takes the preset out of the folder; one that is not there cannot be deleted or read")
    func deleting() throws {
        let library = library()
        defer { remove(library) }
        try library.save(SynthState(capturing: Synth()), as: "Gone")
        try library.delete("Gone")
        #expect(library.names().isEmpty)
        #expect(throws: PresetError.missing("Gone")) { try library.delete("Gone") }
        #expect(throws: PresetError.missing("Gone")) { try library.state(of: "Gone") }
    }

    @Test("A file that is no preset, and a preset of another engine, are not loaded")
    func unreadable() throws {
        let library = library()
        defer { remove(library) }
        try FileManager.default.createDirectory(at: library.folder, withIntermediateDirectories: true)
        try Data("not a preset".utf8).write(to: library.folder.appendingPathComponent("Broken.didgeridoo"))
        // As 1.0.x would have written one: no word about the engine.
        try Data(#"{"program":0,"values":{"vowel":50}}"#.utf8).write(to: library.folder.appendingPathComponent("Old.didgeridoo"))
        #expect(library.names() == ["Broken", "Old"])
        #expect(throws: PresetError.unreadable("Broken")) { try library.state(of: "Broken") }
        #expect(throws: PresetError.otherEngine("Old")) { try library.state(of: "Old") }
    }

    // MARK: What a window keeps

    @Test("A window starts with the folder's presets and the one it was told was in use, if it is still there")
    func shelfStarts() throws {
        let library = library()
        defer { remove(library) }
        try library.save(SynthState(capturing: try sound()), as: "Mine")
        let kept = PresetShelf(library: library, inUse: "Mine")
        #expect(kept.names == ["Mine"])
        #expect(kept.inUse == "Mine")
        #expect(kept.value(of: try knob("vowel")) == 77)
        let lost = PresetShelf(library: library, inUse: "Thrown away")
        #expect(lost.inUse == nil)
        #expect(lost.value(of: try knob("vowel")) == nil)
        #expect(PresetShelf(library: library, inUse: nil).inUse == nil)
    }

    @Test("Saving makes the preset the one in use, under the name it was stored as")
    func shelfSaves() throws {
        let library = library()
        defer { remove(library) }
        var shelf = PresetShelf(library: library, inUse: nil)
        try shelf.save(SynthState(capturing: try sound()), as: " Mine ")
        #expect(shelf.names == ["Mine"])
        #expect(shelf.inUse == "Mine")
        #expect(shelf.value(of: try knob("octave")) == 1)
    }

    @Test("Loading hands over the preset's sound and makes it the one in use; a built-in program ends that")
    func shelfLoads() throws {
        let library = library()
        defer { remove(library) }
        try library.save(SynthState(capturing: try sound()), as: "Mine")
        var shelf = PresetShelf(library: library, inUse: nil)
        let state = try shelf.load("mine")
        #expect(state.values["vowel"] == 77)
        #expect(shelf.inUse == "Mine")                      // as the folder spells it
        shelf.leave()
        #expect(shelf.inUse == nil)
        #expect(shelf.value(of: try knob("vowel")) == nil)
        #expect(throws: PresetError.missing("Nothing")) { try shelf.load("Nothing") }
        #expect(shelf.inUse == nil)
    }

    @Test("Deleting the preset in use leaves none in use; deleting another leaves it")
    func shelfDeletes() throws {
        let library = library()
        defer { remove(library) }
        var shelf = PresetShelf(library: library, inUse: nil)
        try shelf.save(SynthState(capturing: Synth()), as: "One")
        try shelf.save(SynthState(capturing: Synth()), as: "Two")
        try shelf.delete("One")
        #expect(shelf.names == ["Two"])
        #expect(shelf.inUse == "Two")
        try shelf.delete("Two")
        #expect(shelf.names.isEmpty)
        #expect(shelf.inUse == nil)
    }

    @Test("A look at the folder finds what another window saved and what the Finder took away")
    func shelfLooks() throws {
        let library = library()
        defer { remove(library) }
        var mine = PresetShelf(library: library, inUse: nil)
        var theirs = PresetShelf(library: library, inUse: nil)
        try theirs.save(SynthState(capturing: Synth()), as: "From the app")
        #expect(mine.names.isEmpty)
        let found = mine.look()
        #expect(found)                                      // something changed
        #expect(mine.names == ["From the app"])
        let again = mine.look()
        #expect(!again)                                     // nothing new

        _ = try mine.load("From the app")
        try FileManager.default.removeItem(at: library.folder.appendingPathComponent("From the app.didgeridoo"))
        let missed = mine.look()
        #expect(missed)
        #expect(mine.names.isEmpty)
        #expect(mine.inUse == nil)
    }

    @Test("The window is told that a preset in use was named from outside, and forgets one that is not in the folder")
    func shelfFollows() throws {
        let library = library()
        defer { remove(library) }
        try library.save(SynthState(capturing: try sound()), as: "Mine")
        var shelf = PresetShelf(library: library, inUse: nil)
        shelf.follow("Mine")                                // a host's project came back with this name
        #expect(shelf.inUse == "Mine")
        #expect(shelf.value(of: try knob("vowel")) == 77)
        shelf.follow("Untitled")                            // a host's own preset
        #expect(shelf.inUse == nil)
        shelf.follow(nil)
        #expect(shelf.inUse == nil)
    }
}
