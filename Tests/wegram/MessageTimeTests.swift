import Foundation

@main
struct MessageTimeTests {
    static func main() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        func date(_ text: String, calendar: Calendar) -> Date {
            let formatter = ISO8601DateFormatter()
            return formatter.date(from: text)!
        }
        func timestamp(_ text: String) -> Int32 { Int32(date(text, calendar: calendar).timeIntervalSince1970) }
        let now = date("2026-10-18T22:47:00+08:00", calendar: calendar)
        var failures: [String] = []
        func check(_ actual: String, _ expected: String, _ behavior: String) {
            if actual != expected { failures.append("\(behavior): expected \(expected), got \(actual)") }
        }
        check(WegramMessageTime.label(timestamp: timestamp("2026-10-18T00:08:00+08:00"), now: now, calendar: calendar), "00:08", "today uses only 24-hour time")
        check(WegramMessageTime.label(timestamp: timestamp("2026-10-17T19:48:00+08:00"), now: now, calendar: calendar), "昨天 19:48", "yesterday includes time")
        check(WegramMessageTime.label(timestamp: timestamp("2026-10-14T20:57:00+08:00"), now: now, calendar: calendar), "星期三 20:57", "recent dates use weekday")
        check(WegramMessageTime.label(timestamp: timestamp("2026-10-10T12:19:00+08:00"), now: now, calendar: calendar), "10月10日 12:19", "older dates include month and day")
        let newYear = date("2027-01-01T00:02:00+08:00", calendar: calendar)
        check(WegramMessageTime.label(timestamp: timestamp("2026-12-31T23:59:00+08:00"), now: newYear, calendar: calendar), "昨天 23:59", "yesterday survives year boundary")
        check(WegramMessageTime.label(timestamp: timestamp("2025-10-10T12:19:00+08:00"), now: now, calendar: calendar), "2025年10月10日 12:19", "old years remain distinguishable")
        func checkGroups(_ times: [Int32], _ expected: [Int32], _ behavior: String) {
            let actual = WegramMessageTime.groupStarts(for: times.map { $0...$0 }, calendar: calendar)
            if actual != expected { failures.append("\(behavior): expected \(expected), got \(actual)") }
        }
        let base = timestamp("2026-10-18T10:00:00+08:00")
        checkGroups([base+299, base+301], [base+299, base+299], "crossing a time bucket does not create a separator")
        checkGroups([base, base+240, base+480], [base, base, base], "continuous four-minute messages stay together")
        checkGroups([base, base+300], [base, base+300], "exactly five minutes starts a new group")
        let midnight = timestamp("2026-10-19T00:00:00+08:00")
        checkGroups([midnight-1, midnight+1], [midnight-1, midnight+1], "local midnight always separates dates")
        let album = WegramMessageTime.groupStarts(for: [base...(base+240), (base+480)...(base+480)], calendar: calendar)
        if album != [base, base] { failures.append("album's last message bridges the following message") }
        let beforeDeletion = WegramMessageTime.groupStarts(for: [base...base, (base+600)...(base+600)], calendar: calendar)
        let afterInsertion = WegramMessageTime.groupStarts(for: [base...base, (base+240)...(base+240), (base+480)...(base+480), (base+600)...(base+600)], calendar: calendar)
        if beforeDeletion != [base, base+600] || afterInsertion != [base, base, base, base] { failures.append("inserting bridging messages merges two existing groups") }
        let spanningAlbum = WegramMessageTime.groupStarts(for: [(midnight-60)...(midnight+60), (midnight+120)...(midnight+120)], calendar: calendar)
        if spanningAlbum != [midnight-60, midnight+120] { failures.append("a cross-midnight album must not pull later messages into yesterday's group") }
        check(WegramMessageTime.label(timestamp: timestamp("2026-10-18T00:08:00+08:00"), now: date("2026-10-19T00:01:00+08:00", calendar: calendar), calendar: calendar), "昨天 00:08", "refreshing the same timestamp after midnight updates its relative label")
        var losAngeles = calendar
        losAngeles.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        check(WegramMessageTime.label(timestamp: timestamp("2026-03-08T01:30:00-08:00"), now: date("2026-03-09T00:30:00-07:00", calendar: losAngeles), calendar: losAngeles), "昨天 01:30", "DST yesterday uses local calendar dates")
        if !failures.isEmpty {
            failures.forEach { FileHandle.standardError.write(Data(($0+"\n").utf8)) }
            exit(1)
        }
        print("Message time behavior checks passed")
    }
}
