import SwiftUI
import DidgeridooCore

/// The instrument's panel, the same in the app's window and in the plug-in's:
/// a header with the logo, the Program menu (the built-in programs, the
/// player's own presets and the commands that save and delete them) and the
/// buttons LFO 1, LFO 2 and MIDI,
/// then the groups of knobs (Mouth, Lips, Tube, Rhythm) in two columns. With
/// an LFO's button on, the knobs set how far that LFO moves them; with MIDI on
/// they show their MIDI controllers and learn new ones (`KnobView`). `extras` join the header on the right
/// (the app's tempo and settings); `footer` goes below the knobs (the app's
/// keyboard).
/// The caller gives the panel its frame and `instrumentBackground()`.
public struct InstrumentPanel<Extras: View, Footer: View>: View {

    /// The panel's width; its knobs are laid out for it. Its height follows
    /// from what is in it.
    public static var width: CGFloat { 1100 }

    /// Knobs in a row of a group, and the room between two of them: two
    /// groups side by side fill the panel's width.
    private static var knobsInRow: Int { 5 }
    private static var knobSpacing: CGFloat { 9 }

    private let model: any InstrumentModel
    private let extras: Extras
    private let footer: Footer

    /// What the knobs are for at the moment: their values, an LFO's amounts,
    /// or their MIDI controllers.
    @State private var use: KnobUse

    /// Save Preset…: the name being typed, and whether its field is open.
    @State private var naming = false
    @State private var name = ""
    /// What went wrong with a preset, in words, until the player has read it.
    @State private var problem: String?

    /// `showing` is what the panel opens with, for a picture of that state; a
    /// window opens with the knobs as knobs.
    public init(model: any InstrumentModel,
                showing use: KnobUse = .value,
                @ViewBuilder extras: () -> Extras = { EmptyView() },
                @ViewBuilder footer: () -> Footer = { EmptyView() }) {
        self.model = model
        _use = State(initialValue: use)
        self.extras = extras()
        self.footer = footer()
    }

