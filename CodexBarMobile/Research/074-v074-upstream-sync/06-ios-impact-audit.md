# 上游变化与 iOS 数据通道逐项审计

Status: `done`（设计期审计；实现与测试证据见 02/03）

审计方法：上游代码用 `git show v0.74.1:<path>` 和 `git diff v0.73.0 v0.74.1` 读取，fork 现状读合并后的工作树。数据路径按 provider fetch/plugin → `UsageSnapshot` → `SyncCoordinator` → Shared `ProviderUsageSnapshot`（CloudKit opaque JSON）→ iOS 卡片、详情、widget 逐段追踪。三份独立只读审计（新 provider 落点、已有 provider 数据变化、同步层与 Mac 专属功能）的结论已合入下表。

## 新 provider（9 个新 `UsageProvider` case，均为 bundled plugin）

| id | 数据形态 | 合并前能否到 iOS | 本轮决定 |
|---|---|---|---|
| `aerostack` | `primary` 百分比（无 reset）；详情 "Monthly AI tokens"：Tokens used / Allowance / Remaining / Above allowance / Period | 能，但窗口标签和详情是英文，没有颜色和推送 | 颜色 `#6366F1`，追加到 QuotaProviderList，详情和窗口标签四语言，加 mock |
| `cosmic` | `primary`=Input tokens，`secondary`=Output tokens（无 reset）；详情 Used / Allowance（可能是 Unlimited / Not reported）/ Remaining / Above allowance | 同上 | 颜色 `#29ABE2`，QuotaProviderList，四语言（包括 Unlimited / Not reported），mock |
| `tavily` | `primary`=Plan credits，`secondary`=API key；详情 Account plan / API key / Pay as you go，取值 "N credits" | 同上 | 颜色 `#78B0A1`，QuotaProviderList，四语言（包括 "N credits"），mock |
| `exa` | 只有详情 "API key this month (UTC)" → Spend | 能（作为详情预览） | 颜色 `#0143D9`，**按 ID 或名称精确匹配**（`vertexai` 包含 "exa"），四语言，mock |
| `linkup` | 只有详情 "Account balance" → Credit balance（可能为负） | 能 | 颜色 `#202020`（深色模式下自动提亮），mock |
| `tinyapi` | 只有详情 "Credits" → Available credits "N credits" | 能 | 颜色 `#F97316`，四语言，mock |
| `sailresearch` | 只有详情 "Organization billing" → Credit balance 和区间支出（Last hour、6h、24h、7d、30d、Billing-period spend） | 能 | 颜色 `#2C4681`，所有区间标签四语言，mock |
| `sofya` | 只有详情 "Account credits" → Available / Plan / Purchased credits、Monthly reset | 能 | 颜色 `#B0B820`，四语言，mock |
| `xapi` | `cost{used 0, limit 0, balance（可能为负）, period "Prepaid credits"}`；详情 "Credits"：Balance / Purchased credits / Free credits | **余额会丢**：`mapProviderAmount` 走 `default` 返回 nil | Mac 桥接新增 `.xapi` 余额分支（负数也发布），iOS 复用 `ProviderAmountCard`（`.currency` 正确显示负数）。颜色 `#71767B`，精确匹配，mock 带负余额 |

QuotaProviderList 只追加有百分比窗口的 aerostack、cosmic、tavily（84 → 87，252 → 261 个 zone）。其余 6 个只有余额或支出，没有可以触发额度提醒的窗口。

## 已有 provider 的变化

