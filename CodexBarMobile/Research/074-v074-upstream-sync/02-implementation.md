# 实现记录

Status: `in-progress`

## 合并冲突决策（2026-10-12）

`git merge --no-ff --no-commit v0.74.1`（tag commit `7c08c0ae783b72040b728757eb85a6cfe4fc2443`，已包含 v0.74.0），19 个冲突文件，逐个处理：

- `README.md`：没有冲突，但上游改动被自动合入。按规则恢复为 mobile-dev 的原字节（`git checkout origin/mobile-dev -- README.md`），之后单独提交上游事实（见下文 README 一节）。
- `AGENTS.md`：保留 fork 版。上游新增的 “CI Efficiency / Commit & PR Guidelines” 属于上游贡献者规则，fork 的 AGENTS.md 是 fork 自己的路由文档。
- `appcast.xml`、`version.env`：保留 fork 版。版本号随后按 00 的方案单独更新。
- `CHANGELOG.md`：上游 0.74.1、0.74.0 段放在 fork 0.73.0.1 段之前，按时间倒序，上游段完整保留。fork 0.74.1.1 段在发版准备时加在最前面。
- `docs/claude.md`：采用上游版本。fork 的两处补充（Enterprise spend 说明、insights-only 说明）原本就是从上游提前移植的，上游版本已包含相同文字。
- `.github/pr-proof/antigravity-source-diagnostics.log`：上游删除了这个 proof 日志，接受删除。
- CI：`.github/workflows/ci.yml`、`Scripts/ci_macos_test_gate.sh`、`Scripts/ci_verify_test_jobs.sh`、`Scripts/test_ci_path_gate.sh` 整份保留 fork 版本。上游 0.74 把 CI 改成单 runner、两个 direct worker、compiled SwiftPM cache 和 draft 延迟；fork 的双层触发和 6 shard 由 `docs/ci-policy.md` 规定，不采用上游的 workflow 结构。`Scripts/test_swift_test_sharding.sh` 只有冲突 hunk 取 fork（6 shard 断言），其余自动合入的部分保留。
- `Scripts/lint.sh`：两边都保留。fork 的 `check_ci_upstream_check_gate`、`check_ci_policy` 和上游新增的 `check_ci_build_cache`（只测试 `Scripts/ci_swiftpm_cache.py`、`Scripts/ci_prune_swiftpm_cache.py` 这两个独立脚本，不读 workflow）都在 portable checks 里。
- `Sources/CodexBar/MenuCardView+ModelHelpers.swift`：日期格式化保留 fork 的 `codexBarLocalizedLocale()`（跟随 app 语言），时区采用上游 #4324 的 `dateOnly` UTC 规则（续费日期只有日期，不随本地时区漂移）。
- `Sources/CodexBar/PreferencesAboutPane.swift`：About 链接保留 fork（GitHub 仓库、官网、X、邮件都是 fork 的地址）。
- `UsageStore+Refresh.swift` 和 `UsageStore+TokenAccounts.swift`（上游 #4310 Settings 里按账号刷新）：上游给 `refreshProvider` 加了 `codexAccountIDs`，并给 `refreshCodexVisibleAccountsForMenu` 加了 `requestedAccountIDs`。fork 在这两个函数外面包了一层返回“发布是否完整”的 `…ForSnapshotPublication`。处理方式：
  - 两个参数贯通 fork 的包装层：`refreshProvider` → `refreshProviderForSnapshotPublication(…, codexAccountIDs:)` → 任务内的 `refreshProviderTracked/Pass`。
  - `refreshCodexVisibleAccountsForSnapshotPublication(generation:requestedAccountIDs:)` 只在全账号刷新（`requestedAccountIDs == nil`）且每个账号都成功时返回 true。只刷新部分账号时会更新这些账号的行，但不算一次完整发布，不调用 `markProviderRefreshSuccessful`。上游函数里的两个 `return` 对应改成 `return false`。
  - 上游新增的 ambient PAT 守卫（`guard !shouldUseAmbientCodexPATForUsage()`）也保留在 fork 的扇出分支里。
- `Tests/CodexBarTests/CostUsageStoreTests.swift`：取 fork 写法，用 `CostUsageStore.incompatibleRetainedReportPredecessorParserHashes` 判断，不用上游硬编码的数组，两者内容一致。
- `WidgetExtension/CodexBarWidgetExtension.xcodeproj/project.pbxproj`：两边都保留。fork 的 package 引用（`EFBE36CB…`）加上上游新增的 vi/en/es Localizable 引用，`plutil -lint` 通过。
- `CodexParserHash.generated.swift`：由脚本重新生成，见下节。

