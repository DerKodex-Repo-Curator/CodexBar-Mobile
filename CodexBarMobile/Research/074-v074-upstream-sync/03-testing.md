# 测试

Status: `done`

日志目录：`/Volumes/StudioSSD/Developer/BuildScratch/CodexBar/upstream-v074/`（下文只写文件名）。

## Mac

| 项目 | 命令 | 结果 | 日志 |
|---|---|---|---|
| 合并后编译 | `swift build` | 第一次只报 `AccountIdentityComputer` 的 switch 不完整（9 个新 provider），补齐后 Build complete | build1.log |
| 测试 target 编译 | `swift build --build-tests` | 通过 | build-tests1.log |
| 定向：provider / mock / sync | `swift test --filter 'ProviderArchitectureGatekeeper\|QuotaProviderList\|MockProvider\|AccountIdentityComputer\|SyncCoordinator'` | 266 项通过（更新计数和 gatekeeper 指纹之后） | t-focused2.log |
| 新桥接 | `swift test --filter SyncV074BridgeTests` | 4 项通过：X API 负余额、日期锚点、Claude 完整推送路径、Qwen Team/Monthly 标签 | — |
| 全量（第一次） | `Scripts/test.sh` | 第 12 组失败后停止：上游新增的 `AboutWebsiteTests` 要求 About 网站等于 `docs/CNAME`（codexbar.app），而 fork 保留自己的网站。测试改为固定 fork 网站后，单独重跑 2 项通过 | mac-full1.log |
| 全量（第二次） | `Scripts/test.sh` | 第 34 组失败后停止：上游测试 `ClaudeSubscriptionPresentationTests` 用 `Locale.current` 计算期望日期，fork 的日期跟随 app 语言。测试改用 `codexBarLocalizedLocale()` 后 3 项通过 | mac-full2.log |
| 并行全量（作废） | `swift test --parallel` | 这套测试有大量计时类用例，并行负载下大面积超时，结果不作为证据，最终以 `Scripts/test.sh` 为准 | mac-parallel1.log |
| lint | `bash Scripts/lint.sh lint` | 第一次：2 个 swiftlint 违规（孤立 doc comment、多余的 `file_length` disable）；review 另外发现上游收紧的 `check-app-locales.mjs` 会失败。修复后退出码 0：0 个违规、App locales OK（22 个目录，2501 个英文 key）、Codex parser hash 是最新的（`68cbd75ed0e591d9`）、parser 版本审计 OK、fork README guard 通过、i18n 全部 translated | lint1.log、lint2.log |
| 全量分片 0 | `CODEXBAR_TEST_SHARD_INDEX=0 CODEXBAR_TEST_SHARD_COUNT=2 Scripts/test.sh` | **77/77 组首轮通过**（851 项） | mac-full3-s0.log |
| 全量分片 1（第一次） | 同上，index 1 | 第 34 组失败：`compatible predecessor parser hash adopts without rebuilding` 精确比对前驱集合，缺少新登记的 `0d41437dcd95c17e`。补上后 `CostUsageStoreTests` 77 项通过 | mac-full3-s1.log |
| 全量分片 1（第二次） | 同上 | 第 60 组失败：fork 自己的 Aixy 测试期望 zh-Hans "Organization" = "组织"；删除重复 key 后保留的是上游译文“组织机构”。测试改为上游译文后 16 项通过 | mac-full4-s1.log |
| 全量分片 1（最终） | 同上 | **76/76 组首轮通过**（856 项） | mac-full5-s1.log |
| 多账号 / 多设备 | `swift test --filter 'AccountIdentity\|MultiAccount\|DualZoneReader'` | 137 + 11 项通过 | t-multiaccount.log |
| Codex 多账号刷新 | `swift test --filter CodexAccountScopedRefreshTests` | 167 项通过（包括新增的超过 6 个账号完整发布回归测试） | — |

两个分片合计 153/153 组、1707 项选择，全部在同一份源码上首轮通过（分片 0 跑完之后只改过测试文件，涉及的 suite 都单独重跑过）。

## iOS

