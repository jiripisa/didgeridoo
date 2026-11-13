import AppKit
import SwiftUI
import DidgeridooCore

/// One parameter as a knob: its name, a value arc around the cap, the value
/// below. Drag up and down to turn it (Shift for fine steps), double-click to
/// go back to the program's value.
public struct KnobView: View {

    private let parameter: Parameter
    private let model: any InstrumentModel

    @State private var dragStart: Float?

    private static let sweep = 270.0          // degrees of travel
    private static let size: CGFloat = 62

    public init(parameter: Parameter, model: any InstrumentModel) {
        self.parameter = parameter
        self.model = model
    }

    public var body: some View {
        let position = Double(model.position(of: parameter))
        VStack(spacing: 4) {
            Text(parameter.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Artwork.cream.opacity(0.75))
                .lineLimit(1)
            ZStack {
                arc(from: 0, to: 1)
                    .stroke(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                arc(from: parameter.isBipolar ? min(0.5, position) : 0, to: parameter.isBipolar ? max(0.5, position) : position)
                    .stroke(Artwork.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                cap
                    .frame(width: Self.size * 0.86, height: Self.size * 0.86)
                // The pointer: a short cream line turning with the value.
                Capsule()
                    .fill(Artwork.cream)
                    .frame(width: 3, height: Self.size * 0.2)
                    .offset(y: -Self.size * 0.22)
                    .rotationEffect(.degrees(-Self.sweep / 2 + Self.sweep * position))
            }
            .frame(width: Self.size + 10, height: Self.size + 10)
            .contentShape(Circle())
            .gesture(drag)
            .onTapGesture(count: 2) { model.resetToDefault(parameter) }
            Text(parameter.label(model.value(of: parameter)))
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .frame(width: 112)
        .accessibilityElement()
        .accessibilityLabel(parameter.name)
        .accessibilityValue(parameter.label(model.value(of: parameter)))
    }

    @ViewBuilder
    private var cap: some View {
        if let image = Artwork.knob {
            Image(nsImage: image).resizable().interpolation(.high)
        } else {
            Circle().fill(Color(white: 0.2))
        }
    }

    /// Part of the 270-degree ring, `from` and `to` being knob positions (0...1).
    private func arc(from: Double, to: Double) -> some Shape {
        // trim() runs clockwise from 3 o'clock; the ring starts at 7:30.
        Circle()
            .trim(from: from * Self.sweep / 360, to: max(from, to) * Self.sweep / 360)
            .rotation(.degrees(135))
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                let start: Float
                if let dragStart {
                    start = dragStart
                } else {
                    start = model.position(of: parameter)
                    dragStart = start
                    model.beginEditing(parameter)
                }
                let fine = NSEvent.modifierFlags.contains(.shift) ? 0.1 : 1.0
                model.setPosition(start - Float(value.translation.height / 200 * fine), of: parameter)
            }
            .onEnded { _ in
                dragStart = nil
                model.endEditing(parameter)
            }
    }
}
