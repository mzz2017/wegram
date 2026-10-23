import XCTest
import UIKit
import Display

final class WegramQrCardTests: XCTestCase {
    func testNameAvatarCodeAndCaptionRemainSeparatedAtLargeTextSizes() {
        for width: CGFloat in [280, 335, 360] {
            for font: CGFloat in [17, 34] {
                for temporary in [false, true] {
                    let card = WegramQrCardView()
                    card.update(name: "很长的真实名字 A long account name 🦆", address: "actual_username", chinese: true, fontSize: font, temporary: temporary)
                    let height = card.layoutCard(width: width)
                    card.frame = CGRect(x: 0, y: 0, width: width, height: height)
                    XCTAssertTrue(card.bounds.contains(card.avatarFrame))
                    XCTAssertTrue(card.bounds.contains(card.codeFrame))
                    XCTAssertEqual(card.codeFrame.width, card.codeFrame.height)
                    XCTAssertGreaterThanOrEqual(card.codeFrame.width, 216)
                    XCTAssertGreaterThanOrEqual(card.nameLabel.frame.minX, card.avatarFrame.maxX + 16)
                    XCTAssertLessThanOrEqual(card.addressLabel.frame.maxX, width - 24)
                    XCTAssertLessThanOrEqual(max(card.avatarFrame.maxY, card.addressLabel.frame.maxY), card.codeFrame.minY - 24)
                    XCTAssertGreaterThanOrEqual(card.hintLabel.frame.minY, card.codeFrame.maxY + 16)
                    XCTAssertLessThanOrEqual(card.hintLabel.frame.maxY + 28, height)
                    XCTAssertEqual(card.countdownFrame.height, temporary ? 28 : 0)
                }
            }
        }
    }

    func testEmptyUsernameDoesNotSubstituteAPhoneNumberAndRefreshKeepsRealNameCase() {
        let card = WegramQrCardView()
        card.update(name: "Alice 陈", address: "", chinese: true, fontSize: 17, temporary: false)
        XCTAssertTrue(card.addressLabel.isHidden)
        XCTAssertNil(card.addressLabel.text)
        XCTAssertEqual(card.nameLabel.text, "Alice 陈")
        card.update(name: "Alice 陈", address: "Alice_Handle", chinese: false, fontSize: 17, temporary: true)
        XCTAssertFalse(card.addressLabel.isHidden)
        XCTAssertEqual(card.addressLabel.text, "@Alice_Handle")
        XCTAssertEqual(card.hintLabel.text, "This QR code updates automatically")
    }

    func testTemporaryExportFileNamesNeverRevealThePrivatePhoneOrAddress() {
        XCTAssertEqual(WegramQrCardView.exportFileName(addressName: nil, phone: "15550001234", temporary: true), "contact-qr")
        XCTAssertEqual(WegramQrCardView.exportFileName(addressName: "PrivateHandle", phone: "15550001234", temporary: true), "contact-qr")
        XCTAssertEqual(WegramQrCardView.exportFileName(addressName: "PublicHandle", phone: "15550001234", temporary: false), "t_me-PublicHandle")
        XCTAssertEqual(WegramQrCardView.exportFileName(addressName: nil, phone: "15550001234", temporary: false), "t_me-15550001234")
        XCTAssertEqual(WegramQrCardView.exportFileName(addressName: nil, phone: "", temporary: false), "t_me-")
    }

    func testTemporarySharingRequiresAnUnexpiredRealToken() {
        XCTAssertTrue(WegramQrCardView.canShare(temporary: false, tokenExpires: nil, now: 100))
        XCTAssertFalse(WegramQrCardView.canShare(temporary: true, tokenExpires: nil, now: 100))
        XCTAssertFalse(WegramQrCardView.canShare(temporary: true, tokenExpires: 99, now: 100))
        XCTAssertFalse(WegramQrCardView.canShare(temporary: true, tokenExpires: 100, now: 100))
        XCTAssertTrue(WegramQrCardView.canShare(temporary: true, tokenExpires: 101, now: 100))
    }

}
