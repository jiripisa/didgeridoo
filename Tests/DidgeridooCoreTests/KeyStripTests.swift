import Testing
@testable import DidgeridooCore

/// How a press on the app's keyboard strip becomes a hit: only the band at a
/// key's lower end overblows.
@Suite("Key strip")
struct KeyStripTests {

    /// The band's part of a key's height in these tests.
    private static let band = 0.16

    @Test("A press in the band is the hardest hit, wherever Toot Vel stands")
    func bandIsTheHardestHit() {
        for tootVelocity in 64...128 {
            #expect(KeyStrip.velocity(depth: 0.85, band: Self.band, tootVelocity: tootVelocity) == 127)
            #expect(KeyStrip.velocity(depth: 1, band: Self.band, tootVelocity: tootVelocity) == 127)
        }
    }

    @Test("A press above the band stays under Toot Vel, so it never overblows")
    func aboveTheBandNeverOverblows() {
        for tootVelocity in 64...128 {
            for step in 0...83 {
                #expect(KeyStrip.velocity(depth: Double(step) / 100, band: Self.band, tootVelocity: tootVelocity) < tootVelocity)
            }
        }
    }

    @Test("Above the band a press is soft at the top and firmer further down")
    func deeperIsFirmer() {
        let velocities = (0...83).map { KeyStrip.velocity(depth: Double($0) / 100, band: Self.band, tootVelocity: 115) }
        #expect(velocities.first == 40)
        #expect(velocities == velocities.sorted())
        #expect((105...110).contains(velocities[83]))          // just above the band: a firm hit
        // A low Toot Vel leaves less room, and the press still uses all of it.
        #expect((75...79).contains(KeyStrip.velocity(depth: 0.83, band: Self.band, tootVelocity: 80)))
        #expect(KeyStrip.velocity(depth: 0, band: Self.band, tootVelocity: 80) == 40)
    }

    @Test("A key without a band is soft to firm over its whole height")
    func keyWithoutABand() {
        #expect(KeyStrip.velocity(depth: 0, band: 0, tootVelocity: 128) == 40)
        #expect(KeyStrip.velocity(depth: 1, band: 0, tootVelocity: 128) == 110)
    }

    @Test("A press dragged off the key counts as the key's nearest edge")
    func outsideTheKey() {
        #expect(KeyStrip.velocity(depth: -0.4, band: Self.band, tootVelocity: 115) == 40)
        #expect(KeyStrip.velocity(depth: 1.7, band: Self.band, tootVelocity: 115) == 127)
    }
}
