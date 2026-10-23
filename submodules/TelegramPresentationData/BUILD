load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "TelegramPresentationData",
    module_name = "TelegramPresentationData",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/Postbox:Postbox",
        "//submodules/Display:Display",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/MediaResources:MediaResources",
        "//submodules/AppBundle:AppBundle",
        "//submodules/StringPluralization:StringPluralization",
        "//submodules/Sunrise:Sunrise",
        "//submodules/TinyThumbnail:TinyThumbnail",
        "//submodules/FastBlur:FastBlur",
        "//Telegram:PresentationStrings",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "WegramBubbleImageTestsLib",
    testonly = True,
    srcs = ["Tests/WegramBubbleImageTests.swift"],
    deps = [":TelegramPresentationData"],
)

ios_test_runner(
    name = "WegramBubbleImageTestRunner",
    device_type = "iPhone 17 Pro",
    os_version = "27.0",
)

ios_unit_test(
    name = "WegramBubbleImageTests",
    minimum_os_version = "15.0",
    runner = ":WegramBubbleImageTestRunner",
    deps = [":WegramBubbleImageTestsLib"],
    visibility = ["//visibility:public"],
)

swift_library(
    name = "WegramNavigationBadgeTestsLib",
    testonly = True,
    srcs = [
        "Tests/WegramNavigationBadgeTests.swift",
        "Tests/WegramNavigationActionTests.swift",
        "Tests/WegramAdminGridTests.swift",
        "//submodules/PeerInfoUI:Sources/WegramAdminGridView.swift",
        "Tests/WegramAvatarSaveTests.swift",
        "Tests/WegramScannerControlsTests.swift",
        "//submodules/QrCodeUI:Sources/WegramScannerControls.swift",
        "//submodules/SaveToCameraRoll:Sources/CameraRollSaveResult.swift",
        "//submodules/SaveToCameraRoll:Sources/CameraRollImageData.swift",
        "Tests/WegramSearchFieldTests.swift",
        "Tests/WegramAboutContentTests.swift",
        "Tests/WegramSettingsCellTests.swift",
        "Tests/WegramMeViewTests.swift",
        "Tests/WegramNameContentTests.swift",
        "Tests/WegramBioContentTests.swift",
        "Tests/WegramGroupDescriptionTests.swift",
        "//submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen:Sources/WegramGroupDescriptionView.swift",
        "Tests/WegramTextSizeTests.swift",
        "Tests/WegramLanguageTests.swift",
        "Tests/WegramDarkModeTests.swift",
        "Tests/WegramNotificationsTests.swift",
        "Tests/WegramAccountsTests.swift",
        "Tests/WegramPrivacyTests.swift",
        "Tests/WegramBlockedTests.swift",
        "Tests/WegramStorageTests.swift",
        "Tests/WegramMediaSettingsTests.swift",
        "Tests/WegramDownloadCategoryTests.swift",
        "Tests/WegramAutoSaveContentTests.swift",
        "Tests/WegramMomentsHeaderTests.swift",
        "Tests/WegramMomentsCoverTests.swift",
        "//submodules/TelegramUI:Sources/WegramMomentsCoverStore.swift",
        "Tests/WegramMomentCellTests.swift",
        "Tests/WegramMomentInteractionTests.swift",
        "Tests/WegramContactContentTests.swift",
        "Tests/WegramGroupContentTests.swift",
        "Tests/WegramGroupManagementTests.swift",
        "Tests/WegramGroupSettingsMenuTests.swift",
        "//submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen:Sources/WegramGroupSettingsMenu.swift",
        "//submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen:Sources/WegramGroupManagementPolicy.swift",
        "//submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen:Sources/WegramGroupManagementView.swift",
        "//submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen:Sources/WegramGroupContentView.swift",
        "Tests/WegramCallFilterTests.swift",
        "Tests/WegramCallRowTests.swift",
        "Tests/WegramCallDetailsViewTests.swift",
        "//submodules/CallListUI:Sources/WegramCallDetailsView.swift",
        "//submodules/CallListUI:Sources/WegramCallDetailsRecordsNode.swift",
        "Tests/WegramCallDetailsRecordsTests.swift",
        "Tests/WegramGroupCallRowTests.swift",
        "Tests/WegramReplyWidthTests.swift",
        "Tests/WegramStickerLayoutTests.swift",
        "Tests/WegramReplyInteractionTests.swift",
        "Tests/WegramPhoneFieldsTests.swift",
        "Tests/WegramWelcomeTests.swift",
        "Tests/WegramAuthorizationLanguageTests.swift",
        "Tests/WegramCodeInputTests.swift",
        "Tests/WegramCodeEntryPageTests.swift",
        "Tests/WegramPasswordEntryPageTests.swift",
        "Tests/WegramEmailEntryPageTests.swift",
        "Tests/WegramSignUpPageTests.swift",
        "Tests/WegramResetWaitPageTests.swift",
        "Tests/WegramAuthorizationConfirmationTests.swift",
        "//submodules/AuthorizationUI:Sources/WegramPhoneFieldsLayout.swift",
        "Tests/WegramMessageDateNodeTests.swift",
        "Tests/WegramMessageTimeZoneTests.swift",
        "Tests/WegramUnreadSeparatorTests.swift",
        "Tests/WegramComposerMediaPreviewTests.swift",
        "Tests/WegramComposerReplyAccessibilityTests.swift",
        "Tests/WegramFolderMenuStateTests.swift",
        "Tests/WegramComposerAccessoriesTests.swift",
        "Tests/WegramInlinePlaceholderTests.swift",
        "Tests/WegramPaidSendLabelTests.swift",
        "Tests/WegramRecordingShortcutsTests.swift",
        "Tests/WegramMessageSelectionTests.swift",
        "Tests/WegramMessageSelectionNodeTests.swift",
        "Tests/WegramSelectionNavigationTests.swift",
        "Tests/WegramCleanupSheetTests.swift",
        "Tests/WegramMessageMenuTests.swift",
        "Tests/WegramVoiceMessageLayoutTests.swift",
        "Tests/WegramLinkPreviewLayoutTests.swift",
        "Tests/WegramFileMessageLayoutTests.swift",
        "Tests/WegramContactMessageLayoutTests.swift",
        "Tests/WegramMapMessageLayoutTests.swift",
        "Tests/WegramLocationPickerSelectionTests.swift",
        "Tests/WegramLocationControlsTests.swift",
        "//submodules/LocationUI:Sources/WegramLocationControls.swift",
        "Tests/WegramVenueRowLayoutTests.swift",
        "//submodules/LocationUI:Sources/WegramLocationPickerSelection.swift",
        "Tests/WegramMessageDeletionTests.swift",
        "//submodules/TelegramUI:Sources/ChatInterfaceStateNavigationButtons.swift",
        "//submodules/TelegramUI/Components/Chat/ChatMessageSelectionInputPanelNode:Sources/WegramMessageSelectionBar.swift",
        "//submodules/TelegramUI/Components/Chat/ChatTextInputActionButtonsNode:Sources/WegramPaidSendLabel.swift",
        "//submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode:Sources/WegramInlinePlaceholder.swift",
        "Tests/WegramAttachmentPagingTests.swift",
        "Tests/WegramVoiceInputTests.swift",
        "Tests/WegramSavedConfirmationTests.swift",
        "Tests/WegramSavedCardTests.swift",
        "//submodules/TelegramUI:Sources/WegramSavedAttachmentCardView.swift",
        "//submodules/TelegramUI:Sources/WegramSavedConfirmationView.swift",
        "//submodules/TelegramUI:Sources/WegramAttachmentInputNode.swift",
        "//submodules/TelegramUI:Sources/WegramVoiceInputView.swift",
        "//submodules/TelegramUI:Sources/WegramAttachmentLayout.swift",
        "//submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode:Sources/WegramComposerAccessories.swift",
        "//submodules/TelegramUI/Components/ContextControllerImpl:Sources/ContextActionNode.swift",
        "//submodules/TelegramUI/Components/Chat/ChatInputMessageAccessoryPanel:Sources/WegramComposerReplyAccessibility.swift",
        "//submodules/TelegramUI/Components/Chat/ChatInputMessageAccessoryPanel:Sources/WegramComposerMediaPreview.swift",
        "Tests/WegramWallpaperPhotoTests.swift",
        "Tests/WegramShortcutMenuTests.swift",
        "Tests/WegramPhotoToolbarTests.swift",
        "//submodules/MediaPickerUI:Sources/WegramPhotoToolbarDoneContent.swift",
        "//submodules/AttachmentUI:Sources/WegramPhotoToolbarView.swift",
        "//submodules/ChatListUI:Sources/WegramShortcutMenuView.swift",
        "//submodules/TelegramUI/Components/Settings/WallpaperGalleryScreen:Sources/WallpaperCropNode.swift",
        "//submodules/TelegramUI/Components/Settings/WallpaperGalleryScreen:Sources/WegramWallpaperPhoto.swift",
        "//submodules/TelegramUI/Components/Settings/WallpaperGalleryScreen:Sources/WegramWallpaperCropController.swift",
        "//submodules/CallListUI:Sources/WegramGroupCallRowLayout.swift",
        "//submodules/CallListUI:Sources/WegramCallRowLayout.swift",
        "//submodules/CallListUI:Sources/WegramCallFilterTitleView.swift",
        "//submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen:Sources/WegramContactContentView.swift",
        "//submodules/TelegramUI:Sources/WegramMomentActionsOverlay.swift",
        "//submodules/TelegramUI:Sources/WegramMomentCell.swift",
        "//submodules/TelegramUI:Sources/WegramMomentsHeaderView.swift",
        "Tests/WegramAutoSaveExceptionsTests.swift",
        "//submodules/SettingsUI:Sources/Data and Storage/WegramAutoSaveExceptionsContentView.swift",
        "//submodules/SettingsUI:Sources/Data and Storage/WegramDownloadCategoryContentView.swift",
        "//submodules/SettingsUI:Sources/Data and Storage/AutodownloadSizeMapping.swift",
        "//submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen:Sources/WegramMediaSettingsContentView.swift",
        "//submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen:Sources/WegramStorageContentView.swift",
        "//submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen:Sources/WegramBlockedContentView.swift",
        "//submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen:Sources/WegramPrivacyContentView.swift",
        "//submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen:Sources/WegramAccountsContentView.swift",
        "//submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen:Sources/WegramNotificationsContentView.swift",
        "Tests/WegramDevicesTests.swift",
        "//submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen:Sources/WegramDevicesContentView.swift",
        "//submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen:Sources/WegramDarkModeContentView.swift",
        "//submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen:Sources/WegramTextSizeContentView.swift",
        "Tests/WegramQrCardTests.swift",
        "Tests/WegramSearchSectionTests.swift",
        "//submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen:Sources/WegramAboutContentView.swift",
        "//submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen:Sources/WegramSettingsCell.swift",
        "//submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen:Sources/WegramMeContentView.swift",
        "//submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen:Sources/WegramNameContentView.swift",
        "//submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen:Sources/WegramBioContentView.swift",
        "//submodules/TelegramUI/Components/Chat/ChatQrCodeScreen:Sources/WegramQrCardView.swift",
        "//submodules/PeerAvatarGalleryUI:Sources/WegramAvatarGalleryHeader.swift",
    ],
    deps = ["//submodules/TelegramUI/Components/PlainButtonComponent", "//submodules/Components/BundleIconComponent", "//submodules/TelegramUI/Components/TabBarComponent", "//submodules/ComponentFlow", "//submodules/ItemListVenueItem", "//submodules/TelegramUI/Components/Chat/ChatHistoryEntry", "//submodules/WegramLanguageUI", "//submodules/AccountContext", "//submodules/PeerInfoUI", "//submodules/ItemListUI", "//submodules/Postbox", "//submodules/SolidRoundedButtonNode", "//submodules/AuthorizationUI", "//submodules/CodeInputView", "//submodules/PhoneInputNode", "//submodules/TelegramUI/Components/Chat/ChatMessageReplyInfoNode", "//submodules/TelegramUI/Components/Chat/ChatNavigationButton", "//submodules/CheckNode", "//submodules/TelegramUI/Components/Chat/ChatMessageSelectionNode", "//submodules/AudioWaveform", "//submodules/ChatInterfaceState", "//submodules/AnimatedCountLabelNode", "//submodules/PresentationDataUtils", "//submodules/TelegramUI/Components/ChatInputNode", "//submodules/ChatPresentationInterfaceState", "//submodules/TelegramUI/Components/ContextControllerImpl", "//submodules/ContextUI", "//submodules/Markdown", "//submodules/TextFormat", "//submodules/TelegramStringFormatting", "//submodules/PhotoResources", "//submodules/TelegramUI/Components/Chat/ChatMessageItemCommon", "//submodules/TelegramUI/Components/Chat/MessageInlineBlockBackgroundView", "//submodules/LegacyComponents", "//submodules/TelegramCore", "//submodules/TelegramUIPreferences", ":TelegramPresentationData", "//submodules/SSignalKit/SwiftSignalKit", "//submodules/QrCode", "//submodules/AvatarNode", "//submodules/AsyncDisplayKit", "//submodules/AppBundle", "//submodules/Display", "//submodules/SearchUI", "//submodules/SearchBarNode", "//submodules/ChatListSearchItemHeader", "//submodules/TelegramUI/Components/NavigationBarImpl"],
)

