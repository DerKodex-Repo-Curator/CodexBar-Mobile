# 上游变化与 iOS 数据通道逐项审计

Status: `in-progress`（设计期审计；实现与测试证据见 02/03）

审计方法：上游代码用 `git show v0.76.0:<path>`、`git diff v0.74.1 v0.76.0` 和只读 worktree `wt-up-0.76.0` 读取，fork 现状读合并前的 mobile-dev（`f1f547b90`）。数据路径按插件 `fetchUsage` → `ProviderPluginSnapshotMapper.map` → `UsageSnapshot` → fork `SyncCoordinator.buildProviderUsageSnapshot` / `mapProviderAmount` / `mapSyncedDetails` → Shared `ProviderUsageSnapshot`（CloudKit opaque JSON）→ iOS 卡片、详情、widget 逐段追踪。三份独立只读审计（新 provider 落点、已有 provider 数据变化、同步层与基础设施）的结论合入下文。

插件→快照的映射规则：`cost{used, limit?, currency, period?, balance?}` → `providerCost`（`limit` 缺省为 0）；`details` 原样 → `ProviderDetailSection`；`identity.organization` → `accountOrganization`，`identity.loginMethod` → `loginMethod`。fork 桥接：`budget` 只在 `limit > 0` 时生成；`providerAmount` 由 `mapProviderAmount` 的 provider 白名单决定，名单外走 `default` 返回 nil；`details` 由 `mapSyncedDetails` 全量透传。

## 新 provider（4 个新 `UsageProvider` case，均为 bundled plugin）

| id | 数据形态（插件原文） | 合并前能否到 iOS | 本轮决定 |
|---|---|---|---|
| `fal` | 无窗口、无 `cost`。详情 "Account balance" 一行 "Credit balance"，值为货币（"$42.50"）。`identity{loginMethod:"API key", organization: username}`。descriptor `balanceOnly`，色值 `0x7C3AED` | 能。余额只在 details 里（与 linkup 相同），username 走 `accountOrganization` | 颜色 `#7C3AED` **精确匹配**（3 个字母，防子串误配）；加入 first-party 集合；加 mock |
| `flora` | 无窗口、无 `cost`。详情 "Workspace balance"：Available（货币，可能为负；secondaryValue "Workspace pool" / "Your allowance"）、Member limit（仅 caller 范围；secondaryValue "Monthly" / "All time"）、Spent this month（货币或 "Unavailable"，secondaryValue "Plan has no usage reporting" / "Needs billing permission" / "Totals not computed; try again" / "Not reported"）、Runs this month（数字）。`loginMethod:"API key"`。色值 `0x111111` | 能（详情预览），标签与 secondaryValue 是英文 | 颜色 `#111111`（深色模式自动提亮）；详情标签与 secondaryValue 四语言；加 mock |
| `parallel` | 无窗口、无 `cost`。详情 "Account balance"：Balance（USD）、可选 "Pending debit"（非 0 时才有）。`loginMethod:"Browser session"`。色值 `0x1D1C1A` | 能 | 颜色 `#1D1C1A`；新增 "Pending debit" 四语言；加 mock |
| `claudeplatform` | `primary` = 最早到期且仍有余额的订阅 API credit grant，`secondary` = 最早到期的已购 grant；都只有 `usedPercent` 与 `resetDescription`（"$124.75 of $200.00 left · Expires Oct 28 (UTC)"），**没有 `resetsAt`**。`cost{used: balance, currency, period:"Prepaid credits", balance}`，**没有 limit**。详情 "Other credit grants"（行 label 是服务端 grant 名称，值 "$a of $b left"，secondaryValue "Expires … (UTC)"，带 progress）与 "Billing"（"This month (UTC)" → 货币，或 "Spend" → "Unavailable"）。`identity{organization, loginMethod:"Console session"}`。descriptor `sessionLabel:"API credit"`、`weeklyLabel:"Purchased credit"`、色值 `0xCC7C5E` | **总余额会丢**：`limit = 0` → 无 `budget`；`mapProviderAmount` 走 `default` 返回 nil。窗口能到 iOS，但 resetDescription 是英文；颜色会被 iOS 的 `contains("claude")` 误配成 Claude 橙 | Mac 桥接新增 `.claudeplatform` 余额分支（负余额与 X API 同样发布）；iOS 复用 `ProviderAmountCard`；颜色 `#CC7C5E` **精确匹配且必须在 claude 规则之前**；追加到 `QuotaProviderList` 尾部（两个百分比窗口，Mac 会发 warning）；窗口标签、详情、"of … left · Expires … (UTC)" 四语言；动态 grant 名称 verbatim；加 mock |

