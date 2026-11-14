/// How a press on the app's keyboard strip becomes a hit. A key has a band at
/// its lower end: a press there is the hardest hit, which overblows the note;
/// a press anywhere above it is soft at the top and firmer further down, and
/// never overblows.
public enum KeyStrip {

    /// The softest hit, at the top of a key, and the firmest one above the band.
    public static let softest = 40, firmest = 110

    /// The velocity of a press `depth` of the way down a key (0 at its top, 1 at
    /// its bottom) whose lowest `band` (a part of its height, 0 for none)
    /// overblows. `tootVelocity` is where overblowing starts (the Toot Vel
    /// knob): a press above the band stays under it.
    public static func velocity(depth: Double, band: Double, tootVelocity: Int) -> Int {
        let depth = min(max(depth, 0), 1)
        if band > 0, depth >= 1 - band { return 127 }
        let top = min(firmest, tootVelocity - 1)
        return softest + Int(Double(top - softest) * depth / (1 - band))
    }
}
