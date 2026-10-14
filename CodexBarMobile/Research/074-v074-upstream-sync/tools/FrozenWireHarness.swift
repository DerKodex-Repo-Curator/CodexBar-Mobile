import Foundation

/// v0.74 wire fixture. Old Macs (0.73.0.1) publish Claude without subscription dates and Qwen
/// Cloud with its 5-hour label; new Macs (0.74.1.1) add a date-only Claude renewal as the
/// `subscriptionRenewsOn` calendar day (no instant), an exact expiry instant at 12:00 UTC,
/// Qwen Cloud's "Team" label, and two new providers: X API with a negative balance and Aerostack
/// with a reset-less percentage window. Old readers compile the published v0.73.0.1-mobile.2.6.0
/// Shared sources; new readers compile this branch.
@main
struct Harness {
    static let capture = Date(timeIntervalSince1970: 1_791_500_000)
    static let qwenReset = capture.addingTimeInterval(86400 * 9)
    static let renewalDay = "2026-11-03"
    /// An exact expiry instant exactly at 12:00:00 UTC, which must pass through unchanged.
    static let exactExpiry = Date(timeIntervalSince1970: 1_793_707_200 + 86400 * 28)

    static func provider(_ id: String, isNewWriter: Bool) -> ProviderUsageSnapshot? {
        switch id {
        case "claude":
            let window = SyncRateWindow(
                id: "primary", label: "Session", usedPercent: 12,
                windowMinutes: 300, resetsAt: self.capture.addingTimeInterval(3600), resetDescription: nil)
            #if NEW_WIRE
            return ProviderUsageSnapshot(
                providerID: "claude", providerName: "Claude", primary: window, secondary: nil,
                accountEmail: nil, loginMethod: "Max", statusMessage: nil, isError: false,
                lastUpdated: self.capture,
                subscriptionExpiresAt: isNewWriter ? self.exactExpiry : nil,
                subscriptionRenewsOn: isNewWriter ? self.renewalDay : nil,
                rateWindows: [window])
            #else
            return ProviderUsageSnapshot(
                providerID: "claude", providerName: "Claude", primary: window, secondary: nil,
                accountEmail: nil, loginMethod: "Max", statusMessage: nil, isError: false,
                lastUpdated: self.capture, rateWindows: [window])
            #endif
        case "qwencloud":
            let window = SyncRateWindow(
                id: "primary", label: isNewWriter ? "Team" : "5-hour", usedPercent: 40,
                windowMinutes: nil, resetsAt: self.qwenReset, resetDescription: isNewWriter ? "Team" : nil)
            return ProviderUsageSnapshot(
                providerID: "qwencloud", providerName: "Qwen Cloud", primary: window, secondary: nil,
                accountEmail: nil, loginMethod: isNewWriter ? "Team Token Plan" : "Coding Plan",
                statusMessage: nil, isError: false, lastUpdated: self.capture, rateWindows: [window])
        case "xapi":
            guard isNewWriter else { return nil }
            return ProviderUsageSnapshot(
                providerID: "xapi", providerName: "X API", primary: nil, secondary: nil,
                accountEmail: nil, loginMethod: "Browser session", statusMessage: nil, isError: false,
                lastUpdated: self.capture, rateWindows: [],
                providerAmount: SyncProviderAmount(
                    kind: "balance", amount: -1.2, currencyCode: "USD", period: "Prepaid credits",
                    isEstimated: false),
                details: [SyncProviderDetailSection(title: "Credits", rows: [
                    .init(label: "Balance", value: "-$1.20", usageValue: -1.2),
                ])])
        case "aerostack":
            guard isNewWriter else { return nil }
            let window = SyncRateWindow(
                id: "primary", label: "Monthly AI tokens", usedPercent: 38,
                windowMinutes: nil, resetsAt: nil, resetDescription: nil)
            return ProviderUsageSnapshot(
                providerID: "aerostack", providerName: "Aerostack", primary: window, secondary: nil,
                accountEmail: nil, loginMethod: "Pro", statusMessage: nil, isError: false,
                lastUpdated: self.capture, rateWindows: [window])
        default:
            return nil
        }
    }

    static let providerIDs = ["claude", "qwencloud", "xapi", "aerostack"]

    static func envelopes(in directory: String) throws -> [ProviderUsageEnvelope] {
        try self.providerIDs.compactMap { id in
            let url = URL(fileURLWithPath: directory).appendingPathComponent(id + ".json")
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            return try CloudSyncConstants.makeJSONDecoder().decode(ProviderUsageEnvelope.self, from: Data(contentsOf: url))
        }
    }

