# 实现记录

Status: `in-progress`

## 合并冲突决策（2026-10-15）

`git merge --no-ff --no-commit v0.76.0`（tag commit `b4051c2efb6d9d2c5d8cfcab5c6a468c75a40646`，已包含 v0.75.0），41 个冲突文件，逐个处理：

- `README.md`：按规则恢复为 mobile-dev 的原字节（`git checkout HEAD -- README.md`），之后单独提交上游事实（见下文 README 一节）。
- `AGENTS.md`、`appcast.xml`、`version.env`：保留 fork 版。版本号随后按 00 的方案单独更新。
- `CHANGELOG.md`：上游 0.76.0、0.75.0 段放在 fork 0.74.1.1 段之前（时间倒序），上游段完整保留。fork 0.76.0.1 段在发版准备时加在最前面。
- CI：`.github/workflows/ci.yml`、`Scripts/ci_verify_test_jobs.sh`、`Scripts/test_ci_path_gate.sh` 整份保留 fork 版本。上游 0.75/0.76 把 macOS runner 换成 `xcode-27` 镜像、删掉 `swift-build-macos-compatibility` job 并改了聚合参数顺序；fork 的双层触发、6 shard 与兼容构建由 `docs/ci-policy.md` 规定，参数约定也不同，不采用。`Scripts/test_swift_test_process_cleanup.py`：上游把成功 fixture 的超时放宽到 15 秒；fork 之前为同一问题加了 `command_timeout` 参数。合并为 `timeout = max(command_timeout, 15 if expected in (0, 23) else 2)`。
- `Sources/CodexBar/PreferencesAboutPane.swift`：About 链接保留 fork（GitHub 仓库、官网、X、邮件），同时接入上游新增的 Acknowledgements `NavigationLink`（开源致谢页是上游 0.76.0 的功能，fork 完整保留）。
- 23 个 `Sources/CodexBar/Resources/*.lproj/Localizable.strings`：冲突都在文件尾部——fork 在 0.74.1.1 追加的 `"Voice slots"`、`"Professional voices"` 与上游追加的新 key（fal/FLORA 凭证说明、Live Usage、provider 排序、Claude plan 等）同位置。脚本化处理：取上游 hunk，再把上游没有的 fork key 追加回去。`en.lproj` 另有 `show_credits_extra_usage_title/subtitle` 冲突，上游 #4484 改变了这个开关的语义（“可选的 credits、支出与账单明细”），取上游文案。全部 `plutil -lint` 通过；fork 自己的 `mobile_*`、`icloud_*`、Aixy 标签等 key 由 git 自动合入，未受影响。
- `Sources/CodexBarCore/UsageFetcher.swift`：`UsageSnapshot` 两边都保留——fork 的 7 个 live-only 桥接字段（perplexity/grok/elevenLabs/groq/llmProxy/azureOpenAI/alibabaTokenPlan）加上游新增的 `throughput: ProviderThroughputSnapshot?`（Codable，上游 Live Usage 用）。
- `Sources/CodexBar/UsageStore.swift`：上游把 `refreshPathDebugInfo` 改成内联赋值并放进 `UsageStore.swift`；fork 早已在 `UsageStore+PathDebug.swift` 中以同样实现提供该方法，所以不再重复定义（保留 fork 侧）。
- Codex 成本（见下节）：`CostUsageScanner+PricingRows.swift` 合并上游 #4452 的 `if row.isIncludedInPlan == true { return 0 }`（Auto-review 自 10-06 起 $0），保留 fork 以 `priorityMetadata` 计算 priority 定价模型的写法；`CostUsageScanner+CacheHelpers.swift` 采用上游把 `customPricing` 参数贯通到 pricing 汇总的改动，同时保留 fork 的 `pricingCatalog` 命名；`CostUsageStore.swift` 的 `compatiblePredecessorParserHashes` 取并集并登记 fork 0.74.1.1 的 hash；两份测试同样取并集（`CostUsageStoreReadWorkTests` 同时保留 fork 的 `bucketTimeZoneIdentifier` 与上游新增的 `detailsAreComplete`）。
- `Sources/CodexBarCore/Generated/CodexParserHash.generated.swift`：由脚本重新生成。
- `Scripts/lint.sh` 无冲突，自动合入上游新增的 `acknowledgements.py` / `test_acknowledgements.py` 检查。

## Codex 成本缓存与 parser 版本

- 上游 0.75/0.76 改动了 parser-hash 覆盖的文件（`CostUsageScanner.swift`、`+CacheHelpers`、`+PricingRows`、`+TemporalBuckets`、`+TurnPerformance`、`CostUsageCacheModels`）。按发布清单，`CostUsagePricing.parserLogicVersion` 从 21 升到 22，并重新生成 `CodexParserHash`，结果 `e34dea88998a523f`。
- 上游把自家 v0.74.1 的 store（`f406dae284de4a55`，“Revision 13 reparses rows to record the session creator account for Auto-review”）和 `fc698834d6329beb` 登记为可沿用前驱，通过 revision 迁移重新解析行。fork 已发布的 0.74.1.1 store（`68cbd75ed0e591d9`）等于上游 0.74.1 的解析逻辑加上 fork 的 ledger 重新定价（与 074 处理 0.73.0.1 时相同的关系），因此也登记为 `compatiblePredecessorParserHashes`，并加入测试的前驱参数表，使 0.74.1.1 用户升级后不全量重扫 Codex 日志。0.73.0.1 的 `0d41437dcd95c17e` 继续保留。

## 编译修复

- `AccountIdentityComputer`：上游新增 4 个 `UsageProvider`（`fal`、`flora`、`parallel`、`claudeplatform`），没有跨 Mac 的账号标识，归入 per-device 分组。