| 项目 | 命令 | 结果 | 日志 |
|---|---|---|---|
| 工程生成 | `xcodegen generate` | 通过 | — |
| 完整单元测试（第一次） | `xcodebuild test -only-testing:CodexBarMobileTests`（模拟器 CodexBar iOS 27 iPhone 18 Pro） | 编译通过，模拟器启动失败（`Invalid connectionUUID`，环境问题） | ios-unit1.log |
| 完整单元测试（第二次） | 启动模拟器后 `test-without-building` | Swift Testing 1085 项，其中 3 处失败，都在新的窗口标签测试：`ProviderWindowLabel` 的 switch `default` 固定返回 "Extra usage"，新 key 会被显示成“额外用量”。补上显式分支后修复。XCTest 部分全部通过（含 `WidgetSnapshotBuilderTests`） | ios-unit2.log |
| 定向重跑 | `V074ProviderPresentationTests`、`ProviderColorPaletteTests`、`QuotaProviderListTests` | 103 项通过 | ios-focused1.log |
| 完整单元测试（第三次） | 与 Mac 分片 1 并发运行 | 只有 `CWLPerformanceTests` 的 “Background history refresh at scale leaves the main actor responsive” 失败；单独重跑通过，属于并发负载造成的抖动 | ios-unit3.log、ios-perf1.log |
| 完整单元测试（最终，单独运行） | `xcodebuild test -only-testing:CodexBarMobileTests` | **TEST SUCCEEDED**：Swift Testing 1085 项 / 66 个 suite 全部通过，XCTest 全部通过（含 `WidgetSnapshotBuilderTests`） | ios-unit4.log、ios-unit4.xcresult |
| Release 设备构建 | `xcodebuild build -destination generic/platform=iOS -configuration Release CODE_SIGNING_ALLOWED=NO` | BUILD SUCCEEDED | ios-release-build.log |
| 四语言 | `bash Scripts/lint.sh audit-i18n` | 三个 xcstrings 全部 translated；source-vs-catalog 408 个 key 齐全 | — |

## 同步兼容 gate（2 Mac × 2 iPhone）

本轮改动属于 gate 适用范围：Mac 发布的 provider 显示数据有变化（X API 余额、Qwen 标签、Claude 日期锚点、9 个新 provider），iOS 渲染也有变化，所以执行 `docs/ios-sync-compatibility-testing.md`。

替代验证：`tools/check_frozen_wire.py --old-ref v0.73.0.1-mobile.2.6.0`（`tools/FrozenWireHarness.swift`）。
- old 是最后公开发布的 `v0.73.0.1-mobile.2.6.0` 的 Shared 源码与 `ProviderSnapshotMerger`；new 是本分支 HEAD。18 个源文件里只有 `QuotaProviderList.swift` 不同。
- old Mac 只发 Claude（没有续费日）和 Qwen Cloud（"5-hour"）；new Mac 另外发 Claude 的续费日（`subscriptionRenewsOn` 日期字段，不发时间戳）和恰好 12:00 UTC 的精确到期时间、Qwen "Team"、X API −1.2 余额、Aerostack 无 reset 窗口。
- 每个组合：两台 iPhone 各自读取两台 Mac 的全部 envelope（解码、校验、JSON 往返），再分别用自己的 merger 按两种顺序合并两台 Mac；还要校验订阅列表（只有 new 读端订阅 aerostack，没有任何一端订阅 xapi）。
- 结果：`PASS: 16 masks, 64 wire reads and 32 real old/new consumer merge processes`，日志 `frozen-wire/matrix-wire.log`、`frozen-wire/matrix-wire.json`、`frozen-wire/source-manifest.json`。

没有实体的 2 台 Mac + 2 台 iPhone 环境，也不能读写 Production CloudKit，所以 16 个组合都记为 `substituted`。old 指 Mac 0.73.0.1、iPhone 2.7.0 (240) 或更早；new 指 Mac 0.74.1.1、iPhone 2.8.0 (241)。

