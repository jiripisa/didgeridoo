import CoreMIDI
import DidgeridooCore
import os

/// A MIDI source on this Mac: a keyboard, a controller, another app's output.
struct MIDISource: Identifiable, Hashable {
    /// CoreMIDI's unique ID: stable across restarts, so the settings remember it.
    let id: Int32
    let name: String
}

/// Which sources the app listens to.
enum MIDISourceChoice: Hashable {
    case all
    case none
    case source(Int32)

    /// Stored form: "all", "none" or the unique ID.
    init(storedValue: String?) {
        switch storedValue {
        case "none": self = .none
        case let value? where Int32(value) != nil: self = .source(Int32(value)!)
        default: self = .all
        }
    }

    var storedValue: String {
        switch self {
        case .all: "all"
        case .none: "none"
        case .source(let id): String(id)
        }
    }
}

/// Feeds MIDI to the synth from the chosen sources and from the app's own
/// virtual port "Didgeridoo", which other applications can send to.
/// CoreMIDI calls back on its own thread, hence the lock around the filter.
final class MIDIInput: @unchecked Sendable {

    private let synth: Synth
    private var client = MIDIClientRef()
    private var port = MIDIPortRef()
    private var destination = MIDIEndpointRef()
    private var connected: [MIDIEndpointRef] = []
    private let filter = OSAllocatedUnfairLock(initialState: MIDIChannelFilter.omni)

    /// Called on the main thread when devices are plugged in or removed.
    var onSourcesChanged: (@MainActor @Sendable () -> Void)?

    init(synth: Synth) {
        self.synth = synth
        MIDIClientCreateWithBlock("Didgeridoo" as CFString, &client) { [weak self] notification in
            guard notification.pointee.messageID == .msgSetupChanged, let self else { return }
            let changed = self.onSourcesChanged
            Task { @MainActor in changed?() }
        }
        MIDIInputPortCreateWithProtocol(client, "Input" as CFString, ._1_0, &port) { [weak self] list, _ in
            self?.receive(list)
        }
        MIDIDestinationCreateWithProtocol(client, "Didgeridoo" as CFString, ._1_0, &destination) { [weak self] list, _ in
            self?.receive(list)
        }
    }

    var channelFilter: MIDIChannelFilter {
        get { filter.withLock { $0 } }
        set { filter.withLock { $0 = newValue } }
    }

    /// Listens to the chosen sources only. Hanging notes are released, because
    /// their note-offs may never arrive from a source that was just dropped.
    func listen(to choice: MIDISourceChoice) {
        for endpoint in connected { MIDIPortDisconnectSource(port, endpoint) }
        connected.removeAll()
        synth.allNotesOff()
        for index in 0..<MIDIGetNumberOfSources() {
            let endpoint = MIDIGetSource(index)
            let wanted: Bool
            switch choice {
            case .all: wanted = true
            case .none: wanted = false
            case .source(let id): wanted = Self.uniqueID(of: endpoint) == id
            }
            if wanted, MIDIPortConnectSource(port, endpoint, nil) == noErr {
                connected.append(endpoint)
            }
        }
    }

    static func sources() -> [MIDISource] {
        (0..<MIDIGetNumberOfSources()).map { index in
            let endpoint = MIDIGetSource(index)
            return MIDISource(id: uniqueID(of: endpoint), name: name(of: endpoint))
        }
    }

    private static func uniqueID(of endpoint: MIDIEndpointRef) -> Int32 {
        var id: Int32 = 0
        MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &id)
        return id
    }

    private static func name(of endpoint: MIDIEndpointRef) -> String {
        var value: Unmanaged<CFString>?
        guard MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &value) == noErr, let value else {
            return "MIDI source"
        }
        return value.takeRetainedValue() as String
    }

    /// MIDI 1.0 channel-voice messages arrive as Universal MIDI Packets of
    /// type 2, one 32-bit word each: 0x2G SS D1 D2.
    private func receive(_ list: UnsafePointer<MIDIEventList>) {
        let accepted = channelFilter
        for packet in list.unsafeSequence() {
            let count = Int(packet.pointee.wordCount)
            let words = UnsafeRawPointer(packet)
                .advanced(by: MemoryLayout<MIDIEventPacket>.offset(of: \.words)!)
                .assumingMemoryBound(to: UInt32.self)
            var index = 0
            while index < count {
                let word = words[index]
                let type = word >> 28
                if type == 2 {
                    let status = UInt8((word >> 16) & 0xFF)
                    if accepted.accepts(status: status) {
                        synth.postMIDI(status: status, data1: UInt8((word >> 8) & 0x7F), data2: UInt8(word & 0x7F))
                    }
                }
                index += type == 5 ? 4 : (type == 3 || type == 4) ? 2 : 1
            }
        }
    }
}
