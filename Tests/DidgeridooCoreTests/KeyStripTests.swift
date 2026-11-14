import Testing
@testable import DidgeridooCore

/// How a press on the app's keyboard strip becomes a hit.
@Suite("Key strip")
struct KeyStripTests {

    @Test("A press is soft at the top of a key and the hardest hit at its bottom")
    func topToBottom() {
        #expect(KeyStrip.velocity(depth: 0) == 40)
        #expect(KeyStrip.velocity(depth: 1) == 127)
    }

    @Test("Further down is firmer, all the way")
    func deeperIsFirmer() {
        let velocities = (0...100).map { KeyStrip.velocity(depth: Double($0) / 100) }
        #expect(velocities == velocities.sorted())
        #expect(Set(velocities).count > 60)             // no flat stretch, no jump: the band that overblew is gone
        #expect(zip(velocities, velocities.dropFirst()).allSatisfy { $1 - $0 <= 2 })
    }

    @Test("A press dragged off the key counts as the key's nearest edge")
    func outsideTheKey() {
        #expect(KeyStrip.velocity(depth: -0.4) == 40)
        #expect(KeyStrip.velocity(depth: 1.7) == 127)
    }
}
