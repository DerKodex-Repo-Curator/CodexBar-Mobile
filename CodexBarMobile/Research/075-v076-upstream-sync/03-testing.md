# 测试

Status: `in-progress`

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
| lint（第三到五次） | `bash Scripts/lint.sh lint` | 第三次：新测试两行超宽；第四次：swiftlint 5 处（multiline_arguments、line_length）；第五次 **退出码 0**：0 违规（3087 文件）、acknowledgements 18 components、CI policy、Codex parser hash 最新（`e34dea88998a523f`）、parser 版本审计 OK（parser 改动且已 bump）、fork README guard、App locales OK、i18n 409 个 key 齐全 | lint3.log、lint4.log、lint5.log |
| 全量分片 0（第一次） | `CODEXBAR_TEST_SHARD_INDEX=0 CODEXBAR_TEST_SHARD_COUNT=2 Scripts/test.sh` | 第 23 组 `CodexLaunchPreflightNPMMemoTests`（上游 #4080，fork 未改）首轮 2 处失败（standalone + hardened 的 Gatekeeper memo），`test.sh` 自动重试后该组通过；属于环境/时序抖动，记为观察项 | mac-full1-s0.log |
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

## CloudKit Production schema 审计

对照最新公开 tag `v0.74.1.1-mobile.2.8.0`：
- `git diff $LAST_TAG..HEAD | grep -E "^\+.*(recordType|CKRecordZone\(|addIndex|querySchema|CKContainer|providerPayloadVersion|CKQuerySubscription|CKRecordZoneSubscription|encodingVersion)"`：无输出。
- `Shared/iCloud/CloudConstants.swift` 与 `Scripts/cloudkit/`：没有 diff；`providerPayloadVersion=1`。
- `Shared/Models/UsageSnapshot.swift`：`public let` 没有增减；Shared 只有 `QuotaProviderList` 追加 1 个运行时 zone provider。
- 打包：`Scripts/package_app.sh` 是 Production、容器 `iCloud.com.o1xhack.codexbar`、没有 `aps-environment`；iOS entitlements 是 Production。

结论 `NO_DEPLOY`，已写入 `docs/cloudkit-deploy-audit.md`。本轮没有调用 Production export 或 deploy。
