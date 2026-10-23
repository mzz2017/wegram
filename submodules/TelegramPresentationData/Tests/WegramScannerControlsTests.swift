import XCTest
import UIKit

final class WegramScannerControlsTests: XCTestCase {
    func testControlsFitSafeAreasAndLeaveTheCameraPreviewTouchable() {
        for size in [CGSize(width: 320, height: 568), CGSize(width: 402, height: 874), CGSize(width: 720, height: 320)] {
            let controls = WegramScannerControls()
            controls.update(chinese: true, hasTorch: true, torchOn: false)
            controls.updateLayout(size: size, safe: UIEdgeInsets(top: 0, left: 8, bottom: 34, right: 8), top: 44)
            let buttons = [controls.back, controls.myCode, controls.torch, controls.gallery]
            for button in buttons {
                XCTAssertGreaterThanOrEqual(button.bounds.width, 44)
                XCTAssertGreaterThanOrEqual(button.bounds.height, 44)
                XCTAssertTrue(controls.bounds.contains(button.frame))
                XCTAssertLessThanOrEqual(button.frame.maxY, size.height - 34)
                let hit = controls.hitTest(button.center, with: nil)
                XCTAssertTrue(hit === button || hit?.isDescendant(of: button) == true)
            }
            XCTAssertLessThan(controls.myCode.frame.maxX, controls.torch.frame.minX)
            XCTAssertLessThan(controls.torch.frame.maxX, controls.gallery.frame.minX)
            XCTAssertNil(controls.hitTest(CGPoint(x: size.width / 2, y: 100), with: nil))
            controls.setControlsAlpha(0)
            XCTAssertTrue(controls.hitTest(controls.back.center, with: nil) === controls.back)
            XCTAssertNil(controls.hitTest(controls.gallery.center, with: nil))
        }
    }

    func testTorchAvailabilitySelectionAndLanguageHaveRealAccessibilityState() {
        let controls = WegramScannerControls()
        controls.update(chinese: true, hasTorch: false, torchOn: false)
        XCTAssertTrue(controls.torch.isHidden)
        controls.update(chinese: true, hasTorch: true, torchOn: true)
        XCTAssertFalse(controls.torch.isHidden)
        XCTAssertEqual(controls.torch.accessibilityValue, "已开启")
        XCTAssertEqual(controls.gallery.accessibilityLabel, "相册")
        controls.update(chinese: false, hasTorch: true, torchOn: false)
        XCTAssertEqual(controls.torch.accessibilityValue, "Off")
        XCTAssertEqual(controls.myCode.accessibilityLabel, "My QR Code")
        XCTAssertEqual(controls.gallery.accessibilityLabel, "Photos")
    }

    func testButtonsDeliverTheirBoundActionsAndRenderWithoutARealCamera() throws {
        let controls = WegramScannerControls()
        var gallery = 0
        var torch = 0
        controls.gallery.addAction(UIAction { _ in gallery += 1 }, for: .touchUpInside)
        controls.torch.addAction(UIAction { _ in torch += 1 }, for: .touchUpInside)
        controls.gallery.sendActions(for: .touchUpInside)
        controls.torch.sendActions(for: .touchUpInside)
        XCTAssertEqual(gallery, 1)
        XCTAssertEqual(torch, 1)
        controls.update(chinese: true, hasTorch: true, torchOn: false)
        controls.updateLayout(size: CGSize(width: 402, height: 874), safe: UIEdgeInsets(top: 0, left: 0, bottom: 34, right: 0), top: 62)
        if let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
            let format = UIGraphicsImageRendererFormat(); format.scale = 1
            let image = UIGraphicsImageRenderer(size: controls.bounds.size, format: format).image { context in
                UIColor.black.setFill(); context.fill(controls.bounds)
                controls.layer.render(in: context.cgContext)
            }
            try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("scanner-controls-component.png"))
        }
    }
}