ios_unit_test(
    name = "WegramNavigationBadgeTests",
    resources = ["//Telegram:InstantPagePreviewTestStrings"],
    minimum_os_version = "15.0",
    runner = ":WegramBubbleImageTestRunner",
    deps = [":WegramNavigationBadgeTestsLib"],
    visibility = ["//visibility:public"],
)

swift_library(
    name = "WegramQrHostedTestsLib",
    testonly = True,
    srcs = [
        "Tests/WegramQrHostedTests.swift",
        "//submodules/TelegramUI/Components/Chat/ChatQrCodeScreen:Sources/WegramQrCardView.swift",
    ],
    deps = ["//submodules/QrCode", "//submodules/Display"],
)

ios_unit_test(
    name = "WegramQrHostedTests",
    minimum_os_version = "15.0",
    runner = ":WegramBubbleImageTestRunner",
    test_host = "//Tests/wegram/qr-host:WegramQrTestHost",
    deps = [":WegramQrHostedTestsLib"],
    visibility = ["//visibility:public"],
)


swift_library(
    name = "WegramShortcutHostedTestsLib",
    testonly = True,
    srcs = [
        "Tests/WegramShortcutHostedTests.swift",
        "//submodules/ChatListUI:Sources/WegramShortcutMenuView.swift",
        "//submodules/ChatListUI:Sources/WegramShortcutMenuController.swift",
    ],
    deps = ["//submodules/Display", "//submodules/AsyncDisplayKit"],
)

