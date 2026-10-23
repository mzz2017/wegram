load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_application")

swift_library(
    name = "QrTestHostLib",
    srcs = ["QrTestHost.swift"],
    deps = ["//submodules/Display", "//submodules/QrCode"],
    testonly = True,
)

ios_application(
    name = "WegramQrTestHost",
    bundle_id = "app.wegram.qrtesthost",
    families = ["iphone", "ipad"],
    minimum_os_version = "15.0",
    infoplists = ["Info.plist"],
    deps = [":QrTestHostLib"],
    resources = ["//submodules/TelegramUI:TelegramUIAssets"],
    testonly = True,
    visibility = ["//submodules/TelegramPresentationData:__pkg__", "//submodules/ChatListUI:__pkg__"],
)
