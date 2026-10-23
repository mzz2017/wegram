public enum WegramStoryInteraction: Equatable {
    case like
    case unlike
    case reply
}

public struct WegramStoryInteractionTarget: Hashable {
    public let peerId: Int64
    public let storyId: Int32
    public init(peerId: Int64, storyId: Int32) {
        self.peerId = peerId
        self.storyId = storyId
    }
    public func matches(_ current: Self, expiration: Int32, expired: Bool, now: Int64) -> Bool {
        self == current && !expired && Int64(expiration) > now
    }
}

public struct WegramStoryInteractionRequest {
    public let target: WegramStoryInteractionTarget
    public private(set) var action: WegramStoryInteraction?
    public init(target: WegramStoryInteractionTarget, action: WegramStoryInteraction) {
        self.target = target
        self.action = action
    }
    public mutating func cancel() { self.action = nil }
    public mutating func take(current: WegramStoryInteractionTarget, expiration: Int32, expired: Bool, now: Int64, visible: Bool, ready: Bool, interacting: Bool) -> WegramStoryInteraction? {
        if interacting { self.cancel(); return nil }
        guard visible, ready else { return nil }
        guard self.target.matches(current, expiration: expiration, expired: expired, now: now) else { self.cancel(); return nil }
        let result = self.action
        self.cancel()
        return result
    }
}
