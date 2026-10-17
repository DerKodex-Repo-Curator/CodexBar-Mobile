# 测试

Status: `done`（合并前；实体四设备矩阵为替代验证）

日志目录：`/Volumes/StudioSSD/Developer/BuildScratch/CodexBar/upstream-v076/`（下文只写文件名）。

## Mac

| 项目 | 命令 | 结果 | 日志 |
|---|---|---|---|
| 合并后编译 | `swift build` | 第一次失败：上游 #4467 新增的 `detailEarliest` 调用 `SpendDashboardModel.day(_:provider:)`，fork 已改为 `day(_:input:)`（时区桶）；改用 fork 重载后 Build complete。`AccountIdentityComputer` 的 4 个新 case 在合并时已补齐 | build1.log、build2.log |
| 测试 target 编译 | `swift build --build-tests` | 第一次失败：`CostUsageStoreReadWorkTests` 合并后参数顺序（`detailsAreComplete` 必须在 `bucketTimeZoneIdentifier` 之前）；修正后通过 | build-tests1.log、build-tests2.log |
| lint（第一次） | `bash Scripts/lint.sh lint` | swiftformat 1 处：新加的前驱 hash 注释超过行宽；其余（acknowledgements、CI policy、parser hash、fork README guard）通过。修正后待复跑 | lint1.log |
| 定向（第一次） | `swift test --filter 'SyncV076Bridge\|CostUsageCodexAutoReview\|QuotaProviderList\|MockProvider\|AccountIdentityComputer\|ProviderArchitectureGatekeeper\|CostUsageStoreTests\|CostUsageStoreReadWork'` | 337 项，8 处失败，全部是预期中的计数与指纹更新：mock 115/105/110 → 119/109/114；gatekeeper 两处允许列表（`mapProviderAmount` 新增 claudeplatform、`AccountIdentityComputer` 新增 4 个）；`SyncV076BridgeTests` 的 FLORA 用例——FLORA 需要 API key 才会被 Mac 标为可用，改用浏览器会话型的 Parallel 走完整发布路径，FLORA 改为直接测 `mapSyncedDetails` | t-focused1.log |
| 定向（第二次） | `swift test --filter 'SyncV076Bridge\|MockProvider\|ProviderArchitectureGatekeeper'` | 127 项通过（计数、指纹、Parallel/FLORA 用例修正后） | t-focused2.log |
| 定向（第三到六次） | `swift test --filter 'SyncV076Bridge\|ProviderArchitectureGatekeeper\|SyncCoordinatorTests\|SyncV074Bridge\|CostUsageCodexAutoReview'` | 第三次：Claude budget 推断误加在插件路径导致编译失败；第四、五次：gatekeeper 把新的 `provider == .claude` 并入相邻的 alibabatokenplan/perplexity 集群、随后新 helper 的 guard 与已有锚点同文、说明注释不在紧邻行；抽成独立 `inferredBudgetReset` helper 并用单行 `Provider-specific by design` 注释后，第六次 53 项通过（含 98 项的第四次集合在前几轮已通过的部分） | t-focused3.log … t-focused6.log |
| lint（第三到五次） | `bash Scripts/lint.sh lint` | 第三次：新测试两行超宽；第四次：swiftlint 5 处（multiline_arguments、line_length）；第五次 **退出码 0**：0 违规（3087 文件）、acknowledgements 18 components、CI policy、Codex parser hash 当时最新（`e34dea88998a523f`）、parser 版本审计 OK（parser 改动且已 bump）、fork README guard、App locales OK、i18n 409 个 key 齐全 | lint3.log、lint4.log、lint5.log |
| 全量分片 0（第一次） | `CODEXBAR_TEST_SHARD_INDEX=0 CODEXBAR_TEST_SHARD_COUNT=2 Scripts/test.sh` | 第 23 组 `CodexLaunchPreflightNPMMemoTests`（上游 #4080，fork 未改）首轮 2 处失败（standalone + hardened 的 Gatekeeper memo），`test.sh` 自动重试后该组通过；属于环境/时序抖动，记为观察项 | mac-full1-s0.log |
| 全量分片 0（结果） | 同上 | **退出码 0**：79 组，8048 项，第 23 组重试后通过；Timed out groups 0 | mac-full1-s0.log |
| 全量分片 1（第一次） | `CODEXBAR_TEST_SHARD_INDEX=1 … Scripts/test.sh` | `swift test list` 编译失败：review 轮把 mock 计数断言消息改成了字符串拼接，`#expect` 的 `Comment` 只接受字面量；改回单一字面量 | mac-full1-s1.log |
| 全量分片 1（第二次） | 同上 | **退出码 0**：7278 项，Isolated selection retries 12，Timed out groups 0 | mac-full2-s1.log |
| lint（第六次，revision 原地升级后） | `bash Scripts/lint.sh lint` | 退出码 0：0 违规、parser hash 当时最新（`dfc233f15775044b`）、parser 版本审计 OK | lint6.log |
| lint（第七次，最终源码 `ee6084b0e`） | `bash Scripts/lint.sh lint` | 退出码 0：0 违规、parser hash 最新（`8bf44283c990726d`）、parser 版本审计 OK、i18n 409 个 key | lint7.log |
| **最终全量分片 0**（`ee6084b0e`） | `CODEXBAR_TEST_SHARD_INDEX=0 … Scripts/test.sh` | **退出码 0**：79 组，8071 项；第 24 组 `CodexPaginatedHistoryAccountingTests` 的 "stale parser revision reparses an inflated continuation" 首轮失败、组重试通过（见下） | mac-final-s0.log |
| **最终全量分片 1**（`ee6084b0e`） | 同上 index 1 | **退出码 0**：7275 项，Timed out 0，Isolated retries 0 | mac-final-s1.log |
| 多账号 / 多设备 | `swift test --filter 'AccountIdentity\|MultiAccount\|DualZoneReader\|CodexAccountScopedRefresh'` | 通过（见 t-multiaccount.log） | t-multiaccount.log |
| 上游测试调整 | `swift test --filter 'CodexPaginatedHistoryAccounting\|CostUsageForkParserRevision\|CodexDayAttribution\|CostUsageCodexSourceRecovery\|CostUsageCodexAutoReview'` | 那条上游测试把 `currentCodexParserRevision - 1` 当作“任意陈旧 revision”并期望从头重解析修正人为注入的虚高 `days`；fork 对 12→13 原地升级保留缓存，于是结果取决于分页续写页的枚举顺序（首轮失败、重试通过）。改为 `- 2`（更旧的 stale revision 仍走上游重解析），6 个 suite 32 项通过；该 suite 单独循环 5 次全部通过。其他使用 `- 1` 的上游测试（DayAttribution、SourceRecovery、AutoReview）与原地升级兼容，均通过 | t-revision3.log、t-pag-1..5.log |
| lint（第八次，最终 HEAD `ca74e7954`） | `bash Scripts/lint.sh lint` | 退出码 0 | lint8.log |
| **最终 HEAD 全量分片 0/1**（`ca74e7954`，之后的提交只改 Research 文档） | `Scripts/test.sh` ×2 | **两个分片退出码 0**，无失败 suite（分片 0：7953 项，Timed out groups 0；分片 1：7275 项，1 个组整体超时后由 `test.sh` 拆成 12 个 isolated selection 重跑全部通过，与本机同时在跑的打包/诊断任务争抢 CPU 有关） | mac-final2-s0.log、mac-final2-s1.log |
| 定向（parser hash 复核） | `bash Scripts/lint.sh lint` 第二次 | 发现 `CodexParserHash` 过期（`codexPricingIsEstimated` 改动在重生成之后），重生成为 `e34dea88998a523f` | lint2.log |

