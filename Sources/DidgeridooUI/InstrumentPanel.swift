import SwiftUI
import DidgeridooCore

/// The instrument's panel, the same in the app's window and in the plug-in's:
/// a header with the logo, the program and the LFOs' buttons, then the groups
/// of knobs (Mouth, Lips, Tube, Rhythm) in two columns. With an LFO's button
/// on, the knobs set how far that LFO moves them (`KnobView`). `extras` join the header on the right
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

    /// The LFO whose amounts the knobs are setting (0 for the first); nil
    /// while they are knobs.
    @State private var assigning: Int?

    /// `assigning` is the LFO the panel opens with its button on, for a
    /// picture of that state; a window opens with none.
    public init(model: any InstrumentModel,
                assigning: Int? = nil,
                @ViewBuilder extras: () -> Extras = { EmptyView() },
                @ViewBuilder footer: () -> Footer = { EmptyView() }) {
        self.model = model
        _assigning = State(initialValue: assigning)
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
            // One at a time: the knobs can set one LFO's amounts.
            ForEach(0..<LFOs.count, id: \.self) { lfo in lfoButton(lfo) }
            extras
        }
        .frame(height: 46)
    }

    /// An LFO's button: its colour as a dot, and filled with it while the knobs
    /// are setting that LFO's amounts. Drawn here, not left to the system's
    /// toggle, so that it shows which LFO is on in a window that is not in front.
    private func lfoButton(_ lfo: Int) -> some View {
        let on = assigning == lfo
        return Button {
            assigning = on ? nil : lfo
        } label: {
            HStack(spacing: 6) {
                Circle().fill(on ? Color.black.opacity(0.55) : Artwork.lfo(lfo)).frame(width: 8, height: 8)
                Text("LFO \(lfo + 1)")
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(on ? Color.black.opacity(0.85) : Artwork.cream)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(on ? Artwork.lfo(lfo) : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Artwork.lfo(lfo).opacity(on ? 0 : 0.45)))
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help(on ? "Back to the knobs" : "Drag the knobs to set how far LFO \(lfo + 1) moves them")
        .accessibilityLabel("LFO \(lfo + 1) amounts")
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
                    KnobView(parameter: parameter, model: model, assigning: assigning)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Artwork.panel, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06)))
    }
}
