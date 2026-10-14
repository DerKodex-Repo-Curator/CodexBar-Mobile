import CodexBarSync
import Foundation
import Testing
@testable import CodexBar
@testable import CodexBarCore

@MainActor
@Suite(.serialized)
struct SyncV074BridgeTests {
    private let observed = Date(timeIntervalSince1970: 1_791_500_000)

    private static func utcDate(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        return try #require(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)))
    }

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
    func `X API prepaid credits publish as a balance including a negative amount`() throws {
        for balance in [3.5, -1.2] {
            let cost = ProviderCostSnapshot(
                used: 0,
                limit: 0,
                currencyCode: "USD",
                period: "Prepaid credits",
                balance: balance,
                updatedAt: self.observed)
            let amount = try #require(SyncCoordinator.mapProviderAmount(
                provider: .xapi,
                snapshot: nil,
                providerCost: cost))
            #expect(amount.kind == "balance")
            #expect(amount.amount == balance)
            #expect(amount.period == "Prepaid credits")
            #expect(amount.observedAt == self.observed)
        }
        let noBalance = ProviderCostSnapshot(used: 0, limit: 0, currencyCode: "USD", updatedAt: self.observed)
        #expect(SyncCoordinator.mapProviderAmount(provider: .xapi, snapshot: nil, providerCost: noBalance) == nil)
    }

    @Test
    func `date-only subscription dates publish as a calendar day and exact dates pass through`() throws {
        let midnight = try Self.utcDate(2026, 11, 3)
        #expect(SyncCoordinator.syncSubscriptionDay(midnight, isDateOnly: true) == "2026-11-03")
        #expect(SyncCoordinator.syncSubscriptionDay(midnight.addingTimeInterval(86399), isDateOnly: true)
            == "2026-11-03")
        #expect(SyncCoordinator.syncSubscriptionDay(midnight, isDateOnly: false) == nil)
        #expect(SyncCoordinator.syncSubscriptionDay(nil, isDateOnly: true) == nil)
    }

    @Test
    func `Claude date-only renewal publishes a calendar day and no instant`() async throws {
        let (settings, store) = try Self.makeStore(suite: "SyncV074BridgeTests-claude-renewal", provider: .claude)
        let renewal = try Self.utcDate(2026, 11, 3)
        let exactExpiry = try Self.utcDate(2026, 12, 1, hour: 12)
        let snapshot = UsageSnapshot(
            primary: RateWindow(usedPercent: 12, windowMinutes: 300, resetsAt: nil, resetDescription: nil),
            secondary: nil,
            updatedAt: self.observed)
            .withSubscriptionMetadata(expiresAt: exactExpiry, renewsAt: renewal, renewsAtIsDateOnly: true)
        store._setSnapshotForTesting(snapshot, provider: .claude)
        let mock = MockSyncPusher()
        let coordinator = SyncCoordinator(store: store, settings: settings, syncManager: mock)

        await coordinator.pushCurrentSnapshot()

        let provider = try #require(mock.lastSnapshot?.providers
            .first(where: { $0.providerID == UsageProvider.claude.rawValue }))
        // Old iPhones format instants locally, so a date-only day is never sent as an instant.
        #expect(provider.subscriptionRenewsAt == nil)
        #expect(provider.subscriptionRenewsOn == "2026-11-03")
        // An exact timestamp is unchanged, even on the old 12:00 UTC anchor instant.
        #expect(provider.subscriptionExpiresAt == exactExpiry)
        #expect(provider.subscriptionExpiresOn == nil)
        let json = try #require(String(
            bytes: CloudSyncConstants.makeJSONEncoder().encode(provider),
            encoding: .utf8))
        #expect(json.contains("\"subscriptionRenewsOn\":\"2026-11-03\""))
        #expect(!json.contains("subscriptionExpiresOn"))
    }

    @Test
    func `Qwen Cloud Team and monthly windows keep their Mac labels on the wire`() async throws {
        let (settings, store) = try Self.makeStore(suite: "SyncV074BridgeTests-qwen", provider: .qwencloud)
        let mock = MockSyncPusher()
        let coordinator = SyncCoordinator(store: store, settings: settings, syncManager: mock)
        let cases: [(RateWindow, String)] = [
            (RateWindow(
                usedPercent: 40,
                windowMinutes: nil,
                resetsAt: self.observed.addingTimeInterval(86400),
                resetDescription: "Team"), "Team"),
            (RateWindow(
                usedPercent: 25,
                windowMinutes: 30 * 24 * 60,
                resetsAt: self.observed.addingTimeInterval(86400),
                resetDescription: nil), "Monthly"),
        ]
        for (window, label) in cases {
            store._setSnapshotForTesting(
                UsageSnapshot(primary: window, secondary: nil, updatedAt: self.observed),
                provider: .qwencloud)
            await coordinator.pushCurrentSnapshot()
            let provider = try #require(mock.lastSnapshot?.providers
                .first(where: { $0.providerID == UsageProvider.qwencloud.rawValue }))
            #expect(provider.rateWindows.first?.label == label)
            #expect(provider.primary?.label == label)
        }
    }
}
