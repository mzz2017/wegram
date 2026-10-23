import Foundation
import UIKit

public final class WegramMessageTimeZoneObserver {
    private let notificationCenter: NotificationCenter
    private let timeZone: () -> TimeZone
    private let updated: () -> Void
    private var previousTimeZone: TimeZone
    private var observers: [NSObjectProtocol] = []

    public init(notificationCenter: NotificationCenter = .default, timeZone: @escaping () -> TimeZone = { .current }, updated: @escaping () -> Void) {
        self.notificationCenter = notificationCenter
        self.timeZone = timeZone
        self.updated = updated
        self.previousTimeZone = timeZone()
        for name in [Notification.Name.NSSystemTimeZoneDidChange, UIApplication.significantTimeChangeNotification, UIApplication.didBecomeActiveNotification] {
            self.observers.append(notificationCenter.addObserver(forName: name, object: nil, queue: .main, using: { [weak self] _ in
                guard let self else { return }
                let current = self.timeZone()
                guard current != self.previousTimeZone else { return }
                self.previousTimeZone = current
                self.updated()
            }))
        }
    }

    deinit {
        for observer in self.observers { self.notificationCenter.removeObserver(observer) }
    }
}

public enum WegramMessageTime {
    public static func label(timestamp: Int32, now: Date = Date(), calendar: Calendar = .current) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let parts = calendar.dateComponents([.year, .month, .day, .weekday, .hour, .minute], from: date)
        let time = String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case 0:
            return time
        case 1:
            return "昨天 \(time)"
        case 2...6:
            let weekdays = ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"]
            return "\(weekdays[(parts.weekday ?? 1) - 1]) \(time)"
        default:
            let year = parts.year == calendar.component(.year, from: now) ? "" : "\(parts.year ?? 0)年"
            return "\(year)\(parts.month ?? 0)月\(parts.day ?? 0)日 \(time)"
        }
    }

    /// Spans are visible messages/albums in chronological order; compare adjacent messages, not clock buckets.
    public static func groupStarts(for spans: [ClosedRange<Int32>], calendar: Calendar = .current) -> [Int32] {
        var previousEnd: Int32?
        var groupStart: Int32 = 0
        return spans.map { span in
            let date = Date(timeIntervalSince1970: TimeInterval(span.lowerBound))
            if let previousEnd {
                let groupDate = Date(timeIntervalSince1970: TimeInterval(groupStart))
                if Int64(span.lowerBound) - Int64(previousEnd) >= 300 || !calendar.isDate(date, inSameDayAs: groupDate) {
                    groupStart = span.lowerBound
                }
            } else {
                groupStart = span.lowerBound
            }
            previousEnd = max(previousEnd ?? span.upperBound, span.upperBound)
            return groupStart
        }
    }
}
