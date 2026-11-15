import SwiftUI
import DidgeridooCore

/// What Save Preset… opens: a field for the name, and a button that says
/// whether it saves a new preset or replaces one.
struct PresetNameView: View {

    @Binding var name: String
    /// The presets there are, to tell whether the name is one of them.
    let presets: [String]
    let save: () -> Void
    let cancel: () -> Void

    /// The field has the keyboard as soon as it opens: the next thing to do is to type.
    @FocusState private var typing: Bool

    private var usable: Bool { PresetLibrary.cleaned(name) != nil }
    private var replaces: Bool { PresetLibrary.name(name, isAmong: presets) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Save the sound as a preset").font(.headline)
            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)
                .focused($typing)
                .onSubmit { if usable { save() } }
            Text(replaces ? "A preset of this name exists and will be replaced."
                          : "Every knob is stored, the octave and the LFO amounts included.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancel", action: cancel).keyboardShortcut(.cancelAction)
                Button(replaces ? "Replace" : "Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!usable)
            }
        }
        .padding(14)
        .onAppear { typing = true }
    }
}
