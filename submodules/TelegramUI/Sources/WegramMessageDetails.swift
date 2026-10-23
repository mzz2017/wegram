import Foundation

enum WegramMessageDeliveryStatus: Equatable {
    case sending
    case failed
    case sent
    case read

    static func resolve(incoming: Bool, failed: Bool, sending: Bool, read: Bool) -> Self? {
        guard !incoming else { return nil }
        if failed { return .failed }
        if sending { return .sending }
        return read ? .read : .sent
    }
}

func wegramMessageDetailTimestamp(_ timestamp: Int32, locale: Locale, timeZone: TimeZone, uses24HourTime: Bool) -> String {
    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.timeZone = timeZone
    formatter.setLocalizedDateFormatFromTemplate(uses24HourTime ? "yMMMdHHmmssz" : "yMMMdhmmssaz")
    return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))
}