## iOS

| 项目 | 命令 | 结果 | 日志 |
|---|---|---|---|
| 工程生成 | `xcodegen generate` | 通过（2.9.0 / 242，全部 target） | — |
| 模拟器构建 | `xcodebuild build`（CodexBar iOS 27 iPhone 18 Pro） | 通过 | ios-build1.log |
| 四语言 | `bash Scripts/lint.sh audit-i18n` | 三个 xcstrings 全部 translated；source-vs-catalog 408 个 key 齐全 | — |
| 完整单元测试（第一次） | `xcodebuild test -only-testing:CodexBarMobileTests` | 编译失败：新测试把 `String` 变量当作 `#expect` 的 `Comment`，改为字面量插值 | ios-unit1.log |
| 完整单元测试（第二次） | 同上 | 9 处失败，都在新测试：`ProviderWindowLabel.localized` 的 switch 没有 "API credit" / "Purchased credit" 的显式 case（落到 "Extra usage" 默认分支），以及 "Monthly cap" 没加入 `semanticLabels`。修复后 | ios-unit2.log |
| 完整单元测试（第三次） | 同上 | **TEST SUCCEEDED**：Swift Testing 1093 项 / 67 个 suite 全部通过，XCTest 全部通过（含 `WidgetSnapshotBuilderTests`） | ios-unit3.log、ios-unit3.xcresult |
| 完整单元测试（第四次，review 修复后） | 同上 | 1 处失败：新加的希伯来历 locale 用例把日/月顺序写死（实际 "Expires 28 Oct (UTC)"，公历日期正确）；断言改为检查公历日与月 | ios-unit4.log |
| 完整单元测试（第五次） | 同上 | **TEST SUCCEEDED**：1093 项 / 67 个 suite 全部通过 | ios-unit5.log、ios-unit5.xcresult |
| 小组件概览统一每周窗口（Research 076）后完整测试 | `xcodebuild test`（含 UI 测试） | **TEST SUCCEEDED**：Swift Testing 1096 项 / 67 个 suite，XCTest 单元 60 项，UI 24 项（6 项跳过）；小组件四套件与 review 记录见 Research/076 | ios-full3.log、ios-widget5.log |

