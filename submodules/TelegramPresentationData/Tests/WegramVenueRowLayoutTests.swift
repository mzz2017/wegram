import XCTest
import UIKit
import Display
import TelegramCore
import ItemListVenueItem

final class WegramVenueRowLayoutTests: XCTestCase {
    func testActualTextLeavesSpaceForSelectionAndOriginalInfoAtLargeType() {
        for width: CGFloat in [100, 250, 402] {
            for font: CGFloat in [17, 34, 56] {
                for hasInfo in [false, true] {
                    let budget = WegramVenueRowLayout.textWidth(width: width, leftInset: 0, rightInset: 0, hasInfo: hasInfo)
                    let (title, _) = TextNode.asyncLayout(nil)(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "上海巨鹿花园别墅 长名字", font: .systemFont(ofSize: font), textColor: .black), maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: budget, height: .greatestFiniteMagnitude)))
                    let (address, _) = TextNode.asyncLayout(nil)(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "4.3km | 上海市静安区巨鹿路889号", font: .systemFont(ofSize: floor(font * 13 / 17)), textColor: .gray), maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: budget, height: .greatestFiniteMagnitude)))
                    let row = WegramVenueRowLayout(width: width, leftInset: 0, rightInset: 0, titleSize: title.size, addressSize: address.size, hasInfo: hasInfo)
                    for frame in [row.titleFrame, row.addressFrame, row.checkFrame, row.separatorFrame] {
                        XCTAssertGreaterThanOrEqual(frame.minX, 0)
                        XCTAssertLessThanOrEqual(frame.maxX, width)
                        XCTAssertGreaterThanOrEqual(frame.minY, 0)
                        XCTAssertLessThanOrEqual(frame.maxY, row.height)
                    }
                    XCTAssertGreaterThanOrEqual(row.addressFrame.minY - row.titleFrame.maxY, 4)
                    if !row.titleFrame.isEmpty { XCTAssertGreaterThanOrEqual(row.checkFrame.minX - row.titleFrame.maxX, hasInfo ? 52 : 8) }
                    if !row.addressFrame.isEmpty { XCTAssertGreaterThanOrEqual(row.checkFrame.minX - row.addressFrame.maxX, hasInfo ? 52 : 8) }
                    XCTAssertGreaterThanOrEqual(row.height, 76)
                    if font == 56 && width >= 250 { XCTAssertGreaterThan(row.height, 76) }
                }
            }
        }
        let row = WegramVenueRowLayout(width: 402, leftInset: 44, rightInset: 44, titleSize: CGSize(width: 80, height: 20), addressSize: CGSize(width: 100, height: 16), hasInfo: true)
        XCTAssertEqual(row.titleFrame.minX, 54)
        XCTAssertEqual(row.checkFrame.maxX, 342)
        XCTAssertEqual(row.separatorFrame.maxX, 348)
    }

    func testSearchHighlightsEveryMatchWithUTF16RangesAndKeepsOtherText() {
        let title = "📍巨鹿路，巨鹿花园 ROAD road"
        let chinese = WegramVenueRowLayout.title(title, query: "巨鹿", font: .systemFont(ofSize: 17), color: .black)
        XCTAssertEqual(chinese.string, title)
        let green = UIColor(rgb: 0x07c160)
        for offset in [2, 6] { XCTAssertTrue((chinese.attribute(.foregroundColor, at: offset, effectiveRange: nil) as? UIColor)?.isEqual(green) == true) }
        XCTAssertTrue((chinese.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor)?.isEqual(UIColor.black) == true)
        let english = WegramVenueRowLayout.title("ROAD road", query: "road", font: .systemFont(ofSize: 17), color: .black)
        for offset in [0, 5] { XCTAssertTrue((english.attribute(.foregroundColor, at: offset, effectiveRange: nil) as? UIColor)?.isEqual(green) == true) }
        let addressText = "4.3km | 上海市静安区巨鹿路889号"
        let address = WegramVenueRowLayout.title(addressText, query: "巨鹿", font: .systemFont(ofSize: 13), color: .gray)
        let addressMatch = (addressText as NSString).range(of: "巨鹿")
        XCTAssertEqual(address.string, addressText)
        XCTAssertTrue((address.attribute(.foregroundColor, at: addressMatch.location, effectiveRange: nil) as? UIColor)?.isEqual(green) == true)
        XCTAssertTrue((address.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor)?.isEqual(UIColor.gray) == true)
        XCTAssertEqual((address.attribute(.font, at: addressMatch.location, effectiveRange: nil) as? UIFont)?.pointSize, 13)
        for query: String? in [nil, "", "不存在"] {
            let plain = WegramVenueRowLayout.title(title, query: query, font: .systemFont(ofSize: 17), color: .black)
            XCTAssertTrue((plain.attribute(.foregroundColor, at: 2, effectiveRange: nil) as? UIColor)?.isEqual(UIColor.black) == true)
        }
    }

    func testPlaceIdentityIncludesCoordinateAndProviderForSelectionAndDeduplication() {
        func place(_ latitude: Double, _ provider: String?, _ id: String?, title: String = "同名地点") -> TelegramMediaMap {
            return TelegramMediaMap(latitude: latitude, longitude: 121.4, heading: nil, accuracyRadius: nil, venue: MapVenue(title: title, address: "上海", provider: provider, id: id, type: nil))
        }
        let selected = place(31.2, "one", "42")
        XCTAssertTrue(WegramLocationPickerSelection.matches(selected, place(31.2, "one", "42")))
        XCTAssertFalse(WegramLocationPickerSelection.matches(selected, place(31.3, "one", "42")))
        XCTAssertFalse(WegramLocationPickerSelection.matches(selected, place(31.2, "two", "42")))
        XCTAssertFalse(WegramLocationPickerSelection.matches(selected, place(31.2, "one", "43")))
        XCTAssertFalse(WegramLocationPickerSelection.matches(place(31.2, nil, nil), place(31.2, nil, nil, title: "另一个没有ID的地点")))
    }
    func testRowIdentitySeparatesMissingIdsAndContentRefreshIncludesTypeAndTitle() {
        func place(_ title: String, _ type: String?, provider: String = "one") -> TelegramMediaMap {
            return TelegramMediaMap(latitude: 31.2, longitude: 121.4, heading: nil, accuracyRadius: nil, venue: MapVenue(title: title, address: "上海", provider: provider, id: "42", type: type))
        }
        let current = place("家", "home")
        XCTAssertEqual(WegramLocationPickerSelection.rowIdentity(current, index: 0), WegramLocationPickerSelection.rowIdentity(place("家", "home"), index: 0))
        XCTAssertNotEqual(WegramLocationPickerSelection.rowIdentity(nil, index: 0), WegramLocationPickerSelection.rowIdentity(nil, index: 1))
        XCTAssertNotEqual(WegramLocationPickerSelection.rowIdentity(current, index: 0), WegramLocationPickerSelection.rowIdentity(place("家", "home", provider: "two"), index: 0))
        XCTAssertTrue(WegramLocationPickerSelection.sameContent(current, place("家", "home")))
        XCTAssertFalse(WegramLocationPickerSelection.sameContent(current, place("公司", "home")))
        XCTAssertFalse(WegramLocationPickerSelection.sameContent(current, place("家", "work")))
        XCTAssertFalse(WegramLocationPickerSelection.sameContent(current, nil))
        XCTAssertTrue(WegramLocationPickerSelection.sameContent(nil, nil))
    }

}
