import XCTest
import UIKit
import Display
import TelegramCore
import TelegramPresentationData
import NavigationBarImpl
@testable import AuthorizationUI
@testable import WegramLanguageUI

final class WegramAuthorizationLanguageTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        WegramSearchFieldTests.exchangeResourceLookups()
    }
    override class func tearDown() {
        WegramSearchFieldTests.exchangeResourceLookups()
        super.tearDown()
    }
    private func language(_ code: String, title: String? = nil) -> LocalizationInfo {
        LocalizationInfo(languageCode: code, baseLanguageCode: nil, customPluralizationCode: nil, title: title ?? code, localizedTitle: title ?? code, isOfficial: true, totalStringCount: 1, translatedStringCount: 1, platformUrl: "")
    }
    private func invoke(_ item: UIBarButtonItem?) throws {
        let item = try XCTUnwrap(item)
        let target = try XCTUnwrap(item.target as? NSObject)
        let action = try XCTUnwrap(item.action)
        _ = target.perform(action)
    }
    private func withNavigation(_ body: () throws -> Void) rethrows {
        let original = defaultNavigationBarImpl
        defaultNavigationBarImpl = { NavigationBarImpl(presentationData: $0) }
        defer { defaultNavigationBarImpl = original }
        try body()
    }

    func testDraftWaitsForActualDoneAndSubmittingRejectsOldDoneAndCancel() throws {
        try self.withNavigation {
            let page = WegramAuthorizationLanguageController(theme: defaultPresentationTheme, strings: defaultPresentationStrings, languages: [self.language("en"), self.language("de")])
            var applied: [String] = []
            var cancelled = 0
            page.apply = { applied.append($0) }
            page.cancelled = { cancelled += 1 }
            page.content.tableView(page.content.table, didSelectRowAt: IndexPath(row: 1, section: 0))
            XCTAssertEqual(page.content.draft.selectedCode, "de")
            XCTAssertTrue(applied.isEmpty)
            try self.invoke(page.navigationItem.rightBarButtonItem)
            XCTAssertEqual(applied, ["de"])
            XCTAssertTrue(page.content.submitting)
            XCTAssertFalse(page.navigationItem.leftBarButtonItem?.isEnabled ?? true)
            try self.invoke(page.navigationItem.rightBarButtonItem)
            try self.invoke(page.navigationItem.leftBarButtonItem)
            XCTAssertEqual(applied, ["de"])
            XCTAssertEqual(cancelled, 0)
            page.setSubmitting(false)
            try self.invoke(page.navigationItem.leftBarButtonItem)
            XCTAssertEqual(cancelled, 1)
            XCTAssertEqual(applied, ["de"])
        }
    }

    func testCancelledPageRejectsRetainedDoneAndCancelActions() throws {
        try self.withNavigation {
            let page = WegramAuthorizationLanguageController(theme: defaultPresentationTheme, strings: defaultPresentationStrings, languages: [self.language("en")])
            let oldDone = page.navigationItem.rightBarButtonItem
            let oldCancel = page.navigationItem.leftBarButtonItem
            var applied: [String] = []
            var cancelled = 0
            page.apply = { applied.append($0) }
            page.cancelled = { cancelled += 1 }
            try self.invoke(oldCancel)
            try self.invoke(oldCancel)
            try self.invoke(oldDone)
            page.content.saveButton.sendActions(for: .touchUpInside)
            XCTAssertTrue(applied.isEmpty, "A retained Done action must not apply language after Cancel")
            XCTAssertEqual(cancelled, 1, "Closing a picker must consume its cancel callback")
        }
    }

    func testServerUpdatesPreserveDraftDeduplicateAndRejectRemovedSelection() throws {
        try self.withNavigation {
            let page = WegramAuthorizationLanguageController(theme: defaultPresentationTheme, strings: defaultPresentationStrings, languages: [])
            XCTAssertEqual(page.content.draft.languages.map(\.languageCode), ["en"])
            page.loadLanguages([self.language("en"), self.language("zh-hans"), self.language("de"), self.language("de")])
            XCTAssertEqual(page.content.draft.languages.map(\.languageCode), ["zh-hans", "en", "de"])
            page.content.tableView(page.content.table, didSelectRowAt: IndexPath(row: 2, section: 0))
            page.loadLanguages([self.language("fr"), self.language("en")])
            XCTAssertEqual(page.content.draft.selectedCode, "de")
            XCTAssertFalse(page.content.canSave)
            var applied: [String] = []
            page.apply = { applied.append($0) }
            try self.invoke(page.navigationItem.rightBarButtonItem)
            XCTAssertTrue(applied.isEmpty)
            page.loadLanguages([self.language("fr"), self.language("en"), self.language("de")])
            XCTAssertEqual(page.content.draft.selectedCode, "de")
            XCTAssertTrue(page.content.canSave)
        }
    }

    func testActualPageLayoutKeepsFlatRowsAndHeaderWithinSafeAreas() throws {
        try self.withNavigation {
            for dark in [false, true] {
                let page = WegramAuthorizationLanguageController(theme: dark ? defaultDarkPresentationTheme : defaultPresentationTheme, strings: defaultPresentationStrings, languages: (0..<30).map { self.language("language-\($0)", title: "Language \($0)") })
                for width: CGFloat in [320, 402, 720] {
                    let size = CGSize(width: width, height: 874)
                    page.displayNode.frame = CGRect(origin: .zero, size: size)
                    page.containerLayoutUpdated(ContainerViewLayout(size: size, metrics: LayoutMetrics(widthClass: .compact, heightClass: .regular, orientation: nil), deviceMetrics: .iPhoneX, intrinsicInsets: UIEdgeInsets(top: 0, left: 0, bottom: 34, right: 0), safeInsets: .zero, additionalInsets: .zero, statusBarHeight: 54, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: true, presentedInFormSheet: false), transition: .immediate)
                    page.content.layoutIfNeeded()
                    XCTAssertGreaterThanOrEqual(page.content.frame.minY, 98)
                    XCTAssertEqual(page.content.frame.maxY, 874)
                    XCTAssertEqual(page.content.bounds.width, width)
                    XCTAssertEqual(page.content.table.contentInset.bottom, 34)
                    XCTAssertEqual(page.content.table.frame, page.content.bounds)
                    XCTAssertGreaterThan(page.content.table.contentSize.height, page.content.bounds.height)
                    XCTAssertEqual(page.navigationItem.leftBarButtonItem?.accessibilityLabel, defaultPresentationStrings.Common_Cancel)
                    XCTAssertEqual(page.navigationItem.rightBarButtonItem?.accessibilityLabel, defaultPresentationStrings.Common_Done)
                    XCTAssertNil(page.navigationItem.title)
                    if width == 402, let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                        let format = UIGraphicsImageRendererFormat(); format.scale = 1
                        let image = UIGraphicsImageRenderer(size: size, format: format).image { page.displayNode.layer.render(in: $0.cgContext) }
                        try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("authorization-languages-\(dark ? "dark" : "light").png"))
                    }
                }
            }
        }
    }
}
