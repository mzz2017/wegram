import XCTest
import UIKit
import AsyncDisplayKit
import Display

final class WegramCallRowTests: XCTestCase {
    private var infoActions = 0
    @objc private func infoPressed() { self.infoActions += 1 }

    func testNameDateStatusAndInfoStaySeparateWithLargeFontsAndSafeInsets() {
        for width: CGFloat in [320, 402, 720] {
            for safe: CGFloat in [0, 16, 59] {
                for font: CGFloat in [17, 34] {
                    for editing in [false, true] {
                        let titleHeight = ceil(UIFont.systemFont(ofSize: font).lineHeight)
                        let statusHeight = ceil(UIFont.systemFont(ofSize: font * 14 / 17).lineHeight)
                        let height = WegramCallRowLayout.height(titleHeight: titleHeight, statusHeight: statusHeight)
                        let layout = WegramCallRowLayout(width: width, height: height, safeLeft: safe, safeRight: safe, editingOffset: editing ? 44 : 0, revealOffset: 0, editing: editing)
                        for credibilityWidth: CGFloat in [0, 20, 58] {
                            let dateSize = CGSize(width: layout.dateMaxWidth(credibilityWidth: credibilityWidth), height: ceil(UIFont.systemFont(ofSize: font * 12 / 17).lineHeight))
                            let title = layout.title(size: CGSize(width: layout.titleWidth(dateWidth: dateSize.width, credibilityWidth: credibilityWidth), height: titleHeight))
                            let date = layout.date(size: dateSize, titleHeight: titleHeight)
                            let status = layout.status(size: CGSize(width: layout.statusWidth(typeIconWidth: 13), height: statusHeight), titleHeight: titleHeight, typeIconWidth: 13)
                            let type = layout.typeIcon(size: CGSize(width: 13, height: 12), statusFrame: status)
                            XCTAssertEqual(layout.avatar.size, CGSize(width: 40, height: 40))
                            XCTAssertEqual(layout.avatar.minX, safe + (editing ? 44 : 0) + 16)
                            XCTAssertLessThanOrEqual(layout.avatar.maxX + 12, title.minX)
                            XCTAssertGreaterThanOrEqual(title.width, 0)
                            XCTAssertGreaterThanOrEqual(status.width, 0)
                            XCTAssertLessThanOrEqual(title.maxX + credibilityWidth + 10, date.minX + 0.1)
                            XCTAssertLessThanOrEqual(date.maxY, status.minY)
                            XCTAssertLessThanOrEqual(type.maxX + 6, status.minX + 0.1)
                            XCTAssertLessThanOrEqual(status.maxX, layout.textRight + 0.1)
                            XCTAssertGreaterThanOrEqual(height, 72)
                            XCTAssertLessThanOrEqual(status.maxY + 12, height + 0.1)
                            if !editing {
                                XCTAssertLessThanOrEqual(date.maxX + 8, layout.info.minX + 0.1)
                                XCTAssertFalse(status.intersects(layout.info))
                                XCTAssertEqual(layout.info.maxX, width - safe - 8)
                            }

                        }
                    }
                }
            }
        }
    }

    func testRevealTranslatesEveryElementEquallyWithoutDoubleMovingEditingDates() {
        for editing in [false, true] {
            let base = WegramCallRowLayout(width: 402, height: 72, safeLeft: 16, safeRight: 8, editingOffset: editing ? 44 : 0, revealOffset: 0, editing: editing)
            for offset: CGFloat in [-120, -80, 0, 40] {
                let layout = WegramCallRowLayout(width: 402, height: 72, safeLeft: 16, safeRight: 8, editingOffset: editing ? 44 : 0, revealOffset: offset, editing: editing)
                let titleSize = CGSize(width: 90, height: 21)
                let dateSize = CGSize(width: 48, height: 15)
                let statusSize = CGSize(width: 110, height: 17)
                let baseStatus = base.status(size: statusSize, titleHeight: 21, typeIconWidth: 13)
                let status = layout.status(size: statusSize, titleHeight: 21, typeIconWidth: 13)
                let pairs = [(base.avatar, layout.avatar), (base.info, layout.info), (base.title(size: titleSize), layout.title(size: titleSize)), (base.date(size: dateSize, titleHeight: 21), layout.date(size: dateSize, titleHeight: 21)), (baseStatus, status), (base.typeIcon(size: CGSize(width: 13, height: 12), statusFrame: baseStatus), layout.typeIcon(size: CGSize(width: 13, height: 12), statusFrame: status))]
                for (before, after) in pairs { XCTAssertEqual(after, before.offsetBy(dx: offset, dy: 0)) }
                XCTAssertEqual(layout.dateMaxWidth(credibilityWidth: 20), base.dateMaxWidth(credibilityWidth: 20))
                XCTAssertEqual(layout.statusWidth(typeIconWidth: 0), base.statusWidth(typeIconWidth: 0))
            }
        }
    }

