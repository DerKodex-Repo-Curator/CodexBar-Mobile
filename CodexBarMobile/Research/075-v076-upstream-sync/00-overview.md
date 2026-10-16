# v0.75.0–v0.76.0 单版本上游同步 + iOS 2.9.0

Status: `draft`
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
- `git merge-tree` 预览 42 个冲突文件（CI、AGENTS、CHANGELOG、README、About、23 个 Localizable.strings、UsageStore/UsageFetcher、CostUsage store/scanner 与测试、parser hash、appcast、version.env），见 `merge-conflicts.txt`。

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

## 授权边界

本 Goal 不包括 live release、TestFlight 上传、tag 发布、merge 与 push；遇到发布凭证、CloudKit schema deploy 或无法判断的 iOS scope 时暂停询问。Mac Draft 按 Goal 用本机凭证生成（与 074 相同的 `--draft-no-tag-push` 方式）。
