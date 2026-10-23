import XCTest
import UIKit
import TelegramPresentationData
import LegacyComponents
import AccountContext
import TelegramCore

final class WegramAboutContentTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        WegramSearchFieldTests.exchangeResourceLookups()
    }

    override class func tearDown() {
        WegramSearchFieldTests.exchangeResourceLookups()
        super.tearDown()
    }

    private func content(width: CGFloat = 402, height: CGFloat = 734, font: CGFloat = 17, chinese: Bool = true, dark: Bool = false, action: @escaping (WegramAboutContentView.Action) -> Void = { _ in }) -> WegramAboutContentView {
        let view = WegramAboutContentView(action: action)
        view.frame = CGRect(x: 0, y: 0, width: width, height: height)
        view.update(icon: nil, version: "12.1", build: "12345", chinese: chinese, isDark: dark, fontSize: font)
        view.layoutIfNeeded()
        return view
    }

    func testHeaderAndActionTargetsMatchTheMeasuredStructure() {
        var actions: [WegramAboutContentView.Action] = []
        let view = self.content(action: { actions.append($0) })
        XCTAssertEqual(view.iconView.frame, CGRect(x: 169, y: 48, width: 64, height: 64))
        XCTAssertEqual(view.nameLabel.text, "WeGram")
        XCTAssertEqual(view.versionLabel.text, "Version 12.1")
        XCTAssertTrue(view.versionLabel.accessibilityValue?.contains("12345") == true)
        XCTAssertEqual(view.buttons.count, 5)
        for (index, button) in view.buttons.enumerated() {
            XCTAssertGreaterThanOrEqual(button.bounds.height, 44)
            XCTAssertGreaterThanOrEqual(button.bounds.width, 44)
            let point = CGPoint(x: button.bounds.midX, y: button.bounds.midY)
            XCTAssertTrue(button.hitTest(point, with: nil) === button, "Action target intercepted")
            if let arrow = button.viewWithTag(1) {
                XCTAssertLessThanOrEqual(button.titleLabel?.frame.maxX ?? 0, arrow.frame.minX)
            }
            button.sendActions(for: .touchUpInside)
            XCTAssertEqual(actions.last, WegramAboutContentView.Action.allCases[index])
        }
    }

    func testSmallAndLargeLayoutsRemainScrollableWithoutOverlappingActions() {
        for (width, height, font): (CGFloat, CGFloat, CGFloat) in [(320, 390, 17), (402, 734, 34), (720, 180, 17)] {
            let view = self.content(width: width, height: height, font: font, chinese: false, dark: true)
            XCTAssertGreaterThanOrEqual(view.scrollView.contentSize.height, height)
            XCTAssertLessThanOrEqual(view.nameLabel.frame.maxY, view.versionLabel.frame.minY)
            XCTAssertLessThan(view.versionLabel.frame.maxY, view.buttons[0].frame.minY)
            for button in view.buttons {
                XCTAssertGreaterThanOrEqual(button.frame.minX, 0)
                XCTAssertLessThanOrEqual(button.frame.maxX, width)
                XCTAssertGreaterThanOrEqual(button.bounds.height, 44)
            }
            for pair in zip(view.buttons.prefix(3), view.buttons.dropFirst().prefix(2)) {
                XCTAssertLessThanOrEqual(pair.0.frame.maxY, pair.1.frame.minY)
            }
            XCTAssertLessThan(view.buttons[2].frame.maxY, view.buttons[3].frame.minY)
            XCTAssertFalse(view.buttons[3].frame.intersects(view.buttons[4].frame))
            XCTAssertLessThanOrEqual(view.disclosureLabel.frame.maxY, view.scrollView.contentSize.height)
        }
    }

    func testThemeAndLanguageUpdatePreservesNamesAndButtonActions() {
        let view = self.content()
        view.update(icon: nil, version: "12.2", build: "12346", chinese: false, isDark: true, fontSize: 17)
        view.layoutIfNeeded()
        XCTAssertEqual(view.nameLabel.text, "WeGram")
        XCTAssertEqual(view.versionLabel.text, "Version 12.2")
        XCTAssertEqual(view.buttons[0].title(for: .normal), "Features")
        XCTAssertEqual(view.buttons[4].title(for: .normal), "WeGram Privacy")
        for button in view.buttons {
            XCTAssertEqual(button.titleLabel?.text, button.title(for: .normal))
            XCTAssertGreaterThan(button.titleLabel?.frame.width ?? 0, 0)
            XCTAssertGreaterThan(button.titleLabel?.layer.opacity ?? 0, 0.9, "Updated button text is invisible")
        }
        XCTAssertTrue(view.disclosureLabel.text?.contains("Third-party") == true)
        XCTAssertEqual(view.backgroundColor, UIColor(white: 0.1, alpha: 1))
        let renderer = UIGraphicsImageRenderer(size: view.bounds.size)
        let image = renderer.image { context in view.layer.render(in: context.cgContext) }
        XCTAssertNotNil(image.cgImage)
        let attachment = XCTAttachment(image: image)
        attachment.name = "WeGram About dark English 402pt"
        attachment.lifetime = .keepAlways
        self.add(attachment)
        if let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
            for (name, content) in [("about-dark-en.png", view), ("about-light-zh.png", self.content()), ("about-large-en.png", self.content(width: 320, height: 390, font: 34, chinese: false))] {
                let rendered = UIGraphicsImageRenderer(size: content.bounds.size).image { context in content.layer.render(in: context.cgContext) }
                XCTAssertNoThrow(try rendered.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent(name)))
            }
        }
    }
}

