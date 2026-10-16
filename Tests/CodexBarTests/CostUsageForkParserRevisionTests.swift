import Foundation
import Testing
@testable import CodexBarCore

/// Fork-only: a revision-12 store (0.74.1.1) adopts parser revision 13 by re-reading the leaf `session_meta`
/// instead of reparsing every file from the start, so cached rows never disappear mid-migration.
struct CostUsageForkParserRevisionTests {
    @Test(arguments: [false, true])
    func `revision 12 files adopt the creator account flag without dropping cached rows`(growing: Bool) throws {
        let env = try CostUsageTestEnvironment()
        defer { env.cleanup() }
        let day = try env.makeLocalNoon(year: 2026, month: 10, day: 7)
        let model = "gpt-5.6-luna"
        func header(_ id: String, creator: String?) throws -> String {
            var payload: [String: Any] = ["id": id]
            if let creator { payload["creator_account_id"] = creator }
            return try env.jsonl([
                ["type": "session_meta", "timestamp": env.isoString(for: day), "payload": payload],
                ["type": "turn_context", "timestamp": env.isoString(for: day), "payload": ["model": model]],
            ]) + "\n"
        }
        func event(_ input: Int, second: Double) throws -> String {
            try env.jsonl([[
                "type": "event_msg",
                "timestamp": env.isoString(for: day.addingTimeInterval(second)),
                "payload": [
                    "type": "token_count",
                    "info": ["total_token_usage": [
                        "input_tokens": input,
                        "cached_input_tokens": 0,
                        "output_tokens": 0,
                    ]],
                ],
            ]]) + "\n"
        }
        _ = try env.writeCodexSessionFile(
            day: day,
            filename: "chatgpt.jsonl",
            contents: header("chatgpt", creator: "acct_fixture") + event(100, second: 1) + event(200, second: 2))
        _ = try env.writeCodexSessionFile(
            day: day, filename: "apikey.jsonl", contents: header("apikey", creator: nil) + event(50, second: 1))
        var options = CostUsageScanner.Options(
            codexSessionsRoot: env.codexSessionsRoot,
            claudeProjectsRoots: nil,
            cacheRoot: env.cacheRoot,
            codexTraceDatabaseURL: env.root.appendingPathComponent("missing-traces.sqlite"))
        options.refreshMinIntervalSeconds = 0
        options.preferNewestCodexSessionsFirst = false
        let clean = CostUsageScanner.loadDailyReport(
            provider: .codex, since: day, until: day, now: day, options: options)
        #expect(clean.summary?.totalTokens == 250)

        // Age the store to the 0.74.1.1 shape: revision 12 rows that never recorded the creator account.
        var legacy = CostUsageStoreAccess.read(cacheRoot: env.cacheRoot)
        let chatgptPath = try #require(legacy.files.keys.first { $0.hasSuffix("/chatgpt.jsonl") })
        let apikeyPath = try #require(legacy.files.keys.first { $0.hasSuffix("/apikey.jsonl") })
        for path in [chatgptPath, apikeyPath] {
            legacy.files[path]?.codexParserRevision = CostUsageScanner.codexCreatorAccountParserRevision - 1
            legacy.files[path]?.codexSession?.hasCreatorAccount = nil
        }
        let cachedRows = try #require(legacy.files[chatgptPath]?.codexRows?.map(\.input))
        #expect(cachedRows == [100, 100])
        CostUsageStoreAccess.replace(cacheRoot: env.cacheRoot, cache: legacy)
        if growing {
            let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: chatgptPath))
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(event(300, second: 3).utf8))
            try handle.close()
        }

        // A one-byte budget would leave an upstream from-the-start reparse with no rows at all.
        options.maxCodexScanBytesPerRefresh = 1
        let budgeted = CostUsageScanner.loadDailyReport(
            provider: .codex, since: day, until: day, now: day.addingTimeInterval(3), options: options)
        let adopted = CostUsageStoreAccess.read(cacheRoot: env.cacheRoot)
        let chatgpt = try #require(adopted.files[chatgptPath])
        let apikey = try #require(adopted.files[apikeyPath])
        #expect(chatgpt.hasCurrentCodexParser)
        #expect(apikey.hasCurrentCodexParser)
        #expect(chatgpt.codexSession?.hasCreatorAccount == true)
        #expect(apikey.codexSession?.hasCreatorAccount == false)
        #expect(apikey.codexRows?.map(\.input) == [50])
        #expect(chatgpt.codexRows?.map(\.input).prefix(2) == [100, 100])
        if !growing {
            #expect(chatgpt.codexScanComplete != false)
            #expect(budgeted.data == clean.data)
        }

        options.maxCodexScanBytesPerRefresh = 512 * 1024 * 1024
        let final = CostUsageScanner.loadDailyReport(
            provider: .codex, since: day, until: day, now: day.addingTimeInterval(4), options: options)
        var referenceOptions = options
        referenceOptions.cacheRoot = env.root.appendingPathComponent("reference-cache")
        let expected = CostUsageScanner.loadDailyReport(
            provider: .codex, since: day, until: day, now: day.addingTimeInterval(4), options: referenceOptions)
        #expect(final.data == expected.data)
        #expect(final.summary?.totalTokens == (growing ? 350 : 250))
        let reopened = CostUsageStore(cacheRoot: env.cacheRoot).syncLoadCodexCache(calendar: .current)
        #expect(reopened.files[chatgptPath]?.codexRows?.map(\.input) == (growing ? [100, 100, 100] : [100, 100]))
        #expect(reopened.files[chatgptPath]?.codexSession?.hasCreatorAccount == true)
    }

    @Test
    func `older revisions and current files are left to the upstream path`() throws {
        let env = try CostUsageTestEnvironment()
        defer { env.cleanup() }
        let url = env.root.appendingPathComponent("missing.jsonl")
        var usage = CostUsageScanner.makeFileUsage(
            mtimeUnixMs: 1, size: 1, days: [:], parsedBytes: 1, codexRows: [], codexScanComplete: true)
        usage.codexParserRevision = CostUsageScanner.codexCreatorAccountParserRevision - 2
        #expect(CostUsageScanner.codexFileUsageAdoptingCreatorAccountRevision(usage, fileURL: url) == nil)
        usage.codexParserRevision = CostUsageScanner.codexCreatorAccountParserRevision
        #expect(CostUsageScanner.codexFileUsageAdoptingCreatorAccountRevision(usage, fileURL: url) == nil)
        #expect(CostUsageScanner.codexFileUsageAdoptingCreatorAccountRevision(nil, fileURL: url) == nil)
        // A revision-12 file whose leaf metadata cannot be read still adopts the revision and keeps its rows.
        usage.codexParserRevision = CostUsageScanner.codexCreatorAccountParserRevision - 1
        let adopted = try #require(CostUsageScanner.codexFileUsageAdoptingCreatorAccountRevision(usage, fileURL: url))
        #expect(adopted.hasCurrentCodexParser)
        #expect(adopted.codexSession?.hasCreatorAccount == nil)
        #expect(adopted.codexRows == usage.codexRows)
    }
}