## Codex 成本缓存与 parser 版本

- 上游 0.74 改动了 parser-hash 覆盖的文件：`CostUsageScanner.swift`、`+TurnPerformance`、`+CodexFastJSON`、`+Projects`、`CostUsageCacheModels`。按发布清单，`CostUsagePricing.parserLogicVersion` 从 20 升到 21，并重新生成 `CodexParserHash`，结果为 `68cbd75ed0e591d9`。如果后续还改了被 hash 覆盖的文件，以 lint 的 `check_codex_parser_hash` 为准。
- 上游 0.74 把自家 0.73.0 的 store（`7ff985e81e281a11`）登记为可沿用的前驱，旧数据行通过 revision 迁移补齐 timing 字段。fork 已发布的 0.73.0.1 store（`0d41437dcd95c17e`）等于上游 0.73.0 的解析逻辑加上 fork 的 ledger 重新定价；这部分 fork 差异在合并后的代码里保持不变（parser 文件里 fork 相对上游的差异在 0.73.0.1 和本轮完全相同）。因此把 `0d41437dcd95c17e` 也登记为 `compatiblePredecessorParserHashes`，并加入测试的前驱参数表，这样 0.73.0.1 用户升级后不会全量重扫 Codex 日志。0.72.0.1 及更早发布的 fork store 仍然保持重建（`published fork stores before the ledger pricing fix rebuild instead of adopting`）。

## 编译修复

- `AccountIdentityComputer`：上游新增了 9 个 `UsageProvider`（`xapi`、`tavily`、`linkup`、`tinyapi`、`exa`、`cosmic`、`aerostack`、`sailresearch`、`sofya`）。它们没有跨 Mac 的账号标识，所以归入 per-device 分组。

## README（commit b23b79928）

合并 commit 里的 README 与 mobile-dev 字节一致。之后单独审计 `git diff v0.73.0 v0.74.1 -- README.md`，只移植事实变化：social 图 token 与 "100 providers"、生成区块（Langdock 的浏览器 profile，以及 X API、Tavily、Linkup、TinyApi、Exa、Cosmic AI、Aerostack、Sail Research、Sofya）、"Phone & web" 一节的 Starbridge。fork 身份与下载内容不变。guard hash 更新为 `3877c335a364f59864611b0fe9ffbb410a671e625a5428e375dd3a76e747dcc4`，`Scripts/check_fork_readme.sh` 通过。

## Mac→iOS 桥接（commit 300064fac）

- `SyncCoordinator.mapProviderAmount` 新增 `.xapi`（`balance != nil` 时发布，负数也发布；period 默认 "Prepaid credits"）。
- `buildProviderUsageSnapshot`：qwencloud 的 primary 标签改用 descriptor 的 `rateWindowLabels`（"Team" / "Monthly" / session 标签）。
- 只有日期的续费/到期日：最初移到当天 12:00 UTC 再发布；PR #192 review 之后改为发布新增的可选字段 `subscriptionRenewsOn/ExpiresOn`（`syncSubscriptionDay`），不再发时间戳。native 与 plugin 两条映射路径都改了。
- `QuotaProviderList` 尾部追加 aerostack、cosmic、tavily（87 / 261）。
- `MockProviderInjector`：9 个新 provider 的 mock（115 个快照 / 105 个 ID），详情行标签与插件输出逐一核对（Sofya 是 Available/Plan/Purchased credits，Sail Research 是 "Last 30 days spend"）；`resetsInSeconds <= 0` 时不带 `resetsAt`（真实插件没有 reset）。
- 23 种语言 `Localizable.strings`：mock 说明计数 106/96 → 115/105（包括波斯数字）；删除 fork 自己的 "5-hour"、"Organization"、"Plan expires: %@"、"Renews: %@" 副本，上游在同一文件后面也定义了这 4 个 key（后定义的生效），保留上游译文。全部 `plutil -lint` OK。
- gatekeeper：更新 4 处已登记的指纹（SyncCoordinator 标签与金额两段、UsageStore+Refresh、AccountIdentityComputer），新加的 mock 片段都写了 `Provider-specific by design` 说明。
- 新测试 `SyncV074BridgeTests`。

## iOS 2.8.0 (241)（commit 082e96bcc）

