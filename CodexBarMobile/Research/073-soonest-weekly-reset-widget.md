# 073 — 每周窗口统一判定（Grok）与 CodexBar 小组件“按每周重置”

状态：done（实现与模拟器实测完成；已知验证缺口：真机待验）
日期：2026-10-10
分支：`feat/ios-soonest-reset-widget`（iOS 2.7.0 (240)）
相关：Research/064（卡片排序）、060（概览多选）、062/09（SiriKit 独立槽位）、071（额度窗口）、072（iOS 27 App Intents 小组件）

## 1. 背景

1. **Bug**：用户真机上 Grok 卡片显示 “Weekly 0%”、3 天后重置，但排序设置页的“每周重置（最近的在前）”显示 “No weekly reset”。`UsageCardOrdering.isWeekly` 只认 `period == .weekly` 或 `windowMinutes == 10080` 整。
2. **需求**：CodexBar 小组件保留“自己选服务商”，新增一种模式：不选服务商，只选显示几个（2/3/4），按每周重置时间从近到远自动排序，与 App 里卡片用哪种排序无关；小、中、大都能选 2/3/4。

## 2. Grok 在 Mac 上的形态（只读核对，不改 Mac）

- `GrokCreditsProxyFetcher.windowMinutes`：`(end - start) / 60` 向下取整，`period` 不设置 → iOS 收到 `period == nil`，`windowMinutes` 常为 10079，也可能为 nil。
- `SyncCoordinator`：Grok primary 的 label 是 `GrokProviderDescriptor.displayLabel(window:)`，即英文常量 `"Weekly"` / `"Monthly"`（时长或距重置的天数四舍五入：4–12 天为 Weekly，20–45 天为 Monthly；无时长且有重置时间、又落在这两段之外时兜底为 Weekly，见 #2929）。Mac 的 gRPC 路径不设 `windowMinutes`，所以月度额度池在距重置不到 3.5 天、或 12.5–19.5 天时也会以 "Weekly" 同步过来（独立 review 发现）。Mac 同步的 label 都是未本地化的英文常量，iOS 只在显示时本地化（`ProviderWindowLabel` 把 `"Weekly"` 映射到 `v045_window_weekly`）。

## 3. 每周窗口规则（`CodexBarWidgetShared/WeeklyResetWindow.swift`）

App 与小组件扩展共用：

1. 有 `period`：以它为准，只有 `.weekly` 算每周。
2. 无 `period`、有 `windowMinutes`：四舍五入到整天等于 7 天（9360 ≤ 分钟 < 10800，即 6.5 天到不足 7.5 天）。依据：Grok 的长度来自账单周期起止向下取整（10079），夏令时会再差 60 分钟；按整天四舍五入是 Mac 命名 Grok 窗口用的同一取整方式（`GrokProviderDescriptor.primaryLabel`），只取“正好 7 天”而不取 Mac 的 4–12 天，避免把其他服务商的多日窗口算成每周。5 小时（300）、1 天（1440）、30 天（43200）都远在范围外。
3. 两者都没有：同时满足三条才算——Mac 的 label 去空白后不区分大小写等于 `"Weekly"`（Grok 无类型的额度窗口）；有 `resetsAt`；`resetsAt` 距快照观测时间（`ProviderUsageSnapshot.lastUpdated`，也就是 Mac 当时算 label 的时刻）不超过 7.5 天（一周加上第 2 条允许的半天）。这样排除了上面 12.5–19.5 天的月度池，以及没有重置时间的 "Weekly" 回退窗口（Windsurf flow actions）。译文（如“每周”）不是 Mac 会发的 label，不算；`"Premium weekly"` 这类不算。
4. 有长度时长度优先于 label（与 Mac “Keep explicit durations authoritative” 一致）。

下次重置（`WeeklyResetWindow.soonest(for:now:)`，App 排序、小组件排序和小组件格子共用这一个函数）：在服务商的窗口里取有 `resetsAt` 的每周窗口；如果其中有**账号级**每周窗口（`QuotaPaceWindowSelection.isAccountWeeklyCandidate`：Claude 的 tertiary Sonnet/Opus 槽、`claude-weekly-scoped-*`、`claude-routines` 不算账号级，与 Mac 每周切换器一致），只在账号级里取；没有账号级时才退回所有每周窗口。已过去的重置按整周向后滚动，取最早；小组件还记下这个窗口当前的已用百分比（重置已过则为 nil）。这会让 App 的“每周重置”排序在少数情况下改变：Claude 的分模型周额度早于账号总周额度重置时，原来按分模型的时间排，现在按账号总周额度排。