extension WegramAboutContentTests {
    func testDownloadedLanguageUsesWegramBrandBeforeFormattingUserContent() {
        let strings = PresentationStrings(primaryComponent: PresentationStrings.Component(languageCode: "zh-hans", localizedName: "中文", pluralizationRulesCode: nil, dict: [
            "Contacts.AccessDeniedError": "请允许 Telegram 访问通讯录。Telegram. TELEGRAM... Telegram.org @Telegram",
            "Tour.Title1": "تيليجرام / تلگرام / تليجرام",
            "Notification.Joined": "%@ 加入了 Telegram",
            "Conversation.UnsupportedMedia": "请更新 TELEGRAM：https://telegram.org/update，联系 @Telegram。"
        ]), secondaryComponent: nil, groupingSeparator: "")
        XCTAssertEqual(strings.Contacts_AccessDeniedError, "请允许 WeGram 访问通讯录。WeGram. WeGram... Telegram.org @Telegram")
        XCTAssertEqual(strings.Tour_Title1, "WeGram / WeGram / WeGram")
        let notification = strings.Notification_Joined("Telegram 用户 👋")
        XCTAssertEqual(notification.string, "Telegram 用户 👋 加入了 WeGram")
        let range = notification.ranges[0].range
        XCTAssertEqual((notification.string as NSString).substring(with: range), "Telegram 用户 👋")
        XCTAssertEqual(strings.Conversation_UnsupportedMedia, "请更新 WeGram：https://telegram.org/update，联系 @Telegram。")
    }

    func testSecondaryAndBundledFallbackUseWegramBrand() {
        let secondary = PresentationStrings.Component(languageCode: "en", localizedName: "English", pluralizationRulesCode: nil, dict: ["Contacts.AccessDeniedError": "Telegram cannot access your contacts. Open Telegram..."])
        let strings = PresentationStrings(primaryComponent: PresentationStrings.Component(languageCode: "custom", localizedName: "Custom", pluralizationRulesCode: nil, dict: [:]), secondaryComponent: secondary, groupingSeparator: "")
        XCTAssertEqual(strings.Contacts_AccessDeniedError, "WeGram cannot access your contacts. Open WeGram...")
        XCTAssertEqual(strings.Tour_Title1, "WeGram")
    }

    func testLegacyLanguageBrandingPreservesLinksAndHandlesSentenceEndings() throws {
        let legacy = try XCTUnwrap(TGLocalization(version: 1, code: "en", dict: ["BrandingProbe": "Telegram. TELEGRAM... https://Telegram.org @Telegram"], isActive: true))
        XCTAssertEqual(legacy.get("BrandingProbe"), "WeGram. WeGram... https://Telegram.org @Telegram")
    }

    func testNewContactProfileUsesAppNameWithTheOriginalReference() {
        let peer = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: ._internalFromInt64Value(42))
        let address = DeviceContactUrlData(appProfile: peer)
        XCTAssertEqual(address.label, "WeGram")
        XCTAssertEqual(parseAppSpecificContactReference(address.value), peer)
    }

    func testPluralLanguageTemplatesUseTheAppBrandForBothCounts() {
        let strings = PresentationStrings(primaryComponent: PresentationStrings.Component(languageCode: "en", localizedName: "English", pluralizationRulesCode: nil, dict: ["Contacts.ImportersCount_1": "%@ contact on Telegram.", "Contacts.ImportersCount_any": "%@ contacts on TELEGRAM..."]), secondaryComponent: nil, groupingSeparator: "")
        XCTAssertEqual(strings.Contacts_ImportersCount(1), "1 contact on WeGram.")
        XCTAssertEqual(strings.Contacts_ImportersCount(3), "3 contacts on WeGram...")
    }
}
