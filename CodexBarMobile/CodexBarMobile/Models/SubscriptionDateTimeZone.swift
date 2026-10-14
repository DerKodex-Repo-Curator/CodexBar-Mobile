import CodexBarSync
import Foundation

/// How a provider's subscription renewal/expiration date is shown, matching the Mac.
enum SubscriptionDateTimeZone {
    static func timeZone(providerID: String, date: Date) -> TimeZone {
        if providerID == "minimax", let shanghai = TimeZone(identifier: "Asia/Shanghai") {
            return shanghai
        }
        return .current
    }

    /// Formats a `yyyy-MM-dd` calendar day (Mac 0.74.1.1+ `subscription…On`) in the UTC calendar,
    /// so the day never shifts with the reader's time zone.
    static func calendarDayString(_ day: String, locale: Locale = .current) -> String? {
        guard let date = ProviderUsageSnapshot.calendarDayDate(day), let utc = TimeZone(secondsFromGMT: 0) else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.timeZone = utc
        return formatter.string(from: date)
    }
}