### 3.0 新规则对各服务商的影响

| 服务商 / 形态 | 2.6.0 | 2.7.0 | 说明 |
|---|---|---|---|
| Grok（10079 分钟，或无时长 + "Weekly" 且 7.5 天内重置） | 无每周重置 | 每周 | 修复（本次 bug） |
| Grok 月度池（无时长 + "Weekly"，12.5–19.5 天后重置） | 无每周重置 | 无每周重置 | review 后加的距离限制挡住 |
| Aixy（插件预算窗口） | 无每周重置 | 每周 | 按 review 结论列为修复；Aixy 是插件 provider，Mac 源码里没有它的窗口构造，未逐项核对 |
| Windsurf 周额度（secondary：无时长、label "Weekly"、有 `weeklyResetAtUnix`） | 无每周重置 | 每周 | 修复 |
| Windsurf flow actions 回退（secondary：label "Weekly"，无时长、无重置） | 无每周重置 | 无每周重置 | `resetsAt` 条件挡住 |
| Claude、Codex、z.ai、Antigravity 等（10080 分钟或 period） | 每周 | 每周 | 不变；Claude 只在分模型周额度早于账号周额度时排序变化（见上） |
| 用 metadata 的 "Weekly" 作 secondary 标签、但不带时长和 period 的服务商 | 无每周重置 | 7.5 天内重置时为每周 | 一般是正确识别；数据形态少见 |
| Cursor 一类按计费周期算时长的窗口 | 仅 ==10080 | 6.5–7.5 天的周期会算每周 | 潜在误判：不足一周或接近一周的计费周期 |

### 3.1 App 里其它“每周窗口”判定

| 位置 | 原判定 | 结论 |
|---|---|---|
| `UsageCardOrdering.isWeekly` / `weeklyResetDate`（排序、排序设置页、`ContentView` 的重排时钟） | period 或 ==10080 | 同一根因，已改用共用规则（本次 bug） |
| `QuotaPaceWindowSelection.isWeekly`（额度消耗趋势默认窗口）、`widgetTitle`（无 label 的 7 天窗口叫 “Weekly”） | 先看 ==10080，再看 period | 同一根因，已改用共用规则。Grok 的默认窗口原来靠“配速窗口”兜底，正常数据下结果相同；现在直接按每周找到 |
| `QuotaPace.duration`（配速） | Grok 无时长时按距重置 4–12 天算 7 天；有时长用时长 | 不受影响（10079 分钟直接当时长） |
| `MobileQuotaBurndown.historySeriesName`（Codex 曲线 lane 名，==10080） | 只用于 Codex，镜像 Mac `CodexConsumerProjection` 的历史序列命名 | 不同根因，未改 |
| `ProviderUsageSnapshot.quotaWarning`（阈值用 session 还是 weekly 设置） | period，无 period 按槽位 | 不同根因（镜像 Mac 的阈值存储），未改 |
| 卡片显示（`UsageCardView` 等） | 显示 Mac 的 label | 不受影响 |

## 4. 小组件“按每周重置”

### 4.1 配置（两套共用 `StatusWidgetConfigurationAdapter` 与 `WidgetOverviewSelection`）

| | SiriKit `SelectStatusWidget`（iOS 26 及以下） | App Intents `StatusWidgetAppIntent`（iOS 27 起） |
|---|---|---|
| `providerSelection` | 枚举 `StatusWidgetProviderSelection`（manual / soonestWeeklyReset），默认 manual，tag 8，父参数 `mode` EnumHasExactValue `overview` | `StatusWidgetProviderSelectionAppEnum`，默认 `.manual` |
| `providerCount` | 枚举 `StatusWidgetProviderCount`（two / three / four），默认 two，tag 9，父参数 `providerSelection` EnumHasExactValue `soonestWeeklyReset` | `StatusWidgetProviderCountAppEnum`，默认 `.two` |
| `provider1`–`provider4` | 父参数仍是 `mode` == `overview`（见 4.3） | `ParameterSummary` 嵌套 `When`：概览 + 手动时显示 |

