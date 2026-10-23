import XCTest
import UIKit
import Display
import NavigationBarImpl
import AsyncDisplayKit
import TelegramPresentationData

final class WegramMomentsCoverTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        WegramSearchFieldTests.exchangeResourceLookups()
    }
    override class func tearDown() {
        WegramSearchFieldTests.exchangeResourceLookups()
        super.tearDown()
    }

    func testFixedCoverCropAndDefaultWallpaperCropAcrossRotation() throws {
        let previousFactory = defaultNavigationBarImpl
        defaultNavigationBarImpl = { NavigationBarImpl(presentationData: $0) }
        defer { defaultNavigationBarImpl = previousFactory }
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 1600)).image { _ in }
        for fixed in [false, true] {
            let controller = WegramWallpaperCropController(image: image, presentationData: defaultPresentationData(), aspectRatio: fixed ? CGSize(width: 4, height: 3) : nil, title: fixed ? "Adjust Cover" : nil)
            _ = controller.view
            for size in [CGSize(width: 402, height: 874), CGSize(width: 874, height: 402), CGSize(width: 320, height: 568)] {
                let layout = ContainerViewLayout(size: size, metrics: LayoutMetrics(), deviceMetrics: .iPhoneX, intrinsicInsets: UIEdgeInsets(top: 0, left: 0, bottom: 34, right: 0), safeInsets: UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12), additionalInsets: .zero, statusBarHeight: 44, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false, presentedInFormSheet: false)
                controller.containerLayoutUpdated(layout, transition: .immediate)
                let crop = try XCTUnwrap(controller.displayNode.subnodes?.compactMap { $0 as? WallpaperCropNode }.first)
                XCTAssertEqual(crop.frame.width / crop.frame.height, fixed ? 4.0 / 3.0 : size.width / size.height, accuracy: 0.001)
                XCTAssertGreaterThanOrEqual(crop.frame.minX, 12)
                XCTAssertLessThanOrEqual(crop.frame.maxX, size.width - 12 + 0.01)
                XCTAssertLessThanOrEqual(crop.frame.maxY, size.height - 34)
                let output = try XCTUnwrap(prepareCapturedWallpaperPhoto(image, viewport: fixed ? crop.frame.size : size, cropRect: crop.cropRect))
                let ratio: CGFloat = fixed ? 4.0 / 3.0 : size.width / size.height
                // The renderer rounds each output dimension to whole pixels.
                XCTAssertEqual(output.size.width, output.size.height * ratio, accuracy: 1 + ratio)
            }
            if fixed { XCTAssertEqual(controller.title, "Adjust Cover") }
        }
    }

    func testCoverPersistsPerAccountAndResetDoesNotAffectAnotherAccount() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let first = root.appendingPathComponent("first")
        let second = root.appendingPathComponent("second")
        try FileManager.default.createDirectory(at: first, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: second, withIntermediateDirectories: true)
        let store = WegramMomentsCoverStore(accountPath: first.path)
        let other = WegramMomentsCoverStore(accountPath: second.path)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 30)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 30))
        }
        let bytes = try XCTUnwrap(image.jpegData(compressionQuality: 0.8))
        XCTAssertNil(store.load())
        try store.save(bytes)
        XCTAssertEqual(WegramMomentsCoverStore(accountPath: first.path).load()?.size, CGSize(width: 40, height: 30))
        XCTAssertNil(other.load())
        XCTAssertThrowsError(try store.save(Data("invalid".utf8)))
        XCTAssertNotNil(store.load(), "A failed replacement must preserve the current cover")
        try other.save(bytes)
        try store.reset()
        XCTAssertNil(store.load())
        XCTAssertNotNil(other.load())
        try store.reset()
    }

    func testMissingAccountDirectoryFailsWithoutCreatingGlobalFallback() {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        let store = WegramMomentsCoverStore(accountPath: path)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 3)).image { _ in }
        XCTAssertThrowsError(try store.save(image.jpegData(compressionQuality: 0.8)!))
        XCTAssertNil(store.load())
        XCTAssertFalse(FileManager.default.fileExists(atPath: path))
    }

    func testCoverHitTargetKeepsAvatarIndependentAndImageSurvivesThemeAndSizeChanges() {
        let header = WegramMomentsHeaderView(frame: .zero)
        var covers = 0
        var stories = 0
        header.changeCover = { covers += 1 }
        header.openOwnStories = { stories += 1 }
        header.changeCoverButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(covers, 0)
        let image = UIImage()
        header.cover.image = image
        for width: CGFloat in [320, 402, 720] {
            header.update(name: "Test Account", dark: width == 402, fontSize: 34, chinese: true)
            header.frame = CGRect(x: 0, y: 0, width: width, height: header.measuredHeight(width: width))
            header.layoutIfNeeded()
            XCTAssertTrue(header.cover.image === image)
            XCTAssertTrue(header.hitTest(CGPoint(x: 40, y: 40), with: nil) === header.changeCoverButton)
            let avatar = header.ownStories.frame
            for y in [avatar.minY + 1, avatar.maxY - 1] {
                XCTAssertTrue(header.hitTest(CGPoint(x: avatar.midX, y: y), with: nil) === header.ownStories)
            }
            header.changeCoverButton.sendActions(for: .touchUpInside)
            header.ownStories.sendActions(for: .touchUpInside)
        }
        XCTAssertEqual(covers, 3)
        XCTAssertEqual(stories, 3)
        XCTAssertEqual(header.changeCoverButton.accessibilityLabel, "更换封面")
        XCTAssertEqual(header.changeCoverButton.accessibilityHint, "仅保存在本机当前账号")
        header.update(name: nil, dark: false, fontSize: 17, chinese: false)
        header.changeCoverButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(covers, 3)
        XCTAssertFalse(header.changeCoverButton.isEnabled)
    }
}
