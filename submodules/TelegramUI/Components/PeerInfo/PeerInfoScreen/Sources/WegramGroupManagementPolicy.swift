import TelegramCore

enum WegramGroupManagementAction: Equatable {
    case administrators, permissions, requests, more
}

func wegramIsOrdinaryJoinedGroup(peer: EnginePeer?) -> Bool {
    guard let peer, !peer.isScam, !peer.isFake, !peer.isVerified else { return false }
    switch peer {
    case let .legacyGroup(group):
        return group.membership == .Member && group.migrationReference == nil
    case let .channel(channel):
        guard case .group = channel.info else { return false }
        return channel.participationStatus == .member && !channel.isForumOrMonoForum && channel.restrictionInfo == nil
    default: return false
    }
}

func wegramGroupManagementActions(peer: EnginePeer?, pendingRequests: Int = 0) -> [WegramGroupManagementAction] {
    guard let peer, wegramIsOrdinaryJoinedGroup(peer: peer) else { return [] }
    var permissions = true
    var invitations = false
    switch peer {
    case let .legacyGroup(group):
        switch group.role {
        case .member: return []
        case .creator: invitations = true
        case let .admin(rights, _): invitations = rights.rights.contains(.canInviteUsers)
        }
    case let .channel(channel):
        guard channel.flags.contains(.isCreator) || channel.adminRights != nil else { return [] }
        permissions = !channel.flags.contains(.isGigagroup)
        invitations = channel.flags.contains(.isCreator) || channel.adminRights?.rights.contains(.canInviteUsers) == true
    default: return []
    }
    return [.administrators] + (permissions ? [.permissions] : []) + (invitations && pendingRequests > 0 ? [.requests] : []) + [.more]
}
