import Foundation

@main
struct ChatTitleTests {
    static func main() {
        precondition(WegramChatTitle.memberSuffix(memberCount: 4) == "(4)", "Group count must use the reference parentheses")
        precondition(WegramChatTitle.memberSuffix(memberCount: 12345) == "(12345)", "Group count must not be silently rounded")
        for count: Int? in [nil, 0, -1] {
            precondition(WegramChatTitle.memberSuffix(memberCount: count) == nil, "Unknown/invalid counts must not be invented")
        }
        print("Chat title member-count checks passed")
    }
}
