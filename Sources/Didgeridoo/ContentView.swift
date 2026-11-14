import SwiftUI
import DidgeridooCore
import DidgeridooUI

/// The app's window: the instrument's panel with the tempo and the settings in
/// its header and a keyboard strip below.
struct ContentView: View {

    let model: AppModel
    @State private var showingSettings = false

    var body: some View {
        InstrumentPanel(model: model) {
            HStack(spacing: 6) {
                Text("Tempo").foregroundStyle(.secondary)
                TextField("BPM", value: Binding(get: { model.bpm }, set: { model.setTempo($0) }),
                          format: .number.precision(.fractionLength(0...1)))
                    .frame(width: 58)
                    .multilineTextAlignment(.trailing)
            }
            Button {
                showingSettings = true
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .help("MIDI input, audio output and the Audio Unit")
        } footer: {
            KeyboardView(model: model)
                .frame(height: 64)
        }
        .frame(width: InstrumentPanel<EmptyView, EmptyView>.width)
        .fixedSize(horizontal: false, vertical: true)      // as tall as the knobs and the keyboard need
        .instrumentBackground()
        .sheet(isPresented: $showingSettings) { SettingsView(model: model) }
        .task {
            // A MIDI controller moves knobs without telling a view. Ends with the window.
            while !Task.isCancelled {
                model.followMIDI()
                try? await Task.sleep(for: .milliseconds(40))
            }
        }
    }
}
