import AppKit
import SwiftUI
import DidgeridooCore

/// What the knobs of the panel are for at the moment.
public enum KnobUse: Equatable, Sendable {
    /// Knobs: a drag turns them.
    case value
    /// The amounts of an LFO (0 for the first): a drag sets how far it moves the knob.
    case amount(lfo: Int)
    /// MIDI controllers: a click makes the knob take the next controller that moves.
    case controller
}

/// One parameter as a knob: its name, a value arc around the cap, the value
/// below. Drag up and down to turn it (Shift for fine steps), double-click to
/// go back to the program's value.
///
/// A knob an LFO moves shows a thin arc in that LFO's colour: the part of its
/// travel the LFO sweeps. While an LFO's button in the header is on, the knob
/// sets that LFO's amount instead of its own value: the same drag and double
/// click, the amount below. Knobs an LFO cannot move step back meanwhile; the
/// LFOs' own knobs stay as they are.
///
/// While the MIDI button is on, the knob shows its MIDI controller below. A
/// click makes it listen: the next controller that moves is its own from then
/// on. A second click calls that off. A double click gives it back the
/// controller it came with; the menu under a secondary click can also take
/// its controller away.
public struct KnobView: View {

    private let parameter: Parameter
    private let model: any InstrumentModel
    private let use: KnobUse

    @State private var dragStart: Float?

    /// The room a knob takes in the panel's grid.
    public static var width: CGFloat { 92 }

    private static let sweep = 270.0          // degrees of travel
    private static let size: CGFloat = 62

    public init(parameter: Parameter, model: any InstrumentModel, use: KnobUse = .value) {
        self.parameter = parameter
        self.model = model
        self.use = use
    }

    /// The LFO whose amounts the knobs are setting, if any.
    private var assigning: Int? {
        if case .amount(let lfo) = use { return lfo }
        return nil
    }

    /// Whether this knob is waiting for a controller to move.
    private var listening: Bool { use == .controller && model.learning == parameter }

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
            .overlay {
                // Listening for a controller: a dashed ring round the knob.
                if listening {
                    Circle().stroke(Artwork.cream, style: StrokeStyle(lineWidth: 2, dash: [4, 4])).padding(-5)
                }
            }
            .contentShape(Circle())
            .modifier(Handling(use: use, drag: drag,
                               doubleClick: { use == .controller ? model.setController(Controllers.standard(for: parameter), of: parameter)
                                                                 : model.resetToDefault(edited) },
                               click: { model.learn(listening ? nil : parameter) }))
            .contextMenu {
                if use == .controller {
                    Button("No controller") { model.setController(nil, of: parameter) }
                    if let standard = Controllers.standard(for: parameter) {
                        Button("Back to \(Controllers.label(standard))") { model.setController(standard, of: parameter) }
                    }
                }
            }
            Text(valueText)
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(use == .controller ? (listening ? Artwork.cream : Artwork.accent)
                                                    : amount == nil ? Color.white : Artwork.lfo(assigning ?? 0))
                .lineLimit(1)
        }
        .frame(width: Self.width)
        .opacity(steppedBack ? 0.3 : 1)
        .allowsHitTesting(!steppedBack)
        .accessibilityElement()
        .accessibilityLabel(amount?.name ?? parameter.name)
        .accessibilityValue(valueText)
    }

    /// Below the knob: its value, the amount being set, or its controller.
    private var valueText: String {
        if use == .controller { return listening ? "move a control" : Controllers.label(model.controller(of: parameter)) }
        if let amount { return LFOs.label(amount: model.value(of: amount)) }
        return parameter.label(model.value(of: parameter))
    }

    /// What the mouse does on the knob: a drag and a double click while it is
    /// a knob or an amount; a click and a double click while it shows its
    /// controller, when a drag would turn a knob nobody is looking at.
    private struct Handling<Drag: Gesture>: ViewModifier {
        let use: KnobUse
        let drag: Drag
        let doubleClick: () -> Void
        let click: () -> Void

        func body(content: Content) -> some View {
            if use == .controller {
                content.onTapGesture(count: 2, perform: doubleClick).onTapGesture(perform: click)
            } else {
                content.gesture(drag).onTapGesture(count: 2, perform: doubleClick)
            }
        }
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
