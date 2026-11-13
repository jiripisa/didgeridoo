import AppKit
import AudioToolbox
import AudioToolbox.AUCocoaUIView
import SwiftUI
import DidgeridooUI

/// The plug-in's window in a host: the instrument's panel without the app's
/// tempo, settings and keyboard, which a host has of its own.
struct AudioUnitWindow: View {

    let model: AudioUnitModel

    var body: some View {
        InstrumentPanel(model: model)
            .frame(width: InstrumentPanel<EmptyView, EmptyView>.width)
            .fixedSize()                    // as tall as the knobs need
            .instrumentBackground()
            .task {
                // Follow the host: its automation and its own controls move parameters
                // without telling a view. Ends when the window goes away.
                while !Task.isCancelled {
                    model.refresh()
                    try? await Task.sleep(for: .milliseconds(40))
                }
            }
    }
}

/// The class a host asks for the plug-in's window. The Audio Unit names it,
/// and the bundle it lives in, in its `kAudioUnitProperty_CocoaUI` property
/// (DidgeridooAU.cpp); the name must stay in step with `DIDGERIDOO_AU_VIEW_CLASS`.
@objc(DidgeridooAUViewFactory)
@MainActor
public final class DidgeridooAUViewFactory: NSObject, @preconcurrency AUCocoaUIBase {

    public func interfaceVersion() -> UInt32 { 0 }

    public func uiView(forAudioUnit unit: AudioUnit, with preferredSize: NSSize) -> NSView? {
        Artwork.bundle = Bundle(for: DidgeridooAUViewFactory.self)      // the component, not the host
        let view = NSHostingView(rootView: AudioUnitWindow(model: AudioUnitModel(unit: unit)))
        view.frame = NSRect(origin: .zero, size: view.fittingSize)      // a host shows the view at the size it comes in
        return view
    }
}