## 同步兼容 gate（2 Mac × 2 iPhone）

本轮改动属于 gate 适用范围：Mac 发布的 provider 显示数据有变化（Claude Platform 余额与 grant 窗口、Claude 登录邮箱身份、Claude 月度上限 budget 的推断 reset、不再发送 Session 占位窗口、4 个新 provider），iOS 渲染也有变化，所以执行 `docs/ios-sync-compatibility-testing.md`。

替代验证：`tools/check_frozen_wire.py --old-ref v0.74.1.1-mobile.2.8.0`（`tools/FrozenWireHarness.swift`）。
- old 是最后公开发布的 `v0.74.1.1-mobile.2.8.0`（`1c5b6bd9e`）的 Shared 源码与 `ProviderSnapshotMerger`；new 是本分支工作树。18 个源文件里只有 `QuotaProviderList.swift` 不同（Shared 模型零改动）。
- old Mac 只发 Claude（无邮箱，Session 0% 占位 + Weekly）；new Mac 发 Claude（邮箱身份 `claude:email:…`、只有 Weekly、"Monthly cap" budget）、Claude Platform（两个无 reset 的 grant 窗口、188.75 余额、带 progress 的 grant 明细）和 Parallel（仅余额详情）。
- 每个组合：两台 iPhone 各自读取两台 Mac 的全部 envelope（解码、校验、JSON 往返），再分别用自己的 merger 按两种顺序合并两台 Mac；校验订阅列表（只有 new 读端订阅 claudeplatform，没有任何一端订阅 parallel/fal/flora，old 读端列表以 tavily 结尾、new 读端以 claudeplatform 结尾）。
- 新旧 Mac 混用时，Claude 的旧 Mac 行（无身份）与新 Mac 行（邮箱身份）是两个账号，合并后 1–2 行都必须能渲染；两台 Mac 同版本时恰好 1 行。
- 结果：`PASS: 16 masks, 64 wire reads and 32 real old/new consumer merge processes`，日志 `frozen-wire/matrix-wire.log`、`frozen-wire/matrix-wire.json`、`frozen-wire/source-manifest.json`。

没有实体的 2 台 Mac + 2 台 iPhone 环境，也不能读写 Production CloudKit，所以 16 个组合都记为 `substituted`。old 指 Mac 0.74.1.1、iPhone 2.8.0 (241) 或更早；new 指 Mac 0.76.0.1、iPhone 2.9.0 (242)。

