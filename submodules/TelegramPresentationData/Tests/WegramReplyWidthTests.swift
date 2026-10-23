import XCTest
import UIKit
import Display
import TelegramPresentationData
import ChatMessageItemCommon

final class WegramReplyWidthTests: XCTestCase {
    func testImageQuoteKeepsMoreOfTheAuthorWithoutLosingTheThumbnail() {
        for width: CGFloat in [120, 180, 280, 500] {
            for status in [false, true] {
                for check in [false, true] {
                    for gift in [false, true] {
                        let layout = WegramReplyAccessoryLayout(hasStatus: status, hasCheck: check, hasGift: gift)
                        let limit = layout.authorMaxWidth(constrainedWidth: width, hasImage: true)
                        let side = layout.thumbnailSide(constrainedWidth: width)
                        let remaining = width - 24 - layout.leadingInset - layout.trailingInset - side
                        XCTAssertEqual(limit, remaining)
                        XCTAssertEqual(side, 32)
                        for fontSize: CGFloat in [14, 28] {
                            let (author, _) = TextNode.asyncLayout(nil)(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "很长的群聊发送者名字 Long Sender Name：", font: .systemFont(ofSize: fontSize), textColor: .gray), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: limit, height: 200), alignment: .natural, cutout: nil, insets: UIEdgeInsets(top: 3, left: 0, bottom: 3, right: 0)))
                            let imageX = 14 + author.size.width + layout.leadingInset
                            let cardWidth = author.size.width + layout.leadingInset + side + 24 + layout.trailingInset
                            XCTAssertLessThanOrEqual(cardWidth, width + 0.5)
                            XCTAssertLessThanOrEqual(imageX + side + 10 + layout.trailingInset, cardWidth + 0.5)
                            XCTAssertGreaterThanOrEqual(imageX - (10 + author.size.width), 4)
                            XCTAssertEqual(author.numberOfLines, limit > 0 ? 1 : 0)
                        }
                    }
                }
            }
        }
        let plain = WegramReplyAccessoryLayout(hasStatus: false, hasCheck: false, hasGift: false)
        XCTAssertGreaterThan(plain.authorMaxWidth(constrainedWidth: 280, hasImage: true), plain.authorMaxWidth(constrainedWidth: 280, hasImage: false))
        XCTAssertEqual(plain.authorMaxWidth(constrainedWidth: 280, hasImage: false), 126)
    }

    func testImageQuoteAuthorAlignsToTheThumbnailTopAndLargeTypeStillFits() {
        let layout = WegramReplyAccessoryLayout(hasStatus: false, hasCheck: false, hasGift: false)
        for fontSize: CGFloat in [14, 28, 56] {
            let (author, _) = TextNode.asyncLayout(nil)(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "张思远：", font: .systemFont(ofSize: fontSize), textColor: .gray), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 250, height: 200), alignment: .natural, cutout: nil, insets: UIEdgeInsets(top: 3, left: 0, bottom: 3, right: 0)))
            let height = layout.cardHeight(titleHeight: author.size.height, textHeight: 0, thumbnailSide: 32)
            let authorY = layout.authorOriginY(cardHeight: height, titleHeight: author.size.height, hasImage: true)
            let imageY = floor((height - 32) / 2)
            XCTAssertEqual(authorY + 3, 8)
            XCTAssertGreaterThanOrEqual(imageY, 8)
            XCTAssertLessThanOrEqual(authorY + author.size.height, height - 5)
            XCTAssertLessThanOrEqual(imageY + 32, height - 8)
            if fontSize == 14 {
                XCTAssertEqual(height, 48)
                XCTAssertEqual(authorY + 3, imageY)
            }
            let textHeight = layout.cardHeight(titleHeight: author.size.height, textHeight: author.size.height, thumbnailSide: nil)
            XCTAssertEqual(textHeight, max(32, author.size.height + 6))
            XCTAssertEqual(layout.authorOriginY(cardHeight: textHeight, titleHeight: author.size.height, hasImage: false), floor((textHeight - author.size.height) / 2))
        }
    }

    func testDateLabelFitsTheSafeWidthAndItsReservedHeaderAtLargeFonts() throws {
        for fontSize: CGFloat in [14, 28, 42, 56] {
            let font = UIFont.systemFont(ofSize: fontSize)
            let reserved = WegramMessageDateLayout.headerHeight(labelHeight: WegramMessageDateTextLayout.labelHeight(font: font))
            for width: CGFloat in [240, 320, 402, 874] {
                let left: CGFloat = 24
                let right: CGFloat = 8
                let textWidth = WegramMessageDateLayout.textWidth(width: width, leftInset: left, rightInset: right)
                for text in ["00:08", "昨天 19:48", "星期三 20:57", "2025年10月10日 12:19"] {
                    let (label, _) = TextNode.asyncLayout(nil)(TextNodeLayoutArguments(attributedString: NSAttributedString(string: text, font: font, textColor: .gray), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: .zero))
                    XCTAssertLessThanOrEqual(label.size.width + 12, width - left - right)
                    let actualHeight = WegramMessageDateLayout.cardHeight(labelHeight: label.size.height)
                    XCTAssertLessThanOrEqual(actualHeight + 14, reserved)
                    XCTAssertGreaterThanOrEqual(actualHeight, label.size.height + 2)
                    if fontSize == 14 { XCTAssertEqual(reserved, 34) }
                    else { XCTAssertGreaterThan(reserved, 34) }
                }
            }
        }
        XCTAssertEqual(WegramMessageDateLayout.textWidth(width: 20, leftInset: 12, rightInset: 12), 0)
        if let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
            let canvas = UIView(frame: CGRect(x: 0, y: 0, width: 220, height: 120))
            canvas.backgroundColor = UIColor(rgb: 0x151515)
            for (index, colors) in [(UIColor(rgb: 0x242424), UIColor(rgb: 0x999999)), (UIColor(rgb: 0x202020), UIColor.white.withAlphaComponent(0.5)), (UIColor(rgb: 0x272727), UIColor.white.withAlphaComponent(0.5))].enumerated() {
                let background = UIView(frame: CGRect(x: 6, y: CGFloat(index) * 40 + 8, width: 208, height: 24))
                background.backgroundColor = colors.0
                background.layer.cornerRadius = 3
                canvas.addSubview(background)
                let node = TextNode()
                node.displaysAsynchronously = false
                let text = NSAttributedString(string: "00:08  张思远：", font: Font.regular(14), textColor: colors.1)
                let (layout, apply) = TextNode.asyncLayout(node)(TextNodeLayoutArguments(attributedString: text, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 196, height: 24), alignment: .natural, cutout: nil, insets: .zero))
                let _ = apply()
                background.addSubnode(node)
                node.frame = CGRect(x: 6, y: floor((24 - layout.size.height) / 2), width: layout.size.width, height: layout.size.height)
                let _ = node.view
                node.setNeedsDisplayAtScale(3)
                node.recursivelyEnsureDisplaySynchronously(true)
            }
            let format = UIGraphicsImageRendererFormat(); format.scale = 3
            let image = UIGraphicsImageRenderer(size: canvas.bounds.size, format: format).image { canvas.layer.render(in: $0.cgContext) }
            try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("wegram-date-color-comparison.png"))
        }
    }

    func testNarrowImageQuotesKeepTheirMeasuredContentInsideTheCard() {
        for width: CGFloat in [0, 20, 40, 56, 80] {
            let layout = WegramReplyAccessoryLayout(hasStatus: false, hasCheck: false, hasGift: false)
            let author = layout.authorMaxWidth(constrainedWidth: width, hasImage: true)
            let image = layout.thumbnailSide(constrainedWidth: width)
            XCTAssertGreaterThanOrEqual(author, 0)
            XCTAssertGreaterThanOrEqual(image, 0)
            XCTAssertLessThanOrEqual(author + image, max(0, width - 24))
        }
    }
}