    public var body: some View {
        VStack(spacing: 14) {
            header
            // The groups fill two columns in turn: Mouth and Tube on the left,
            // Lips and Rhythm on the right.
            HStack(alignment: .top, spacing: 14) {
                ForEach(0..<2, id: \.self) { column in
                    VStack(spacing: 14) {
                        ForEach(ParameterSection.all.indices.filter { $0 % 2 == column }, id: \.self) { index in
                            section(ParameterSection.all[index])
                        }
                    }
                }
            }
            footer
        }
        .padding(18)
        .alert("Presets", isPresented: Binding(get: { problem != nil }, set: { if !$0 { problem = nil } })) {
            Button("OK") {}
        } message: {
            Text(problem ?? "")
        }
        // Another window may save a preset: the app's while the plug-in's is open, or the other way round.
        .task {
            while !Task.isCancelled {
                model.lookAtPresets()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            if let logo = Artwork.logo {
                Image(nsImage: logo).resizable().aspectRatio(contentMode: .fit).frame(height: 40)
            } else {
                Text("Didgeridoo").font(.system(size: 30, weight: .bold)).foregroundStyle(Artwork.cream)
            }
            Spacer()
            programMenu
            // One at a time: the knobs can be one thing.
            ForEach(0..<LFOs.count, id: \.self) { lfo in
                useButton("LFO \(lfo + 1)", .amount(lfo: lfo), colour: Artwork.lfo(lfo),
                          help: "Drag the knobs to set how far LFO \(lfo + 1) moves them")
            }
            useButton("MIDI", .controller, colour: Artwork.accent,
                      help: "Click a knob, then move a control of your MIDI controller to give it to the knob")
            if use == .controller {
                Button("Defaults") { model.resetControllers() }
                    .help("Give every knob the controller it came with")
            }
            extras
        }
        .frame(height: 46)
    }

    // MARK: Programs and presets

    /// Where the sound came from: a built-in program, one of the player's
    /// presets, or neither (a host's own preset).
    private enum Source: Equatable {
        case program(Int), preset(String), elsewhere
    }

    private var source: Source {
        if let preset = model.preset { return .preset(preset) }
        return Programs.names.indices.contains(model.program) ? .program(model.program) : .elsewhere
    }

    private var sourceName: String {
        switch source {
        case .program(let index): Programs.names[index]
        case .preset(let name): name
        case .elsewhere: "—"
        }
    }

    /// The Program menu: the built-in programs, below them the player's
    /// presets, each ticked while it is in use, and the commands.
    private var programMenu: some View {
        HStack(spacing: 8) {
            Text("Program")
            Menu {
                Section {
                    ForEach(Programs.names.indices, id: \.self) { index in
                        Toggle(Programs.names[index], isOn: Binding(get: { source == .program(index) },
                                                                    set: { _ in model.loadProgram(index) }))
                    }
                }
                if !model.presets.isEmpty {
                    Section("Your presets") {
                        ForEach(model.presets, id: \.self) { preset in
                            Toggle(preset, isOn: Binding(get: { source == .preset(preset) },
                                                         set: { _ in attempt { try model.loadPreset(preset) } }))
                        }
                    }
                }
                Section {
                    Button("Save Preset…") {
                        name = model.preset ?? ""
                        naming = true
                    }
                    if let preset = model.preset {
                        Button("Delete “\(preset)”") { attempt { try model.deletePreset(preset) } }
                    }
                    Button("Show in Finder") { showPresets() }
                }
            } label: {
                // One width for every name, so that the header stands still.
                // The system's newer menu button takes its width from this
                // label…
                Text(sourceName).lineLimit(1).truncationMode(.tail).frame(width: 136, alignment: .leading)
            }
            // …and its older one, which the app gets (it is built for
            // macOS 14), from the name itself, whatever the label says: a long
            // preset name pushed the header apart. Hence a width here as well.
            .frame(width: 183)
            .help("Built-in programs and your own presets")
            .accessibilityLabel("Program")
            .popover(isPresented: $naming, arrowEdge: .bottom) {
                PresetNameView(name: $name, presets: model.presets, save: saveNamed, cancel: { naming = false })
            }
        }
        .fixedSize()            // its own size, whatever the header has to share out: the label must not wrap
    }

    private func saveNamed() {
        guard naming else { return }            // Return and the button may both ask
        naming = false
        attempt { try model.savePreset(as: name) }
    }

    private func showPresets() {
        attempt {
            try model.presetLibrary.makeFolder()
            NSWorkspace.shared.open(model.presetLibrary.folder)
        }
    }

    /// Runs something that may fail and keeps the reason for the player.
    private func attempt(_ action: () throws -> Void) {
        do { try action() } catch { problem = error.localizedDescription }
    }

    /// A button that turns the knobs into something else and back: its colour
    /// as a dot, and filled with it while it is on. Drawn here, not left to the
    /// system's toggle, so that it shows what is on in a window that is not in
    /// front.
    private func useButton(_ title: String, _ what: KnobUse, colour: Color, help: String) -> some View {
        let on = use == what
        return Button {
            if use == .controller { model.learn(nil) }      // leaving the controllers: nobody is left learning
            use = on ? .value : what
        } label: {
            HStack(spacing: 6) {
                Circle().fill(on ? Color.black.opacity(0.55) : colour).frame(width: 8, height: 8)
                Text(title)
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(on ? Color.black.opacity(0.85) : Artwork.cream)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(on ? colour : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(colour.opacity(on ? 0 : 0.45)))
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help(on ? "Back to the knobs" : help)
        .accessibilityLabel(title)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func section(_ section: ParameterSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(section.title.uppercased())
                .font(.system(size: 12, weight: .bold))
                .kerning(1.5)
                .foregroundStyle(Artwork.accent)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(KnobView.width), spacing: Self.knobSpacing), count: Self.knobsInRow),
                      alignment: .leading, spacing: 14) {
                ForEach(section.parameters) { parameter in
                    KnobView(parameter: parameter, model: model, use: use)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Artwork.panel, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06)))
    }
}