| 上游变更 | Mac 数据 | 合并前到 iOS | 本轮决定 | 新 wire |
|---|---|---|---|---|
| Qwen Cloud Team Token Plan（#3711） | `primary{resetDescription:"Team"}`，Mac 用 descriptor labeler 显示 "Team"（30 天窗口显示 "Monthly"）；详情 Team Token Plan：Credits / Remaining / Seats | 窗口标签错发成 "5-hour"（桥接没有用 labeler） | Mac 桥接对 qwencloud 用 `rateWindowLabels` 的 primary 标签；iOS 增加窗口标签 Team，详情四语言，"u / t credits used" 本地化 | 否（沿用 `label`） |
| Claude 续费/到期日期（#4324） | 沿用 `subscriptionRenewsAt/ExpiresAt`，新增 `…IsDateOnly`，只有日期的值按 UTC 0 点解析，Mac 按 UTC 显示 | 日期能到 iOS，但 iOS 按本地时区显示，**UTC 以西会早一天** | Mac 对只有日期的值改发新增的可选字段 `subscriptionRenewsOn/ExpiresOn`（`yyyy-MM-dd`），不再发时间戳；精确时间照旧。新 iPhone 按 UTC 日历显示，所有时区都正确；旧 iPhone 忽略新键，不显示 Claude 续费日（0.73.0.1 本来也不发）。最初的 12:00 UTC 锚点方案因 PR #192 review 指出的歧义而放弃 | 是（两个可选字段，payload 内） |
| X API 负余额（#4127） | 见上表 | 余额丢失 | 见上表 | 否 |
| OpenCode Go `~`（#4410）与最受限额度（#3349） | 快照级 `dataConfidence == .estimated` 时，Mac 菜单栏百分比前加 `~`；最受限额度只影响菜单栏和 switcher 的选择 | `usageDataConfidence` 已同步，iOS 只用来关闭 pace | iOS 用量卡片在 estimated 时加 `~`（OpenCode Go、Pi、Muse Code）；窗口本身已全部同步，不需要改 | 否 |
| Claude 外部登录后的 Refresh 指引（#3395） | 新错误文本 "Claude Code credentials changed (Updated …). Click Refresh to re-grant CodexBar access." | 原样显示 Mac 的英文，相对时间停在推送时刻，而且提到的按钮只在 Mac 上有 | iOS 识别这条错误，换成四语言说明“请在那台 Mac 上打开 CodexBar 点击刷新” | 否 |
| Ollama `/api/balance` 和 credit wallet（#4399/#4370） | 月度窗口加上详情 Credits：Credit balance / Monthly credits used / Next refill | 能到 iOS，但标签是英文 | `ollama` 加入 first-party 详情集合，新增标签四语言 | 否 |
| JetBrains AI 充值额度（#4372） | 详情 "Top-up credits" → Remaining | 能到 iOS，但标签是英文 | `jetbrains` 加入 first-party 集合（标签已有翻译） | 否 |
| xAI 实时剩余估算（#4406） | 详情行 "Live remaining (est.)"，主余额不变 | 行能到 iOS，标签是英文 | 标签四语言 | 否 |
| Command Code Go v1、未知套餐（#4405） | `loginMethod` 与月度窗口，不需要新字段 | 能 | 不改 | 否 |
| Claude Enterprise Extra usage（#4320）、预付 credits 进入 Balance 布局（#4422） | 只改 Mac 视图；数据沿用 budget / providerCost.balance | 能 | 不改 | 否 |
| Codex 按账号刷新与首次刷新错误（#4310/#4364） | `codexAccountSnapshots` 会保留未刷新的账号；Settings 里按账号刷新也会写入 | 每个账号的记录照常发布；只有错误、没有快照的账号仍然跳过 | 合并时保证部分刷新不算一次完整发布（见 02）。错误账号同步留作后续 | 否 |
| Claude Plan Usage 历史重新绑定（#4322） | `preferredAccountKey` 可能换一个 key | 可能让 iOS 的 Claude utilization 序列重新开始或切换一次 | 不改；记为已知风险 | 否 |
| Accounts widget（Mac WidgetKit） | Mac 本地 `WidgetSnapshot.accounts` | iOS 没有对应的 widget | **本轮不做**：属于新的 iOS 小组件功能，不是上游同步的数据。iOS 已经有多账号卡片，Status widget 也能按账号显示行。记为后续候选 | — |
| Usage & Spend 会话性能、工具操作、会话标题、缓存复用、Pace 符号、按 provider 上色、跟随前台 App、Homebrew、Linux serve、Omarchy、23 种语言 | 都是 Mac 或 Linux 本地功能，或者只是显示偏好 | 不同步 | Mac 完整保留；iOS 没有对应入口 | — |

## 同步层

- 合并没有改动 `Shared/`、`Sources/CodexBar/Sync/`（fork 桥接）、CloudSyncEngine 和 entitlements。上游只在 fleet 的 `SyncedPreferences` 加了可选的 `unifiedIconSource`，fork 的 Mobile 通道不读它。
- `Scripts/package_app.sh`：仍是 `icloud-container-environment = Production`、容器 `iCloud.com.o1xhack.codexbar`，没有 `aps-environment`。上游 #4403 加了 `--sdk` 和 `-platform_version`，以及 otool 对 minos 14.0 / SDK 的门槛。fork 的 `sign-and-notarize.sh` 会先跑一次不带这些参数的 `swift build -c release`，结果正确，只是多一次构建。
- fork 同步代码调用的上游 API 没有改名或删除；新增参数都有默认值。

## 不支持或推迟的项目

- iOS Accounts widget：新功能，列为后续候选。
- 只有错误、没有快照的 Codex 账号在 iOS 上显示错误：低优先级，列为后续候选。
- iOS widget 的百分比不加 `~`：本轮只改 app 内的用量卡片。
- 旧 iPhone：新 provider 按未知 provider 的通用卡片显示（没有颜色、不本地化），也不会订阅新 provider 的推送 zone；Qwen Team 标签在旧 iPhone 上同样显示 "Team"（标签由 Mac 决定）；Claude 只有日期的续费日在旧 iPhone 上不显示。
