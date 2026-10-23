import Foundation

enum WegramChatTitle {
    static func memberSuffix(memberCount: Int?) -> String? {
        guard let memberCount, memberCount > 0 else { return nil }
        return "(\(memberCount))"
    }
}
