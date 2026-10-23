import Foundation

/// Chinese list labels follow the supplied WeChat list; older years keep system regional dates.
enum WegramChatListTime {
    static func label(timestamp: Int32, now: Date = Date(), calendar: Calendar = .current, locale: Locale = .current) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let parts = calendar.dateComponents([.year, .month, .day, .weekday, .hour, .minute], from: date)
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case 0: return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
        // The user's list (IMG_2438/2439) shows "昨天 22:37"; older weekdays have no time.
        case 1: return String(format: "昨天 %02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
        case 2...6:
            return ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"][(parts.weekday ?? 1) - 1]
        default:
            if parts.year == calendar.component(.year, from: now) { return "\(parts.month ?? 0)月\(parts.day ?? 0)日" }
            return date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, locale: locale, calendar: calendar, timeZone: calendar.timeZone))
        }
    }
}