| Case | Mac A | Mac B | iPhone A | iPhone B | Result | Evidence | Notes |
|---:|---|---|---|---|---|---|---|
| 1 | old | old | old | old | substituted | 冻结 wire mask 0 PASS | 与上一版行为相同 |
| 2 | old | old | old | new | substituted | mask 1 PASS | 只有 old Mac，new iPhone 没有新数据可显示；新 iPhone 多订阅 claudeplatform 的 3 个推送 zone，不会收到推送 |
| 3 | old | old | new | old | substituted | mask 2 PASS | 同 2 |
| 4 | old | old | new | new | substituted | mask 3 PASS | 同 2 |
| 5 | old | new | old | old | substituted | mask 4 PASS | old iPhone 把 Claude Platform / Parallel 显示为未知 provider 通用卡（Claude Platform 为旧版 Claude 橙、英文、无推送）；Claude Platform 余额以通用余额卡显示；Claude 出现两张卡（旧 Mac 无身份 + 新 Mac 邮箱身份），直到两台 Mac 都升级；"Monthly cap" 英文显示；Claude 月度上限预算显示推断的重置时间 |
| 6 | old | new | old | new | substituted | mask 5 PASS | iPhone A 同 5；iPhone B 完整显示（品牌色、四语言、grant 到期日按 UTC 日历） |
| 7 | old | new | new | old | substituted | mask 6 PASS | 同 6（角色互换） |
| 8 | old | new | new | new | substituted | mask 7 PASS | 两台 iPhone 收敛到同一状态；Claude 仍为两张卡（Mac 版本不同） |
| 9 | new | old | old | old | substituted | mask 8 PASS | 同 5（Mac 角色互换） |
| 10 | new | old | old | new | substituted | mask 9 PASS | 同 6 |
| 11 | new | old | new | old | substituted | mask 10 PASS | 同 6 |
| 12 | new | old | new | new | substituted | mask 11 PASS | 同 8 |
| 13 | new | new | old | old | substituted | mask 12 PASS | 同 5，但 Claude 合并为一张卡（两台 Mac 都发邮箱身份） |
| 14 | new | new | old | new | substituted | mask 13 PASS | 同 6，Claude 一张卡 |
| 15 | new | new | new | old | substituted | mask 14 PASS | 同 6，Claude 一张卡 |
| 16 | new | new | new | new | substituted | mask 15 PASS | 全部新功能生效 |

残余风险：
- 实体四设备、Production CloudKit 收敛、APNs 时序、SwiftData 持久化与真实 UI 没有在本轮实测。
- 新 provider 没有真实账号，数据来自插件 fixture、mock 注入和单元测试。
- Claude 邮箱身份切换：同一台 Mac 升级后 Claude 卡的身份从 legacy 变为邮箱，`compositeKey` 换 key，utilization 序列由 Mac 推送重建，成本账本按既有 ownership 迁移；token 轮换后 profile 查询超时可能让身份短暂来回切换一次（上游缓存行为），只能实机验证。
- 旧 iPhone 上，Claude Platform 以旧版 Claude 橙显示、grant 到期日为英文。
- Gate 结论：16 个组合全部列出，均为 substituted，没有 fail。

## 真实日志成本验证（2026-10-15/16）

目的：确认 0.74.1.1 用户升级到 0.76.0.1 后成本数据不被破坏，升级过程中 iPhone 不会收到偏低的“已知值”（Research 068/069/070/074 的核心要求）。

工具与数据（全部在 `/Volumes/StudioSSD/Developer/BuildScratch/CodexBar/costdiag/v076/`）：
- `CostDiag`（`loadDailyReport`）与 `CostSnap`（App 的 `CostUsageFetcher.loadTokenSnapshot`，默认扫描额度，每次调用相当于 App 刷新一次，统计会作为已知值发给 iPhone 的天数和 30 天金额）。两者都只在临时 worktree 里加 target：`wt-0741rel`（published tag `v0.74.1.1-mobile.2.8.0`）、`wt-0761`（本分支）、`wt-up-0760`（上游 v0.76.0），用 `swift build -c release -Xswiftc -enable-testing` 构建。
- 只读快照：T2 = 2026-10-13 的 `~/.codex`（沿用 074 的 `codex-t2-stage`，930 个 jsonl）；T3 = 2026-10-15 的 `~/.codex`（`rsync` + `sqlite3 .backup`，**只剩 58 个 jsonl + 883 个 `.jsonl.zst`**，见 00 的 zst 问题）。定价目录冻结为同一份 `models-dev-v1.json`。trace 库必须转成 `journal_mode=delete`，否则只读打开失败、扫描不执行（074 已记录；本轮第一次跑出 0 天就是这个原因）。

