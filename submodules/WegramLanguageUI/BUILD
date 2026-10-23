load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "WegramLanguageUI",
    module_name = "WegramLanguageUI",
    srcs = glob(["Sources/**/*.swift"]),
    copts = ["-warnings-as-errors"],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/TelegramCore",
    ],
    visibility = ["//visibility:public"],
)