- 两者都是独立标量参数，不用固定长度数组（062/09 的经验）。`INIntentLastParameterTag` 9，已有 tag 不变。
- 默认数量 2：所有尺寸都不挤，等于小号小组件原来的自动数量；用户选了这个模式后数量就在下一行，可以改成 3 或 4。
- adapter：SiriKit 的 `unknown`（更新前放置的小组件）一律视为手动；数量未知时用默认 2；数量限制在 2…4。结果 `WidgetOverviewSelection`（`.manual` / `.soonestWeeklyReset(count:)`）放在 `CodexBarWidgetEntry.overviewSelection`，不进旧版 `CodexBarWidgetConfigurationIntent`（它是旧 kind 的存储结构）。
- Research/072 的元数据防回归不变：新类型都不遵循 `CustomIntentMigratedAppIntent`，元数据里搜不到 SiriKit 类名（240a/240c 两份 `extract.actionsdata` 的 sha1 相同：`6eea0464…`、`b6b5ca18…`）。
- 编辑面板四语言：SiriKit `WidgetStatus.strings`、App Intents `WidgetConfiguration.xcstrings`（同一套译文）。

### 4.2 排序与显示（`WidgetProviderSelection`）

- `soonestWeeklyReset(from:count:now:)`：每个服务商一条，取它在 `topProviders` 里的第一条，也就是概览在其他模式下显示的那个账号（用量最高的），按这个账号的每周重置排序；比较函数与 App 相同（`WeeklyResetOrdering.precedes`）：有每周重置的按下次重置升序（过去的按整周滚动），没有的排后面按名称，完全相同时保持快照顺序；取前 N。
  - 单账号时与 App 的“每周重置”排序一致（单测）；多账号时可能不同：App 折叠的服务商卡片按它的第一个账号排序，小组件按它显示的账号排序（单测锁住现状）。
  - 出错（`isError`）的服务商在这个小组件模式下视为没有每周重置，排到后面按名称，不会占掉正常服务商的格子；App 的排序不变（出错的卡片仍按它的每周重置排）。
- 数据：`CodexBarWidgetProviderSummary` 新增可选 `weeklyResetsAt`、`weeklyUsedPercent`，由小组件在已取到的同步快照上计算（`CodexBarWidgetSnapshotBuilder.summary`），不新增联网或账号探测。旧数据解码为 nil。catalogue 只给编辑面板用，不需要重置时间，未改。
- 显示：这个模式下格子显示用来排序的每周窗口（当前周期内的已用百分比和重置时间）；没有每周重置的服务商、以及手动模式，仍显示原来“用得最多的窗口”。否则会出现按每周排序、却显示 5 小时窗口重置时间的情况（实测发现：Claude 显示 0.6d 却排第三）。
- 手动模式：`overview(…, selection: .manual)` 直接调用原来的 `resolve`，行为不变（含“全部未选择 = 自动”，小号 2 个、其他 4 个）。

### 4.3 SiriKit 的限制（实测发现，已调整）

最初按需求把 SiriKit 的服务商槽位挂到 `providerSelection == manual` 下。iOS 26.5 实测：SiriKit 每个参数只有一个父参数，父参数被隐藏时不会连带隐藏子参数（只看父参数的值）。结果把小组件类型切到“今日费用”时，服务商 1–4 又出现了（原来是隐藏的，属于回归）。因此 SiriKit 槽位保留原来的 `mode == overview`：

- 手动模式、非概览类型：与 2.6.0 相同；
- “按每周重置”模式下，SiriKit 面板仍显示服务商 1–4（被忽略）；
- 选了“按每周重置”后再把类型切离概览，面板里“服务商数量”会留到保存为止；保存后再打开就不显示。隐藏的值仍会保存：保存为“今日费用”后 timeline 仍是 `providerIDs=claude, selection=soonestWeeklyReset(3)`，切回概览时“按每周重置”和服务商 1 都还在（`ios265-r2/`）。

**切走再切回概览（review 第 6 条）**：iOS 26.5 上实测三种情况，“服务商选择方式”都没有显示“未知”，所以没有改 Options 扩展或 unknown 的显示名：