| Case | Mac A | Mac B | iPhone A | iPhone B | Result | Evidence | Notes |
|---:|---|---|---|---|---|---|---|
| 1 | old | old | old | old | substituted | 冻结 wire mask 0 PASS | 与上一版行为相同 |
| 2 | old | old | old | new | substituted | mask 1 PASS | 只有 old Mac，new iPhone 没有新数据可显示；新 iPhone 多订阅 3 个推送 zone，不会收到推送 |
| 3 | old | old | new | old | substituted | mask 2 PASS | 同 2 |
| 4 | old | old | new | new | substituted | mask 3 PASS | 同 2 |
| 5 | old | new | old | old | substituted | mask 4 PASS | old iPhone 把新 provider 显示为未知 provider 通用卡（没有颜色、英文），X API 余额照常显示；Qwen 显示英文 "Team"；Claude 续费日不显示（旧版没有这个字段）；不订阅新 provider 推送 |
| 6 | old | new | old | new | substituted | mask 5 PASS | iPhone A 同 5；iPhone B 完整显示 |
| 7 | old | new | new | old | substituted | mask 6 PASS | 同 6（角色互换） |
| 8 | old | new | new | new | substituted | mask 7 PASS | 两台 iPhone 收敛到同一状态；Claude 续费日来自 new Mac |
| 9 | new | old | old | old | substituted | mask 8 PASS | 同 5（Mac 角色互换） |
| 10 | new | old | old | new | substituted | mask 9 PASS | 同 6 |
| 11 | new | old | new | old | substituted | mask 10 PASS | 同 6 |
| 12 | new | old | new | new | substituted | mask 11 PASS | 同 8 |
| 13 | new | new | old | old | substituted | mask 12 PASS | 同 5 |
| 14 | new | new | old | new | substituted | mask 13 PASS | 同 6 |
| 15 | new | new | new | old | substituted | mask 14 PASS | 同 6 |
| 16 | new | new | new | new | substituted | mask 15 PASS | 全部新功能生效 |

残余风险：
- 实体四设备、Production CloudKit 收敛、APNs 时序、SwiftData 持久化与真实 UI 没有在本轮实测。
- 新 provider 没有真实账号，数据来自插件 fixture、mock 注入和单元测试。
- 旧 iPhone 上，Claude 只有日期的续费日不显示（与 0.73.0.1 时相同）。
- Gate 结论：16 个组合全部列出，均为 substituted，没有 fail。

## CloudKit Production schema 审计

对照最新公开 tag `v0.73.0.1-mobile.2.6.0`：
- `git diff $LAST_TAG..HEAD | grep -E "^\+.*(recordType|CKRecordZone\(|addIndex|querySchema|CKContainer|providerPayloadVersion|CKQuerySubscription|CKRecordZoneSubscription|encodingVersion)"`：只命中 iOS CHANGELOG 里的说明文字。
- `Shared/iCloud/CloudConstants.swift` 与 `Scripts/cloudkit/`：没有 diff；`providerPayloadVersion=1`。
- `Shared/Models/UsageSnapshot.swift`：`public let` 没有增减；Shared 只有 `QuotaProviderList` 追加 3 个运行时 zone。
- 打包：`Scripts/package_app.sh` 是 Production、容器 `iCloud.com.o1xhack.codexbar`、没有 `aps-environment`；iOS entitlements 是 Production。

结论 `NO_DEPLOY`，已写入 `docs/cloudkit-deploy-audit.md`。本轮没有调用 Production export 或 deploy。

## 真实日志成本验证（2026-10-13，用户要求补做）

目的：确认合并上游 v0.74 之后，前两版修好的成本数据（Research 068/069/070）不会被破坏，升级过程中 iPhone 也不会收到错误的已知值。

工具与数据（全部在 `/Volumes/StudioSSD/Developer/BuildScratch/CodexBar/costdiag/v074/`）：
- 只读快照：
  - T1：10-07 的 Codex 日志（沿用 Research 070 的快照，含 `logs_2.sqlite`）；
  - T2：今天 10-13 的 `~/.codex/sessions`、`archived_sessions`（`rsync`）和 `logs_2.sqlite`（`sqlite3 .backup`）；
  - Claude：`~/.claude/projects`。
  
  定价目录冻结为同一份 `models-dev-v1.json`。