    func testInfoTargetIsFortyFourPointsAndDoesNotExtendIntoTheRowArea() throws {
        let layout = WegramCallRowLayout(width: 402, height: 72, safeLeft: 0, safeRight: 0, editingOffset: 0, revealOffset: 0, editing: false)
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 402, height: 72))
        let button = HighlightableButtonNode()
        button.hitTestSlop = .zero
        let icon = try XCTUnwrap(UIImage(systemName: "info.circle"))
        button.setImage(icon, for: .normal)
        button.contentEdgeInsets = UIEdgeInsets(top: (44 - icon.size.height) / 2, left: (44 - icon.size.width) / 2, bottom: (44 - icon.size.height) / 2, right: (44 - icon.size.width) / 2)
        button.frame = layout.info
        button.addTarget(self, action: #selector(self.infoPressed), forControlEvents: .touchUpInside)
        host.addSubnode(button)
        _ = button.view
        button.recursivelyEnsureDisplaySynchronously(true)
        button.view.layoutIfNeeded()
        XCTAssertEqual(button.frame.size, CGSize(width: 44, height: 44))
        for x: CGFloat in [0.1, 43.9] {
            for y: CGFloat in [0.1, 43.9] { XCTAssertNotNil(button.view.hitTest(CGPoint(x: x, y: y), with: nil)) }
        }
        XCTAssertNil(button.view.hitTest(CGPoint(x: -1, y: 22), with: nil))
        button.sendActions(forControlEvents: .touchUpInside, with: nil)
        XCTAssertEqual(self.infoActions, 1)
        XCTAssertFalse(CGRect(x: 0, y: 0, width: layout.info.minX, height: 72).intersects(button.frame))
        if let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
            let avatar = UIView(frame: layout.avatar)
            avatar.layer.cornerRadius = 4
            host.addSubview(avatar)
            let name = UILabel()
            name.font = .systemFont(ofSize: 17)
            name.text = "组件检查联系人"
            let date = UILabel()
            date.font = .systemFont(ofSize: 12)
            date.text = "星期三"
            let status = UILabel()
            status.font = .systemFont(ofSize: 14)
            status.text = "呼出，2分钟"
            let type = UIImageView(image: UIImage(systemName: "arrow.up.right"))
            for label in [name, date, status] { host.addSubview(label) }
            host.addSubview(type)
            let dateSize = date.sizeThatFits(CGSize(width: layout.dateMaxWidth(credibilityWidth: 0), height: 44))
            let titleSize = name.sizeThatFits(CGSize(width: layout.titleWidth(dateWidth: dateSize.width, credibilityWidth: 0), height: 44))
            name.frame = layout.title(size: titleSize)
            date.frame = layout.date(size: dateSize, titleHeight: titleSize.height)
            status.frame = layout.status(size: status.sizeThatFits(CGSize(width: layout.statusWidth(typeIconWidth: 13), height: 44)), titleHeight: titleSize.height, typeIconWidth: 13)
            type.frame = layout.typeIcon(size: CGSize(width: 13, height: 12), statusFrame: status.frame)
            for dark in [false, true] {
                host.backgroundColor = dark ? UIColor(white: 0.1, alpha: 1) : .white
                avatar.backgroundColor = UIColor(white: dark ? 0.2 : 0.9, alpha: 1)
                name.textColor = dark ? .lightGray : .black
                date.textColor = .gray
                status.textColor = .gray
                type.tintColor = .gray
                let tinted = UIGraphicsImageRenderer(size: icon.size).image { _ in
                    icon.withTintColor(dark ? .lightGray : .gray, renderingMode: .alwaysOriginal).draw(in: CGRect(origin: .zero, size: icon.size))
                }
                button.setImage(tinted, for: .normal)
                button.view.setNeedsLayout()
                button.view.layoutIfNeeded()
                button.recursivelyEnsureDisplaySynchronously(true)
                let image = UIGraphicsImageRenderer(size: host.bounds.size).image { host.layer.render(in: $0.cgContext) }
                try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent(dark ? "call-row-geometry-dark.png" : "call-row-geometry-light.png"))
            }
        }
        button.isUserInteractionEnabled = false
        button.isAccessibilityElement = false
        XCTAssertNil(button.view.hitTest(CGPoint(x: 22, y: 22), with: nil))
        XCTAssertFalse(button.isAccessibilityElement)
    }
}
