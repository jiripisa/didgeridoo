/// How a press on the app's keyboard strip becomes a hit: soft at the top of
/// a key, firmer further down, the hardest hit at its bottom.
public enum KeyStrip {

    /// The softest hit, at the top of a key, and the hardest, at its bottom.
    public static let softest = 40, hardest = 127

    /// The velocity of a press `depth` of the way down a key (0 at its top, 1 at
    /// its bottom).
    public static func velocity(depth: Double) -> Int {
        softest + Int((Double(hardest - softest) * min(max(depth, 0), 1)).rounded())
    }
}