## README（单独 commit）

合并 commit 里的 README 与 mobile-dev 字节一致。之后单独审计 `git diff v0.74.1 v0.76.0 -- README.md`，只移植事实变化：social 图 token 与 "104 providers"；Command Code 改为 API key 或浏览器/手动 cookie；X API、LithosAI、TinyApi 的 "Chrome" 改为 "Browser"（上游 #4443 全浏览器 cookie 导入）；在 Sofya 之后新增 fal、FLORA、Parallel、Claude Platform 四行；社区项目 codexbar-kde 更名为 CodexBar AgentView，新增 "Desk display" 一节（AI Monitor、TokenTV；AI Monitor 在上游 0.74.1 已存在，074 轮漏移植，本轮补上）与 "Phone & web" 的 Notify! CodexBar。fork 身份与下载内容不变。guard hash 更新为 `236bd03f6ccc5226f7db3e00acafbc382be9ddd29f5b19c0d6a884b6f97d0aa5`，`Scripts/check_fork_readme.sh` 通过。

## Mac→iOS 桥接

- `SyncCoordinator.mapProviderAmount` 新增 `.claudeplatform`（`balance != nil` 时发布，负数也发布；period 默认 "Prepaid credits"）。
- `buildProviderUsageSnapshot` 的 budget：provider 为 `.claude` 且 provider 没报 reset 时，`budget.resetsAt` 改用上游 `claudeMonthlySpendWindow` 推断的 UTC 月末（与 Mac 菜单 meter 一致）；provider 明确给出的 reset 不被替换。注意 fork 有两条 budget 路径（插件 `buildPluginProviderUsageSnapshot` 与 first-party），只有 first-party 路径有 `provider`，第一次误改到插件路径导致编译失败，已移回。
- `QuotaProviderList` 尾部追加 `claudeplatform`（88 / 264）。
- `MockProviderInjector`：4 个新 provider 的 mock（119 个快照 / 109 个 ID）：fal（details "Account balance"，organization "fixture-team"）、FLORA（caller 范围三行，带 secondaryValue）、Parallel（Balance + Pending debit）、Claude Platform（两个无 reset 的 grant 窗口、带 progress 的 "Other credit grants" 行、Billing、188.75 余额）。`SyncProviderDetailSection.Row.progress` 是 `Progress(used:total:)`，不是 Double。
- 23 种语言 `Localizable.strings`：mock 说明计数 115/105 → 119/109（包括波斯数字）。
- `codexPricingIsEstimated(for row:)`：`isIncludedInPlan == true` 直接返回 false（$0 Auto-review 行不算估算）。
- gatekeeper：更新 `mapProviderAmount`（11 个引用）与 `AccountIdentityComputer`（49 个引用）两处指纹；新 mock 片段都写了 `Provider-specific by design` 说明。
- 新测试 `SyncV076BridgeTests`（Claude Platform 余额、grant 窗口与明细上线、Claude 月度上限推断 reset、Parallel 详情透传、FLORA `mapSyncedDetails`）与 `CostUsageCodexAutoReviewEstimateTests`。FLORA / fal 需要 API key 才会被 `UsageStore.isProviderAvailable` 标为可用，所以完整发布路径用浏览器会话型的 Parallel 覆盖。

## iOS 2.9.0 (242)

- `ProviderColorPalette.v072BrandHex`：claudeplatform `CC7C5E`、fal `7C3AED`、flora `111111`、parallel `1D1C1A`，全部精确匹配（claudeplatform 必须在通用 `contains("claude")` 之前；fal 只有三个字母）。
- `ProviderDetailLocalization`：4 个 provider 加入 first-party；新增语义标签 Workspace balance / Member limit / Runs this month / Pending debit / Other credit grants / Monthly cap / Spend limit；`verbatimRowSections["claudeplatform"] = ["Other credit grants"]`；`localizedFloraValue`（固定说明值）与 `localizedClaudePlatformValue`（"<a> of <b> left"、"Expires <MMM d[, yyyy]> (UTC)"、两者以 " · " 拼接的窗口描述；日期用 `en_US_POSIX` UTC 解析，再按读者 locale 的 `MMMd` / `yMMMd` 模板输出，保留 "(UTC)"）。
- `ProviderWindowLabel`：`localizationKey` 与 `localized` 的显式 case 同时加入 "API credit" / "Purchased credit"（只加前者会落到 "Extra usage" 默认分支，第一次 iOS 单测即因此失败）。
- `Localizable.xcstrings`：新增 17 个 UI key 与 7 条 2.9.0 应用内说明（四语言），沿用文件原有的“每条一行、最新在前”格式（不能用 `json.dump` 重排整个文件）。
- `MobileReleaseNotesCatalog` 新增 2.9.0（Latest），2.8.0 不再标 Latest；`CodexBarMobile/CHANGELOG.md` 新增 2.9.0 (242)；`AppStoreMetadata/2.9.0` 四语言 release notes 与 review notes；`project.yml` 五个 target 2.9.0 / 242。
- 新测试 `V076ProviderPresentationTests`、`ProviderColorPaletteTests.v076ProviderColorsMatchUpstreamBrands`、`QuotaProviderListTests.v076ProvidersAppended`。
- PreviewData 按卡片类型核对：余额卡与纯详情卡沿用已有组件，本轮不新增样例。

## 版本

`version.env`：0.76.0.1 / 169.1 / Mobile 2.9.0 / v0.76.0 / 2026-10-15；根 CHANGELOG 增加 fork 0.76.0.1 段（`Scripts/validate_changelog.sh 0.76.0.1` 通过，`changelog-to-html.sh` 提取的是 fork 段）。
