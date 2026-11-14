import SwiftUI
import DidgeridooCore

/// The instrument's panel, the same in the app's window and in the plug-in's:
/// a header with the logo, the program and the buttons LFO 1, LFO 2 and MIDI,
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
    }

    private var header: some View {
        HStack(spacing: 16) {
            if let logo = Artwork.logo {
                Image(nsImage: logo).resizable().aspectRatio(contentMode: .fit).frame(height: 40)
            } else {
                Text("Didgeridoo").font(.system(size: 30, weight: .bold)).foregroundStyle(Artwork.cream)
            }
            Spacer()
            Picker("Program", selection: Binding(get: { model.program }, set: { model.loadProgram($0) })) {
                ForEach(Programs.names.indices, id: \.self) { index in
                    Text(Programs.names[index]).tag(index)
                }
                if !Programs.names.indices.contains(model.program) {
                    Text("—").tag(model.program)        // a host's own preset
                }
            }
            .frame(width: 230)
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
