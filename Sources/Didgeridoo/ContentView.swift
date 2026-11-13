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
        .frame(width: 1100, height: 720)
        .instrumentBackground()
        .sheet(isPresented: $showingSettings) { SettingsView(model: model) }
    }
}
