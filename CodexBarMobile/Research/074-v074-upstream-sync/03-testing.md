# 测试

Status: `in-progress`

日志目录：`/Volumes/StudioSSD/Developer/BuildScratch/CodexBar/upstream-v074/`（下文只写文件名）。

## Mac

| 项目 | 命令 | 结果 | 日志 |
|---|---|---|---|
| 合并后编译 | `swift build` | 第一次只报 `AccountIdentityComputer` 的 switch 不完整（9 个新 provider），补齐后 Build complete | build1.log |
| 测试 target 编译 | `swift build --build-tests` | 通过 | build-tests1.log |
| 定向：provider / mock / sync | `swift test --filter 'ProviderArchitectureGatekeeper\|QuotaProviderList\|MockProvider\|AccountIdentityComputer\|SyncCoordinator'` | 266 项通过（更新计数和 gatekeeper 指纹之后） | t-focused2.log |
| 新桥接 | `swift test --filter SyncV074BridgeTests` | 4 项通过：X API 负余额、日期锚点、Claude 完整推送路径、Qwen Team/Monthly 标签 | — |
| 全量（第一次） | `Scripts/test.sh` | 第 12 组失败后停止：上游新增的 `AboutWebsiteTests` 要求 About 网站等于 `docs/CNAME`（codexbar.app），而 fork 保留自己的网站。测试改为固定 fork 网站后，单独重跑 2 项通过 | mac-full1.log |
| 全量（第二次） | `Scripts/test.sh` | 待填 | mac-full2.log |

## iOS

| 项目 | 命令 | 结果 | 日志 |
|---|---|---|---|
| 工程生成 | `xcodegen generate` | 通过 | — |
| 完整单元测试（第一次） | `xcodebuild test -only-testing:CodexBarMobileTests`（模拟器 CodexBar iOS 27 iPhone 18 Pro） | 编译通过，模拟器启动失败（`Invalid connectionUUID`，环境问题） | ios-unit1.log |
| 完整单元测试（第二次） | 启动模拟器后 `test-without-building` | Swift Testing 1085 项，其中 3 处失败，都在新的窗口标签测试：`ProviderWindowLabel` 的 switch `default` 固定返回 "Extra usage"，新 key 会被显示成“额外用量”。补上显式分支后修复。XCTest 部分全部通过（含 `WidgetSnapshotBuilderTests`） | ios-unit2.log |
| 定向重跑 | `V074ProviderPresentationTests`、`ProviderColorPaletteTests`、`QuotaProviderListTests` | 103 项通过 | ios-focused1.log |
| 四语言 | `bash Scripts/lint.sh audit-i18n` | 三个 xcstrings 全部 translated；source-vs-catalog 408 个 key 齐全 | — |

## 同步兼容 gate（2 Mac × 2 iPhone）

本轮改动属于 gate 适用范围：Mac 发布的 provider 显示数据有变化（X API 余额、Qwen 标签、Claude 日期锚点、9 个新 provider），iOS 渲染也有变化，所以执行 `docs/ios-sync-compatibility-testing.md`。

替代验证：`tools/check_frozen_wire.py --old-ref v0.73.0.1-mobile.2.6.0`（`tools/FrozenWireHarness.swift`）。
- old 是最后公开发布的 `v0.73.0.1-mobile.2.6.0` 的 Shared 源码与 `ProviderSnapshotMerger`；new 是本分支 HEAD。18 个源文件里只有 `QuotaProviderList.swift` 不同。
- old Mac 只发 Claude（没有续费日）和 Qwen Cloud（"5-hour"）；new Mac 另外发 Claude 的 12:00 UTC 续费日、Qwen "Team"、X API −1.2 余额、Aerostack 无 reset 窗口。
- 每个组合：两台 iPhone 各自读取两台 Mac 的全部 envelope（解码、校验、JSON 往返），再分别用自己的 merger 按两种顺序合并两台 Mac；还要校验订阅列表（只有 new 读端订阅 aerostack，没有任何一端订阅 xapi）。
- 结果：`PASS: 16 masks, 64 wire reads and 32 real old/new consumer merge processes`，日志 `frozen-wire/matrix-wire.log`、`frozen-wire/matrix-wire.json`、`frozen-wire/source-manifest.json`。

没有实体的 2 台 Mac + 2 台 iPhone 环境，也不能读写 Production CloudKit，所以 16 个组合都记为 `substituted`。old 指 Mac 0.73.0.1、iPhone 2.7.0 (240) 或更早；new 指 Mac 0.74.1.1、iPhone 2.8.0 (241)。

| Case | Mac A | Mac B | iPhone A | iPhone B | Result | Evidence | Notes |
|---:|---|---|---|---|---|---|---|
| 1 | old | old | old | old | substituted | 冻结 wire mask 0 PASS | 与上一版行为相同 |
| 2 | old | old | old | new | substituted | mask 1 PASS | 只有 old Mac，new iPhone 没有新数据可显示；新 iPhone 多订阅 3 个推送 zone，不会收到推送 |
| 3 | old | old | new | old | substituted | mask 2 PASS | 同 2 |
| 4 | old | old | new | new | substituted | mask 3 PASS | 同 2 |
| 5 | old | new | old | old | substituted | mask 4 PASS | old iPhone 把新 provider 显示为未知 provider 通用卡（没有颜色、英文），X API 余额照常显示；Qwen 显示英文 "Team"；Claude 续费日在 UTC−11 到 +11 正确；不订阅新 provider 推送 |
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
- 旧 iPhone 上，Claude 只有日期的续费日在 UTC+12 及更东会晚一天。
- Gate 结论：16 个组合全部列出，均为 substituted，没有 fail。

## CloudKit Production schema 审计

对照最新公开 tag `v0.73.0.1-mobile.2.6.0`：
- `git diff $LAST_TAG..HEAD | grep -E "^\+.*(recordType|CKRecordZone\(|addIndex|querySchema|CKContainer|providerPayloadVersion|CKQuerySubscription|CKRecordZoneSubscription|encodingVersion)"`：只命中 iOS CHANGELOG 里的说明文字。
- `Shared/iCloud/CloudConstants.swift` 与 `Scripts/cloudkit/`：没有 diff；`providerPayloadVersion=1`。
- `Shared/Models/UsageSnapshot.swift`：`public let` 没有增减；Shared 只有 `QuotaProviderList` 追加 3 个运行时 zone。
- 打包：`Scripts/package_app.sh` 是 Production、容器 `iCloud.com.o1xhack.codexbar`、没有 `aps-environment`；iOS entitlements 是 Production。

结论 `NO_DEPLOY`，已写入 `docs/cloudkit-deploy-audit.md`。本轮没有调用 Production export 或 deploy。
