import XCTest
import UIKit
import Display
import TelegramCore
import ChatMessageItemCommon
import MessageInlineBlockBackgroundView

final class WegramLinkPreviewLayoutTests: XCTestCase {
    private func content(url: String = "https://example.com/article", type: String? = "article", title: String? = "分享标题", text: String? = "摘要", embedUrl: String? = nil) -> TelegramMediaWebpageLoadedContent {
        return TelegramMediaWebpageLoadedContent(url: url, displayUrl: url, hash: 0, type: type, websiteName: "来源", title: title, text: text, embedUrl: embedUrl, embedType: nil, embedSize: nil, duration: nil, author: nil, isMediaLargeByDefault: nil, imageIsVideoCover: false, image: nil, file: nil, story: nil, attributes: [], instantPage: nil)
    }

    func testOnlyOrdinaryWebArticlesAndExactStandaloneURLsUseCompactProjection() {
        let article = self.content()
        XCTAssertTrue(WegramLinkPreviewLayout.supports(article))
        XCTAssertTrue(WegramLinkPreviewLayout.supports(self.content(type: nil)))
        XCTAssertTrue(WegramLinkPreviewLayout.hidesURLText(" \n\(article.url)\n", content: article, forceLargeMedia: nil))
        XCTAssertFalse(WegramLinkPreviewLayout.hidesURLText("说明：\(article.url)", content: article, forceLargeMedia: nil))
        XCTAssertFalse(WegramLinkPreviewLayout.hidesURLText("https://other.example/", content: article, forceLargeMedia: nil))
        XCTAssertFalse(WegramLinkPreviewLayout.hidesURLText(article.url, content: article, forceLargeMedia: true))
        for type in ["telegram_channel", "telegram_theme", "telegram_album", "photo", "video"] {
            XCTAssertFalse(WegramLinkPreviewLayout.supports(self.content(type: type)))
        }
        for url in ["tg://resolve?domain=example", "file:///tmp/example", "https://t.me/example", "https://telegram.me/example", "https://telegram.dog/example", "no host"] {
            let special = self.content(url: url)
            XCTAssertFalse(WegramLinkPreviewLayout.supports(special), url)
            XCTAssertFalse(WegramLinkPreviewLayout.hidesURLText(url, content: special, forceLargeMedia: nil), url)
        }
        XCTAssertFalse(WegramLinkPreviewLayout.supports(self.content(embedUrl: "https://example.com/player")))
        XCTAssertFalse(WegramLinkPreviewLayout.supports(self.content(title: nil, text: nil)))
        XCTAssertTrue(WegramLinkPreviewLayout.supports(self.content(title: nil)))
    }

    func testRealTextLayoutsKeepFullWidthTitleSummaryBesideThumbnailAndSourceBelow() {
        func text(_ value: String, width: CGFloat, font: CGFloat, lines: Int) -> CGSize {
            return TextNode.asyncLayout(nil)(TextNodeLayoutArguments(attributedString: NSAttributedString(string: value, font: .systemFont(ofSize: font), textColor: .black), maximumNumberOfLines: lines, truncationType: .end, constrainedSize: CGSize(width: max(0, width), height: .greatestFiniteMagnitude))).0.size
        }
        for width: CGFloat in [40, 100, 250, 400] {
            for font: CGFloat in [14, 17, 34, 56] {
                for imageSize: CGSize? in [nil, CGSize(width: 1600, height: 1000), CGSize(width: 100, height: 400)] {
                    let contentWidth = max(0, width - 20)
                    let thumbnail = WegramLinkPreviewLayout.thumbnailSize(imageSize: imageSize, contentWidth: contentWidth)
                    for (heading, description) in [("美国肯德基将换百事可乐为可口可乐", "UP主：示例来源\n播放：20.1万\n第三行摘要"), ("只有标题", ""), ("", "只有正文摘要")] {
                        let title = text(heading, width: contentWidth, font: font, lines: 2)
                        let summary = text(description, width: contentWidth - (thumbnail.width > 0 ? thumbnail.width + 12 : 0), font: floor(font * 14 / 17), lines: 3)
                        let source = text("来源网站名称", width: contentWidth, font: floor(font * 12 / 17), lines: 1)
                        let layout = WegramLinkPreviewLayout(width: width, titleSize: title, summarySize: summary, sourceSize: source, thumbnailSize: thumbnail)
                        for frame in [layout.titleFrame, layout.summaryFrame, layout.sourceFrame, layout.thumbnailFrame] {
                            XCTAssertGreaterThanOrEqual(frame.minX, 0)
                            XCTAssertLessThanOrEqual(frame.maxX, width)
                            XCTAssertGreaterThanOrEqual(frame.minY, 0)
                            XCTAssertLessThanOrEqual(frame.maxY, layout.height)
                        }
                        XCTAssertEqual(layout.titleFrame.minY, 12)
                        XCTAssertGreaterThanOrEqual(layout.summaryFrame.minY, layout.titleFrame.maxY)
                        if !layout.summaryFrame.isEmpty && !layout.thumbnailFrame.isEmpty {
                            XCTAssertFalse(layout.summaryFrame.intersects(layout.thumbnailFrame))
                            XCTAssertGreaterThanOrEqual(layout.thumbnailFrame.minX - layout.summaryFrame.maxX, 12)
                        }
                        XCTAssertGreaterThanOrEqual(layout.sourceFrame.minY, max(layout.summaryFrame.maxY, layout.thumbnailFrame.maxY) + 20)
                        XCTAssertEqual(layout.height - layout.sourceFrame.maxY, 10)
                    }
                }
            }
        }
        XCTAssertEqual(WegramLinkPreviewLayout.thumbnailSize(imageSize: CGSize(width: 1600, height: 1000), contentWidth: 230), CGSize(width: 54, height: 33))
        XCTAssertEqual(WegramLinkPreviewLayout.thumbnailSize(imageSize: .zero, contentWidth: 230), .zero)
    }

    func testPlainCardBackgroundKeepsHitAreaAndProgressWithoutDecorativeFillOrLine() {
        let view = MessageInlineBlockBackgroundView(frame: CGRect(x: 0, y: 0, width: 250, height: 146))
        view.update(size: view.bounds.size, isTransparent: false, primaryColor: .blue, secondaryColor: nil, thirdColor: nil, backgroundColor: nil, pattern: nil, animation: .None)
        let decorations = view.subviews
        XCTAssertEqual(decorations.count, 2)
        XCTAssertTrue(decorations.allSatisfy { !$0.isHidden })
        view.displaysFillAndLine = false
        XCTAssertTrue(decorations.allSatisfy { $0.isHidden })
        XCTAssertFalse(view.isHidden)
        XCTAssertTrue(view.point(inside: CGPoint(x: 125, y: 73), with: nil))
        view.displayProgress = true
        XCTAssertTrue(view.displayProgress)
        XCTAssertTrue(decorations.allSatisfy { $0.isHidden })
        XCTAssertTrue(view.subviews.contains { candidate in !decorations.contains(where: { $0 === candidate }) && !candidate.isHidden }, "The original progress overlay remains visible")
        view.displayProgress = false
        view.displaysFillAndLine = true
        XCTAssertTrue(decorations.allSatisfy { !$0.isHidden }, "Reusing the view for the original preview restores its decoration")
    }

}