ios_unit_test(
    name = "WegramShortcutHostedTests",
    minimum_os_version = "15.0",
    runner = ":WegramBubbleImageTestRunner",
    test_host = "//Tests/wegram/qr-host:WegramQrTestHost",
    deps = [":WegramShortcutHostedTestsLib"],
    visibility = ["//visibility:public"],
)


swift_library(
    name = "WegramGroupDescriptionHostedTestsLib",
    testonly = True,
    srcs = [
        "Tests/WegramGroupDescriptionHostedTests.swift",
        "//submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen:Sources/WegramGroupDescriptionView.swift",
    ],
    deps = ["//submodules/Display", "//submodules/AccountContext", "//submodules/TextFormat"],
)

ios_unit_test(
    name = "WegramGroupDescriptionHostedTests",
    minimum_os_version = "15.0",
    runner = ":WegramBubbleImageTestRunner",
    test_host = "//Tests/wegram/qr-host:WegramQrTestHost",
    deps = [":WegramGroupDescriptionHostedTestsLib"],
    visibility = ["//visibility:public"],
)


swift_library(
    name = "WegramItemListHostedTestsLib",
    testonly = True,
    srcs = ["Tests/WegramItemListAppearanceTests.swift"],
    deps = [":TelegramPresentationData", "//submodules/Display", "//submodules/AsyncDisplayKit", "//submodules/ItemListUI", "//submodules/AppBundle", "//submodules/SSignalKit/SwiftSignalKit", "//submodules/TelegramUI/Components/NavigationBarImpl"],
)