- `CostDiag`：调用 `CostUsageScanner.loadDailyReport`。`CostSnap`：调用 App 的 `CostUsageFetcher.loadTokenSnapshot`，使用默认扫描额度，每调用一次相当于 App 刷新一次，并按 `SyncCoordinator` 的规则统计会作为已知值发给 iPhone 的天数和金额。两者都只在临时 worktree 里加 target，不进分支。
- 版本：0.73.0.1 tag（`273b23344`）、本分支、上游 v0.73.0 与 v0.74.1。
- 本机真实 App 的缓存元数据确认：parser hash 是 `0d41437dcd95c17e`（0.73.0.1），优先级库是 `~/.codex/logs_2.sqlite`。

### 结果

| 对比 | 74 天（08-01..10-13）合计 | 结论 |
|---|---|---|
| 0.73.0.1 全新扫描 vs 新版全新扫描 | $9,377.53 / 18.894B token vs 相同 | 逐天、逐模型一致（模型级差异不超过 3e-12 美元，浮点误差） |
| 0.73.0.1 在 T1 建缓存 → 日志按原地追加长到 T2 → 新版沿用并按默认额度分批扫描 | $9,377.53 | 与全新扫描逐天一致 |
| 0.73.0.1 缓存追到 T2 → 立即升级，App 路径逐次刷新 12 次 | 每次 30 天已知成本都是 $3,652.33 | 与 0.73.0.1 基线逐天、逐模型一致，没有任何中间低值 |
| Claude：0.73.0.1 建缓存 → 新版沿用 vs 新版全新扫描 | 19 天，$4,743.84 | 完全一致 |
| 上游 v0.73.0 → v0.74.1 沿用（缓存最新） | $9,377.53 | 一致 |

### 过程中的误判与纠正

- **第一轮结论“沿用少算 $586”是测试方法造成的假象。**
  - 当时用普通 `rsync` 把快照从 T1 更新到 T2。rsync 先写临时文件再改名，长大的 10 个会话文件因此换了 inode。
  - 上游迁移检查发现文件 ID 变了，按设计把整份文件的旧定价作废（调试日志 `guard1 fileId=…43872186/…43924135`），这些行都变成未定价。上游自己在同样条件下结果也一样。
  - 真实的 Codex 原地追加写入，inode 不变。改用 `rsync --inplace` 重测后，结果与全新扫描一致。
- **据此提交的“改为重建 0.73.0.1 缓存”（`25f16e5f2`）已经撤销（`4f4a83b19`）。** App 路径实测显示，重建期间每次刷新会把偏低的已知值发给 iPhone：30 天合计从 $84 起，逐次增加，按默认额度大约要刷新二十多次才能补完。iPhone 账本对更新的已知值会直接覆盖（`CostLedgerService.upsertDayPoint` 只拦“未知覆盖已知”），所以这个方案会让升级后的 iPhone 成本暂时大幅下降。沿用方案不会出现这个问题。
- 撤销后，Mac 打包输入（Sources、Shared、Package、打包脚本、version.env）与 Draft 构建时的 `ea96a4f20` 完全一致，已生成的 Draft 仍然有效。

### 补充测试

`0d41437dcd95c17e` 加入三张前驱参数表：
- `CostUsageRequestLedgerMigrationTests`：迁移后保留定价历史和 checkpoint；
- `CostUsageCoverageCompatibilityTests`：保留实际的 previous report；
- `CostUsagePerformanceGateTests`：沿用时零次会话头解析（fixture 行已经是当前 parser revision；真实的 0.73.0.1 store 被沿用后，仍会按扫描额度做 parser revision 迁移，重新读取日志）。

连同 `CostUsageStoreTests` 共 118 项通过；swiftformat、swiftlint 检查通过。

### 两个已有现象（不是本次合并引入，两个版本表现相同）

- **trace 库只读打开失败时不扫描新日志。** 如果 `logs_2.sqlite` 是 WAL 模式，但旁边没有 `-wal`/`-shm`（例如 Codex 退出后），只读连接打不开（SQLITE_CANTOPEN，错误 14）。这时新旧版本都只保留已缓存的数据，不扫描新日志，等 Codex 再运行时才统计。数据会延后，不会丢。
- **`historyIsFullyScanned` 在 CostSnap 路径上大多为 false**，基线和沿用都是这样。fork 发给 iPhone 的每日 `costIsKnown` 不依赖这个标记，所以没有影响；但这说明“按它拦截未扫完的数据”不能作为保护手段。
