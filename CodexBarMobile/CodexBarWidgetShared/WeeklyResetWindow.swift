import CodexBarSync
import Foundation

/// Which quota windows are weekly and when the next weekly reset comes
/// (Research/073). Shared by the app's "Weekly Reset (Soonest First)" card
/// order, the Quota pace default window and the CodexBar widget's "By weekly
/// reset" overview, so they always agree.
enum WeeklyResetWindow {
    static let weekMinutes = 7 * 24 * 60
    static let week: TimeInterval = 7 * 24 * 60 * 60

    /// Whether a window is the provider's weekly window:
    ///
    /// 1. A declared `period` decides: only `.weekly` is weekly.
    /// 2. Without one, a length that rounds to seven whole days (6.5 to just
    ///    under 7.5 days). Grok's length is its billing period's end minus
    ///    start, floored to minutes (`GrokCreditsProxyFetcher.windowMinutes`),
    ///    so it is often 10079 rather than 10080; rounding to whole days is
    ///    the Mac's own rule for naming a Grok window (`GrokProviderDescriptor
    ///    .primaryLabel`). 5-hour, daily and 30-day windows stay far outside.
    /// 3. Without a length either, the Mac's label: Grok's untyped credits
    ///    window arrives as "Weekly" (`GrokProviderDescriptor.displayLabel`).
    ///    Mac labels are unlocalized English constants; iOS localizes them on
    ///    display only.
    static func isWeekly(_ window: SyncRateWindow) -> Bool {
        self.isWeekly(period: window.period, windowMinutes: window.windowMinutes, label: window.label)
    }

    static func isWeekly(period: SyncRateWindowPeriod?, windowMinutes: Int?, label: String?) -> Bool {
        if let period { return period == .weekly }
        if let windowMinutes {
            return Int((Double(windowMinutes) / 1440).rounded(.toNearestOrAwayFromZero)) == 7
        }
        guard let label = label?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
        return label.caseInsensitiveCompare("Weekly") == .orderedSame
    }

    /// The soonest next weekly reset among `windows`, or nil without a
    /// weekly window that has a reset time. A reset already in the past
    /// rolls forward by whole weeks, so data that has not refreshed since its
    /// reset still sorts by its next one.
    static func nextReset(of windows: [SyncRateWindow], now: Date) -> Date? {
        self.soonest(of: windows, now: now)?.nextReset
    }

    /// The weekly window whose next reset comes first, with that reset.
    static func soonest(of windows: [SyncRateWindow], now: Date) -> (window: SyncRateWindow, nextReset: Date)? {
        windows
            .filter(self.isWeekly)
            .compactMap { window in
                window.resetsAt.map { (window: window, nextReset: self.nextOccurrence(of: $0, after: now)) }
            }
            .min { $0.nextReset < $1.nextReset }
    }

    /// Used percent of that window while its observation is current: known
    /// usage whose reset is still ahead (after a missed reset it is stale).
    static func currentUsedPercent(of window: SyncRateWindow, now: Date) -> Double? {
        guard window.usageKnown, window.usedPercent.isFinite,
              let reset = window.resetsAt, reset > now
        else { return nil }
        return min(100, max(0, window.usedPercent))
    }

    static func nextOccurrence(of reset: Date, after now: Date) -> Date {
        guard reset <= now else { return reset }
        let elapsedWeeks = floor(now.timeIntervalSince(reset) / self.week) + 1
        return reset.addingTimeInterval(elapsedWeeks * self.week)
    }
}

/// The "Weekly Reset (Soonest First)" comparison shared by the app's cards
/// and the widget overview (Research/064, 073): the soonest weekly reset
/// first; items without one after them; ties and items without a reset by
/// name, then by a secondary name (an account label). Nil means a full tie,
/// which callers break by their source order.
enum WeeklyResetOrdering {
    struct Key: Equatable, Sendable {
        let resetAt: Date?
        let name: String
        let secondaryName: String

        init(resetAt: Date?, name: String, secondaryName: String = "") {
            self.resetAt = resetAt
            self.name = name
            self.secondaryName = secondaryName
        }
    }

    static func precedes(_ lhs: Key, _ rhs: Key) -> Bool? {
        switch (lhs.resetAt, rhs.resetAt) {
        case let (left?, right?) where left != right:
            left < right
        case (.some, nil):
            true
        case (nil, .some):
            false
        default:
            self.compareNames(lhs, rhs, descending: false)
        }
    }

    /// Name first, then the secondary name (always ascending so the accounts
    /// of one provider stay readable in both directions).
    static func compareNames(_ lhs: Key, _ rhs: Key, descending: Bool) -> Bool? {
        let primary = self.compare(lhs.name, rhs.name)
        if primary != .orderedSame {
            return descending ? primary == .orderedDescending : primary == .orderedAscending
        }
        let secondary = self.compare(lhs.secondaryName, rhs.secondaryName)
        if secondary != .orderedSame {
            return secondary == .orderedAscending
        }
        return nil
    }

    private static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        lhs.compare(rhs, options: [.caseInsensitive, .numeric, .diacriticInsensitive, .widthInsensitive])
    }
}