见 01 的 iOS 呈现一节和 06 的清单。其中一处修复：`ProviderWindowLabel` 的 switch `default` 分支固定返回 "Extra usage"，新 key 必须显式写分支，否则窗口标签会显示成“额外用量”（由新测试发现）。

## 版本（commit c90a62c74）

`version.env`：0.74.1.1 / 167.1 / Mobile 2.8.0 / v0.74.1 / 2026-10-11；根 CHANGELOG 增加 fork 0.74.1.1 段（`Scripts/validate_changelog.sh 0.74.1.1` 通过，`changelog-to-html.sh` 提取的是 fork 段）。

## Review 修复（commit 2d3b1851e）

独立 review agent（只读）第 1 轮的结果：

| 级别 | 问题 | 处理 |
|---|---|---|
| 阻断 | 上游 0.74 收紧的 `check-app-locales.mjs` 扫到了 fork 代码：About 署名行、Debug 面板的 "Refresh" 与提示文字、Mobile 面板的开发者推送测试标签、ElevenLabs 的两个 `title:`。`lint.sh lint` / `lint-macos` 会失败 | Debug 的 Refresh 改用 `L("Refresh")`；fork 专用的署名与开发者工具文字改为 `Text(verbatim:)`；"Voice slots"、"Professional voices" 补进 23 种语言目录（中日文与 iOS 译法一致）。`node Scripts/check-app-locales.mjs` 通过 |
| 应修 | 合并后上游会保留本轮没抓取账号的旧行。Codex 可见账号超过 6 个（抓取上限）时，fork 用 `currentSnapshots.count == accounts.count` 判断完整发布，结果永远是 false，Mac fleet 可能一直拿不到 Codex 的发布来源 | 改成逐个检查本轮抓取的账号都有成功快照；新增 8 个账号的回归测试 `full publication counts fetched accounts when rows beyond the menu limit are retained`（`CodexAccountScopedRefreshTests` 167 项通过） |
| 小 | 根 CHANGELOG 把完整性标记说成和 iPhone 有关，实际只影响 Mac fleet | 已改措辞 |
| 小 | Qwen Team 没有 reset 时间时，卡片的重置行显示英文 "Team" | `localizedV074Value` 增加 "Team"，加测试 |
| 小 | Claude 精确时间恰好是 12:00:00 UTC 时也会按 UTC 显示 | 当时接受；PR #192 review 再次指出，最终改为显式的日期字段，见下节 |
| 说明 | `pricingFingerprint` 已经没有调用者，升 `parserLogicVersion` 只通过 parser hash 起作用 | 记录；CHANGELOG 不再声称 Claude 会重扫 |

全量测试时另外修了两处上游测试和 fork 行为的冲突：
- `AboutWebsiteTests` 期望 About 网站等于 `docs/CNAME`（上游的 codexbar.app）。fork 保留自己的网站，测试改为固定 `https://codexbarios.o1xhack.com`。
- `ClaudeSubscriptionPresentationTests` 用 `Locale.current` 计算期望日期，fork 的日期跟随 app 语言（`codexBarLocalizedLocale()`，与提示文字同一语言）。测试改用同一个 locale。

另外删除了 `CostUsageModels.swift` 里已经多余的 `swiftlint:disable file_length`（上游把 session breakdown 拆到了单独文件），并把孤立的 doc comment 改为普通注释。`bash Scripts/lint.sh lint` 退出码 0，0 个违规。

## PR #192 Codex review

| 轮次 | head | 发现 | 处理 |
|---|---|---|---|
| 1 | `8c79f88` | P2：精确时间恰好是 12:00:00 UTC 时，iOS 会把它当成“只有日期”的锚点（UTC+12 以东会早一天） | `d28b779`：Mac 把这种精确时间往后挪 1 秒；补 Mac/iOS 测试和兼容 harness。线程已回复并 resolve |
| 2 | `d28b779` | P2：旧 iPhone 在 UTC+12 到 +14 会把 12:00 UTC 锚点显示成第二天，新 iPhone 的判断救不了旧版本 | 改用显式日期字段：Shared 新增可选 `subscriptionRenewsOn/ExpiresOn`（校验 `yyyy-MM-dd`，非法值解码为 nil），Mac 对只有日期的值只发这两个字段；去掉正午锚点、挪 1 秒和 iOS 的锚点判断。合并器取最新的非空值，payload 镜像负责持久化，SwiftData schema 不变。补测试：Mac `SyncV074BridgeTests`、iOS `V074ProviderPresentationTests`（显示、校验、合并），兼容 harness 改为新写端发日期字段、旧读端忽略，16 组合通过 |
