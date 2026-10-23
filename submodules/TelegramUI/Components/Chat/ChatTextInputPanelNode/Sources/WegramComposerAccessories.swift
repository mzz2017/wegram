import TelegramCore
import ChatInterfaceState
import AccountContext
import ChatPresentationInterfaceState
import TelegramPresentationData
import TelegramStringFormatting

public enum WegramComposerShortcut: Equatable {
    case stopIncomingStreamingMessage
    case accessory(ChatTextInputAccessoryItem)
    case sendAs
    case boostToUnrestrict(Int32)
    case recordingDelete(ChatInterfaceMediaDraftState)
    case recordingResume(ChatInterfaceMediaDraftState)
    case recordingViewOnce(ChatInterfaceMediaDraftState, Bool)
    case editMedia
    case botMenu(BotMenuButton, showCommands: Bool)
}

func wegramComposerShortcutActions(_ items: [ChatTextInputAccessoryItem], hasScheduledMessages: Bool, isTextEmpty: Bool, hasSendAsPeers: Bool, editMessageState: ChatEditInterfaceMessageState? = nil, botMenuButton: BotMenuButton? = nil, showBotCommands: Bool = false, slowmodeState: ChatSlowmodeState? = nil, boostsToUnrestrict: Int32? = nil, secretChat: TelegramSecretChat? = nil, subject: ChatControllerSubject? = nil, canStopIncomingStreamingMessage: Bool = false) -> [WegramComposerShortcut] {
    var effectiveItems = items
    if let secretChat, wegramComposerSupportsSecretChat(secretChat) {
        effectiveItems.removeAll { $0.key == .messageAutoremoveTimeout }
        effectiveItems.append(.messageAutoremoveTimeout(secretChat.messageAutoremoveTimeout))
    }
    var actions: [WegramComposerShortcut] = canStopIncomingStreamingMessage ? [.stopIncomingStreamingMessage] : []
    if let editMessageState {
        actions.append(contentsOf: effectiveItems.compactMap { item in
            if case .messageAutoremoveTimeout = item { return .accessory(item) }
            return nil
        })
        switch editMessageState.content {
        case .plaintext: actions.append(.editMedia)
        case let .media(options):
            if !options.isEmpty { actions.append(.editMedia) }
        }
        return actions
    }
    actions.append(contentsOf: wegramComposerShortcutItems(effectiveItems, hasScheduledMessages: hasScheduledMessages && subject != .scheduledMessages, isTextEmpty: isTextEmpty).map(WegramComposerShortcut.accessory))
    if subject != .scheduledMessages, slowmodeState != nil, let boostsToUnrestrict, boostsToUnrestrict > 0 { actions.append(.boostToUnrestrict(boostsToUnrestrict)) }
    if hasSendAsPeers { actions.append(.sendAs) }
    if let botMenuButton { actions.append(.botMenu(botMenuButton, showCommands: showBotCommands)) }
    return actions
}

func wegramComposerSupportsSubject(_ subject: ChatControllerSubject?) -> Bool {
    switch subject {
    case nil, .message, .scheduledMessages: return true
    default: return false
    }
}

func wegramComposerSupportsSecretChat(_ chat: TelegramSecretChat?) -> Bool {
    guard let chat else { return true }
    switch chat.embeddedState {
    case .active: return true
    case .handshake, .terminated: return false
    }
}

func wegramComposerSupportsAccessoryItems(_ items: [ChatTextInputAccessoryItem]) -> Bool {
    var keys = Set<ChatTextInputAccessoryItem.Key>()
    for item in items {
        guard keys.insert(item.key).inserted else { return false }
        switch item {
        case .input, .scheduledMessages, .messageAutoremoveTimeout, .gift, .commands, .botInput(_, .bot), .silentPost, .suggestPost:
            break
        case .botInput(_, .keyboard):
            guard items.count == 1 else { return false }
        default:
            return false
        }
    }
    return wegramComposerPrimaryInputItem(items) != nil
}

func wegramComposerPrimaryInputItem(_ items: [ChatTextInputAccessoryItem]) -> ChatTextInputAccessoryItem? {
    for item in items { if case .input = item { return item } }
    if items.count == 1, case .botInput(_, .keyboard) = items[0] { return items[0] }
    return nil
}

func wegramComposerShortcutItems(_ items: [ChatTextInputAccessoryItem], hasScheduledMessages: Bool, isTextEmpty: Bool) -> [ChatTextInputAccessoryItem] {
    var result = items.filter { item in
        switch item {
        case .messageAutoremoveTimeout, .gift, .suggestPost: return true
        case .commands, .botInput(_, .bot), .silentPost: return isTextEmpty
        case .scheduledMessages: return hasScheduledMessages
        default: return false
        }
    }
    if hasScheduledMessages && !result.contains(where: { $0.key == .scheduledMessages }) {
        result.append(.scheduledMessages)
    }
    return result
}

func wegramComposerShortcutTitle(_ item: ChatTextInputAccessoryItem, strings: PresentationStrings, isSelfChat: Bool) -> String? {
    switch item {
    case .scheduledMessages:
        return isSelfChat ? strings.ScheduledMessages_RemindersTitle : strings.ScheduledMessages_Title
    case let .messageAutoremoveTimeout(timeout):
        if let timeout {
            return strings.VoiceOver_SelfDestructTimerOn(timeIntervalString(strings: strings, value: timeout)).string
        }
        return strings.VoiceOver_SelfDestructTimerOff
    case let .silentPost(value):
        return value ? strings.VoiceOver_SilentPostOn : strings.VoiceOver_SilentPostOff
    case .suggestPost:
        return strings.VoiceOver_SuggestPost
    case .gift:
        return strings.VoiceOver_GiftPremium
    case .commands:
        return strings.VoiceOver_BotCommands
    case .botInput(_, .bot):
        return strings.VoiceOver_BotKeyboard
    default:
        return nil
    }
}

func wegramRecordingShortcuts(_ draft: ChatInterfaceMediaDraftState?, canViewOnce: Bool, viewOnce: Bool) -> [WegramComposerShortcut] {
    guard let draft else { return [] }
    var result: [WegramComposerShortcut] = []
    if case .audio = draft {
        result.append(.recordingResume(draft))
        if canViewOnce { result.append(.recordingViewOnce(draft, viewOnce)) }
    }
    result.append(.recordingDelete(draft))
    return result
}