| 情况 | 切回概览后 | 证据 |
|---|---|---|
| 手动（服务商 1 = Claude）→ 今日费用 → 保存 → 概览 | Choose Manually，服务商 1 仍为 Claude | `ios265-r2/01-*`、`02-back-overview-set.png` |
| 按每周（数量 3）→ 今日费用 → 保存 → 概览 | By Weekly Reset (Soonest First) | `ios265-r2/03-*`–`06-back-overview-set.png`、`log.txt` |
| 新添加 → 直接改今日费用 → 保存 → 概览 | Choose Manually，服务商未选择 | `ios265-r2/07-*`、`08-fresh-back-overview-set.png` |

iOS 27 的 App Intents 小组件按设计隐藏（嵌套 `When` 实测正常）。如果要在 iOS 26 上也完全隐藏，可选方案是把“按每周重置”做成“小组件类型”的一个新值（槽位与数量各挂在 `mode` 的不同值下），这会改变需求里的参数结构，留给后续决定。

## 5. 测试

### 5.1 单测（`CodexBarMobileTests/SoonestWeeklyResetTests.swift` 等）

- 每周判定：Grok 10079 / 10080 / nil + "Weekly"；DST 少一小时；Claude、Codex；5 小时、1 天、30 天、"Monthly"、无信息；period 显式为 monthly / session / daily / lifetime / weekly；7 天四舍五入边界 9359/9360/10799/10800；label 去空白、译文与 "Premium weekly" 不算；有长度时 label 不覆盖。
- label 兜底：月度 Grok（无时长、"Weekly"、15 天后重置）不算；7.4 / 7.6 天边界；从观测时间而不是 now 量距离；剩余歧义（2 天后重置的月度池仍算，锁住现状）；Windsurf flow actions（"Weekly"、无时长、无重置）不算。
- 下次重置：多窗口取最早、只看每周窗口、过去滚动、无 resetsAt；Claude 有账号周窗口时 Sonnet / `claude-weekly-scoped-*` / `claude-routines` 不参与（App 排序、小组件 summary 的时间和用量一致），只有分模型窗口时退回它们；非 Claude 的 tertiary 照常参与。
- App：Grok 不再是 nil，并排在正确位置；额度消耗趋势默认窗口找到 Grok 的 `primary`，无 label 的 10079 分钟窗口标题为 “Weekly”。
- 小组件数据：summary 带每周重置与当前用量（过期滚动后用量为 nil）；缺字段的旧 JSON 能解码；占位数据的每周重置与其 weekly lane 一致。
- 排序：重置升序、无重置按名称、并列按名称再按快照顺序、过去滚动、数量 2/3/4 截断与 1→2、9→4、不足数量、空列表、同服务商多账号只取显示的那个；单账号时与 App “每周重置”排序逐项一致（同一组快照）；多账号时按显示的账号排序、与 App 不同（锁住现状）；出错的服务商排到后面、App 排序不变；手动模式与原 `resolve` 完全相同；格子数字（手动 / 每周 / 滚动后 / 无每周）。
- 配置：SiriKit unknown → 手动、各数量映射、未知数量 → 默认；App Intents 与 SiriKit 所有组合结果一致；SiriKit 父参数关系、默认值 two、tag 不重复；`WidgetConfigurationAppIntentsTests` 的参数一致性（名称、类型、枚举 case、默认值对照 `.intentdefinition`）加入两个新参数，元数据防回归不变。
- 全量 iOS 单测（`-only-testing:CodexBarMobileTests`，iOS 27.0 模拟器，en_US）：Swift Testing 1,078 项（65 个 suite）+ XCTest 60 项全部通过（review 修复后：`logs/r2-test-full.log`、`xcresult/r2-full.xcresult`；首版 1,073 项：`logs/test-full-final.log`）。
- `Scripts/lint.sh audit-i18n` 通过；改动的 Swift 文件用 swiftformat 0.63.0 / swiftlint 0.65.1 只看改动行：除 App 内更新说明的 4 行长字符串（与 2.6.0 及更早各条相同的既有写法，其中 1 行超过 250 字符，文件里已有十余行同类）外无告警。

### 5.2 SpringBoard 实测