### 第一版（作废）
缓存建在 `codex-home-t2`，却对另一份拷贝扫描（inode 不同），上游把每个文件当作“文件 ID 变了”整体作废，结果不可信（074 已踩过同样的坑：`rsync --inplace` 才能保留 inode）。

### 第二版（忠实设置：同一目录原地增长）
| 对比 | 结果 |
|---|---|
| 0.74.1.1 全新扫描 vs 0.76.0.1 全新扫描（增长后，76 天） | $9,555.02 / 19.618B token，逐天逐模型一致（浮点差 <1e-12） |
| 0.74.1.1 在 T2 建缓存 → 原地增长到 T3 → 0.74.1.1 增量 | $9,555.02，与全新扫描完全一致 |
| 同一缓存 → **合并后代码（未修复前）沿用，无限额度 1 次** | $9,473.86：最近 3 天偏低（10-13/14/15） |
| 同一缓存 → 合并后代码沿用，默认额度 30 次 | $9,574.44：6 天与全新扫描不同（有高有低） |
| **CostSnap（App 路径）**：0.74.1.1 自己的缓存，3 次刷新 | 30 天已知成本 3024.97 → 3153.08 → 3171.18，第 3 次 `historyCoverageIsEstablished=true` |
| **CostSnap：合并后代码（未修复前）沿用 0.74.1.1 缓存，12 次刷新** | 3095 → 3094 → 2790 → 2757 → … → **2713**，第 8 次起 knownDays 29，直到第 12 次仍 2713 / last30 2808，从未 established；逐天看 10-10 从 $144.45 降到 $28.83、09-26 从 $75.74 降到 $17.15 |

缓存库对比：升级后的 store `usage_rows` 从 129,037 降到 88,263，`file_day_aggregates` 849 → 592，若干大文件 `parsed_bytes` 远小于 `size`、`scan_complete=0`（重解析进行中），另有文件 `parsed_bytes=0` 且 0 行。

根因：上游 #4452 把 `currentCodexParserRevision` 从 12 升到 13，只为记录 leaf `session_meta` 的 `creator_account_id`；`keepCachedCodexFileIfFresh` 对旧 revision 文件返回 false，`replaceCachedRows` 为 true，于是每个旧文件都在扫描额度内从头重解析，并用部分行替换已缓存的行，直到该文件解析完为止——整份历史（约 11 GB）要几十次刷新才能恢复，期间 Mac 显示偏低的 30 天成本，iPhone 账本会把这些偏低值当作已知值覆盖（`CostLedgerService.upsertDayPoint` 只拦“未知覆盖已知”）。这不是 fork 合并引入，而是上游 0.75/0.76 对所有 0.74.x store 的迁移行为（plan3 用上游 v0.76.0 + 上游 0.74.1 store 对照，见下）。

### 模拟 Codex 归档（同一目录，把 T3 中已是 .zst 的 883 个 jsonl 换成 zst）
| 对比 | 结果 |
|---|---|
| 0.76.0.1 沿用（已升级的 store） | $1,310.32 / 4.064B |
| 0.74.1.1 自己的 store | $1,179.40 / 3.942B |
| 0.76.0.1 全新扫描 | $1,028.56 / 3.653B |
| CostSnap 归档后继续刷新 3 次 | knownDays 25/30，30 天已知成本 2252 → 2296，last30 2530 |

结论：jsonl 被压缩后，两个版本都只保留极少量历史（已缓存的行随文件消失而被清理），这是上游扫描器不识别 `.zst` 的既有问题（issue #4523 / PR #4534），0.74.1.1 与 0.76.0.1 行为相同，不是本轮回归；本机用户的 Mac 在 2026-10-13 之后已处于这个状态。

