import SwiftUI
import DidgeridooCore

/// The instrument's panel, the same in the app's window and in the plug-in's:
/// a header with the logo and the program, then the three groups of knobs
/// (Mouth, Lips, Rhythm). `extras` join the header on the right (the app's
/// tempo and settings); `footer` goes below the knobs (the app's keyboard).
/// The caller gives the panel its frame and `instrumentBackground()`.
public struct InstrumentPanel<Extras: View, Footer: View>: View {

    /// The panel's width; its knobs are laid out for it. Its height follows
    /// from what is in it.
    public static var width: CGFloat { 1100 }

    private let model: any InstrumentModel
    private let extras: Extras
    private let footer: Footer

    public init(model: any InstrumentModel,
                @ViewBuilder extras: () -> Extras = { EmptyView() },
                @ViewBuilder footer: () -> Footer = { EmptyView() }) {
        self.model = model
        self.extras = extras()
        self.footer = footer()
    }

    public var body: some View {
        VStack(spacing: 14) {
            header
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 14) {
                    section(ParameterSection.all[0])
                    section(ParameterSection.all[2])
                }
                section(ParameterSection.all[1])
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
            extras
        }
        .frame(height: 46)
    }

    private func section(_ section: ParameterSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(section.title.uppercased())
                .font(.system(size: 12, weight: .bold))
                .kerning(1.5)
                .foregroundStyle(Artwork.accent)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(112), spacing: 10), count: 4), alignment: .leading, spacing: 14) {
                ForEach(section.parameters) { parameter in
                    KnobView(parameter: parameter, model: model)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Artwork.panel, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06)))
    }
}
