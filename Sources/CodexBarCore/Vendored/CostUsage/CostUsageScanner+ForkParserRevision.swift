import Foundation

extension CostUsageScanner {
    /// Upstream parser revision 13 (#4452) exists only to record whether the leaf `session_meta` names a
    /// ChatGPT creator account. Upstream reparses every older file from the start under the scan budget,
    /// which replaces that file's cached rows with the partially reparsed ones while the bounded reparse is
    /// in flight, so day totals drop for many refreshes and the iPhone ledger receives lowered "known"
    /// costs. A revision-12 store (fork 0.74.1.1, upstream 0.74.1) only needs the leaf metadata re-read.
    static let codexCreatorAccountParserRevision = 13

    /// A cached revision-12 file that the fork adopts in place. The caller hydrates the file's token
    /// history first: the store persists a revision change as a full rewrite, which would otherwise
    /// delete the snapshots that fork children resolve their baselines from.
    static func codexFileUsageNeedsCreatorAccountRevision(_ cached: CostUsageFileUsage?) -> Bool {
        cached?.codexParserRevision == self.codexCreatorAccountParserRevision - 1
            && CostUsageFileUsage.currentCodexParserRevision == self.codexCreatorAccountParserRevision
    }

    /// Adopts a revision-12 file in place: re-reads the leaf `session_meta` for the creator-account flag,
    /// stamps the current revision and keeps every cached row, checkpoint, snapshot and buffer untouched.
    /// Older or already-current files return nil and follow the upstream path; an unreadable file also
    /// returns nil so the next refresh retries instead of freezing the flag as unknown.
    static func codexFileUsageAdoptingCreatorAccountRevision(
        _ cached: CostUsageFileUsage?,
        fileURL: URL) -> CostUsageFileUsage?
    {
        guard let cached, codexFileUsageNeedsCreatorAccountRevision(cached),
              FileManager.default.isReadableFile(atPath: fileURL.path)
        else { return nil }
        let leaf = try? Self.parseCodexSessionMetadata(fileURL: fileURL)
        var updated = cached
        if let hasCreatorAccount = leaf?.hasCreatorAccount {
            var session = cached.codexSession ?? CostUsageCodexSessionMetadata()
            session.hasCreatorAccount = hasCreatorAccount
            updated.codexSession = session
        }
        updated.codexParserRevision = Self.codexCreatorAccountParserRevision
        return updated
    }
}
