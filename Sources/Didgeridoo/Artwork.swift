import AppKit
import SwiftUI

/// The window's artwork (Resources/Art, copied into the app bundle by build.sh)
/// and its colours.
enum Artwork {

    static let background = image("background")
    static let knob = image("knob")
    static let logo = image("logo")

    /// Ochre: value arcs, the selected key, section titles.
    static let accent = Color(red: 0.86, green: 0.60, blue: 0.24)
    static let cream = Color(red: 0.94, green: 0.89, blue: 0.77)
    static let panel = Color.black.opacity(0.28)

    private static func image(_ name: String) -> NSImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Art") else { return nil }
        return NSImage(contentsOf: url)
    }
}
