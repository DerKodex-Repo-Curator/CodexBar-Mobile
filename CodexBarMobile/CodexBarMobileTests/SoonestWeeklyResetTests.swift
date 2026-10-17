import CodexBarSync
import Foundation
import Intents
import Testing
import WidgetKit
@testable import CodexBarMobile

/// Research/073 — one weekly-window rule for the app's "Weekly Reset
/// (Soonest First)" order and the CodexBar widget's "By weekly reset"
/// overview, and the widget configuration that selects it.
@Suite("Weekly reset rule and the soonest-reset widget overview")
struct SoonestWeeklyResetTests {
    private static let now = Date(timeIntervalSince1970: 1_800_000_000)

    private static func window(
        id: String? = nil,
        label: String? = nil,
        period: SyncRateWindowPeriod? = nil,
        minutes: Int?,
        resetInHours hours: Double? = 24) -> SyncRateWindow
    {
        SyncRateWindow(
            id: id,
            label: label,
            usedPercent: 10,
            windowMinutes: minutes,
            period: period,
            resetsAt: hours.map { Self.now.addingTimeInterval($0 * 3600) },
            resetDescription: nil)
    }

    private static func provider(
        _ id: String,
        name: String? = nil,
        email: String? = nil,
        windows rawWindows: [SyncRateWindow],
        usedPercents: [Double]? = nil,
        isError: Bool = false) -> ProviderUsageSnapshot
    {
        let windows = rawWindows.enumerated().map { index, window in
            guard let used = usedPercents?[index] else { return window }
            return SyncRateWindow(
                id: window.id, label: window.label, usedPercent: used, windowMinutes: window.windowMinutes,
                period: window.period, resetsAt: window.resetsAt, resetDescription: window.resetDescription)
        }
        return ProviderUsageSnapshot(
            providerID: id,
            providerName: name ?? id.capitalized,
            primary: windows.first,
            secondary: windows.dropFirst().first,
            accountEmail: email,
            loginMethod: nil,
            statusMessage: nil,
            isError: isError,
            lastUpdated: self.now.addingTimeInterval(-60),
            rateWindows: windows)
    }

    /// Grok as the Mac syncs it: no period, the floored billing period as
    /// its length, and the descriptor's "Weekly" label.
    private static func grokWindow(minutes: Int?, resetInHours hours: Double = 72) -> SyncRateWindow {
        self.window(id: "primary", label: "Weekly", minutes: minutes, resetInHours: hours)
    }

    private static func summary(
        _ id: String,
        name: String? = nil,
        account: String = "a",
        weeklyResetInHours hours: Double?,
        usagePercent: Double = 10,
        weeklyUsedPercent: Double? = nil) -> CodexBarWidgetProviderSummary
    {
        CodexBarWidgetProviderSummary(
            id: "\(id)|\(account)",
            providerName: name ?? id.capitalized,
            providerID: id,
            loginMethod: nil,
            usagePercent: usagePercent,
            todayCostUSD: nil,
            thirtyDayCostUSD: nil,
            tokensToday: nil,
            isError: false,
            statusMessage: nil,
            lastUpdated: self.now,
            weeklyResetsAt: hours.map { Self.now.addingTimeInterval($0 * 3600) },
            weeklyUsedPercent: weeklyUsedPercent)
    }

    // MARK: Weekly window rule

    /// The rule for a window observed at `now`.
    private static func weekly(_ window: SyncRateWindow, observedAt: Date = Self.now) -> Bool {
        WeeklyResetWindow.isWeekly(window, observedAt: observedAt)
    }

    @Test func `Grok's untyped weekly window counts as weekly`() {
        #expect(Self.weekly(Self.grokWindow(minutes: 10079)))
        #expect(Self.weekly(Self.grokWindow(minutes: 10080)))
        #expect(Self.weekly(Self.grokWindow(minutes: nil)))
        // A floored period one DST hour short is still a week.
        #expect(Self.weekly(Self.window(minutes: 10020)))
    }

    @Test func `Claude and Codex weekly windows stay weekly`() {
        #expect(Self.weekly(Self.window(id: "secondary", label: "Weekly", minutes: 10080)))
        #expect(Self.weekly(Self.window(id: "secondary", minutes: 10080)))
        #expect(Self.weekly(Self.window(period: .weekly, minutes: nil)))
    }

    @Test func `Session, daily and monthly windows are never weekly`() {
        #expect(!Self.weekly(Self.window(label: "Session", minutes: 300)))
        #expect(!Self.weekly(Self.window(minutes: 1440)))
        #expect(!Self.weekly(Self.window(minutes: 43200)))
        #expect(!Self.weekly(Self.window(label: "Monthly", minutes: nil)))
        #expect(!Self.weekly(Self.window(minutes: nil)))
        // A length outranks the label: Grok's Mac also keeps explicit durations authoritative.
        #expect(!Self.weekly(Self.window(label: "Weekly", minutes: 43200)))
    }

    @Test func `A declared period decides whatever the length or label`() {
        #expect(!Self.weekly(Self.window(period: .monthly, minutes: 10080)))
        #expect(!Self.weekly(Self.window(label: "Weekly", period: .session, minutes: nil)))
        #expect(!Self.weekly(Self.window(period: .daily, minutes: 10079)))
        #expect(!Self.weekly(Self.window(period: .lifetime, minutes: nil)))
        #expect(Self.weekly(Self.window(period: .weekly, minutes: 9000)))
    }

