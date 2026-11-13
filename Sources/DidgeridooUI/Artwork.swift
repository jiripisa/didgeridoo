import AppKit
import SwiftUI

/// The panel's artwork (Resources/Art, copied into the bundle by build.sh) and
/// its colours.
@MainActor
public enum Artwork {

    /// The bundle that holds the artwork: the app, or the plug-in when the
    /// panel is shown in a host, where `Bundle.main` is the host's. Set it
    /// before the first panel is made.
    public static var bundle = Bundle.main

    public static let background = image("background")
    public static let knob = image("knob")
    public static let logo = image("logo")

    /// Ochre: value arcs, the selected key, section titles.
    public static let accent = Color(red: 0.86, green: 0.60, blue: 0.24)
    public static let cream = Color(red: 0.94, green: 0.89, blue: 0.77)
    public static let panel = Color.black.opacity(0.28)

    private static func image(_ name: String) -> NSImage? {
        guard let url = bundle.url(forResource: name, withExtension: "png", subdirectory: "Art") else { return nil }
        return NSImage(contentsOf: url)
    }
}

public extension View {
    /// The dark wood behind the panel, covering the view's whole frame.
    func instrumentBackground() -> some View {
        background {
            if let background = Artwork.background {
                Image(nsImage: background).resizable().scaledToFill()
            } else {
                Color(red: 0.11, green: 0.08, blue: 0.06)
            }
        }
        .clipped()
        .preferredColorScheme(.dark)
    }
}
