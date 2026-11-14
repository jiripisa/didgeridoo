import SwiftUI
import DidgeridooCore
import DidgeridooUI

/// A strip of piano keys for trying the sound with the mouse. Where a key is
/// pressed sets the velocity: soft near the top, firmer further down
/// (`KeyStrip`).
struct KeyboardView: View {

    let model: AppModel
    /// MIDI note of the leftmost key (a C): C2. With Octave at 0 the strip
    /// covers the instrument's useful range, a didgeridoo's own in its second octave.
    let firstNote = 48
    let octaves = 4

    @State private var sounding: Int?

    private static let blackOffsets: Set<Int> = [1, 3, 6, 8, 10]

    var body: some View {
        GeometryReader { geometry in
            let whiteNotes = (firstNote..<(firstNote + octaves * 12 + 1)).filter { !Self.blackOffsets.contains($0 % 12) }
            let keyWidth = geometry.size.width / CGFloat(whiteNotes.count)
            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    ForEach(whiteNotes, id: \.self) { note in
                        key(note, colour: Artwork.cream, width: keyWidth, height: geometry.size.height)
                            .overlay(alignment: .bottom) {
                                if note % 12 == 0 {
                                    Text("C\(note / 12 - 2)")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.black.opacity(0.55))
                                        .padding(.bottom, 4)
                                        .allowsHitTesting(false)        // a click on the name plays the key under it
                                }
                            }
                    }
                }
                ForEach(Array(whiteNotes.enumerated()), id: \.element) { index, note in
                    if Self.blackOffsets.contains((note + 1) % 12), index < whiteNotes.count - 1 {
                        key(note + 1, colour: Color(white: 0.1), width: keyWidth * 0.62, height: geometry.size.height * 0.6)
                            .offset(x: CGFloat(index + 1) * keyWidth - keyWidth * 0.31)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private func key(_ note: Int, colour: Color, width: CGFloat, height: CGFloat) -> some View {
        Rectangle()
            .fill(sounding == note ? Artwork.accent : colour)
            .overlay(Rectangle().stroke(Color.black.opacity(0.5), lineWidth: 0.5))
            .frame(width: width, height: height)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard sounding != note else { return }
                        sounding = note
                        model.synth.noteOn(note, velocity: KeyStrip.velocity(depth: value.startLocation.y / height))
                    }
                    .onEnded { _ in
                        model.synth.noteOff(note)
                        if sounding == note { sounding = nil }
                    }
            )
    }
}