### 修复：revision 13 原地升级（commit `0e4463a4e`，见 02）
对 revision 12 的文件只重读 leaf `session_meta`、写入 `hasCreatorAccount`、盖上 revision 13，保留全部行。单元测试 `CostUsageForkParserRevisionTests`（1 字节额度下仍保留全部行、增长后与全新扫描一致）。真实日志复验见下方 plan3。

### plan3：上游对照与修复复验（同一目录原地增长，App 刷新路径 CostSnap，`plan3.out`）

| 场景 | 30 天已知成本（逐次刷新） |
|---|---|
| F0：0.74.1.1 沿用自己的 0.74.1.1 store（基线） | 3171.91 → 3184.71 → 3203.87 → **3208.45**（第 4 次 `historyCoverageIsEstablished=true`） |
| U1：**上游 v0.76.0** 沿用上游 0.74.1 store | 3068.72 → 2756.58 ×3 → 2719.59 → 2081.62 ×2 → **1909.28** ×2 → 1952.04 → 2266.16 → 2455.50，12 次仍未 established，knownDays 一度 29 |
| U2：原地升级第一版（`0e4463a4e`，未先 hydrate，已被 plan4 取代）沿用上游 0.74.1 store | 3171.07 → 3183.86 → 3203.87 → **3208.45**（第 4 次 established），之后保持 3208.45（第 11 次一次性回到 3171.18，第 12 次又是 3208.45） |
| F1：原地升级第一版（`0e4463a4e`，已被 plan4 取代）沿用 fork 0.74.1.1 store | 3163.86 → 3177.92 → 3203.87 → **3208.45**（第 4 次 established），之后同 U2 |
| U0 / F2：空缓存全新建立（上游 / fork） | 154 → 1668（6 次）/ 280 → 1331（6 次），两者都在逐次补齐，仅作参考 |

结论：
- 下降是上游 0.75/0.76 对所有 0.74.x store 的迁移行为（U1），不是 fork 合并引入；原地升级后的路径与 0.74.1.1 基线逐次一致（U2/F1 vs F0），但这两份 store 后来被第二轮 review 发现丢了 token snapshots，最终代码的复验见 plan4 与 plan5。
- 观察项：U2/F1（丢 snapshot 的构建）第 11 次刷新一次性回到 3171.18，下一次恢复 3208.45，差 $37（1.2%）。F0 当时只跑了 4 次。是否在最终代码上仍出现，由 plan5（F0 与 F3 各 12 次）回答。
- 是否把这个迁移下降反馈给上游由用户决定（涉及上游仓库的外部操作，本轮不做）。

### plan4：第二轮 review 阻塞问题修复后的复验（`ee6084b0e`，`plan4.out`）

第二轮 review 用只读 sqlite 查询发现：plan3 的 F1/U2 store 虽然 `usage_rows` 未丢，但 `token_snapshots` 从 147,102 行掉到 13,250 行（有 snapshot 的文件 435 → 32），43 个 fork 子会话的父会话失去基线——原地升级在未加载 token 历史时盖 revision，store 把 revision 变化当作整份重写而删除了 snapshots。改为先 `hydrateCodexScanHistory` 再升级后：

| store | token_snapshots | 有 snapshot 的文件 | usage_rows | 30 天已知成本（逐次） |
|---|---|---|---|---|
| fk0741（0.74.1.1 源 store） | 147,102 | 435 | 125,324 | — |
| F0（0.74.1.1 基线） | 153,057 | 451 | 130,424 | 3171.91 → 3184.71 → 3203.87 → 3208.45 |
| F1（修复前，作废） | 13,250 | 32 | 129,037 | 3163.86 → … → 3208.45 |
| **F3（修复后，fork 0.74.1.1 store）** | **153,057** | **451** | **130,424** | 3166.26 → 3179.05 → 3203.87 → 3208.45（第 4 次 established），之后保持 |
| **U3（修复后，上游 0.74.1 store）** | **153,057** | **451** | **130,424** | 3164.62 → 3177.42 → 3203.87 → 3208.45（第 4 次 established） |

结论：修复后的升级路径与 0.74.1.1 基线在文件数、`usage_rows`、`token_snapshots`（第三轮 review 按文件逐一比较差异为 0，行 payload 归一化后差异为 0）上完全一致；逐次成本第 1、2 次比基线低 $5–6（0.2%，3166/3179 vs 3172/3185），第 3 次起完全相同。差异原因推测是同一批新增日志在两条路径上分批读取的顺序不同，未逐行核实。