    @Test func `The length must round to seven whole days`() {
        #expect(!Self.weekly(Self.window(minutes: 9359)))
        #expect(Self.weekly(Self.window(minutes: 9360)))
        #expect(Self.weekly(Self.window(minutes: 10799)))
        #expect(!Self.weekly(Self.window(minutes: 10800)))
    }

    @Test func `The label fallback reads the Mac's unlocalized English label`() {
        #expect(Self.weekly(Self.window(label: " weekly ", minutes: nil)))
        // Mac labels are never localized; a translated label is not a Mac label.
        #expect(!Self.weekly(Self.window(label: "每周", minutes: nil)))
        #expect(!Self.weekly(Self.window(label: "Premium weekly", minutes: nil)))
    }

    @Test func `The next weekly reset is the soonest weekly window and past resets roll forward`() {
        let mixed = Self.provider("grok", windows: [
            Self.window(id: "a", label: "Session", minutes: 300, resetInHours: 1),
            Self.window(id: "b", label: "Weekly", minutes: 10080, resetInHours: 90),
            Self.window(id: "c", label: "Weekly", minutes: 10079, resetInHours: 40),
        ])
        #expect(WeeklyResetWindow.nextReset(for: mixed, now: Self.now) == Self.now.addingTimeInterval(40 * 3600))
        let stale = Self.provider("grok", windows: [Self.grokWindow(minutes: nil, resetInHours: -24)])
        #expect(WeeklyResetWindow.nextReset(for: stale, now: Self.now) == Self.now.addingTimeInterval(6 * 86400))
        let session = Self.provider("zai", windows: [Self.window(minutes: 300)])
        #expect(WeeklyResetWindow.nextReset(for: session, now: Self.now) == nil)
        let noReset = Self.provider("codex", windows: [Self.window(minutes: 10080, resetInHours: nil)])
        #expect(WeeklyResetWindow.nextReset(for: noReset, now: Self.now) == nil)
    }

    @Test func `A monthly Grok pool labeled Weekly without a length is not weekly`() {
        // The Mac's gRPC path sends no length and falls back to "Weekly" for
        // a monthly pool 12.5 to 19.5 days (or under 3.5 days) from reset.
        #expect(!Self.weekly(Self.grokWindow(minutes: nil, resetInHours: 15 * 24)))
        let monthly = Self.provider("grok", windows: [Self.grokWindow(minutes: nil, resetInHours: 15 * 24)])
        #expect(WeeklyResetWindow.nextReset(for: monthly, now: Self.now) == nil)
        // The fallback reaches 7.5 days from the observation.
        #expect(Self.weekly(Self.grokWindow(minutes: nil, resetInHours: 7.4 * 24)))
        #expect(!Self.weekly(Self.grokWindow(minutes: nil, resetInHours: 7.6 * 24)))
        // Measured from when the data was captured, not from now.
        let reset = Self.grokWindow(minutes: nil, resetInHours: 5 * 24)
        #expect(!Self.weekly(reset, observedAt: Self.now.addingTimeInterval(-5 * 86400)))
        // Known remaining ambiguity: a monthly pool in its last 7.5 days.
        #expect(Self.weekly(Self.grokWindow(minutes: nil, resetInHours: 2 * 24)))
    }

    @Test func `A Weekly-labeled fallback window without a reset is not weekly`() {
        // Windsurf's flow-actions fallback: "Weekly", no length, no reset.
        let flow = Self.window(id: "windsurf-flow", label: "Weekly", minutes: nil, resetInHours: nil)
        #expect(!Self.weekly(flow))
        let windsurf = Self.provider("windsurf", windows: [flow])
        #expect(WeeklyResetWindow.nextReset(for: windsurf, now: Self.now) == nil)
        #expect(UsageCardOrdering.weeklyResetDate(for: windsurf, now: Self.now) == nil)
    }

    @Test func `Account-level weekly windows outrank Claude's model and routine limits`() {
        let claude = Self.provider("claude", windows: [
            Self.window(id: "primary", label: "Session", minutes: 300, resetInHours: 2),
            SyncRateWindow(
                id: "secondary",
                label: "Weekly",
                usedPercent: 30,
                windowMinutes: 10080,
                resetsAt: Self.now.addingTimeInterval(100 * 3600),
                resetDescription: nil),
            Self.window(id: "tertiary", label: "Sonnet", minutes: 10080, resetInHours: 20),
            Self.window(id: "claude-weekly-scoped-fable", label: "Fable only", minutes: 10080, resetInHours: 30),
            Self.window(id: "claude-routines", label: "Routines", minutes: 10080, resetInHours: 25),
        ])
        let account = Self.now.addingTimeInterval(100 * 3600)
        #expect(WeeklyResetWindow.nextReset(for: claude, now: Self.now) == account)
        #expect(UsageCardOrdering.weeklyResetDate(for: claude, now: Self.now) == account)
        let summary = CodexBarWidgetSnapshotBuilder.summary(for: claude, now: Self.now)
        #expect(summary.weeklyResetsAt == account)
        #expect(summary.weeklyUsedPercent == 30)
        // Without an account-level weekly window, the carve-outs still count.
        let sonnetOnly = Self.provider("claude", windows: [
            Self.window(id: "tertiary", label: "Sonnet", minutes: 10080, resetInHours: 20),
            Self.window(id: "claude-weekly-scoped-fable", label: "Fable only", minutes: 10080, resetInHours: 30),
        ])
        #expect(WeeklyResetWindow.nextReset(for: sonnetOnly, now: Self.now) == Self.now.addingTimeInterval(20 * 3600))
        // An account window without a reset time still claims the account's
        // place: the carve-out's reset never stands in for it.
        let resetlessAccount = Self.provider("claude", windows: [
            Self.window(id: "secondary", label: "Weekly", minutes: 10080, resetInHours: nil),
            Self.window(id: "tertiary", label: "Sonnet", minutes: 10080, resetInHours: 20),
        ])
        #expect(WeeklyResetWindow.nextReset(for: resetlessAccount, now: Self.now) == nil)
        #expect(UsageCardOrdering.weeklyResetDate(for: resetlessAccount, now: Self.now) == nil)
        // Other providers' third slot is an ordinary window.
        let other = Self.provider("minimax", windows: [
            Self.window(id: "secondary", minutes: 10080, resetInHours: 100),
            Self.window(id: "tertiary", minutes: 10080, resetInHours: 20),
        ])
        #expect(WeeklyResetWindow.nextReset(for: other, now: Self.now) == Self.now.addingTimeInterval(20 * 3600))
    }

