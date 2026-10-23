import XCTest
import UIKit
import ChatHistoryEntry

final class WegramMessageTimeZoneTests: XCTestCase {
    func testTimeZoneNotificationsOnlyInvalidateAfterAnActualChangeAndReleaseObservers() throws {
        let center = NotificationCenter()
        var zone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        var updates = 0
        var observer: WegramMessageTimeZoneObserver? = WegramMessageTimeZoneObserver(notificationCenter: center, timeZone: { zone }, updated: { updates += 1 })
        weak var weakObserver = observer
        let notifications = [Notification.Name.NSSystemTimeZoneDidChange, UIApplication.significantTimeChangeNotification, UIApplication.didBecomeActiveNotification]
        for name in notifications { center.post(name: name, object: nil) }
        XCTAssertEqual(updates, 0, "Returning to the foreground in the same time zone must not reproject history")
        zone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        for name in notifications { center.post(name: name, object: nil) }
        XCTAssertEqual(updates, 1)
        zone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        center.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        XCTAssertEqual(updates, 2, "Foregrounding must recover a time zone change missed in the background")
        observer = nil
        XCTAssertNil(weakObserver)
        zone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        for name in notifications { center.post(name: name, object: nil) }
        XCTAssertEqual(updates, 2)
    }

    func testSameMessagesRegroupAtTheNewLocalMidnightWithoutChangingTheirTimestamps() throws {
        let center = NotificationCenter()
        var zone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let formatter = ISO8601DateFormatter()
        let first = Int32(try XCTUnwrap(formatter.date(from: "2026-10-20T23:58:00Z")).timeIntervalSince1970)
        let second = first + 240
        let spans = [first...first, second...second]
        func calendar() -> Calendar {
            var value = Calendar(identifier: .gregorian)
            value.timeZone = zone
            return value
        }
        var groups = WegramMessageTime.groupStarts(for: spans, calendar: calendar())
        let now = try XCTUnwrap(formatter.date(from: "2026-10-21T00:03:00Z"))
        var label = WegramMessageTime.label(timestamp: first, now: now, calendar: calendar())
        XCTAssertEqual(groups, [first, second])
        XCTAssertEqual(label, "昨天 23:58")
        let observer = WegramMessageTimeZoneObserver(notificationCenter: center, timeZone: { zone }, updated: {
            groups = WegramMessageTime.groupStarts(for: spans, calendar: calendar())
            label = WegramMessageTime.label(timestamp: first, now: now, calendar: calendar())
        })
        zone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        center.post(name: .NSSystemTimeZoneDidChange, object: nil)
        XCTAssertEqual(groups, [first, first])
        XCTAssertEqual(label, "07:58")
        XCTAssertEqual(spans, [first...first, second...second])
        withExtendedLifetime(observer) {}
    }
}