ios_unit_test(
    name = "WegramItemListHostedTests",
    resources = ["//Telegram:InstantPagePreviewTestStrings"],
    minimum_os_version = "15.0",
    runner = ":WegramBubbleImageTestRunner",
    test_host = "//Tests/wegram/qr-host:WegramQrTestHost",
    deps = [":WegramItemListHostedTestsLib"],
    visibility = ["//visibility:public"],
)


swift_library(
    name = "WegramCardBackgroundHostedTestsLib",
    testonly = True,
    srcs = ["Tests/WegramCardBackgroundHostedTests.swift"],
    deps = [":TelegramPresentationData", "//submodules/ChatMessageBackground", "//submodules/TelegramUI/Components/Chat/ChatMessageForwardInfoNode", "//submodules/WallpaperBackgroundNode", "//submodules/TelegramUI/Components/Chat/ChatMessageItemCommon", "//submodules/Display", "//submodules/AsyncDisplayKit", "//submodules/SSignalKit/SwiftSignalKit", "//submodules/Postbox", "//submodules/TelegramCore"],
)

ios_unit_test(
    name = "WegramCardBackgroundHostedTests",
    minimum_os_version = "15.0",
    runner = ":WegramBubbleImageTestRunner",
    test_host = "//Tests/wegram/qr-host:WegramQrTestHost",
    deps = [":WegramCardBackgroundHostedTestsLib"],
    visibility = ["//visibility:public"],
)
