load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_application")

swift_library(
    name = "SettingsTestHostLib",
    srcs = [
        "SettingsTestHost.swift",
        "//submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen:Sources/WegramDarkModeContentView.swift",
    ],
    deps = ["//submodules/TelegramUIPreferences", "//submodules/Display"],
    testonly = True,
)

ios_application(
    name = "WegramSettingsTestHost",
    bundle_id = "app.wegram.settingstesthost",
    families = ["iphone", "ipad"],
    minimum_os_version = "15.0",
    infoplists = ["Info.plist"],
    deps = [":SettingsTestHostLib"],
    testonly = True,
)
