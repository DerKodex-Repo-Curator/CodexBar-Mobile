# 合并与数据通道设计

Status: `in-progress`

## 合并规则

- 一次 `git merge v0.76.0`（已包含 v0.75.0），保留 v0.74.1..v0.76.0 的全部上游历史、provider、安全、性能和修复。
- 冲突逐个 hunk 处理，fork 约束优先：
  - README 保持 mobile-dev 的原字节，之后单独审计上游 README 的事实变化并移植；
  - `appcast.xml`、`version.env`、AGENTS.md、About 链接保留 fork；About 接入上游新增的开源致谢页；
  - CI 保留 fork 的双层触发和 6 shard（`docs/ci-policy.md`、`Scripts/check_ci_policy.sh`），不采用上游 0.75/0.76 的 `xcode-27` runner 与删除兼容构建的 workflow；上游 `release-cli.yml` 自动合入 THIRD_PARTY_NOTICES 打包，不影响 fork 的 Homebrew gate；
  - fork 的 release 脚本不被上游覆盖（本轮上游没有改 `package_app.sh`/`release.sh`）；
  - CloudKit 容器保持 fork 的 `CloudSyncConstants.containerIdentifier`。
- 成本缓存：按 parser 文件的变化把 `parserLogicVersion` 升到 22 并重新生成 hash。上游用“登记为前驱 + revision 13 有界重解析”沿用自家 0.74.1 store，fork 的 0.74.1.1 store 与之等价（上游 0.74.1 解析逻辑 + fork ledger 重新定价，与 074 处理 0.73.0.1 时关系相同），也登记为可沿用前驱，不让 0.74.1.1 用户全量重扫。
- fork 独有的 Codex 估算判定（`codexPricingIsEstimated(for row:)`）识别上游新增的 `isIncludedInPlan`，让 $0 Auto-review 行不把当天标成估算。

## Mac → iOS 数据通道

原则：只用已有字段或已有 opaque JSON 里的值，不提升 `providerPayloadVersion`，不新增 schema 层的 record type、field 或 index，只在尾部追加运行时 zone subscription（第 2 点），不同步 credential、cookie、路径或环境变量。本轮 Shared 模型零改动，`Shared/` 只有 `QuotaProviderList` 尾部追加 1 个运行时 zone provider。

1. `mapProviderAmount` 新增 `.claudeplatform`：`balance != nil` 时发布 Console 预付 credit 总余额（负数也发布），period 用 `providerCost.period`，没有时用 "Prepaid credits"。插件不报 limit，`budget` 通道保持为空。
2. `QuotaProviderList` 尾部追加 `claudeplatform`（两个百分比窗口会触发 Mac quota warning；87 → 88 个 provider，261 → 264 个 zone）。fal、FLORA、Parallel 只有余额详情，不追加。
3. fal、FLORA、Parallel 的余额与说明完全在 `details` 里，经 `mapSyncedDetails` 透传；Claude Platform 的两个 grant 窗口沿用 descriptor 的 `sessionLabel` / `weeklyLabel`（"API credit" / "Purchased credit"），`resetDescription` 为 "<left> of <granted> left · Expires <MMM d> (UTC)"（没有 `resetsAt`）。
4. 已有 provider：Claude OAuth 新带 `accountEmail`（经 `AccountIdentityComputer` 变成 `claude:email:` 身份，多 Mac 同账号会合并为一张卡）；Claude CLI 来源新发 `budget{period:"Monthly cap"}`；Claude Web 不再发 0% 的 Session 占位窗口；OpenAI token 总数不再重复计音频；Codex Auto-review 日期从未知变为已知 $0。都不改字段，无需新映射。
5. Claude 月度支出上限（spend-only 或 CLI 账户）：Mac 的 `budget.resetsAt` 在 provider 没报 reset 时改用上游 `claudeMonthlySpendWindow` 的推断值（观测月的 UTC 月末），与上游菜单 meter 的 "Inferred" rollover 一致。既有字段，新旧 iPhone 的预算卡都会显示“X 天后重置”；provider 明确给出的 reset 不被替换。
6. 上游 `UsageSnapshot.throughput`（OpenAI Live Usage tokens/min）本轮不同步：它是近 60 分钟的实时曲线，iPhone 只能看到上次推送时的值；完整 minutes × models 体积大；属于新功能而非数据修正。后续可只同步摘要。
7. Mac mock：4 个新 provider 各一个快照（119 个快照 / 109 个 ID），详情行标签与插件输出一致；Claude Platform mock 带两个无 reset 的窗口和余额。

## iOS 呈现

- 颜色：4 个上游品牌色（claudeplatform `#CC7C5E`、fal `#7C3AED`、flora `#111111`、parallel `#1D1C1A`），归入 v072+ 组（Light Mode 按需加深，Dark Mode 提亮）。全部精确匹配：`claudeplatform` 必须在通用 `contains("claude")` 规则之前，`fal` 只有三个字母。
- 详情本地化：4 个新 provider 加入 first-party 集合；新增语义标签（Workspace balance、Member limit、Runs this month、Pending debit、Other credit grants）与 FLORA 固定说明值、Claude Platform 的 "<a> of <b> left" / "Expires <day> (UTC)"（按 UTC 日历日、读者 locale 的日期格式）；"Other credit grants" 行标签是服务端 grant 名称，保持 verbatim。
- 窗口标签：API credit、Purchased credit（译文取自上游 Mac 目录），显式分支避免落入 "Extra usage" 默认值。
- Claude Extra usage 的 `budget.period` "Monthly cap" / "Spend limit" 补四语言（CLI 来源本轮开始发送）。
- Claude Platform 卡片复用 `ProviderAmountCard` 显示总余额；两个 grant 窗口沿用现有百分比卡片。
- PreviewData：按卡片类型核对。余额卡片和纯详情卡片沿用已有组件，Demo 已覆盖主要卡片类型，本轮不新增样例。

## CloudKit 判断

见 [03-testing.md](03-testing.md#cloudkit-production-schema-审计)。预判：`NO_DEPLOY`（Shared 模型零 diff，只追加运行时 zone provider）。

## 测试与完成门

- Mac：`swift build`、`Scripts/lint.sh lint`、完整 `Scripts/test.sh`、多账号/多设备 filter、gatekeeper/mapper/新 provider 定向测试、`SyncV076BridgeTests`、`CostUsageCodexAutoReviewEstimateTests`、0.74.1.1 → 新版的成本缓存沿用验证。
- iOS：xcodegen、Simulator 构建、完整单元测试；改了 provider 显示数据，所以加跑 `WidgetSnapshotBuilderTests`；四语言审计。
- 同步兼容：本轮改了 provider 显示数据和 Mac 发布的值约定，触发 `docs/ios-sync-compatibility-testing.md` gate，16 个组合逐格记录。实体硬件不可用时用冻结 wire harness 和单元测试替代验证，并写明残余风险。
- Review：先自查，再用独立 review agent 循环，直到阻塞问题为 0。