    // MARK: App ordering (the reported bug)

    @Test func `The app sorts Grok by its weekly reset instead of No weekly reset`() {
        let grok = Self.provider("grok", windows: [Self.grokWindow(minutes: 10079, resetInHours: 72)])
        let grokUntyped = Self.provider("grok", windows: [Self.grokWindow(minutes: nil, resetInHours: 72)])
        #expect(UsageCardOrdering.weeklyResetDate(for: grok, now: Self.now) == Self.now.addingTimeInterval(72 * 3600))
        #expect(UsageCardOrdering.weeklyResetDate(for: grokUntyped, now: Self.now) != nil)

        var preferences = UsageCardPreferences()
        preferences.usesDefaultSort = true
        preferences.defaultSortRule = .weeklyReset
        let descriptors = [
            UsageCardSortDescriptor(
                key: "provider:openrouter", name: "OpenRouter", secondaryName: "", weeklyResetAt: nil),
            UsageCardSortDescriptor(
                key: "provider:claude",
                name: "Claude",
                secondaryName: "",
                weeklyResetAt: Self.now.addingTimeInterval(96 * 3600)),
            UsageCardSortDescriptor(
                key: "provider:grok",
                name: "Grok",
                secondaryName: "",
                weeklyResetAt: UsageCardOrdering.weeklyResetDate(for: grok, now: Self.now)),
        ]
        #expect(UsageCardOrdering.arrange(descriptors, preferences: preferences).others == [
            "provider:grok", "provider:claude", "provider:openrouter",
        ])
    }

    @Test func `The Quota pace default window finds Grok's weekly window`() {
        let grok = Self.provider("grok", windows: [Self.grokWindow(minutes: 10079, resetInHours: 72)])
        #expect(QuotaPaceWindowSelection.defaultWindowID(for: grok, now: Self.now) == "primary")
        let title = QuotaPaceWindowSelection.widgetTitle(
            label: nil,
            windowMinutes: 10079,
            cardIndex: 0,
            period: nil,
            providerID: "grok",
            locale: Locale(identifier: "en"))
        #expect(title == "Weekly")
    }

    // MARK: Widget data

    @Test func `Widget summaries carry the next weekly reset`() {
        let now = Self.now
        let snapshot = SyncedUsageSnapshot(
            providers: [
                Self.provider("grok", windows: [Self.grokWindow(minutes: 10079, resetInHours: 30)]),
                Self.provider("openrouter", windows: [Self.window(minutes: 60, resetInHours: 1)]),
            ],
            syncTimestamp: now.addingTimeInterval(-30),
            deviceName: "Fictitious Mac",
            deviceID: "device-a")
        let widget = CodexBarWidgetSnapshotBuilder.makeSnapshot(from: [snapshot], now: now)
        let byID = Dictionary(uniqueKeysWithValues: widget.topProviders.map { ($0.providerID, $0) })
        #expect(byID["grok"]?.weeklyResetsAt == now.addingTimeInterval(30 * 3600))
        #expect(byID["openrouter"] != nil)
        #expect(byID["openrouter"]?.weeklyResetsAt == nil)
    }

    @Test func `Widget summaries carry the soonest weekly window's current usage`() {
        let now = Self.now
        func window(_ id: String, used: Double, minutes: Int, resetInHours hours: Double) -> SyncRateWindow {
            SyncRateWindow(
                id: id,
                usedPercent: used,
                windowMinutes: minutes,
                resetsAt: now.addingTimeInterval(hours * 3600),
                resetDescription: nil)
        }
        let claude = Self.provider("claude", windows: [
            window("primary", used: 80, minutes: 300, resetInHours: 1),
            window("secondary", used: 35, minutes: 10080, resetInHours: 50),
        ])
        let stale = Self.provider("codex", windows: [window("secondary", used: 90, minutes: 10080, resetInHours: -1)])
        let synced = SyncedUsageSnapshot(
            providers: [claude, stale],
            syncTimestamp: now,
            deviceName: "Fictitious Mac",
            deviceID: "device-a")
        let widget = CodexBarWidgetSnapshotBuilder.makeSnapshot(from: [synced], now: now)
        let byID = Dictionary(uniqueKeysWithValues: widget.topProviders.map { ($0.providerID, $0) })
        #expect(byID["claude"]?.usagePercent == 80)
        #expect(byID["claude"]?.weeklyUsedPercent == 35)
        #expect(byID["claude"]?.weeklyResetsAt == now.addingTimeInterval(50 * 3600))
        // A missed reset rolls forward; its old usage is not shown as current.
        #expect(byID["codex"]?.weeklyResetsAt == now.addingTimeInterval(167 * 3600))
        #expect(byID["codex"]?.weeklyUsedPercent == nil)
    }

    @Test func `Soonest-reset tiles show the weekly window they sort by`() {
        let now = Self.now
        let claude = CodexBarWidgetProviderSummary(
            id: "claude|a",
            providerName: "Claude",
            providerID: "claude",
            loginMethod: nil,
            usagePercent: 80,
            resetsAt: now.addingTimeInterval(3600),
            todayCostUSD: nil,
            thirtyDayCostUSD: nil,
            tokensToday: nil,
            isError: false,
            statusMessage: nil,
            lastUpdated: now,
            weeklyResetsAt: now.addingTimeInterval(50 * 3600),
            weeklyUsedPercent: 35)
        // Every overview mode shows the weekly window, not the fullest (session) one.
        let manual = WidgetProviderSelection.overviewFigures(for: claude, selection: .manual, now: now)
        #expect(manual.usagePercent == 35 && manual.resetsAt == now.addingTimeInterval(50 * 3600))
        let soonest = WidgetProviderSelection.overviewFigures(
            for: claude, selection: .soonestWeeklyReset(count: 2), now: now)
        #expect(soonest.usagePercent == 35 && soonest.resetsAt == now.addingTimeInterval(50 * 3600))
        // After the weekly reset passes, the next one shows without stale usage.
        let later = now.addingTimeInterval(51 * 3600)
        let rolled = WidgetProviderSelection.overviewFigures(
            for: claude, selection: .soonestWeeklyReset(count: 2), now: later)
        #expect(rolled.usagePercent == nil && rolled.resetsAt == now.addingTimeInterval((50 + 168) * 3600))
        // Without a weekly reset the tile keeps its usual figures in both modes.
        let openRouter = Self.summary("openrouter", weeklyResetInHours: nil)
        let fallback = WidgetProviderSelection.overviewFigures(
            for: openRouter, selection: .soonestWeeklyReset(count: 2), now: now)
        #expect(fallback.usagePercent == openRouter.usagePercent && fallback.resetsAt == openRouter.resetsAt)
        let manualFallback = WidgetProviderSelection.overviewFigures(for: openRouter, selection: .manual, now: now)
        #expect(manualFallback.usagePercent == openRouter.usagePercent && manualFallback.resetsAt == openRouter
            .resetsAt)
        // A stale weekly reset in manual mode also hides the stale usage instead of showing another window.
        let rolledManual = WidgetProviderSelection.overviewFigures(for: claude, selection: .manual, now: later)
        #expect(rolledManual.usagePercent == nil && rolledManual.resetsAt == now.addingTimeInterval((50 + 168) * 3600))
    }

    @Test func `Overview tiles show the weekly window from the synced snapshot in every mode`() {
        // Session 80, Weekly 35 and a fuller model-only window: the tile shows Weekly.
        let claude = Self.provider("claude", windows: [
            Self.window(id: "primary", label: "Session", minutes: 300, resetInHours: 1),
            Self.window(id: "secondary", label: "Weekly", minutes: 10080, resetInHours: 50),
            Self.window(id: "claude-weekly-scoped-fable", label: "Fable only", minutes: 10080, resetInHours: 30),
        ], usedPercents: [80, 35, 90])
        let summary = CodexBarWidgetSnapshotBuilder.summary(for: claude, now: Self.now)
        #expect(summary.usagePercent == 90)
        let figures = WidgetProviderSelection.overviewFigures(for: summary, selection: .manual, now: Self.now)
        #expect(figures.usagePercent == 35 && figures.resetsAt == Self.now.addingTimeInterval(50 * 3600))
        // An account weekly window without a reset still wins over Session and Fable only, without a countdown.
        let resetless = Self.provider("claude", windows: [
            Self.window(id: "primary", label: "Session", minutes: 300, resetInHours: 1),
            Self.window(id: "secondary", label: "Weekly", minutes: 10080, resetInHours: nil),
            Self.window(id: "claude-weekly-scoped-fable", label: "Fable only", minutes: 10080, resetInHours: 30),
        ], usedPercents: [80, 35, 90])
        let resetlessSummary = CodexBarWidgetSnapshotBuilder.summary(for: resetless, now: Self.now)
        #expect(resetlessSummary.weeklyResetsAt == nil && resetlessSummary.weeklyUsedPercent == 35)
        let resetlessFigures = WidgetProviderSelection.overviewFigures(
            for: resetlessSummary, selection: .manual, now: Self.now)
        #expect(resetlessFigures.usagePercent == 35 && resetlessFigures.resetsAt == nil)
        // Weekly windows that reset together show the fuller one.
        let antigravity = Self.provider("antigravity", windows: [
            Self.window(
                id: "antigravity-quota-summary-gemini-weekly",
                label: "Gemini",
                minutes: 10080,
                resetInHours: 40),
            Self.window(id: "antigravity-quota-summary-3p-weekly", label: "3P", minutes: 10080, resetInHours: 40),
        ], usedPercents: [30, 55])
        #expect(CodexBarWidgetSnapshotBuilder.summary(for: antigravity, now: Self.now).weeklyUsedPercent == 55)
        // A window with unknown usage never wins the tie, however large its raw figure.
        let unknownUsage = Self.provider("antigravity", windows: ["gemini", "3p"].map { model in
            let known = model == "3p"
            return SyncRateWindow(
                id: "antigravity-quota-summary-\(model)-weekly", label: model, usedPercent: known ? 55 : 99,
                usageKnown: known, windowMinutes: 10080, resetsAt: Self.now.addingTimeInterval(40 * 3600),
                resetDescription: nil)
        })
        #expect(CodexBarWidgetSnapshotBuilder.summary(for: unknownUsage, now: Self.now).weeklyUsedPercent == 55)
        // A provider with no weekly window keeps its most-used window.
        let balance = Self.provider("openrouter", windows: [
            Self.window(id: "primary", label: "Daily", minutes: 1440, resetInHours: 5),
        ], usedPercents: [12])
        let balanceFigures = WidgetProviderSelection.overviewFigures(
            for: CodexBarWidgetSnapshotBuilder.summary(for: balance, now: Self.now), selection: .manual, now: Self.now)
        #expect(balanceFigures.usagePercent == 12 && balanceFigures.resetsAt == Self.now.addingTimeInterval(5 * 3600))
    }

    @Test func `Automatic overview picks follow the weekly figures the tiles show`() {
        // Codex leads on its session window but Claude leads weekly: Claude takes the first tile.
        let codex = Self.summary("codex", weeklyResetInHours: 60, usagePercent: 78, weeklyUsedPercent: 39)
        let claude = Self.summary("claude", weeklyResetInHours: 80, usagePercent: 42, weeklyUsedPercent: 54)
        let openRouter = Self.summary("openrouter", weeklyResetInHours: nil, usagePercent: 60)
        let picks = WidgetProviderSelection.resolve(
            from: [codex, claude, openRouter], selected: nil, family: .systemMedium, now: Self.now)
        #expect(picks.map(\.providerID) == ["openrouter", "claude", "codex"])
        let small = WidgetProviderSelection.resolve(
            from: [codex, claude, openRouter], selected: nil, family: .systemSmall, now: Self.now)
        #expect(small.map(\.providerID) == ["openrouter", "claude"])
        // An explicit selection is never reordered.
        let chosen = WidgetProviderSelection.resolve(
            from: [codex, claude, openRouter],
            selected: [
                WidgetProviderEntity(id: "codex", name: "Codex"),
                WidgetProviderEntity(id: "claude", name: "Claude"),
            ],
            family: .systemMedium, now: Self.now)
        #expect(chosen.map(\.providerID) == ["codex", "claude"])
    }

    @Test func `Automatic overview picks keep providers in error behind working ones`() {
        // A failed provider keeps its last figure (92%) but must not take the first tile.
        let failed = CodexBarWidgetProviderSummary(
            id: "openrouter|a", providerName: "OpenRouter", providerID: "openrouter",
            loginMethod: nil, usagePercent: 92, todayCostUSD: nil, thirtyDayCostUSD: nil,
            tokensToday: nil, isError: true, statusMessage: "Sync Error", lastUpdated: Self.now)
        let codex = Self.summary("codex", weeklyResetInHours: 60, usagePercent: 78, weeklyUsedPercent: 39)
        let claude = Self.summary("claude", weeklyResetInHours: 80, usagePercent: 42, weeklyUsedPercent: 54)
        let picks = WidgetProviderSelection.resolve(
            from: [failed, codex, claude], selected: nil, family: .systemMedium, now: Self.now)
        #expect(picks.map(\.providerID) == ["claude", "codex", "openrouter"])
        let small = WidgetProviderSelection.resolve(
            from: [failed, codex, claude], selected: nil, family: .systemSmall, now: Self.now)
        #expect(small.map(\.providerID) == ["claude", "codex"])
        // The gallery placeholder leads with working providers, not the failed sample.
        let placeholder = WidgetProviderSelection.resolve(
            from: CodexBarWidgetSnapshot.placeholder(now: Self.now).topProviders,
            selected: nil, family: .systemSmall, now: Self.now)
        #expect(placeholder.map(\.providerID) == ["claude", "codex"])
    }

    @Test func `Summaries encoded without a weekly reset still decode`() throws {
        let summary = Self.summary("codex", weeklyResetInHours: 5)
        var object = try #require(try JSONSerialization
            .jsonObject(with: JSONEncoder().encode(summary)) as? [String: Any])
        object.removeValue(forKey: "weeklyResetsAt")
        object.removeValue(forKey: "weeklyUsedPercent")
        let decoded = try JSONDecoder().decode(
            CodexBarWidgetProviderSummary.self,
            from: JSONSerialization.data(withJSONObject: object))
        #expect(decoded.weeklyResetsAt == nil)
        #expect(decoded.weeklyUsedPercent == nil)
        #expect(decoded.providerID == "codex")
    }

    // MARK: Widget order

    @Test func `Soonest weekly reset first, providers without one last by name`() {
        let providers = [
            Self.summary("zai", name: "z.ai", weeklyResetInHours: nil),
            Self.summary("codex", weeklyResetInHours: 50),
            Self.summary("openrouter", name: "OpenRouter", weeklyResetInHours: nil),
            Self.summary("grok", weeklyResetInHours: 20),
            Self.summary("claude", weeklyResetInHours: 90),
        ]
        let order = WidgetProviderSelection.soonestWeeklyReset(from: providers, count: 4, now: Self.now)
        #expect(order.map(\.providerID) == ["grok", "codex", "claude", "openrouter"])
    }

    @Test func `The count cuts the list and stays between two and four`() {
        let providers = (1...6).map { Self.summary("p\($0)", weeklyResetInHours: Double(10 * $0)) }
        for count in 2...4 {
            let ids = WidgetProviderSelection.soonestWeeklyReset(from: providers, count: count, now: Self.now)
                .map(\.providerID)
            #expect(ids == Array(["p1", "p2", "p3", "p4"].prefix(count)))
        }
        #expect(WidgetProviderSelection.soonestWeeklyReset(from: providers, count: 1, now: Self.now).count == 2)
        #expect(WidgetProviderSelection.soonestWeeklyReset(from: providers, count: 9, now: Self.now).count == 4)
        // Fewer providers than the count show them all.
        #expect(WidgetProviderSelection.soonestWeeklyReset(
            from: Array(providers.prefix(1)), count: 3, now: Self.now).count == 1)
        #expect(WidgetProviderSelection.soonestWeeklyReset(from: [], count: 3, now: Self.now).isEmpty)
    }

    @Test func `Past weekly resets roll forward before sorting`() {
        let providers = [
            Self.summary("stale", weeklyResetInHours: -24), // next: in 6 days
            Self.summary("soon", weeklyResetInHours: 48),
        ]
        #expect(WidgetProviderSelection.soonestWeeklyReset(from: providers, count: 2, now: Self.now)
            .map(\.providerID) == ["soon", "stale"])
    }

    @Test func `Equal resets fall back to name, then snapshot order`() {
        let providers = [
            Self.summary("b", name: "Beta", weeklyResetInHours: 30),
            Self.summary("a", name: "Alpha", weeklyResetInHours: 30),
            Self.summary("twin-2", name: "Twin", weeklyResetInHours: nil),
            Self.summary("twin-1", name: "Twin", weeklyResetInHours: nil),
        ]
        #expect(WidgetProviderSelection.soonestWeeklyReset(from: providers, count: 4, now: Self.now)
            .map(\.providerID) == ["a", "b", "twin-2", "twin-1"])
    }

    @Test func `One entry per provider, the one the overview shows`() {
        let providers = [
            Self.summary("codex", account: "work", weeklyResetInHours: 100),
            Self.summary("claude", weeklyResetInHours: 50),
            Self.summary("codex", account: "side", weeklyResetInHours: 10),
        ]
        let order = WidgetProviderSelection.soonestWeeklyReset(from: providers, count: 4, now: Self.now)
        #expect(order.map(\.id) == ["claude|a", "codex|work"])
    }

    @Test func `With one account per provider the widget order matches the app's`() {
        let now = Self.now
        let snapshots = [
            Self.provider("claude", windows: [
                Self.window(id: "primary", label: "Session", minutes: 300, resetInHours: 2),
                Self.window(id: "secondary", label: "Weekly", minutes: 10080, resetInHours: 80),
            ]),
            Self.provider("codex", windows: [
                Self.window(id: "primary", minutes: 300, resetInHours: 1),
                Self.window(id: "secondary", minutes: 10080, resetInHours: -30),
            ]),
            Self.provider("grok", windows: [Self.grokWindow(minutes: nil, resetInHours: 60)]),
            Self.provider("openrouter", name: "OpenRouter", windows: [Self.window(minutes: 60, resetInHours: 1)]),
            Self.provider("zai", name: "z.ai", windows: [Self.window(minutes: 43200, resetInHours: 20)]),
        ]
        var preferences = UsageCardPreferences()
        preferences.usesDefaultSort = true
        preferences.defaultSortRule = .weeklyReset
        let app = UsageCardOrdering.arrange(
            snapshots.map { snapshot in
                UsageCardSortDescriptor(
                    key: snapshot.providerID,
                    name: snapshot.providerName,
                    secondaryName: "",
                    weeklyResetAt: UsageCardOrdering.weeklyResetDate(for: snapshot, now: now))
            },
            preferences: preferences).others
        let widget = CodexBarWidgetSnapshotBuilder.makeSnapshot(
            from: [SyncedUsageSnapshot(
                providers: snapshots,
                syncTimestamp: now,
                deviceName: "Fictitious Mac",
                deviceID: "device-a")],
            now: now)
        let widgetOrder = WidgetProviderSelection.soonestWeeklyReset(
            from: widget.topProviders, count: 4, now: now).map(\.providerID)
        #expect(app == ["grok", "claude", "codex", "openrouter", "zai"])
        #expect(widgetOrder == Array(app.prefix(4)))
    }

    /// Locks the current behavior: with several accounts the widget sorts a
    /// provider by the account it shows (the most used), the app's collapsed
    /// card by its first account, so the two orders can differ.
    @Test func `With several accounts the widget sorts by the account it shows`() {
        let now = Self.now
        func account(_ email: String, sessionUsed: Double, weeklyResetInHours hours: Double) -> ProviderUsageSnapshot {
            ProviderUsageSnapshot(
                providerID: "codex",
                providerName: "Codex",
                primary: nil,
                secondary: nil,
                accountEmail: email,
                loginMethod: nil,
                statusMessage: nil,
                isError: false,
                lastUpdated: now.addingTimeInterval(-60),
                rateWindows: [
                    SyncRateWindow(
                        id: "primary",
                        usedPercent: sessionUsed,
                        windowMinutes: 300,
                        resetsAt: now.addingTimeInterval(2 * 3600),
                        resetDescription: nil),
                    SyncRateWindow(
                        id: "secondary",
                        usedPercent: 10,
                        windowMinutes: 10080,
                        resetsAt: now.addingTimeInterval(hours * 3600),
                        resetDescription: nil),
                ])
        }
        let work = account("work@example.com", sessionUsed: 5, weeklyResetInHours: 150)
        let side = account("side@example.com", sessionUsed: 95, weeklyResetInHours: 5)
        let claude = Self.provider("claude", windows: [Self.window(id: "secondary", minutes: 10080, resetInHours: 50)])
        let all = [work, side, claude]
        var preferences = UsageCardPreferences()
        preferences.usesDefaultSort = true
        preferences.defaultSortRule = .weeklyReset
        let cards = UsageCardBuilder.cards(groups: all.groupedByProvider(), preferences: UsageCardPreferences())
        let app = UsageCardOrdering.arrangedCards(cards, preferences: preferences, now: now).others.map(\.providerID)
        let synced = SyncedUsageSnapshot(
            providers: all,
            syncTimestamp: now,
            deviceName: "Fictitious Mac",
            deviceID: "d")
        let widget = CodexBarWidgetSnapshotBuilder.makeSnapshot(from: [synced], now: now)
        let shown = WidgetProviderSelection.soonestWeeklyReset(from: widget.topProviders, count: 4, now: now)
        #expect(app == ["claude", "codex"])
        #expect(shown.map(\.providerID) == ["codex", "claude"])
        #expect(shown.first?.id == "codex|side@example.com")
    }

    @Test func `A provider in error never takes a soonest-reset slot ahead of a working one`() {
        let now = Self.now
        let grok = CodexBarWidgetProviderSummary(
            id: "grok|a",
            providerName: "Grok",
            providerID: "grok",
            loginMethod: nil,
            usagePercent: 10,
            todayCostUSD: nil,
            thirtyDayCostUSD: nil,
            tokensToday: nil,
            isError: true,
            statusMessage: "Sync Error",
            lastUpdated: now,
            weeklyResetsAt: now.addingTimeInterval(3 * 3600))
        let providers = [
            Self.summary("claude", weeklyResetInHours: 50),
            Self.summary("codex", weeklyResetInHours: 60),
            Self.summary("openrouter", name: "OpenRouter", weeklyResetInHours: nil),
            grok,
        ]
        #expect(WidgetProviderSelection.soonestWeeklyReset(from: providers, count: 2, now: now)
            .map(\.providerID) == ["claude", "codex"])
        // In error it sorts like a provider without a weekly reset, by name.
        #expect(WidgetProviderSelection.soonestWeeklyReset(from: providers, count: 4, now: now)
            .map(\.providerID) == ["claude", "codex", "grok", "openrouter"])
        // The app's order still uses its weekly reset.
        var preferences = UsageCardPreferences()
        preferences.usesDefaultSort = true
        preferences.defaultSortRule = .weeklyReset
        let app = UsageCardOrdering.arrange(
            providers.map {
                UsageCardSortDescriptor(
                    key: $0.providerID,
                    name: $0.providerName,
                    secondaryName: "",
                    weeklyResetAt: $0.weeklyResetsAt)
            },
            preferences: preferences).others
        #expect(app.first == "grok")
    }

    @Test func `Manual selection resolves the same tiles as resolve for every family`() {
        let providers = CodexBarWidgetSnapshot.placeholder(now: Self.now).topProviders
        let selected = [WidgetProviderEntity(id: "claude", name: "Claude")]
        for family in [WidgetFamily.systemSmall, .systemMedium, .systemLarge] {
            for chosen in [nil, [], selected] {
                #expect(WidgetProviderSelection.overview(
                    from: providers, selected: chosen, selection: .manual, family: family, now: Self.now)
                    == WidgetProviderSelection.resolve(
                        from: providers, selected: chosen, family: family, now: Self.now))
            }
        }
        // Chosen slots kept by a widget do not apply to the soonest-reset overview.
        let soonest = WidgetProviderSelection.overview(
            from: providers,
            selected: selected,
            selection: .soonestWeeklyReset(count: 2),
            family: .systemSmall,
            now: Self.now)
        #expect(soonest.map(\.providerID) == ["codex", "claude"])
    }

    @Test func `Every placeholder provider with a weekly lane has a weekly reset`() {
        for provider in CodexBarWidgetSnapshot.placeholder(now: Self.now).topProviders {
            let laneReset = provider.quotaPace?.windows.first { $0.laneSeriesName == "weekly" }?.resetsAt
            #expect(provider.weeklyResetsAt == laneReset, "\(provider.providerID)")
        }
    }

    // MARK: Configuration (both widget generations)

    @Test func `SiriKit provider selection maps to the overview selection`() {
        let intent = SelectStatusWidgetIntent()
        // Widgets added before the parameter existed read unknown values.
        #expect(StatusWidgetConfigurationAdapter.overviewSelection(from: intent) == .manual)
        intent.providerSelection = .manual
        intent.providerCount = .four
        #expect(StatusWidgetConfigurationAdapter.overviewSelection(from: intent) == .manual)
        intent.providerSelection = .soonestWeeklyReset
        intent.providerCount = .unknown
        #expect(StatusWidgetConfigurationAdapter.overviewSelection(from: intent)
            == .soonestWeeklyReset(count: WidgetOverviewSelection.defaultCount))
        for (count, expected) in [(StatusWidgetProviderCount.two, 2), (.three, 3), (.four, 4)] {
            intent.providerCount = count
            #expect(StatusWidgetConfigurationAdapter.overviewSelection(from: intent)
                == .soonestWeeklyReset(count: expected))
        }
        // The rendering configuration is unchanged by the selection.
        intent.provider1 = StatusWidgetProvider(identifier: "claude", display: "Claude")
        #expect(StatusWidgetConfigurationAdapter.configuration(from: intent).providers?.map(\.id) == ["claude"])
        #expect(StatusWidgetConfigurationAdapter.configuration(from: intent).mode == .overview)
    }

    @available(iOS 27.0, *)
    @Test func `App Intent provider selection maps like the SiriKit one`() {
        #expect(StatusWidgetConfigurationAdapter.overviewSelection(from: StatusWidgetAppIntent()) == .manual)
        #expect(StatusWidgetAppIntent().providerSelection == .manual)
        #expect(StatusWidgetAppIntent().providerCount.count == WidgetOverviewSelection.defaultCount)
        let pairs: [(StatusWidgetProviderSelectionAppEnum, StatusWidgetProviderSelection)] = [
            (.manual, .manual),
            (.soonestWeeklyReset, .soonestWeeklyReset),
        ]
        let counts: [(StatusWidgetProviderCountAppEnum, StatusWidgetProviderCount)] = [
            (.two, .two),
            (.three, .three),
            (.four, .four),
        ]
        for (appSelection, siriSelection) in pairs {
            for (appCount, siriCount) in counts {
                let app = StatusWidgetAppIntent(
                    mode: .overview,
                    providerSelection: appSelection,
                    providerCount: appCount)
                let siri = SelectStatusWidgetIntent()
                siri.mode = .overview
                siri.providerSelection = siriSelection
                siri.providerCount = siriCount
                #expect(StatusWidgetConfigurationAdapter.overviewSelection(from: app)
                    == StatusWidgetConfigurationAdapter.overviewSelection(from: siri))
            }
        }
        #expect(StatusWidgetConfigurationAdapter.overviewSelection(from: StatusWidgetAppIntent(
            mode: .overview, providerSelection: .soonestWeeklyReset, providerCount: .three))
            == .soonestWeeklyReset(count: 3))
    }

    /// SiriKit parent relations (independent scalar parameters, not a
    /// fixed-size array; Research/062/09): the selection under the overview,
    /// the count under "By weekly reset". A parameter has one parent and a
    /// hidden parent does not hide its children (iOS 26.5, Research/073), so
    /// the slots keep their shipped `mode == overview` relation: under
    /// `providerSelection` they would show for every widget type.
    @Test func `SiriKit parameters show only where they apply`() throws {
        let url = try #require(Bundle.main.url(forResource: "WidgetStatus", withExtension: "intentdefinition"))
        let definition = try #require(try PropertyListSerialization.propertyList(
            from: Data(contentsOf: url), format: nil) as? [String: Any])
        let intents = try #require(definition["INIntents"] as? [[String: Any]])
        let status = try #require(intents.first { $0["INIntentName"] as? String == "SelectStatusWidget" })
        let parameters = try #require(status["INIntentParameters"] as? [[String: Any]])
        func relation(_ name: String) -> [String]? {
            guard let parameter = parameters.first(where: { $0["INIntentParameterName"] as? String == name }),
                  let relation = parameter["INIntentParameterRelationship"] as? [String: Any]
            else { return nil }
            return [
                relation["INIntentParameterRelationshipParentName"] as? String ?? "",
                relation["INIntentParameterRelationshipPredicateName"] as? String ?? "",
                relation["INIntentParameterRelationshipPredicateValue"] as? String ?? "",
            ]
        }
        #expect(relation("mode") == nil)
        #expect(relation("colorStyle") == nil)
        #expect(relation("providerSelection") == ["mode", "EnumHasExactValue", "overview"])
        #expect(relation("providerCount") == ["providerSelection", "EnumHasExactValue", "soonestWeeklyReset"])
        for slot in 1...4 {
            #expect(relation("provider\(slot)") == ["mode", "EnumHasExactValue", "overview"])
        }
        let counts = parameters.first { $0["INIntentParameterName"] as? String == "providerCount" }
        let defaultCount = (counts?["INIntentParameterMetadata"] as? [String: Any])?[
            "INIntentParameterMetadataDefaultValue",
        ] as? String
        #expect(defaultCount == "two")
        #expect(WidgetOverviewSelection.defaultCount == 2)
        // Tags only grow: placed widgets keep their stored values.
        let tags = parameters.compactMap { $0["INIntentParameterTag"] as? Int }
        #expect(Set(tags).count == tags.count)
        #expect((status["INIntentLastParameterTag"] as? Int).map { $0 >= tags.max() ?? 0 } == true)
    }
}
