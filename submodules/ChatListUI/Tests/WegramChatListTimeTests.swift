import XCTest
import Foundation
@testable import ChatListUI

final class WegramChatListTimeTests: XCTestCase {
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
    private func label(_ value: String, now: String = "2026-10-19T22:32:00+08:00", zone: String = "Asia/Singapore", locale: String = "en_SG") -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return WegramChatListTime.label(timestamp: Int32(self.date(value).timeIntervalSince1970), now: self.date(now), calendar: calendar, locale: Locale(identifier: locale))
    }
    func testReferenceListUsesTimeFullWeekdayMonthDayAndRegionalOlderYear() {
        XCTAssertEqual(self.label("2026-10-19T21:46:00+08:00"), "21:46")
        XCTAssertEqual(self.label("2026-10-14T22:00:00+08:00"), "星期三")
        XCTAssertEqual(self.label("2026-10-11T12:00:00+08:00"), "10月11日")
        XCTAssertEqual(self.label("2026-10-10T12:00:00+08:00"), "10月10日")
        XCTAssertEqual(self.label("2025-01-09T12:00:00+08:00"), "9 Jan 2025")
    }
    func testYesterdayAndWeekBoundaryUseCalendarDaysAcrossMidnightAndNewYear() {
        XCTAssertEqual(self.label("2026-10-18T23:59:00+08:00", now: "2026-10-19T00:01:00+08:00"), "昨天 23:59")
        XCTAssertEqual(self.label("2026-12-31T23:59:00+08:00", now: "2027-01-01T00:01:00+08:00"), "昨天 23:59")
        XCTAssertEqual(self.label("2026-10-13T00:00:00+08:00"), "星期二")
        XCTAssertEqual(self.label("2026-10-12T23:59:00+08:00"), "10月12日")
        XCTAssertEqual(self.label("2026-10-20T00:00:00+08:00"), "10月20日")
    }
    func testTimezoneAndDSTDoNotUseElapsedTwentyFourHourDays() {
        XCTAssertEqual(self.label("2026-03-08T01:30:00-08:00", now: "2026-03-09T00:30:00-07:00", zone: "America/Los_Angeles"), "昨天 01:30")
        XCTAssertEqual(self.label("2026-10-18T23:30:00+00:00", now: "2026-10-19T00:01:00+00:00", zone: "Asia/Singapore"), "07:30")
        XCTAssertEqual(self.label("2026-10-18T23:30:00+00:00", now: "2026-10-19T00:01:00+00:00", zone: "UTC"), "昨天 23:30")
        XCTAssertNotEqual(self.label("2025-01-09T12:00:00+08:00", locale: "zh_CN"), "9 Jan 2025")
    }
}
