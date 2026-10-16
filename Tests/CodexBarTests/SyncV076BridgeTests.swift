import CodexBarSync
import Foundation
import Testing
@testable import CodexBar
@testable import CodexBarCore

@MainActor
@Suite(.serialized)
struct SyncV076BridgeTests {
    private let observed = Date(timeIntervalSince1970: 1_791_600_000)

    private static func makeStore(suite: String, provider: UsageProvider) throws -> (SettingsStore, UsageStore) {
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let settings = SettingsStore(
            userDefaults: defaults,
            configStore: testConfigStore(suiteName: suite),
            zaiTokenStore: NoopZaiTokenStore(),
            syntheticTokenStore: NoopSyntheticTokenStore())
        settings.iCloudSyncEnabled = true
        try settings.setProviderEnabled(
            provider: provider,
            metadata: #require(ProviderDefaults.metadata[provider]),
            enabled: true)
        let store = UsageStore(
            fetcher: UsageFetcher(environment: [:]),
            browserDetection: BrowserDetection(cacheTTL: 0),
            settings: settings)
        return (settings, store)
    }

    @Test
    func `Claude Platform Console credits publish as a prepaid balance`() throws {
        for balance in [188.75, -3.0] {
            let cost = ProviderCostSnapshot(
                used: balance,
                limit: 0,
                currencyCode: "USD",
                period: "Prepaid credits",
                balance: balance,
                updatedAt: self.observed)
            let amount = try #require(SyncCoordinator.mapProviderAmount(
                provider: .claudeplatform,
                snapshot: nil,
                providerCost: cost))
            #expect(amount.kind == "balance")
            #expect(amount.amount == balance)
            #expect(amount.currencyCode == "USD")
            #expect(amount.period == "Prepaid credits")
            #expect(amount.observedAt == self.observed)
            #expect(!amount.isEstimated)
        }
        // Without a reported balance nothing is published; the budget lane stays empty as well.
        let noBalance = ProviderCostSnapshot(used: 0, limit: 0, currencyCode: "USD", updatedAt: self.observed)
        #expect(SyncCoordinator.mapProviderAmount(
            provider: .claudeplatform, snapshot: nil, providerCost: noBalance) == nil)
        // Balance-only v0.75 plugins carry no cost snapshot at all.
        for provider in [UsageProvider.fal, .flora, .parallel] {
            #expect(SyncCoordinator.mapProviderAmount(provider: provider, snapshot: nil, providerCost: nil) == nil)
        }
    }

    @Test
    func `Claude Platform grant windows keep their labels and expiry descriptions on the wire`() async throws {
        let (settings, store) = try Self.makeStore(
            suite: "SyncV076BridgeTests-claudeplatform", provider: .claudeplatform)
        let mock = MockSyncPusher()
        let coordinator = SyncCoordinator(store: store, settings: settings, syncManager: mock)
        let primary = RateWindow(
            usedPercent: 38,
            windowMinutes: nil,
            resetsAt: nil,
            resetDescription: "$124.75 of $200.00 left · Expires Oct 28 (UTC)")
        let secondary = RateWindow(
            usedPercent: 12,
            windowMinutes: nil,
            resetsAt: nil,
            resetDescription: "$44.00 of $50.00 left · Expires Dec 31 (UTC)")
        let grants = try ProviderDetailSection(
            title: "Other credit grants",
            rows: [.init(
                label: "Launch promo",
                value: "$20.00 of $25.00 left",
                secondaryValue: "Expires Nov 15 (UTC)",
                progress: .init(used: 5, total: 25))])
        let billing = try ProviderDetailSection(
            title: "Billing",
            rows: [.init(label: "This month (UTC)", value: "$36.20", usageValue: 36.2)])
        let snapshot = UsageSnapshot(
            primary: primary,
            secondary: secondary,
            providerCost: ProviderCostSnapshot(
                used: 188.75,
                limit: 0,
                currencyCode: "USD",
                period: "Prepaid credits",
                balance: 188.75,
                updatedAt: self.observed),
            details: [grants, billing],
            updatedAt: self.observed)
        store._setSnapshotForTesting(snapshot, provider: .claudeplatform)

        await coordinator.pushCurrentSnapshot()

        let provider = try #require(mock.lastSnapshot?.providers
            .first(where: { $0.providerID == UsageProvider.claudeplatform.rawValue }))
        #expect(provider.rateWindows.map(\.label) == ["API credit", "Purchased credit"])
        #expect(provider.primary?.resetDescription == "$124.75 of $200.00 left · Expires Oct 28 (UTC)")
        #expect(provider.primary?.resetsAt == nil)
        #expect(provider.providerAmount?.amount == 188.75)
        #expect(provider.providerAmount?.kind == "balance")
        #expect(provider.budget == nil)
        #expect(provider.details.map(\.title) == ["Other credit grants", "Billing"])
        #expect(provider.details.first?.rows.first?.label == "Launch promo")
        #expect(provider.details.first?.rows.first?.secondaryValue == "Expires Nov 15 (UTC)")
        #expect(provider.details.first?.rows.first?.progress?.total == 25)
    }

    @Test
    func `Claude monthly spend cap budget publishes the inferred UTC month rollover`() async throws {
        let (settings, store) = try Self.makeStore(suite: "SyncV076BridgeTests-claude-cap", provider: .claude)
        let mock = MockSyncPusher()
        let coordinator = SyncCoordinator(store: store, settings: settings, syncManager: mock)
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let observed = try #require(utc.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 9)))
        let monthEnd = try #require(utc.date(from: DateComponents(year: 2026, month: 11, day: 1)))
        // A spend-only account: no rate windows, only the monthly cap (upstream v0.75 CLI/OAuth parsers).
        let snapshot = UsageSnapshot(
            primary: nil,
            secondary: nil,
            providerCost: ProviderCostSnapshot(
                used: 42.5,
                limit: 100,
                currencyCode: "USD",
                period: "Monthly cap",
                updatedAt: observed),
            updatedAt: observed)
        store._setSnapshotForTesting(snapshot, provider: .claude)

        await coordinator.pushCurrentSnapshot()

        let provider = try #require(mock.lastSnapshot?.providers
            .first(where: { $0.providerID == UsageProvider.claude.rawValue }))
        let budget = try #require(provider.budget)
        #expect(budget.usedAmount == 42.5)
        #expect(budget.limitAmount == 100)
        #expect(budget.period == "Monthly cap")
        #expect(budget.resetsAt == monthEnd)
        // An explicit reset from the provider is never replaced by the inference.
        let explicit = observed.addingTimeInterval(86400 * 3)
        store._setSnapshotForTesting(
            UsageSnapshot(
                primary: nil,
                secondary: nil,
                providerCost: ProviderCostSnapshot(
                    used: 1,
                    limit: 10,
                    currencyCode: "USD",
                    period: "Spend limit",
                    resetsAt: explicit,
                    updatedAt: observed),
                updatedAt: observed),
            provider: .claude)
        await coordinator.pushCurrentSnapshot()
        let updated = try #require(mock.lastSnapshot?.providers
            .first(where: { $0.providerID == UsageProvider.claude.rawValue }))
        #expect(updated.budget?.resetsAt == explicit)
    }

    @Test
    func `Parallel balance details pass through verbatim without a window or amount`() async throws {
        // FLORA and fal need an API key before the Mac marks them available; Parallel is a browser
        // session, so it exercises the same details-only path through the real publication loop.
        let (settings, store) = try Self.makeStore(suite: "SyncV076BridgeTests-parallel", provider: .parallel)
        let mock = MockSyncPusher()
        let coordinator = SyncCoordinator(store: store, settings: settings, syncManager: mock)
        let section = try ProviderDetailSection(
            title: "Account balance",
            rows: [
                .init(label: "Balance", value: "$123.45", usageValue: 123.45),
                .init(label: "Pending debit", value: "$1.50", usageValue: 1.5),
            ])
        store._setSnapshotForTesting(
            UsageSnapshot(primary: nil, secondary: nil, details: [section], updatedAt: self.observed),
            provider: .parallel)

        await coordinator.pushCurrentSnapshot()

        let provider = try #require(mock.lastSnapshot?.providers
            .first(where: { $0.providerID == UsageProvider.parallel.rawValue }))
        #expect(provider.rateWindows.isEmpty)
        #expect(provider.providerAmount == nil)
        #expect(provider.budget == nil)
        let rows = try #require(provider.details.first?.rows)
        #expect(provider.details.first?.title == "Account balance")
        #expect(rows.map(\.label) == ["Balance", "Pending debit"])
        #expect(rows.map(\.value) == ["$123.45", "$1.50"])
        #expect(rows.map(\.usageValue) == [123.45, 1.5])
    }

    @Test
    func `FLORA workspace balance details map verbatim through the first-party mapper`() throws {
        let section = try ProviderDetailSection(
            title: "Workspace balance",
            rows: [
                .init(label: "Available", value: "-$2.00", secondaryValue: "Workspace pool", usageValue: -2),
                .init(label: "Spent this month", value: "Unavailable", secondaryValue: "Needs billing permission"),
                .init(label: "Runs this month", value: "1,234", usageValue: 1234),
            ])
        let mapped = SyncCoordinator.mapSyncedDetails([section], provider: .flora)
        let rows = try #require(mapped.first?.rows)
        #expect(mapped.first?.title == "Workspace balance")
        #expect(rows.map(\.label) == ["Available", "Spent this month", "Runs this month"])
        #expect(rows.map(\.value) == ["-$2.00", "Unavailable", "1,234"])
        #expect(rows.map(\.secondaryValue) == ["Workspace pool", "Needs billing permission", nil])
    }
}
