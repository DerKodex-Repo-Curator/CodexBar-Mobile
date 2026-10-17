import Foundation

/// v0.76 wire fixture. Old Macs (0.74.1.1) publish Claude without a sign-in email and with the
/// synthetic 0 % Session placeholder next to Weekly; new Macs (0.76.0.1) publish Claude's OAuth
/// email as an account identity, drop the placeholder, send the CLI "Monthly cap" budget, and add
/// two new providers: Claude Platform (two grant windows without a reset, a prepaid balance and
/// grant details with progress) and Parallel (balance details only). Old readers compile the
/// published v0.74.1.1-mobile.2.8.0 Shared sources; new readers compile this branch.
@main
struct Harness {
    static let capture = Date(timeIntervalSince1970: 1_791_600_000)
    static let weeklyReset = capture.addingTimeInterval(86400 * 4)
    static let monthReset = capture.addingTimeInterval(86400 * 16)
    static let email = "fixture@example.com"
    static let identity = "claude:email:fixture@example.com"

    static func provider(_ id: String, isNewWriter: Bool) -> ProviderUsageSnapshot? {
        switch id {
        case "claude":
            let weekly = SyncRateWindow(
                id: "secondary", label: "Weekly", usedPercent: 30,
                windowMinutes: 10080, resetsAt: self.weeklyReset, resetDescription: nil)
            if isNewWriter {
                return ProviderUsageSnapshot(
                    providerID: "claude", providerName: "Claude", primary: weekly, secondary: nil,
                    accountEmail: self.email, loginMethod: "Max", statusMessage: nil, isError: false,
                    lastUpdated: self.capture,
                    budget: SyncBudgetSnapshot(
                        usedAmount: 42.5, limitAmount: 100, currencyCode: "USD", period: "Monthly cap",
                        resetsAt: nil, observedAt: self.capture),
                    rateWindows: [weekly],
                    accountIdentities: [self.identity])
            }
            let session = SyncRateWindow(
                id: "primary", label: "Session", usedPercent: 0,
                windowMinutes: 300, resetsAt: nil, resetDescription: nil, isSyntheticPlaceholder: true)
            return ProviderUsageSnapshot(
                providerID: "claude", providerName: "Claude", primary: session, secondary: weekly,
                accountEmail: nil, loginMethod: "Max", statusMessage: nil, isError: false,
                lastUpdated: self.capture, rateWindows: [session, weekly])
        case "claudeplatform":
            guard isNewWriter else { return nil }
            let primary = SyncRateWindow(
                id: "primary", label: "API credit", usedPercent: 38,
                windowMinutes: nil, resetsAt: nil,
                resetDescription: "$124.75 of $200.00 left · Expires Oct 28 (UTC)",
                balanceDescription: "$124.75 of $200.00 left · Expires Oct 28 (UTC)")
            let secondary = SyncRateWindow(
                id: "secondary", label: "Purchased credit", usedPercent: 12,
                windowMinutes: nil, resetsAt: nil,
                resetDescription: "$44.00 of $50.00 left · Expires Dec 31 (UTC)",
                balanceDescription: "$44.00 of $50.00 left · Expires Dec 31 (UTC)")
            return ProviderUsageSnapshot(
                providerID: "claudeplatform", providerName: "Claude Platform", primary: primary, secondary: secondary,
                accountEmail: nil, loginMethod: "Console session", statusMessage: nil, isError: false,
                lastUpdated: self.capture, rateWindows: [primary, secondary],
                providerAmount: SyncProviderAmount(
                    kind: "balance", amount: 188.75, currencyCode: "USD", period: "Prepaid credits",
                    isEstimated: false),
                accountOrganization: "Fixture Org",
                details: [
                    SyncProviderDetailSection(title: "Other credit grants", rows: [
                        .init(
                            label: "Launch promo", value: "$20.00 of $25.00 left",
                            secondaryValue: "Expires Nov 15 (UTC)", progress: .init(used: 5, total: 25)),
                    ]),
                    SyncProviderDetailSection(title: "Billing", rows: [
                        .init(label: "This month (UTC)", value: "$36.20", usageValue: 36.2),
                    ]),
                ])
        case "parallel":
            guard isNewWriter else { return nil }
            return ProviderUsageSnapshot(
                providerID: "parallel", providerName: "Parallel", primary: nil, secondary: nil,
                accountEmail: nil, loginMethod: "Browser session", statusMessage: nil, isError: false,
                lastUpdated: self.capture, rateWindows: [],
                details: [SyncProviderDetailSection(title: "Account balance", rows: [
                    .init(label: "Balance", value: "$123.45", usageValue: 123.45),
                    .init(label: "Pending debit", value: "$1.50", usageValue: 1.5),
                ])])
        default:
            return nil
        }
    }