环境：Xcode 27.0（27A266a），Debug，模拟器本地签名；自建 iPhone 17 Pro：`CodexBar soonest-reset iOS27.0`、`CodexBar soonest-reset iOS26.5`（单测用 `CodexBar soonest-reset unit iOS27.0`）。系统语言英文（另有一张简体中文面板截图）。基线是 `origin/mobile-dev`（`76a71a8ef`，2.6.0 (239)）的构建。App 用 `UI_TEST_PREVIEW_DATA` 写 catalogue；预览数据的 Grok 改成 Mac 形态（无 period、10079 分钟、label "Weekly"、3 天后重置）。模拟器里小组件渲染用 `simulatorMock`，本次加了 Grok 形态的服务商（同样经 builder 计算，1.5 天后重置），预期顺序 Grok 1.5d → Codex 2.9d → Claude 3.6d → OpenRouter（无每周，按名称）。证据目录 `/Volumes/StudioSSD/Developer/BuildScratch/CodexBar/soonest-reset/runs/`。

| 系统 | 项 | 结果 | 证据 |
|---|---|---|---|
| 27.0 | 239 放置 App Intents 中号小组件（彩色 / Claude / Codex），覆盖安装新构建 | 显示不变；timeline `providerIDs=claude,codex, selection=manual`；编辑面板直接出现“Provider Selection: Choose Manually”，服务商 1/2 仍为 Claude / Codex | `ios270/07-*`、`08-*`、`09-*`、`log-new-install.txt` |
| 27.0 | 切到 By Weekly Reset | 面板隐藏服务商槽位、出现 “Number of Providers: 2” | `ios270/10-soonest-2-set.png` |
| 27.0 | 中号 2 / 3 / 4 | Grok、Codex / + Claude / + OpenRouter；日志 `soonestWeeklyReset(2/3/4)` | `ios270/11-*`、`12-*`、`log-240b-*.txt` |
| 27.0 | 小号 2 / 3 / 4、大号 2 / 3 / 4（系统改尺寸，配置保留） | 顺序同上 | `ios270/13-*`、`14-*`、`15-*` |
| 27.0 | 切回 Choose Manually | Claude / Codex（隐藏期间值保留），数字与之前相同 | `ios270/16-*` |
| 27.0 | 新添加小组件默认值 | Choose Manually、服务商未选择，自动选择 | `ios270/17-*`、`18-*` |
| 27.0 | 类型切到 Today Cost（手动 / 按每周） | 两种都只剩类型和颜色 | `ios270/21-*` |
| 27.0 | App 排序设置页 | Codex 2 天、Grok 3 天、Claude 4 天…，Grok 有重置时间 | `ios270/20-*` |
| 27.0 | 简体中文面板 | “服务商选择方式：按每周重置（最近的在前）”“服务商数量” | `ios270/23-zh-Hans-panel.png` |
| 26.5 | 239 放置 SiriKit 小号小组件（彩色 / Claude / Codex），覆盖安装 | 显示不变（`sirikit … providerIDs=claude,codex, selection=manual`）；能编辑（改单色后 timeline 跟着变）；面板没有新参数（已知限制） | `ios265/04-*`、`05-*`、`06-*`、`log-install.txt`、`log-editold.txt` |
| 26.5 | 新添加 SiriKit 小组件 | 面板有 “Provider Selection”；切到 By Weekly Reset 出现数量；2 / 3 / 4 顺序同上 | `ios265/08-*`、`09-*`、`10-*`、`15-*`、`log-soonest-all.txt` |
| 26.5 | 手动 → Today Cost | 只剩类型和颜色（与 2.6.0 相同） | `ios265/13-240c-manual-today-set.png` |
| 26.5 | 按每周 → Today Cost | 数量留在面板，保存后再打开不显示（4.3） | `ios265/13-240c-soonest-today-set.png`、`14-*` |
| 26.5 | 手动回归（服务商 1 = Claude） | `providerIDs=claude, selection=manual`，只显示 Claude | `ios265/16-*` |
| 26.5 | 错误日志 | 覆盖安装后 `No intent in timeline`、`view collection was either nil`、`LNPerformActionErrorCodeActionNotFound` 均 0 次 | `ios265/log-errors-since-upgrade.txt` |
| 26.5 | App 排序设置页 | 同 27.0 | `ios265/18-*` |
| 26.5 | 切走类型再切回概览（review 第 6 条） | 不显示“未知”（见 4.3） | `ios265-r2/` |
| 27.0 | review 修复后（240d）大号“按每周重置”4 个 | Grok 1.5d、Codex 2.9d、Claude 3.6d、OpenRouter；mock 数据不含分模型周窗口和出错且有周重置的服务商，主屏顺序与修复前相同 | `ios270-r2/03-home.png`、`log.txt` |

