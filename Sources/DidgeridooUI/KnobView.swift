import AppKit
import SwiftUI
import DidgeridooCore

/// One parameter as a knob: its name, a value arc around the cap, the value
/// below. Drag up and down to turn it (Shift for fine steps), double-click to
/// go back to the program's value.
///
/// A knob an LFO moves shows a thin arc in that LFO's colour: the part of its
/// travel the LFO sweeps. While an LFO's button in the header is on
/// (`assigning`), the knob sets that LFO's amount instead of its own value:
/// the same drag and double click, the amount below. Knobs an LFO cannot move
/// step back meanwhile; the LFOs' own knobs stay as they are.
public struct KnobView: View {

    private let parameter: Parameter
    private let model: any InstrumentModel
    private let assigning: Int?

    @State private var dragStart: Float?

    /// The room a knob takes in the panel's grid.
    public static var width: CGFloat { 92 }

    private static let sweep = 270.0          // degrees of travel
    private static let size: CGFloat = 62

    public init(parameter: Parameter, model: any InstrumentModel, assigning: Int? = nil) {
        self.parameter = parameter
        self.model = model
        self.assigning = assigning
    }

    /// The amount this knob is setting right now, if an LFO's button is on and
    /// that LFO can move the knob.
    private var amount: Parameter? { assigning.flatMap { LFOs.amount(of: parameter, lfo: $0) } }

    /// Whether the knob is out of play: an LFO's button is on and this is
    /// neither a knob it can move nor one of the LFOs' own.
    private var steppedBack: Bool { assigning != nil && amount == nil && !parameter.identifier.hasPrefix("lfo") }

    /// What a drag and a double click act on: the amount while one is being set, else the knob.
    private var edited: Parameter { amount ?? parameter }

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
                    .stroke(Artwork.accent.opacity(amount == nil ? 1 : 0.4), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                // What the LFOs sweep: an arc each, inside the ring.
                ForEach(0..<LFOs.count, id: \.self) { lfo in
                    if let moved = LFOs.amount(of: parameter, lfo: lfo), model.value(of: moved) != 0 {
                        let range = LFOs.arc(position: position, amount: Double(model.value(of: moved)))
                        arc(from: range.lowerBound, to: range.upperBound)
                            .stroke(Artwork.lfo(lfo), style: StrokeStyle(lineWidth: assigning == lfo ? 3.5 : 2.5, lineCap: .round))
                            .padding(lfo == 0 ? 4.5 : 7.5)
                    }
                }
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
            .onTapGesture(count: 2) { model.resetToDefault(edited) }
            Text(valueText)
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(amount == nil ? Color.white : Artwork.lfo(assigning ?? 0))
                .lineLimit(1)
        }
        .frame(width: Self.width)
        .opacity(steppedBack ? 0.3 : 1)
        .allowsHitTesting(!steppedBack)
        .accessibilityElement()
        .accessibilityLabel(amount?.name ?? parameter.name)
        .accessibilityValue(valueText)
    }

    /// Below the knob: its value, or the amount being set.
    private var valueText: String {
        if let amount { return LFOs.label(amount: model.value(of: amount)) }
        return parameter.label(model.value(of: parameter))
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
                let edited = edited
                let start: Float
                if let dragStart {
                    start = dragStart
                } else {
                    start = model.position(of: edited)
                    dragStart = start
                    model.beginEditing(edited)
                }
                let fine = NSEvent.modifierFlags.contains(.shift) ? 0.1 : 1.0
                var position = start - Float(value.translation.height / 200 * fine)
                if amount != nil {
                    // An amount close to nothing is nothing, so that an LFO can be taken off a knob.
                    position = edited.normalised(LFOs.snapped(amount: edited.plain(min(max(position, 0), 1))))
                }
                model.setPosition(position, of: edited)
            }
            .onEnded { _ in
                dragStart = nil
                model.endEditing(edited)
            }
    }
}
