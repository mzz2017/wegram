import XCTest
import UIKit
import AsyncDisplayKit
import Display

final class WegramGroupCallRowTests: XCTestCase {
    private var joins = 0
    @objc private func joined() { self.joins += 1 }

    private func joinText(_ title: String, font: CGFloat, width: CGFloat) -> (TextNodeLayout, TextNode) {
        let node = TextNode()
        let (layout, apply) = TextNode.asyncLayout(node)(TextNodeLayoutArguments(attributedString: NSAttributedString(string: title, attributes: [.font: UIFont.systemFont(ofSize: font), .foregroundColor: UIColor.white]), backgroundColor: nil, maximumNumberOfLines: 2, truncationType: .end, constrainedSize: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: .zero))
        _ = apply()
        return (layout, node)
    }
    func testMeasuredJoinTitleAvatarIndicatorAndNameFitLargeTextAndSafeAreas() {
        for width: CGFloat in [320, 402, 720] {
            for safe: CGFloat in [0, 16, 59] {
                for font: CGFloat in [17, 34] {
                    for text in ["加入", "Join", "An einem Anruf teilnehmen"] {
                        for active in [false, true] {
                            let measured = self.joinText(text, font: font, width: WegramGroupCallRowLayout.joinTextMaxWidth(width: width, safeLeft: safe, safeRight: safe, editingOffset: 16)).0
                            let titleWidth = WegramGroupCallRowLayout.titleMaxWidth(width: width, safeLeft: safe, safeRight: safe, editingOffset: 16, joinTextWidth: measured.size.width, active: active)
                            let row = WegramGroupCallRowLayout(width: width, safeLeft: safe, safeRight: safe, editingOffset: 16, revealOffset: 0, titleSize: CGSize(width: titleWidth, height: ceil(UIFont.systemFont(ofSize: font).lineHeight)), joinTextSize: measured.size, active: active)
                            XCTAssertGreaterThanOrEqual(row.height, 56)
                            XCTAssertEqual(row.avatar.size, CGSize(width: 40, height: 40))
                            XCTAssertEqual(row.avatar.minX, safe + 32)
                            XCTAssertLessThanOrEqual(row.avatar.maxX + 12, row.title.minX)
                            XCTAssertLessThanOrEqual(row.indicator.maxX + 4, row.title.minX)
                            XCTAssertLessThanOrEqual(row.indicator.maxY, row.height)
                            XCTAssertLessThanOrEqual(row.title.maxX, width - safe - 16)
                            XCTAssertGreaterThanOrEqual(row.title.width, 0)
                            if !active {
                                XCTAssertGreaterThanOrEqual(row.join.width, 44)
                                XCTAssertGreaterThanOrEqual(row.join.height, 44)
                                XCTAssertLessThanOrEqual(row.title.maxX + 12, row.join.minX + 0.1)
                                XCTAssertLessThanOrEqual(row.join.maxY, row.height)
                                XCTAssertGreaterThanOrEqual(row.joinBackground.height, 32)
                                XCTAssertGreaterThanOrEqual(row.joinText.minY, row.joinBackground.minY)
                                XCTAssertLessThanOrEqual(row.joinText.maxY, row.joinBackground.maxY)
                            }
                        }
                    }
                }
            }
        }
    }
    func testCurrentCallUsesFreedTitleSpaceAndRevealMovesTheWholeRow() {
        let inactiveWidth = WegramGroupCallRowLayout.titleMaxWidth(width: 402, safeLeft: 16, safeRight: 8, editingOffset: 0, joinTextWidth: 34, active: false)
        let activeWidth = WegramGroupCallRowLayout.titleMaxWidth(width: 402, safeLeft: 16, safeRight: 8, editingOffset: 0, joinTextWidth: 34, active: true)
        XCTAssertGreaterThan(activeWidth, inactiveWidth)
        let base = WegramGroupCallRowLayout(width: 402, safeLeft: 16, safeRight: 8, editingOffset: 0, revealOffset: 0, titleSize: CGSize(width: inactiveWidth, height: 21), joinTextSize: CGSize(width: 34, height: 21), active: false)
        for offset: CGFloat in [-80, 0, 40] {
            let row = WegramGroupCallRowLayout(width: 402, safeLeft: 16, safeRight: 8, editingOffset: 0, revealOffset: offset, titleSize: base.title.size, joinTextSize: base.joinText.size, active: false)
            for (before, after) in [(base.avatar, row.avatar), (base.title, row.title), (base.indicator, row.indicator), (base.join, row.join)] { XCTAssertEqual(after, before.offsetBy(dx: offset, dy: 0)) }
            XCTAssertEqual(row.joinText, base.joinText)
            XCTAssertEqual(row.joinBackground, base.joinBackground)
        }
    }
    func testJoinTargetDoesNotOverlapRowAndItsChildrenDoNotStealHits() throws {
        let (text, textNode) = self.joinText("加入", font: 17, width: 100)
        let row = WegramGroupCallRowLayout(width: 402, safeLeft: 0, safeRight: 0, editingOffset: 0, revealOffset: 0, titleSize: CGSize(width: 200, height: 21), joinTextSize: text.size, active: false)
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 402, height: row.height))
        let button = HighlightableButtonNode()
        button.hitTestSlop = .zero
        button.frame = row.join
        button.addTarget(self, action: #selector(self.joined), forControlEvents: .touchUpInside)
        let background = ASImageNode()
        background.image = generateStretchableFilledCircleImage(diameter: 10, color: UIColor(red: 0.027, green: 0.757, blue: 0.376, alpha: 1))
        background.frame = row.joinBackground
        background.isUserInteractionEnabled = false
        textNode.frame = row.joinText
        textNode.isUserInteractionEnabled = false
        button.addSubnode(background)
        button.addSubnode(textNode)
        host.addSubnode(button)
        _ = button.view
        button.recursivelyEnsureDisplaySynchronously(true)
        for x in [CGFloat(0.1), button.bounds.width - 0.1] {
            for y in [CGFloat(0.1), button.bounds.height - 0.1] { XCTAssertNotNil(button.view.hitTest(CGPoint(x: x, y: y), with: nil)) }
        }
        XCTAssertTrue(button.view.hitTest(CGPoint(x: button.bounds.midX, y: button.bounds.midY), with: nil) === button.view)
        XCTAssertFalse(CGRect(x: 0, y: 0, width: row.join.minX, height: row.height).intersects(button.frame))
        button.sendActions(forControlEvents: .touchUpInside, with: nil)
        XCTAssertEqual(self.joins, 1)
        if let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
            let avatar = UIView(frame: row.avatar)
            avatar.layer.cornerRadius = 4
            host.addSubview(avatar)
            let title = UILabel(frame: row.title)
            title.font = .systemFont(ofSize: 17)
            title.text = "群通话组件检查"
            host.addSubview(title)
            let indicator = UIImageView(frame: row.indicator)
            indicator.image = UIImage(systemName: "waveform")
            indicator.tintColor = .systemGreen
            host.addSubview(indicator)
            for dark in [false, true] {
                host.backgroundColor = dark ? UIColor(white: 0.1, alpha: 1) : .white
                avatar.backgroundColor = UIColor(white: dark ? 0.2 : 0.9, alpha: 1)
                title.textColor = dark ? .lightGray : .black
                let image = UIGraphicsImageRenderer(size: host.bounds.size).image { host.layer.render(in: $0.cgContext) }
                try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent(dark ? "group-call-row-dark.png" : "group-call-row-light.png"))
            }
        }
        button.isUserInteractionEnabled = false
        button.isAccessibilityElement = false
        XCTAssertNil(button.view.hitTest(CGPoint(x: 22, y: 22), with: nil))
    }
}