### plan5 / plan6：最终代码（`ca74e7954`）上的 12 次与 24 次刷新（`plan5.out`、`plan6.out`，store 逐次克隆在 `stores6/`）

| 场景 | 30 天已知成本序列（窗口 09-17..10-16） |
|---|---|
| F0x12：0.74.1.1 自己的 store，同一进程 12 次 | 2974 → 2987 → 2991 → 3009 → **3013.54** ×8，从未 established |
| F5：最终 fork，同一进程 12 次 | 2953 → 2965 → 3009 → 3013.54（第 4 次 established）→ … → 3013.54 → 第 12 次 **2980.85**（established） |
| F0b：0.74.1.1，24 个独立进程 | 2977 → 3009 → 3013.54 …，**第 9、15、21 次（established）为 2980.85**，其余为 3013.54 |
| F6：最终 fork，24 个独立进程 | 2832 → 2942 → 2976 → **2980.85** 之后 20 次全部不变（第 9、15、21 次 established） |
| UF：上游 v0.76.0 空缓存建立 | 37 → … → 2927（第 23 次仍在追赶，未 established） |

解读（用 store 的 `scan_metadata` 与 CostDiag 全新扫描核对）：
- 两个版本在这份 129k 行的历史上 `codexScanCatchUpPending` 持续为 true（`enforceBudgets` 的行/字节预算），上游 #3051 的机制会在 pending 期间返回保留的旧报告。0.74.1.1 的 store 里持久化的旧报告总额正是 3013.54；只有每第 6 次刷新真正 established 时才返回当前值 2980.85。所以 0.74.1.1 "稳定的 3013.54" 其实是保留报告，2980.85 才是当前值。
- 10-10..10-13 四天的差异（144.68/37.63/98.57/81.26 vs 144.45/35.20/83.51/66.29）：CostDiag 无限额度的全新扫描（0.74.1.1 与 fork 相同）给出 144.45/29.76/76.09/65.70，更接近 2980.85 这一组。
- 最终 fork 从第 4 次起稳定在 2980.85，比 0.74.1.1 在两值之间来回跳更稳定；`usage_rows`、`token_snapshots`、`day_aggregates`、`file_day_aggregates` 与 0.74.1.1 基线逐表比较差异为 0。
- 结论：plan3 的"第 11/12 次回落"是上游保留报告机制在不同快照时间下的表现，0.74.1.1 本身同样存在，且 fork 的值更接近真值；不是回归，不阻塞。iPhone 在 0.74.1.1 下也会周期性收到这两组值之一。

## 同步兼容 gate 复跑（最终提交 `10b9bb304`）

`tools/check_frozen_wire.py --old-ref v0.74.1.1-mobile.2.8.0 --scratch …/frozen-wire-final`：`PASS: 16 masks, 64 wire reads and 32 real old/new consumer merge processes`；old `1c5b6bd9e`，new `10b9bb304`，18 个源文件里仍只有 `QuotaProviderList.swift` 不同。`matrix-wire.json` 已复制到本目录。

## CloudKit Production schema 审计

对照最新公开 tag `v0.74.1.1-mobile.2.8.0`：
- `git diff $LAST_TAG..HEAD | grep -E "^\+.*(recordType|CKRecordZone\(|addIndex|querySchema|CKContainer|providerPayloadVersion|CKQuerySubscription|CKRecordZoneSubscription|encodingVersion)"`：无输出。
- `Shared/iCloud/CloudConstants.swift` 与 `Scripts/cloudkit/`：没有 diff；`providerPayloadVersion=1`。
- `Shared/Models/UsageSnapshot.swift`：`public let` 没有增减；Shared 只有 `QuotaProviderList` 追加 1 个运行时 zone provider。
- 打包：`Scripts/package_app.sh` 是 Production、容器 `iCloud.com.o1xhack.codexbar`、没有 `aps-environment`；iOS entitlements 是 Production。

结论 `NO_DEPLOY`，已写入 `docs/cloudkit-deploy-audit.md`。本轮没有调用 Production export 或 deploy。
