import Foundation

enum WegramSettingsDestination: CaseIterable {
    case security, notifications, privacy, general, help, about, accounts, logout
    case appearance, textSize, language, wallpaper, wallpaperPresets, wallpaperPhoto, wallpaperCamera, media, storage, stickers, powerSaving, advanced
    case twoStepVerification, deviceManagement, securityMore
    case profileAvatar, profileName, profileUsername, profileQr, profileMore, profileBio, profilePhone

    func title(chinese: Bool) -> String {
        switch self {
        case .security: return chinese ? "账号与安全" : "Account Security"
        case .notifications: return chinese ? "新消息通知" : "Notifications"
        case .privacy: return chinese ? "隐私" : "Privacy"
        case .general: return chinese ? "通用" : "General"
        case .help: return chinese ? "帮助与反馈" : "Help & Feedback"
        case .about: return chinese ? "关于 WeGram" : "About WeGram"
        case .accounts: return chinese ? "切换账号" : "Switch Account"
        case .logout: return chinese ? "退出登录" : "Log Out"
        case .appearance: return chinese ? "深色模式" : "Dark Mode"
        case .wallpaperPresets: return chinese ? "选择背景图" : "Choose a Background"
        case .wallpaperCamera: return chinese ? "拍一张" : "Take a Photo"
        case .wallpaperPhoto: return chinese ? "从手机相册选择" : "Choose from Photos"
        case .wallpaper: return chinese ? "聊天背景" : "Chat Background"
        case .textSize: return chinese ? "字体大小" : "Text Size"
        case .language: return chinese ? "多语言" : "Language"
        case .media: return chinese ? "照片、视频、文件与通话" : "Photos, Videos, Files & Calls"
        case .storage: return chinese ? "存储空间与数据" : "Storage & Data"
        case .stickers: return chinese ? "表情与贴纸" : "Emoji & Stickers"
        case .powerSaving: return chinese ? "节能" : "Power Saving"
        case .profileAvatar: return chinese ? "头像" : "Profile Photo"
        case .profileName: return chinese ? "名字" : "Name"
        case .profileUsername: return chinese ? "微信号" : "Username"
        case .profileQr: return chinese ? "我的二维码" : "My QR Code"
        case .profileMore: return chinese ? "更多" : "More"
        case .profileBio: return chinese ? "个性签名" : "Bio"
        case .profilePhone: return chinese ? "手机号" : "Phone Number"
        case .twoStepVerification: return chinese ? "密码与二步验证" : "Password & Two-Step Verification"
        case .deviceManagement: return chinese ? "登录设备管理" : "Logged-in Devices"
        case .securityMore: return chinese ? "更多安全设置" : "More Security Settings"
        case .advanced: return chinese ? "更多设置" : "More Settings"
        }
    }
}

enum WegramSettingsPage {
    case root, general, personal, personalMore, security, wallpaper

    var isPersonal: Bool { self == .personal || self == .personalMore }

    func title(chinese: Bool) -> String {
        switch self {
        case .root: return chinese ? "设置" : "Settings"
        case .wallpaper: return chinese ? "聊天背景" : "Chat Background"
        case .general: return chinese ? "通用" : "General"
        case .security: return chinese ? "账号与安全" : "Account Security"
        case .personal: return chinese ? "个人信息" : "Personal Information"
        case .personalMore: return chinese ? "更多信息" : "More Information"
        }
    }

    var sections: [[WegramSettingsDestination]] {
        switch self {
        case .root:
            return [[.security], [.notifications, .privacy, .general], [.help, .about], [.accounts], [.logout]]
        case .general:
            return [[.appearance, .textSize, .language], [.wallpaper], [.media, .storage, .stickers, .powerSaving]]
        case .wallpaper:
            return [[.wallpaperPresets], [.wallpaperPhoto, .wallpaperCamera]]
        case .personal:
            return [[.profileAvatar, .profileName, .profileUsername, .profileQr, .profileMore]]
        case .personalMore:
            return [[.profileBio, .profilePhone]]
        case .security:
            return [[.profileUsername, .profilePhone], [.twoStepVerification], [.deviceManagement, .securityMore]]
        }
    }
}
