load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

exports_files(
    ["Sources/WegramCallFilterTitleView.swift", "Sources/WegramCallRowLayout.swift", "Sources/WegramGroupCallRowLayout.swift", "Sources/WegramCallDetailsView.swift", "Sources/WegramCallDetailsRecordsNode.swift"],
    visibility = ["//submodules/TelegramPresentationData:__pkg__"],
)

swift_library(
    name = "CallListUI",
    module_name = "CallListUI",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/LottieSettings:LottieSettings",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/AccountContext:AccountContext",
        "//submodules/ItemListUI:ItemListUI",
        "//submodules/PeerInfoUI",
        "//submodules/AvatarNode:AvatarNode",
        "//submodules/TelegramStringFormatting:TelegramStringFormatting",
        "//submodules/AlertUI:AlertUI",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/TelegramNotices:TelegramNotices",
        "//submodules/MergeLists:MergeLists",
        "//submodules/ChatListSearchItemHeader:ChatListSearchItemHeader",
        "//submodules/PeerOnlineMarkerNode:PeerOnlineMarkerNode",
        "//submodules/ContextUI:ContextUI",
        "//submodules/TelegramBaseController:TelegramBaseController",
        "//submodules/AnimatedStickerNode:AnimatedStickerNode",
        "//submodules/TelegramAnimatedStickerNode:TelegramAnimatedStickerNode",
        "//submodules/ItemListPeerActionItem",
        "//submodules/InviteLinksUI",
        "//submodules/UndoUI",
        "//submodules/TelegramCallsUI",
        "//submodules/TelegramUI/Components/EdgeEffect",
        "//submodules/ComponentFlow",
        "//submodules/Components/ComponentDisplayAdapters",
    ],
    visibility = [
        "//visibility:public",
    ],
)