    static let providerIDs = ["claude", "claudeplatform", "parallel"]

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
            precondition(provider.rateWindows.contains { $0.label == "Weekly" && $0.usedPercent == 30 })
            if let email = provider.accountEmail {
                precondition(email == self.email)
                precondition(provider.accountIdentities?.contains(self.identity) == true)
                precondition(provider.budget?.period == "Monthly cap")
                // New writers never publish the synthetic placeholder.
                precondition(!provider.rateWindows.contains { $0.isSyntheticPlaceholder })
            } else {
                precondition(provider.rateWindows.first?.isSyntheticPlaceholder == true)
            }
        case "claudeplatform":
            precondition(provider.providerAmount?.amount == 188.75)
            precondition(provider.providerAmount?.kind == "balance")
            precondition(provider.rateWindows.map(\.label) == ["API credit", "Purchased credit"])
            precondition(provider.primary?.resetsAt == nil)
            precondition(provider.primary?.resetDescription?.hasSuffix("(UTC)") == true)
            precondition(provider.details.count == 2)
            precondition(provider.details.first?.rows.first?.progress?.total == 25)
            precondition(provider.accountOrganization == "Fixture Org")
        case "parallel":
            precondition(provider.rateWindows.isEmpty && provider.providerAmount == nil)
            precondition(provider.details.first?.rows.map(\.usageValue) == [123.45, 1.5])
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
        // Subscription catalog: only new readers subscribe to the v0.76 percentage provider; balance-only
        // providers never subscribe; zone names for existing providers are identical on both sides.
        let zoneIDs = Set(QuotaProviderList.providers.map(\.id))
        precondition(zoneIDs.contains("claude") && zoneIDs.contains("tavily"))
        precondition(zoneIDs.contains("claudeplatform") == isNew)
        precondition(!zoneIDs.contains("parallel") && !zoneIDs.contains("fal") && !zoneIDs.contains("flora"))
        precondition(QuotaProviderList.quotaZoneName(providerID: "claude", state: "depleted") == "Quota-claude-depletedZone")
        precondition(QuotaProviderList.providers.last?.id == (isNew ? "claudeplatform" : "tavily"))

        if args[1] == "merge" {
            let a = try self.envelopes(in: args[2])
            let b = try self.envelopes(in: args[3])
            let newWriters = [a, b].filter { $0.contains { $0.provider.providerID == "claudeplatform" } }.count
            for id in self.providerIDs {
                let sources = (a + b).filter { $0.provider.providerID == id }.map { envelope in
                    SyncedUsageSnapshot(
                        providers: [envelope.provider],
                        syncTimestamp: envelope.syncTimestamp,
                        deviceName: envelope.deviceName,
                        deviceID: envelope.deviceID)
                }
                guard !sources.isEmpty else {
                    precondition(newWriters == 0 || !["claudeplatform", "parallel"].contains(id))
                    continue
                }
                for ordering in [sources, Array(sources.reversed())] {
                    guard let merged = ProviderSnapshotMerger.mergeSnapshots(ordering) else {
                        fatalError("\(id) must survive the merge")
                    }
                    let providers = merged.providers.filter { $0.providerID == id }
                    if id == "claude", newWriters == 1 {
                        // Mixed Macs: the old Mac's legacy no-identity row and the new Mac's email identity
                        // are distinct accounts until both Macs upgrade. Either shape must render.
                        precondition((1...2).contains(providers.count), "claude merged into \(providers.count) rows")
                        precondition(providers.contains { $0.accountEmail == self.email })
                    } else {
                        precondition(providers.count == 1, "\(id) merged into \(providers.count) rows")
                    }
                    for provider in providers {
                        self.checkCommon(provider)
                    }
                    if id == "claude" {
                        precondition(providers.contains { $0.accountEmail != nil } == (newWriters > 0))
                    }
                }
            }
            print("PASS: per-provider consumer merge (both orders), Claude identity retention, new-provider survival")
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
        let writerIsNew = envelopes.contains { $0.provider.providerID == "claudeplatform" }
        print("PASS \(args[3]) \(writerIsNew ? "new" : "old") producer: \(envelopes.count) envelopes, JSON roundtrip")
    }
}
