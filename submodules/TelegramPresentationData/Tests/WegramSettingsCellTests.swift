import XCTest
import UIKit
import AvatarNode

final class WegramSettingsCellTests: XCTestCase {
    func testAvatarAndQrRowsReserveSpaceAndRestoreTheirReusableTextLayout() throws {
        let cell = WegramSettingsCell()
        cell.frame = CGRect(x: 0, y: 0, width: 402, height: 88)
        cell.textLabel?.text = "头像"
        cell.textLabel?.font = .systemFont(ofSize: 17)
        let avatar = UIView()
        avatar.backgroundColor = .green
        cell.avatarContent = avatar
        cell.layoutIfNeeded()
        XCTAssertEqual(avatar.frame.size, CGSize(width: 64, height: 64))
        XCTAssertEqual(avatar.frame.maxX, cell.contentView.bounds.width - 42)
        XCTAssertEqual(avatar.frame.minY, 12)
        XCTAssertLessThanOrEqual(cell.textLabel!.frame.maxX, avatar.frame.minX - 16)
        XCTAssertGreaterThanOrEqual(cell.bounds.height, 44)
        let icon = UIImage(systemName: "qrcode")
        XCTAssertNotNil(icon)
        cell.avatarContent = nil
        cell.valueIcon.image = icon
        cell.frame.size.height = 56
        cell.setNeedsLayout()
        cell.layoutIfNeeded()
        XCTAssertNil(avatar.superview)
        XCTAssertEqual(cell.valueIcon.bounds.size, CGSize(width: 24, height: 24))
        XCTAssertLessThanOrEqual(cell.textLabel!.frame.maxX, cell.valueIcon.frame.minX - 16)
        cell.valueIcon.image = nil
        cell.detailTextLabel?.text = "A real account name"
        cell.setNeedsLayout()
        cell.layoutIfNeeded()
        XCTAssertLessThanOrEqual(cell.textLabel!.frame.maxX, cell.detailTextLabel!.frame.minX)
        XCTAssertLessThanOrEqual(cell.detailTextLabel!.frame.maxX, cell.arrow.frame.minX - 12)
    }

    func testLargeAvatarAndSmallWidthRemainInsideTheCellWithoutOverlappingTheTitle() {
        for width: CGFloat in [320, 402, 720] {
            let cell = WegramSettingsCell()
            cell.frame = CGRect(x: 0, y: 0, width: width, height: 152)
            cell.textLabel?.text = "Profile photo with a long localized title"
            cell.textLabel?.font = .systemFont(ofSize: 34)
            cell.avatarContent = UIView()
            cell.layoutIfNeeded()
            let avatar = cell.avatarContent!
            XCTAssertGreaterThanOrEqual(avatar.frame.minX, 16)
            XCTAssertLessThanOrEqual(avatar.frame.maxX, cell.arrow.frame.minX - 12)
            XCTAssertLessThanOrEqual(cell.textLabel!.frame.maxX, avatar.frame.minX - 16)
            XCTAssertEqual(avatar.frame.height, 128)
        }
    }

    func testAvatarRowSizesTheActualNodeContentsWhenTheFontSizeChanges() {
        let cell = WegramSettingsCell()
        let avatar = AvatarNode(font: .systemFont(ofSize: 26))
        cell.avatarLayout = { [weak avatar] size in avatar?.updateSize(size: size) }
        cell.avatarContent = avatar.view
        for side: CGFloat in [64, 128, 64] {
            cell.frame = CGRect(x: 0, y: 0, width: 402, height: side + 24)
            cell.setNeedsLayout()
            cell.layoutIfNeeded()
            XCTAssertEqual(avatar.subnodes?.first?.bounds.size, CGSize(width: side, height: side), "Only the outer view resized; actual avatar contents remain empty or stale")
        }
    }

    func testLeadingIconReservesTheWeChatInsetAndOrdinaryRowsRestoreTheirLayout() throws {
        let cell = WegramSettingsCell()
        cell.frame = CGRect(x: 0, y: 0, width: 402, height: 56)
        cell.textLabel?.text = "Services"
        cell.imageView?.image = UIImage(systemName: "star")
        cell.layoutIfNeeded()
        XCTAssertEqual(cell.imageView?.frame.minX, 16)
        XCTAssertEqual(cell.imageView?.frame.size, CGSize(width: 24, height: 24))
        XCTAssertEqual(cell.textLabel?.frame.minX, 56)
        XCTAssertLessThanOrEqual(cell.textLabel!.frame.maxX, cell.arrow.frame.minX - 12)
        cell.imageView?.image = nil
        cell.setNeedsLayout()
        cell.layoutIfNeeded()
        XCTAssertEqual(cell.textLabel?.frame.minX, 16)
    }

}
