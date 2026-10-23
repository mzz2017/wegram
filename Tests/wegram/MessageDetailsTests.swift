import Foundation

@main struct MessageDetailsTests {
    static func main() {
        for failed in [false, true] {
            for sending in [false, true] {
                for read in [false, true] {
                    precondition(WegramMessageDeliveryStatus.resolve(incoming: true, failed: failed, sending: sending, read: read) == nil)
                    let expected: WegramMessageDeliveryStatus = failed ? .failed : sending ? .sending : read ? .read : .sent
                    precondition(WegramMessageDeliveryStatus.resolve(incoming: false, failed: failed, sending: sending, read: read) == expected)
                }
            }
        }
        let timestamp: Int32 = 1_760_918_645
        let utc = TimeZone(secondsFromGMT: 0)!
        let singapore = TimeZone(identifier: "Asia/Singapore")!
        let locale = Locale(identifier: "en_US")
        let full = wegramMessageDetailTimestamp(timestamp, locale: locale, timeZone: utc, uses24HourTime: true)
        precondition(full.contains("2025") && full.contains(":05"), full)
        precondition(full != wegramMessageDetailTimestamp(timestamp + 1, locale: locale, timeZone: utc, uses24HourTime: true), "Exact seconds lost")
        precondition(full != wegramMessageDetailTimestamp(timestamp, locale: locale, timeZone: singapore, uses24HourTime: true), "Time zone ignored")
        let twelveHour = wegramMessageDetailTimestamp(timestamp, locale: locale, timeZone: utc, uses24HourTime: false)
        precondition(twelveHour.contains("AM") || twelveHour.contains("PM"), twelveHour)
        let chinese = wegramMessageDetailTimestamp(timestamp, locale: Locale(identifier: "zh_Hans"), timeZone: singapore, uses24HourTime: true)
        precondition(chinese.contains("2025") && chinese.contains("月"), chinese)
        print("Message detail status precedence, incoming privacy, exact timestamp, locale and time zone checks passed")
    }
}