    static func checkCommon(_ provider: ProviderUsageSnapshot) {
        switch provider.providerID {
        case "claude":
            precondition(provider.primary?.usedPercent == 12)
            if let expiry = provider.subscriptionExpiresAt {
                precondition(expiry == self.exactExpiry)
            }
            // A date-only renewal is never published as an instant that old readers would localize.
            precondition(provider.subscriptionRenewsAt == nil)
        case "qwencloud":
            precondition(["Team", "5-hour"].contains(provider.primary?.label ?? ""))
            precondition(provider.primary?.resetsAt == self.qwenReset)
        case "xapi":
            precondition(provider.providerAmount?.amount == -1.2)
            precondition(provider.providerAmount?.kind == "balance")
            precondition(provider.details.first?.rows.first?.usageValue == -1.2)
        case "aerostack":
            precondition(provider.primary?.usedPercent == 38)
            precondition(provider.primary?.resetsAt == nil)
        default:
            fatalError("unexpected provider \(provider.providerID)")
        }
    }

    static func main() throws {
        let args = CommandLine.arguments
        guard args.count == 4 else { fatalError("mode, path, device required") }
        #if NEW_WIRE
        let isNew = true
        #else
        let isNew = false
        #endif
        if args[1] == "write" {
            for id in self.providerIDs {
                guard let provider = self.provider(id, isNewWriter: isNew) else { continue }
                let envelope = ProviderUsageEnvelope(
                    deviceID: args[3], deviceName: "Synthetic " + args[3], appVersion: "fixture",
                    mobileVersion: "fixture", syncTimestamp: self.capture,
                    notificationPushEnabled: false, provider: provider)
                try CloudSyncConstants.makeJSONEncoder().encode(envelope)
                    .write(to: URL(fileURLWithPath: args[2]).appendingPathComponent(id + ".json"))
            }
            return
        }
        // Subscription catalog: only new readers subscribe to the v0.74 percentage providers;
        // zone names for the existing providers are identical on both sides.
        let zoneIDs = Set(QuotaProviderList.providers.map(\.id))
        precondition(zoneIDs.contains("claude") && zoneIDs.contains("qwencloud"))
        precondition(zoneIDs.contains("aerostack") == isNew)
        precondition(!zoneIDs.contains("xapi"))
        precondition(QuotaProviderList.quotaZoneName(providerID: "claude", state: "depleted") == "Quota-claude-depletedZone")

        if args[1] == "merge" {
            let a = try self.envelopes(in: args[2])
            let b = try self.envelopes(in: args[3])
            let newWriters = [a, b].filter { $0.contains { $0.provider.providerID == "xapi" } }.count
            for id in self.providerIDs {
                let sources = (a + b).filter { $0.provider.providerID == id }.map { envelope in
                    SyncedUsageSnapshot(
                        providers: [envelope.provider],
                        syncTimestamp: envelope.syncTimestamp,
                        deviceName: envelope.deviceName,
                        deviceID: envelope.deviceID)
                }
                guard !sources.isEmpty else {
                    precondition(newWriters == 0 || !["xapi", "aerostack"].contains(id))
                    continue
                }
                for ordering in [sources, Array(sources.reversed())] {
                    guard let merged = ProviderSnapshotMerger.mergeSnapshots(ordering) else {
                        fatalError("\(id) must survive the merge")
                    }
                    let providers = merged.providers.filter { $0.providerID == id }
                    precondition(providers.count == 1, "\(id) merged into \(providers.count) rows")
                    let provider = providers[0]
                    self.checkCommon(provider)
                    if id == "claude" {
                        // A renewal from any new writer survives a mixed merge; old-only stays nil.
                        precondition((provider.subscriptionExpiresAt != nil) == (newWriters > 0))
                        #if NEW_WIRE
                        precondition((provider.subscriptionRenewsOn == self.renewalDay) == (newWriters > 0))
                        #endif
                    }
                }
            }
            print("PASS: per-provider consumer merge (both orders), renewal retention, new-provider survival")
            return
        }

        let envelopes = try self.envelopes(in: args[2])
        precondition(!envelopes.isEmpty)
        for envelope in envelopes {
            precondition(envelope.deviceID == args[3])
            let provider = envelope.provider
            precondition(provider.primary == provider.rateWindows.first)
            self.checkCommon(provider)
            let roundtrip = try CloudSyncConstants.makeJSONEncoder().encode(envelope)
            let restored = try CloudSyncConstants.makeJSONDecoder().decode(ProviderUsageEnvelope.self, from: roundtrip)
            precondition(restored == envelope)
        }
        let writerIsNew = envelopes.contains { $0.provider.providerID == "xapi" }
        print("PASS \(args[3]) \(writerIsNew ? "new" : "old") producer: \(envelopes.count) envelopes, JSON roundtrip")
    }
}
