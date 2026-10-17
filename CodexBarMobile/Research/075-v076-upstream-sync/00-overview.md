# v0.75.0–v0.76.0 单版本上游同步 + iOS 2.9.0

Status: `in-progress`（代码、测试、review、Mac Draft 完成；等待用户授权 push/PR/merge、公开发布与 TestFlight，见 04）
Date: 2026-10-15

## 范围与依据

- 基线：`version.env` 为 `UPSTREAM_VERSION=v0.74.1`、`UPSTREAM_SYNC_DATE=2026-10-11`，Mac `0.74.1.1 / 167.1 / Mobile 2.8.0`（最后公开 release `v0.74.1.1-mobile.2.8.0`，2026-10-14，Latest）。
- 上游事实：2026-10-15 用 `gh release list --repo steipete/CodexBar` 读取，最新正式版 **v0.76.0**（2026-10-15T16:47:06Z，tag commit `b4051c2efb6d9d2c5d8cfcab5c6a468c75a40646`），其前为 v0.75.0（2026-10-14T00:59:30Z，`d78a7a7823b650603f4b5f51a2d3d2acefa174b3`），两者线性（v0.75.0 是 v0.76.0 的祖先）。原文保存在 `upstream-v0750.json`、`upstream-v0760.json`；`v0.74.1..v0.76.0` 共 85 个非 merge commit，清单见 `upstream-commits.txt`。上游 `version.env`：v0.75.0 `BUILD_NUMBER=168`，v0.76.0 `MARKETING_VERSION=0.76.0`、`BUILD_NUMBER=169`。
- open upstream-sync issue：只有 [#193](https://github.com/o1xhack/CodexBar-Mobile/issues/193)（v0.75.0，2026-10-15 由 monitor 自动创建）。v0.76.0 在 issue 创建之后数小时发布，monitor 尚未为它开 issue。Goal 规定上游事实以 GitHub Releases 为准，且同一批上游内容不拆版本，所以本轮一次同步到 **v0.76.0**（包含 v0.75.0），#193 与之后 monitor 为 v0.76.0 自动创建的 issue 都由本轮闭环。
- 历史 closed issue：#190/#191（v0.74.0–v0.74.1）由 Research 074 闭环；#185（v0.73.0）由 070；#177–#179 由 067；更早见 Research 索引。本轮不重开这些范围。#134（无 upstream-sync 标签）不在本轮范围。
- iOS 现状：mobile-dev 是 2.8.0 (241)，2026-10-15 已提交 App Store 审核（`WAITING_FOR_REVIEW`，MANUAL，见 Research 074）。为不改动审核中的 2.8.0，本轮 iOS 新内容进入 **2.9.0 (242)**。

## 上游变更概览（v0.74.1 → v0.76.0，513 个文件）

- 新 provider（4 个 `UsageProvider` case，均为 bundled plugin）：`parallel`（预付 credit 余额）、`fal`（账户 credit 余额）、`flora`（workspace 余额/成员上限/月度支出）、`claudeplatform`（Console API credits）。
- 已有 provider 数据变化：Claude spend-only 账户单 meter + 日历月 pace + UTC 1 日 rollover、reset credits / Extra usage / Credits / plan dates 独立选择、OAuth 邮箱显示、stale 提示与错误分离；Codex 多于 3 个账号的结果保留、OpenCodex 替换 totals 时保持 native 详情、identified-request 小计、Auto-review 自 10-06 起 $0 定价；OpenAI Live Usage（Admin Usage API tokens/min 吞吐）与组织 rate limit；Command Code API key；Kimi China Desktop session；JetBrains 新日志记录；Cursor 短标签；Charm Hyper / Helmcode / Droid 浏览器 session；OpenCode Go 扫描缓存。
- Mac 专属：menu bar 进度条 token、stacked-bars 预设、单图标双行、Large text / 等宽数字、Settings provider 列表筛选/搜索/Undo、About 开源致谢、插件内存释放、配置文件读失败不覆盖、cookie import Keychain 提示上限、CLI 并发抓取。
- 同步层：`Shared/` **零 diff**；`Sources/CodexBarCore/Sync/SyncModels.swift` 只给上游 Mac fleet 的 `ProviderIntentPayload` 增加可选 `modelRateLimits`、`claudeResetCreditsVisibilityMigrated`（既有 `ProviderIntent` record 的 JSON 内部）。
- parser-hash 覆盖文件有改动（`CostUsageScanner*.swift`、`CostUsageCacheModels.swift`）→ 需要升 `parserLogicVersion` 并重新生成 `CodexParserHash`。
- 依赖：SweetCookieKit 0.5.5 → 0.5.7。
- `git merge-tree` 预览 42 个冲突文件（实际 merge 报 41 个：预览多算了一个自动合并成功的文件）（CI、AGENTS、CHANGELOG、README、About、23 个 Localizable.strings、UsageStore/UsageFetcher、CostUsage store/scanner 与测试、parser hash、appcast、version.env），见 `merge-conflicts.txt`。

## 分支

- 从最新 `origin/mobile-dev`（`f1f547b907eaf84dd820657fad6fb69e4f6f3c81`，本地与远端一致）创建独立 worktree `/Volumes/StudioSSD/Projects/working/apple/CodexBar-upstream-v076`，分支 `upstream-sync/v0.76.0-mobile.2.9.0`（已取消 upstream 跟踪，避免误推）。原 checkout 保持在 mobile-dev 不动。
- StudioSSD 已挂载，UUID `9D5FE511-B66C-4765-BB8F-61E5ACB3969D`，可写。构建与日志 scratch：`/Volumes/StudioSSD/Developer/BuildScratch/CodexBar/upstream-v076`；上游 v0.76.0 只读 worktree：同目录下 `wt-up-0.76.0`。
- 所有调研、实现、版本号、测试、打包准备只在该分支进行。

## 版本号方案（docs/versioning.md）

| 字段 | 值 | 依据 |
|---|---|---|
| `MARKETING_VERSION` | `0.76.0.1` | 上游 tag v0.76.0 + fork 第 1 版 |
| `BUILD_NUMBER` | `169.1` | 上游 v0.76.0 `BUILD_NUMBER=169` + fork `.1` |
| `MOBILE_VERSION` | `2.9.0` | 本轮配套 iOS 版本（沿用 067/070/074 做法） |
| `UPSTREAM_VERSION` | `v0.76.0` | |
| `UPSTREAM_SYNC_DATE` | `2026-10-15` | 上游 v0.76.0 发布日期 |
| Sparkle `sparkle:version` | `169.1.2.9.0` | `BUILD_NUMBER.MOBILE_VERSION`，大于已发布的 `167.1.2.8.0` |
| Tag | `v0.76.0.1-mobile.2.9.0` | |
| Zip | `CodexBar-0.76.0.1-mobile.2.9.0.zip` | |
| iOS | `2.9.0 (242)`，全部 target 同步 | 2.8.0 (241) 之后 |

只做这一个版本；v0.75.0 与 v0.76.0 的内容不拆成两个用户可见版本。

## 文档

- [01-design.md](01-design.md) — 合并规则、Mac→iOS 数据通道设计、CloudKit 判断
- [02-implementation.md](02-implementation.md) — 冲突决策与实现记录
- [03-testing.md](03-testing.md) — 测试计划、命令证据、16 组合兼容矩阵
- [04-mac-release.md](04-mac-release.md) — Mac 签名、Draft 与发布状态
- [06-ios-impact-audit.md](06-ios-impact-audit.md) — 上游逐项 iOS 影响审计

## 本轮发现的上游未修复问题（不在本轮修）

- **Codex 把旧 rollout 压缩成 `rollout-*.jsonl.zst`，上游成本扫描器只读 `.jsonl`**（上游 issue [#4523](https://github.com/steipete/CodexBar/issues/4523)，开放 PR [#4534](https://github.com/steipete/CodexBar/pull/4534)：vendored zstd 解码器 + 镜像目录，约 2.9 万行，含新 C target，尚未经维护者 review）。本机 `~/.codex` 在 2026-10-13 后出现 640 个 `.zst`（T2 快照 930 个 jsonl，T3 只剩 58 个 jsonl + 883 个 zst），codex-cli 0.142.1。影响：全新扫描的 Codex 历史从压缩点之后开始；已缓存的行是否保留见 03 的成本验证。0.74.1.1 与 0.76.0.1 行为相同，不是本轮回归；等上游合并后下一轮同步跟进（或届时单独移植）。

## 最终交付状态（2026-10-16，合并前）

- **分支**：所有工作都在 `upstream-sync/v0.76.0-mobile.2.9.0`（worktree `CodexBar-upstream-v076`）完成，没有动 mobile-dev。本地 commit（未推送）：

  | Commit | 内容 |
  |---|---|
  | `62fc10079` | merge 上游 v0.76.0（含 v0.75.0）+ 冲突解决 + 编译修复 |
  | `90409cf01` | README 移植上游事实 + guard hash |
  | `cccb84e49` | Mac→iOS 桥接、QuotaProviderList、mock、23 locale 计数、iOS 2.9.0 (242)、version.env、根 CHANGELOG |
  | `784578c38`、`7bcc821cd`、`67ccaa437`、`aee1af601` | 第一轮 review 修复与 lint 修正 |
  | `0e4463a4e`、`1d2d20516`、`ee6084b0e` | Codex parser revision 13 原地升级（先 hydrate 再升级）与 parser hash |
  | `e76becc4b` | 上游分页测试改用更旧 stale revision |
  | `ca74e7954` | 第三轮 review：读不到 leaf 时交回上游路径、子会话测试增强 |
  | 其余 | Research 075、CloudKit 审计、测试记录 |

- **Mac**：已同步到上游 v0.76.0（包含 v0.75.0）。`0.76.0.1 / 169.1 / Mobile 2.9.0`（Sparkle `169.1.2.9.0`）已签名、公证、staple，并生成 **Draft**：https://github.com/o1xhack/CodexBar-Mobile/releases/tag/untagged-87deca90011959e5f109（没有 tag，构建源码 `0e6408597`，详见 04；第一次 Draft 已因 review 后的源码变更删除重做）。
- **iOS**：2.9.0 (242)，全部 target 同步；CHANGELOG、应用内说明（2.9.0 Latest，2.8.0 不再标 Latest）、AppStoreMetadata/2.9.0 四语言。没有上传 TestFlight。
- **测试**（详见 03）：Mac `Scripts/test.sh` 两个分片在 `ee6084b0e` 上 8071 + 7275 项通过（第三轮 review 后的最终 HEAD `ca74e7954` 再跑一次全量，结果见 03）；`lint.sh lint` 0 违规；多账号/多设备 filter 通过；iOS 完整单测 1096 项通过（含 Research 076 小组件概览统一每周窗口的新用例）；iOS Release 设备构建未单独跑（模拟器构建与单测通过）；四语言审计通过；真实日志成本验证（plan2/3/4）证明 0.74.1.1 缓存沿用与基线一致。
- **同步兼容 gate**：16 个组合都已列出，均为 substituted（冻结 wire：64 次读取、32 次新旧合并，全部 PASS，最终提交复跑），没有 fail。
- **CloudKit**：`NO_DEPLOY`（已写入 `docs/cloudkit-deploy-audit.md`）。
- **Review**：独立 review 两轮。第 1 轮无阻塞、5 项应修已修；第 2 轮 1 项阻塞（原地升级删除 token snapshots）已修并用真实 store 复验，应修与小问题已处理或记录。最终阻塞问题为 0。
- **issue**：#193 保持 open。按发布清单，正式 release 公开后再回复并关闭（v0.76.0 若由 monitor 另开 issue，一并关闭）。
- **未覆盖风险**：
  - 没有实体 2 Mac × 2 iPhone、Production CloudKit 收敛与 APNs 时序的验证；
  - 新 provider 没有真实账号数据；
  - 旧 iPhone 上 Claude Platform 显示为旧版 Claude 橙、grant 到期日英文；新旧 Mac 混用期间 Claude 会出现两张卡（legacy 身份 + 邮箱身份）；
  - Codex 把旧 rollout 压缩成 `.jsonl.zst` 后，Mac 的历史成本只剩压缩点之后（上游 #4523 / PR #4534 未合并，两个版本相同，本机已受影响）；
  - fork Final CI 仍用 macOS 26 / Xcode 26.x runner（上游已改 Xcode 27 only），代码仍兼容 Swift 6.2（上游 release-cli 仍用 Xcode 26.3）；
  - 在这份 129k 行的历史上，Mac 的 catch-up 持续 pending，上游 #3051 会在大多数刷新返回保留的旧报告（0.74.1.1 在 3013.54 与 2980.85 之间周期性跳动；最终 fork 稳定在 2980.85，更接近全新扫描真值），见 03 的 plan5/plan6；
  - OpenAI Live Usage 吞吐本轮不同步到 iOS。

## 授权边界

本 Goal 不包括 live release、TestFlight 上传、tag 发布、merge 与 push；遇到发布凭证、CloudKit schema deploy 或无法判断的 iOS scope 时暂停询问。Mac Draft 按 Goal 用本机凭证生成（与 074 相同的 `--draft-no-tag-push` 方式）。
