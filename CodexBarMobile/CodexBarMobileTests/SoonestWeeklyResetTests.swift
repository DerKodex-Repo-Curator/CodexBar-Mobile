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
        windows: [SyncRateWindow],
        isError: Bool = false) -> ProviderUsageSnapshot
    {
        ProviderUsageSnapshot(
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
        weeklyResetInHours hours: Double?) -> CodexBarWidgetProviderSummary
    {
        CodexBarWidgetProviderSummary(
            id: "\(id)|\(account)",
            providerName: name ?? id.capitalized,
            providerID: id,
            loginMethod: nil,
            usagePercent: 10,
            todayCostUSD: nil,
            thirtyDayCostUSD: nil,
            tokensToday: nil,
            isError: false,
            statusMessage: nil,
            lastUpdated: self.now,
            weeklyResetsAt: hours.map { Self.now.addingTimeInterval($0 * 3600) })
    }

    // MARK: Weekly window rule

    @Test func `Grok's untyped weekly window counts as weekly`() {
        #expect(WeeklyResetWindow.isWeekly(Self.grokWindow(minutes: 10079)))
        #expect(WeeklyResetWindow.isWeekly(Self.grokWindow(minutes: 10080)))
        #expect(WeeklyResetWindow.isWeekly(Self.grokWindow(minutes: nil)))
        // A floored period one DST hour short is still a week.
        #expect(WeeklyResetWindow.isWeekly(Self.window(minutes: 10020)))
    }

    @Test func `Claude and Codex weekly windows stay weekly`() {
        #expect(WeeklyResetWindow.isWeekly(Self.window(id: "secondary", label: "Weekly", minutes: 10080)))
        #expect(WeeklyResetWindow.isWeekly(Self.window(id: "secondary", minutes: 10080)))
        #expect(WeeklyResetWindow.isWeekly(Self.window(period: .weekly, minutes: nil)))
    }

    @Test func `Session, daily and monthly windows are never weekly`() {
        #expect(!WeeklyResetWindow.isWeekly(Self.window(label: "Session", minutes: 300)))
        #expect(!WeeklyResetWindow.isWeekly(Self.window(minutes: 1440)))
        #expect(!WeeklyResetWindow.isWeekly(Self.window(minutes: 43200)))
        #expect(!WeeklyResetWindow.isWeekly(Self.window(label: "Monthly", minutes: nil)))
        #expect(!WeeklyResetWindow.isWeekly(Self.window(minutes: nil)))
        // A length outranks the label: Grok's Mac also keeps explicit durations authoritative.
        #expect(!WeeklyResetWindow.isWeekly(Self.window(label: "Weekly", minutes: 43200)))
    }

    @Test func `A declared period decides whatever the length or label`() {
        #expect(!WeeklyResetWindow.isWeekly(Self.window(period: .monthly, minutes: 10080)))
        #expect(!WeeklyResetWindow.isWeekly(Self.window(label: "Weekly", period: .session, minutes: nil)))
        #expect(!WeeklyResetWindow.isWeekly(Self.window(period: .daily, minutes: 10079)))
        #expect(!WeeklyResetWindow.isWeekly(Self.window(period: .lifetime, minutes: nil)))
        #expect(WeeklyResetWindow.isWeekly(Self.window(period: .weekly, minutes: 9000)))
    }

    @Test func `The length must round to seven whole days`() {
        #expect(!WeeklyResetWindow.isWeekly(Self.window(minutes: 9359)))
        #expect(WeeklyResetWindow.isWeekly(Self.window(minutes: 9360)))
        #expect(WeeklyResetWindow.isWeekly(Self.window(minutes: 10799)))
        #expect(!WeeklyResetWindow.isWeekly(Self.window(minutes: 10800)))
    }

    @Test func `The label fallback reads the Mac's unlocalized English label`() {
        #expect(WeeklyResetWindow.isWeekly(Self.window(label: " weekly ", minutes: nil)))
        // Mac labels are never localized; a translated label is not a Mac label.
        #expect(!WeeklyResetWindow.isWeekly(Self.window(label: "每周", minutes: nil)))
        #expect(!WeeklyResetWindow.isWeekly(Self.window(label: "Premium weekly", minutes: nil)))
    }

    @Test func `The next weekly reset is the soonest weekly window and past resets roll forward`() {
        let windows = [
            Self.window(label: "Session", minutes: 300, resetInHours: 1),
            Self.window(label: "Weekly", minutes: 10080, resetInHours: 90),
            Self.grokWindow(minutes: 10079, resetInHours: 40),
        ]
        #expect(WeeklyResetWindow.nextReset(of: windows, now: Self.now) == Self.now.addingTimeInterval(40 * 3600))
        let stale = [Self.grokWindow(minutes: nil, resetInHours: -24)]
        #expect(WeeklyResetWindow.nextReset(of: stale, now: Self.now) == Self.now.addingTimeInterval(6 * 86400))
        #expect(WeeklyResetWindow.nextReset(of: [Self.window(minutes: 300)], now: Self.now) == nil)
        #expect(WeeklyResetWindow.nextReset(of: [Self.window(minutes: 10080, resetInHours: nil)], now: Self.now) == nil)
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
        let manual = WidgetProviderSelection.overviewFigures(for: claude, selection: .manual, now: now)
        #expect(manual.usagePercent == 80 && manual.resetsAt == now.addingTimeInterval(3600))
        let soonest = WidgetProviderSelection.overviewFigures(
            for: claude, selection: .soonestWeeklyReset(count: 2), now: now)
        #expect(soonest.usagePercent == 35 && soonest.resetsAt == now.addingTimeInterval(50 * 3600))
        // After the weekly reset passes, the next one shows without stale usage.
        let later = now.addingTimeInterval(51 * 3600)
        let rolled = WidgetProviderSelection.overviewFigures(
            for: claude, selection: .soonestWeeklyReset(count: 2), now: later)
        #expect(rolled.usagePercent == nil && rolled.resetsAt == now.addingTimeInterval((50 + 168) * 3600))
        // Without a weekly reset the tile keeps its usual figures.
        let openRouter = Self.summary("openrouter", weeklyResetInHours: nil)
        let fallback = WidgetProviderSelection.overviewFigures(
            for: openRouter, selection: .soonestWeeklyReset(count: 2), now: now)
        #expect(fallback.usagePercent == openRouter.usagePercent && fallback.resetsAt == openRouter.resetsAt)
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

    @Test func `The widget order matches the app's Weekly Reset order`() {
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

    @Test func `Manual selection keeps the existing overview`() {
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