- `QuotaProviderList` 只追加 `claudeplatform`（87 → 88 个 provider，261 → 264 个 zone）。`fal`、`flora`、`parallel` 只有余额详情，没有可提醒的窗口，不追加。claudeplatform 的 depleted/restored 几乎不会触发（grant 用完后插件不再输出该线），推送价值主要在阈值 warning。
- 已有 provider 的新数据来源（Command Code API key、Kimi China Desktop session、Charm Hyper 浏览器 session、Helmcode Cloud、Droid Firefox 变体）都只改凭据与 transport，`UsageSnapshot` 字段形态不变，只新增几条英文错误文本（`statusMessage` 原样显示，与现有惯例一致）。
- 上游 fixture：`FalPluginTests`（"$42.50"、organization "fixture-team"）、`FloraPluginTests`（workspace / caller 两种范围、负余额）、`ParallelPluginTests`（"$123.45" + "$1.50"）、`docs/claudeplatform.md`；claudeplatform 没有独立插件测试。

## 已有 provider 的数据变化

| 变更项 | Mac 数据影响 | 到 iOS 的通道影响 | fork Mac 改动 | iOS 改动 |
|---|---|---|---|---|
| Claude #4480 spend-only 月度 cap 单 meter、日历月 pace、UTC 1 日 rollover | `claudeMonthlySpendWindow` 是 presentation-only 的 `NamedRateWindow`，不写入 `extraRateWindows`；spend 继续走 `providerCost` → `budget` 与 `claudeExtraUsage` | 无字段变化；月度 spend 窗口不进 rate windows，iOS 的 `QuotaPace`、推送、窗口标签都看不到它 | 无 | 无（可选：spend-only 账户主卡片按 `budget` 画 meter，本轮不做） |
| Claude #4480 CLI `/usage` 的 "Usage credits" 解析（`ClaudeCLISpendCapParser`） | CLI 来源新发 `providerCost{period:"Monthly cap", resetsAt:nil}` | **值变化**：CLI 用户的 Mac 新发 `budget` 与 `claudeExtraUsage`，字段与渲染（`BudgetProgressView`、`ClaudeExtraUsageCard`）已存在 | 无 | "Monthly cap" / "Spend limit" 补四语言 |
| Claude #4480 Web `five_hour: null` 时不再生成 0% synthetic Session 窗口 | `primary = nil` | **值变化**：`rateWindows` 不再含占位；新 iPhone 早已过滤 `isSyntheticPlaceholder`，旧 iPhone 从 "Session 0%" 变为显示 Weekly | 无 | 无 |
| Claude #4484 reset credits / Extra usage / Credits / plan dates 独立可见性、`claudeResetCreditsVisibilityMigrated` | Mac 显示偏好与 fleet `ProviderIntent` JSON | 无（fork 不读 `hiddenUsageItemIDs`，`mapSyncedDetails` 仍过滤 "Limit Reset Credits"） | 无 | 无 |
| Claude #4493 OAuth 账号 email（`ClaudeOAuthDisplayProfileCache`） | OAuth 来源的 `accountEmail` 被填上（按 token 缓存，后台查询，2 秒宽限） | **值变化**：`accountIdentities` 新增 `claude:email:<norm>`；iOS 从 `claude:legacy-no-identity` 变为 email 分组，多 Mac 同账号合并为一张卡；`compositeKey` 换 key，成本账本由 `migrateCostOwnership` 迁移不重复 | 无 | 无 |
| Claude 菜单 stale 提示与错误分离、Keychain 禁用提示 | 只改 Mac UI（`userFacingErrorPresentation`） | 无：fork 用原始 `errors`，"Claude Code credentials changed (" 识别仍有效 | 无 | 无 |
| Codex #4466 >3 个账号结果保留、#4467 OpenCodex 替换 totals 保持 native 详情 | 只改 `SpendDashboardController/Model/Pane` | 无；`refreshCodexVisibleAccountsForSnapshotPublication` 包装层不受影响 | 编译修复：`SpendDashboardModel.detailEarliest` 改用 fork 的 `day(_:input:)` | 无 |
| Codex #4447 identified-request subtotals（`CodexRequestLedger`、CLI） | 只供 CLI opt-in；scanner 增加 observer hook | 无 | parser hash 重生成 | 无 |
| Codex #4452/#4453 Auto-review 自 10-06 起 $0（`isIncludedInPlan`，parser revision 13） | 报告副本上标记并按 $0 计价 | **值变化**：这些日期的 `costIsKnown` 从 false 变为 true | fork `codexPricingIsEstimated(for row:)` 识别 `isIncludedInPlan`，否则会把 $0 行标成估算（iPhone 显示 `~`）；补测试 | 无 |
| Codex #4472 project 报告 partial-history 提示（`detailsAreComplete`） | 默认 false，只给 Mac/CLI project/session 视图 | 无（fork 不同步 projects/sessions） | 测试参数顺序 | 无 |
| OpenAI Live Usage / `ProviderThroughputSnapshot` | `UsageSnapshot.throughput` 新持久化字段；插件 `liveUsage()` | 无：fork 不映射，Shared 无字段；per-provider hash 不含它，不引起额外推送 | `UsageFetcher` 冲突两边保留 | **本轮不做**（见 01） |
| OpenAI 音频 token 不再重复计数 | `tokens = input + output` | **值变小**：`openAIAPIDashboard` 与每日 `totalTokens`；iOS ledger 用更新的 `sourceUpdatedAt` 覆盖同一天，超出 Mac 历史窗口的旧日期保留旧值 | 无 | 无（release notes 说明） |
| OpenAI 组织 rate limit（`ProviderModelRateLimit`，fleet `ProviderIntent.modelRateLimits`） | config + fleet JSON | 无 | 无 | 无 |
| JetBrains #4457、Qwen Cloud、Cursor T/C/TP/GB 短标签、Devin 图标、Muse Code Keychain grant、OpenCode Go 缓存、TypeSafe/Hyper/Helmcode/Droid/Kimi/Command Code、全浏览器 cookie 导入、Antigravity、MiniMax | 只改凭据、浏览器发现、日志解析、menu bar 渲染或错误文案 | 快照形态不变；新增英文 `statusMessage` 原样显示 | 无 | 无（可选：Muse Code 的 Keychain 错误本地化，本轮不做） |
| `usageDataConfidence` | 本轮没有新的 `.estimated` 来源；4 个新插件都是 `exact` | 无 | 无 | 无 |

