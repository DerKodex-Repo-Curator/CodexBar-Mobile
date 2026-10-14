# 合并与数据通道设计

Status: `done`

## 合并规则

- 一次 `git merge v0.74.1`（已包含 v0.74.0），保留 v0.73.0..v0.74.1 的全部上游历史、provider、安全、性能和修复。
- 冲突逐个 hunk 处理，fork 约束优先：
  - README 保持 mobile-dev 的原字节，之后单独审计上游 README 的事实变化并移植；
  - `appcast.xml`、`version.env`、AGENTS.md、About 链接保留 fork；
  - CI 保留 fork 的双层触发和 6 shard（`docs/ci-policy.md`、`Scripts/check_ci_policy.sh`），不采用上游 0.74 的单 runner、compiled cache workflow；
  - fork 的 release 脚本不被上游 wrapper 覆盖；
  - CloudKit 容器保持 fork 的 `CloudSyncConstants.containerIdentifier`。
- 上游功能和 fork 包装层相交的地方（#4310 按账号刷新），把上游参数贯通 fork 的快照发布包装层，并保持 fork 的“完整发布”语义。
- 成本缓存：按 parser 文件的变化把 `parserLogicVersion` 升到 21 并重新生成 hash。上游沿用自家 0.73.0 store，fork 的 0.73.0.1 store 与之等价，也登记为可沿用的前驱，不让 0.73.0.1 用户全量重扫。

## Mac → iOS 数据通道

原则：只用已有字段或已有 opaque JSON 里的值（唯一例外是第 3 点新增的两个可选日期字段），不提升 `providerPayloadVersion`，不新增 schema 层的 record type、field 或 index，只在尾部追加运行时 zone subscription（第 4 点），不同步 credential、cookie、路径或环境变量。

1. `mapProviderAmount` 新增 `.xapi`：`balance != nil` 时发布余额（包括负数），period 用 `providerCost.period`，没有时用 "Prepaid credits"。
2. `buildProviderUsageSnapshot` 的 primary 标签：qwencloud 改用 descriptor 的 `rateWindowLabels(metadata:snapshot:)`，得到 "Team"（Team Token Plan）、"Monthly"（30 天）或 session 标签。其他 provider 不变。
3. Claude 只有日期的续费/到期日（`subscription…AtIsDateOnly` 为真）：Mac 改为发布 Shared 新增的可选字段 `subscriptionRenewsOn` / `subscriptionExpiresOn`（UTC 日历日 `yyyy-MM-dd`），不再发时间戳；精确时间仍走原来的 `subscription…At`，原样发布。这样做的原因：最初的方案是把日期锚定到 12:00 UTC。PR #192 的 Codex review 两轮指出，精确时间恰好是 12:00 UTC 时会被当成锚点；旧 iPhone 在 UTC+12 到 +14 也会显示成第二天。时区跨度有 26 小时，任何一个时刻都不可能在所有时区落在同一天，所以“只有日期”必须单独表达。旧 iPhone 会忽略新键，不显示 Claude 续费日，这和 0.73.0.1 本来就不发 Claude 日期的情况一样，不算倒退。持久化走 SwiftData 里已有的 payload JSON 镜像，不需要改 schema。
4. 新 provider ID 走已有的 provider 列表和 per-provider 运行时 zone；QuotaTransition 只在尾部追加有百分比窗口的 aerostack、cosmic、tavily，保持已有订阅 ID 不变。
5. Mac mock：9 个新 provider 各一个快照（115 个快照 / 105 个 ID），详情行标签与插件输出一致；没有 reset 的窗口不带 `resetsAt`。

## iOS 呈现

- 颜色：9 个上游品牌色，归入 v072+ 组（Light Mode 按需加深，Dark Mode 提亮）。Exa、X API 精确匹配。
- 详情本地化：9 个新 provider 加上 qwencloud、ollama、jetbrains 加入 first-party 集合，新增语义标签和取值（Unlimited、Not reported、Unavailable、"N credits"、"%@ credits used"），四语言。
- 窗口标签：Team、API key、Plan credits、Input tokens、Output tokens、Monthly AI tokens。
- 用量卡片：`usageDataConfidence == "estimated"` 时百分比前加 `~`。
- Claude 只有日期的续费/到期日（`subscription…On`）按 UTC 日历显示（`SubscriptionDateTimeZone.calendarDayString`）；MiniMax 继续用 Asia/Shanghai。
- Claude 凭证变更错误：改为四语言说明，告诉用户去那台 Mac 上点击刷新。
- PreviewData：按卡片类型核对。余额卡片和纯详情卡片沿用已有组件，Demo 已覆盖主要卡片类型，本轮不新增样例。

## CloudKit 判断

见 [03-testing.md](03-testing.md#cloudkit-production-schema-审计)。结论：`NO_DEPLOY`。

## 测试与完成门

- Mac：`swift build`、`Scripts/lint.sh lint`、完整 `Scripts/test.sh`、多账号/多设备 filter、gatekeeper/mapper/新 provider 定向测试、`SyncV074BridgeTests`。
- iOS：xcodegen、Simulator 构建、完整单元测试；改了 provider 显示数据，所以加跑 `WidgetSnapshotBuilderTests`；四语言审计。
- 同步兼容：本轮改了 provider 显示数据和 Mac 发布的值约定，触发 `docs/ios-sync-compatibility-testing.md` gate，16 个组合逐格记录。实体硬件不可用时用冻结 wire harness 和单元测试替代验证，并写明残余风险。
- Review：先自查，再用独立 review agent 循环，直到阻塞问题为 0。
