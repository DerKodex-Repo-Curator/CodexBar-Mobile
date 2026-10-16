import Foundation
import Testing
@testable import CodexBarCore

/// Fork-only: the iPhone receives `isEstimated` per day, so a plan-included Auto-review row priced at $0
/// with certainty (upstream v0.75 #4452) must not turn the day into an estimate.
struct CostUsageCodexAutoReviewEstimateTests {
    private static func row(includedInPlan: Bool?) -> CostUsageScanner.CodexUsageRow {
        var row = CostUsageScanner.CodexUsageRow(
            day: "2026-10-07",
            model: "codex-auto-review",
            turnID: nil,
            eventIndex: 0,
            timestampUnixMs: 1_791_356_400_000,
            input: 1000,
            cached: 0,
            output: 10)
        row.isIncludedInPlan = includedInPlan
        return row
    }

    @Test
    func `plan-included auto review rows are exact, uncovered ones stay estimated`() {
        // No bundled price for codex-auto-review: an ordinary row is an estimate.
        #expect(CostUsageScanner.codexPricingIsEstimated(
            for: Self.row(includedInPlan: nil), priorityMetadata: nil, modelsDevCatalog: nil))
        #expect(CostUsageScanner.codexPricingIsEstimated(
            for: Self.row(includedInPlan: false), priorityMetadata: nil, modelsDevCatalog: nil))
        // The free policy prices the row at $0 with certainty.
        #expect(!CostUsageScanner.codexPricingIsEstimated(
            for: Self.row(includedInPlan: true), priorityMetadata: nil, modelsDevCatalog: nil))
        #expect(CostUsageScanner.codexResolvedCostUSD(
            for: Self.row(includedInPlan: true),
            priorityTurns: [:],
            modelsDevCatalog: nil,
            modelsDevCacheRoot: nil,
            customPricing: nil) == 0)
    }
}
