# 076 — CodexBar 小组件概览统一显示每周窗口

Status: `done`（代码与 review 完成，随 075 的 PR 合并）
Date: 2026-10-16

## 问题

小组件概览（Overview）的 tile 在"手动选择"模式下显示的是该服务商**用量最高的窗口**（`CodexBarWidgetSnapshot.summary` 取 `allRateWindows` 中 `usedPercent` 最大者，包含 Claude 的 "Fable only" 这类单模型窗口）。Claude 同时有 Session、Weekly、Fable only 三个百分比，哪个高就显示哪个，于是 tile 在 Session 与 Weekly 之间来回切换；只有"按每周重置"模式（Research 073）才固定显示每周窗口。用户要求概览全部统一按 Weekly。

## 设计

- `WidgetProviderSelection.overviewFigures` 不再区分选择模式：tile 一律显示每周窗口。
- 每周窗口的取法沿用 073 的 `WeeklyResetWindow.soonest`：**优先账号级每周窗口**（Claude 的 `tertiary`/`claude-weekly-scoped-*`/`claude-routines` 这类单模型或 routines carve-out 只在账号没有自己的每周窗口时才会被用到）；多个每周窗口重置时间相同时（Antigravity 按模型的每周池）先取用量已知的，再取用量更高的那个，与 Mac 一样取更满的窗口（`soonest` 不像 `QuotaPaceWindowSelection.defaultWindowID` 那样限定 Antigravity 的 summary 窗口、用量也相同时保留卡片顺序，所以不是完全一致；排序键仍是重置时间，073 的排序不变）。
- 账号级每周窗口没有 reset 时（Mac 解析不到重置时间），tile 仍显示它的用量、不显示倒计时（新增 `WeeklyResetWindow.resetlessUsedPercent`），不再回退到 Session/Fable only。
- 每周重置已过去而数据未刷新时隐藏过期用量、只显示下一次重置（沿用 073）。
- 没有任何每周窗口的服务商（例如 OpenRouter 余额/日额度）保持原来的"用量最高窗口"。
- 自动选择（概览未选任何服务商）改为按 tile 显示的每周用量排序，避免"顺序按 Session、数字按 Weekly"的不一致；出错（`isError`）的服务商仍排在正常服务商之后（原来 `displayProviders` 就把出错项放最后，占位数据里出错的 OpenRouter 92% 不会抢到图库预览的首格）；显式选择保持原顺序。
- 既有限制（非本轮引入）：自动选择与"按每周重置"模式都按 `topProviders` 去重，每个服务商取它的第一个账号；格子显示的是这个账号的每周数字，不一定是该服务商每周用量最高的账号。
- 只改 Overview tile 与自动选择；小组件的其他模式（单服务商、列表、Quota pace、Token Activity）、`topProviders`/`maxUsagePercent` 与 App 内卡片不变。不改 wire、不改小组件配置；已放置的小组件在下一次 timeline 自动更新，无需重新添加。两代小组件（iOS 26 SiriKit、iOS 27 App Intents）和 App 内预览走同一个 `overviewFigures`。
- 格子外观不区分"每周"与"回退到最高用量"两种数据（沿用原设计）。

## 实现

- `CodexBarWidgetShared/WidgetProviderSelection.swift`：`overviewFigures` 对所有模式先取每周窗口；`resolve` 的自动分支按每周用量排序。
- `CodexBarWidgetShared/WeeklyResetWindow.swift`：`soonest` 的平局规则；新增 `resetlessUsedPercent`。
- `CodexBarWidgetShared/CodexBarWidgetSnapshot.swift`：`summary` 在没有带 reset 的每周窗口时填 `weeklyUsedPercent`；字段注释与占位数据（Claude 样例 `usagePercent` 改为 71，与 Fable only 71 一致）。
- `SoonestWeeklyResetTests`：手动模式取每周窗口、无每周窗口回退、过期重置隐藏用量、端到端（Session 80 / Weekly 35 / Fable 90 → 35）、无 reset 的账号每周窗口、重置时间相同取更满者、自动选择按每周排序。
- iOS 2.9.0 (242) 同一版本块：CHANGELOG、应用内说明（四语言，术语与既有译法一致：当前周期 / 仅限某个模型的额度）、AppStoreMetadata/2.9.0（条目放在第 3 位，不与"需更新 Mac"的末行相邻）。

## 测试与证据

日志目录：`/Volumes/StudioSSD/Developer/BuildScratch/CodexBar/upstream-v076/`。

| 项目 | 命令 | 结果 | 日志 |
|---|---|---|---|
| 小组件四套件（第一次） | `xcodebuild test -only-testing:` `SoonestWeeklyResetTests`、`WidgetSnapshotBuilderTests`、`CodexBarWidgetRenderMatrixTests`、`WidgetProviderSelectionTests` | TEST SUCCEEDED：Swift Testing 56 项、XCTest 20 项 | ios-widget4.log |
| iOS 完整单测（第一次） | `xcodebuild test`（CodexBarMobile scheme，iPhone 模拟器） | TEST SUCCEEDED：1095 项 / 67 suite | ios-full2.log |
| 第二轮 review 修复后小组件四套件 | 同上 | TEST SUCCEEDED：Swift Testing 57 项（新增出错项排序用例）、XCTest 20 项 | ios-widget5.log |
| 第二轮 review 修复后 iOS 完整测试 | `xcodebuild test`（含 UI 测试） | TEST SUCCEEDED：Swift Testing 1096 项 / 67 suite，XCTest 单元 60 项，UI 24 项（6 项按设计跳过） | ios-full3.log |
| 四语言 | `python3 Scripts/audit_localized_keys.py` | 409 个 source key 齐全；xcstrings 四语言条目已加 | — |
| swiftformat | 仓库 `.build/lint-tools/bin/swiftformat` 对改动的 5 个 Swift 文件 | 无改动需要 | — |

本次不改布局、小组件配置、渲染分支与 wire，不触发真实 SpringBoard gate；`CodexBarWidgetRenderMatrixTests` 覆盖占位数据的全部 family 渲染。Mac 侧 `Sources/`、`Shared/`、`Package.*`、`Scripts/`、`version.env` 没有改动，075 的 Mac Draft 继续有效。

## Review

两轮本地独立 review（只读子代理）。

- 第一轮：无阻塞；应修项（`soonest` 平局取更满窗口、无 reset 的账号级每周窗口不回退 Session、自动选择按每周用量排序、073 文档注释、四语言术语）已全部处理。
- 第二轮：1 项阻塞——自动排序没有看 `isError`，出错的 OpenRouter 占位样例（92%）会抢到图库预览首格；修复为出错项排在正常项之后（与原 `displayProviders` 顺序一致），新增用例锁住顺序与占位预览。应修 2 项（073 第 75 行矛盾、占位 Claude 的 `resetsAt` 与 `usagePercent` 不是同一窗口）已修。小问题：`summary` 改成显式 `if let`、删掉 `resetlessUsedPercent` 未用的 `now`、平局时先取用量已知的窗口（新增用例）、076 文档不再说"与 Mac 完全一致"、`overviewFigures` 保留 `selection` 参数的理由写入注释、应用内说明条目位置与 AppStoreMetadata 一致（第 3 位）、测试改名。未改：文案"always shows … weekly usage and reset"（无 reset 时不显示倒计时属于边缘情况，文案保持简洁）。
- 最终阻塞问题 0。
