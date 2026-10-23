import UIKit
import TelegramPresentationData

func wegramChatListPreview(text: NSAttributedString?, author: NSAttributedString?, topic: NSAttributedString?, isDraft: Bool, mutedUnreadPrefix: String?, font: UIFont, textColor: UIColor, draftColor: UIColor) -> NSAttributedString? {
    let topicTitle = isDraft ? nil : topic?.string.components(separatedBy: .newlines).joined(separator: " ")
    let hasTopic = topicTitle?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    guard text != nil || (author?.length ?? 0) > 0 || hasTopic else { return nil }
    let result = NSMutableAttributedString()
    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor]
    if let mutedUnreadPrefix { result.append(NSAttributedString(string: mutedUnreadPrefix, attributes: attributes)) }
    if hasTopic, let topicTitle {
        result.append(NSAttributedString(string: "[" + topicTitle + "] ", attributes: attributes))
    }
    if let author, author.length > 0 {
        result.append(NSAttributedString(string: author.string + ": ", attributes: [.font: font, .foregroundColor: isDraft ? draftColor : textColor]))
    }
    if let text { result.append(text) }
    return result
}

func chatListForumPreview(text: NSAttributedString?, author: NSAttributedString?, keepsAuthorSeparate: Bool, font: UIFont, textColor: UIColor) -> (text: NSAttributedString?, author: NSAttributedString?) {
    if keepsAuthorSeparate { return (text, author) }
    guard let author, let text else { return (text, nil) }
    let result = NSMutableAttributedString(string: author.string + ": ", attributes: [.font: font, .foregroundColor: textColor])
    result.append(text)
    return (result, nil)
}

/// WeChat's name for the archive: its chat-list row and its page title (IMG_2440, IMG_2441).
func wegramFoldedChatsTitle(_ strings: PresentationStrings) -> String {
    let code = strings.primaryComponent.languageCode
    return code.hasPrefix("zh") ? "折叠的聊天" : (code.hasPrefix("en") ? "Folded Chats" : strings.ChatList_ArchivedChatsTitle)
}
