import Display
import SwiftSignalKit
import TelegramPresentationData
import PresentationDataUtils

enum WegramGroupSettingsAction: Equatable {
    case call, appearance, fullDetails
}

func wegramGroupSettingsMenu(updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>), canCall: Bool, canChangeAppearance: Bool, selected: @escaping (WegramGroupSettingsAction) -> Void) -> ActionSheetController {
    let data = updatedPresentationData.initial
    let chinese = data.strings.baseLanguageCode.hasPrefix("zh")
    var entries: [(String, WegramGroupSettingsAction)] = []
    if canCall { entries.append((chinese ? "群通话" : "Group Call", .call)) }
    if canChangeAppearance { entries.append((chinese ? "群外观与聊天背景" : "Group Appearance and Wallpaper", .appearance)) }
    entries.append((chinese ? "完整群聊资料" : "Full Group Info", .fullDetails))
    return wegramConfirmationController(updatedPresentationData: updatedPresentationData, title: "", text: canChangeAppearance ? (chinese ? "群外观更改对所有成员生效。" : "Group appearance changes apply to all members.") : "", cancelTitle: data.strings.Common_Cancel, styledActions: entries.map { title, action in
        (title: title, color: .accent, action: { selected(action) })
    })
}
