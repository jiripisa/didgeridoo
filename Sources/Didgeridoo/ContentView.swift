import AppKit
import SwiftUI
import DidgeridooCore

/// The instrument panel: a header with the program and tempo, the three groups
/// of knobs (Mouth, Lips, Rhythm) and a keyboard strip.
struct ContentView: View {

    @Bindable var model: AppModel
    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 14) {
            header
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 14) {
                    section(ParameterSection.all[0])
                    section(ParameterSection.all[2])
                }
                section(ParameterSection.all[1])
            }
            KeyboardView(model: model)
                .frame(height: 64)
        }
        .padding(18)
        .frame(width: 1100, height: 720)
        .background {
            if let background = Artwork.background {
                Image(nsImage: background).resizable()
            } else {
                Color(red: 0.11, green: 0.08, blue: 0.06)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingSettings) { SettingsView(model: model) }
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
            }
            .frame(width: 230)
            HStack(spacing: 6) {
                Text("Tempo").foregroundStyle(.secondary)
                TextField("BPM", value: $model.bpm, format: .number.precision(.fractionLength(0...1)))
                    .frame(width: 58)
                    .multilineTextAlignment(.trailing)
                    .onSubmit { model.bpm = min(max(model.bpm, 20), 300) }
            }
            Button {
                showingSettings = true
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .help("MIDI input, audio output and the Audio Unit")
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
