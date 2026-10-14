import Foundation

/// The time zone a provider's subscription renewal/expiration date is shown in, matching the Mac.
enum SubscriptionDateTimeZone {
    static func timeZone(providerID: String, date: Date) -> TimeZone {
        if providerID == "minimax", let shanghai = TimeZone(identifier: "Asia/Shanghai") {
            return shanghai
        }
        // Mac 0.74.1.1+ publishes Claude's date-only billing dates at exactly 12:00:00 UTC (upstream
        // v0.74 #4324 formats them in UTC) and moves an exact timestamp on that instant by one
        // second, so the anchor is unambiguous. Exact timestamps keep the local time zone.
        if providerID == "claude", self.isDateOnlyAnchor(date), let utc = TimeZone(secondsFromGMT: 0) {
            return utc
        }
        return .current
    }

    static func isDateOnlyAnchor(_ date: Date) -> Bool {
        let seconds = date.timeIntervalSince1970
        guard seconds.isFinite, seconds.rounded() == seconds else { return false }
        let secondsPerDay: Double = 86400
        let dayOffset = seconds - (seconds / secondsPerDay).rounded(.down) * secondsPerDay
        return dayOffset == 43200
    }
}