说明：

- 构建：240a（第一版）、240b（加每周用量显示）、240c（SiriKit 槽位改回 `mode`）。27.0 的“已放置小组件升级”用 240a 做，之后同一小组件依次覆盖安装 240b、240c，配置一直保留；三者 App Intents 元数据相同。26.5 的 SiriKit 新参数结构以 240c 新添加的小组件为准（240b 添加的那个结构不同，不计入）。
- 编辑面板打开时覆盖安装，面板会显示 “Unable to Load”，关闭后正常；这是安装时扩展被替换，不是本次引入。
- 模拟器里自动选择（手动模式、全部未选择）的第四个由 OpenRouter 变成 Grok：mock 多了一个正常的服务商，错误的 OpenRouter 本来就排在最后。自动选择逻辑未改（单测覆盖），真机占位数据未加 Grok。

## 6. 局限

- SiriKit（iOS 26 及以下）：“按每周重置”模式下服务商槽位仍显示（被忽略）；切离概览时数量行会留到保存（4.3）。
- 已放置的 SiriKit 小组件（所有系统）看不到新参数，要重新添加；iOS 27 上 2.6.0 起添加的 App Intents 小组件直接可用。
- 一个服务商多个账号时，小组件只按它显示的那个账号（用量最高的）排序，App 折叠卡片按第一个账号排序，两者顺序可能不同；也不取各账号里最早的。
- Grok 月度额度池在最后 7.5 天内（Mac 用 "Weekly" 兜底、又没有时长）仍会被当成每周。根治要在 Mac 端给 Grok gRPC 路径解析周期类型并设置 `period`（follow-up，本次不改 Mac）。
- 新规则在少见数据形态上的潜在误判见 3.0（Cursor 一类按计费周期算时长、长度落在 6.5–7.5 天的窗口）。
- 过期的重置按固定 7×86400 秒向后滚动，跨夏令时会差 1 小时；滚动窗口（没有固定周期）和 Kimi 月度池阻断（`blockingQuota`）这类形态也属于边缘情况，代码未特别处理。
- 小组件“按每周重置”模式把出错的服务商视为没有每周重置；App 的排序仍按它的每周重置。
- 每周判定依赖 Mac 的数据形态；Mac 以后若给 Grok 设置 `period`，以 period 为准。
- 真机未验证。

## 7. 版本与发布

- iOS 2.7.0 (240)，只改 iOS。Mac 的 `version.env`（`MOBILE_VERSION=2.6.0`）不动：`docs/versioning.md` 规定 `MOBILE_VERSION` 只在发 Mac release 时写当时已发的 iOS 版本；先例是 2.5.0 只发 iOS 时（`e0c9f9dde`）`MOBILE_VERSION` 保持 2.4.0，直到 Mac 0.72.0.1 发布（`9b15925e7`）才改，2.5.0 送审说明也写明 “iOS-only; the paired Mac version remains …”。
- 未上传、未推送、未开 PR；提交见交付记录。

## TestFlight（2026-10-10）

- PR #189 两轮 Codex review：
  - 第一轮 1 条 P2：应先确定用账号级每周窗口，再去掉没有重置时间的窗口。已在 `7ec86b915` 修复并补了单测。
  - 第二轮 “Didn't find any major issues”。
  - 门禁通过（unresolved=0），`--match-head-commit` 合并为 `02d6e5405`。
- 合并前在最终 head 上跑完整 iOS 单测：Swift Testing 1,078 项、XCTest 60 项全部通过。合并后的源码（detached worktree `ios240-src`）完整 lint 和 i18n 审计通过。
- 已上传 iOS 2.7.0 (240)：Xcode 27.0 正式版（27A266a），ASC build id `3827ee0f-0f94-4de1-b593-055e80910a74`，状态 `VALID`，内测 `IN_BETA_TESTING`。
- 图标验收：归档里的 `AppIcon60x60@2x.png` 与 238、239 逐字节相同；Apple CDN 上的图标为 152×152，目视正确。
- 还没做真机验证，也还没送审。2.6.0 (239) 仍在审核中。