## 同步层与基础设施

- `Shared/`、`CloudConstants.swift`（`providerPayloadVersion = 1`）、上游 `Sources/CodexBar/Sync/`（CloudSyncEngine 等）、entitlements、`Scripts/package_app.sh` 全部零 diff。`SyncModels.swift` 新增的 `modelRateLimits`、`claudeResetCreditsVisibilityMigrated` 只属于上游 Mac fleet 的 `ProviderIntent` record JSON。
- `AccountIdentityComputer` 是 fork 独有的穷举 switch，4 个新 provider 归入 per-device（fal 的 username、Claude Platform 的组织名都不是稳定的跨 Mac 标识）。
- 上游 #4509 配置文件读失败不覆盖：fork 独有代码不调用这些 API；与 app-group 迁移无关。残余风险：读失败时内存为默认配置，fleet `queueCurrentConfigurationAndPreferences` 仍可能把默认配置推给其他 Mac（上游自身行为，本轮不改）。
- cookie import Keychain gate（#4443/#4464）：新 `BrowserCookiePromptContractTests` 会打开 gate 但所有密钥读取都注入 `FakeKeychain`，设计上不触真实 SecItem；首次单独运行并留意弹窗。
- 开源致谢：`Acknowledgements.json` 是 CodexBarCore 的 `.process("Resources")` 资源，fork 的 `package_app.sh` 复制 bundle 时自动带上；lint 新增的 `acknowledgements.py` / `test_acknowledgements.py` 在 fork 环境通过（18 components）。
- CI：上游改用 `xcode-27` runner 并删除 Xcode 26.3 兼容构建；fork Final CI 仍是 `macos-26` + Xcode 26.3/26.2 与兼容构建。上游 `release-cli` 仍用 Xcode 26.3 构建 CLI，所以代码仍兼容 Swift 6.2；本轮不改 fork CI（记为风险）。
- Mac 23 种语言：fork 在 0.74.1.1 改过的 `show_credits_extra_usage_subtitle` 非 en 译文在上游 #4484 改变开关语义后已过时（上游也没更新非 en 译文），不阻塞，记录待办。
