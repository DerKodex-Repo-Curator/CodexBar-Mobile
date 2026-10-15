# v0.74.0–v0.74.1 单版本上游同步 + iOS 2.8.0

Status: `done`（PR #192 已合并，`efd33c17f`；Mac 0.74.1.1 已于 2026-10-14 公开发布，#190/#191 已关闭；iOS 2.8.0 (241) 已上 TestFlight 并于 2026-10-15 提交 App Store 审核（`WAITING_FOR_REVIEW`）。见 04）
Date: 2026-10-12

## 范围与依据

- 基线：`version.env` 为 `UPSTREAM_VERSION=v0.73.0`、`UPSTREAM_SYNC_DATE=2026-10-08`，Mac `0.73.0.1 / 165.1 / Mobile 2.6.0`（最后公开 release `v0.73.0.1-mobile.2.6.0`，2026-10-08，Latest）。
- 上游事实：2026-10-12 用 `gh release list --repo steipete/CodexBar` 读取，最新正式版 **v0.74.1**（2026-10-11T21:37:03Z，tag commit `7c08c0ae783b72040b728757eb85a6cfe4fc2443`），其前为 v0.74.0（2026-10-10T08:49:41Z，`c2f22ccf8751efc8fe697bfe4714769107965274`），两者线性（v0.74.0 是 v0.74.1 的祖先）。原文保存在 `upstream-v0740.json`、`upstream-v0741.json`；`v0.73.0..v0.74.1` 共 193 个非 merge commit，清单见 `upstream-commits.txt`。上游 `version.env`：v0.74.0 `BUILD_NUMBER=166`，v0.74.1 `MARKETING_VERSION=0.74.1`、`BUILD_NUMBER=167`。
- open upstream-sync issue：[#190](https://github.com/o1xhack/CodexBar-Mobile/issues/190)（v0.74.0）、[#191](https://github.com/o1xhack/CodexBar-Mobile/issues/191)（v0.74.1）。本轮一次同步到 v0.74.1，两个 issue 合并为一个用户可见版本，不拆版本。
- 历史 closed issue：#177–#179（v0.71.0–v0.72.0）由 Research 067 闭环；v0.73.0 没有单独 issue，由 Research 070 完成；更早的见 Research 索引。本轮不重开这些范围。#134（无 upstream-sync 标签，"CodexBar Mobile as an addon?"）不在本轮范围。
- iOS 现状：mobile-dev 是 2.7.0 (240)，2026-10-11 已提交 App Store 审核（`WAITING_FOR_REVIEW`，MANUAL，见 Research 073）；2.6.0 已由用户发布（`READY_FOR_SALE`）。为不改动审核中的 2.7.0，本轮 iOS 新内容进入 **2.8.0 (241)**。

## 分支

- 从最新 `origin/mobile-dev`（`54cca3e01ab2044a532b15cc6153326187aa6b5b`）创建独立 worktree `/Volumes/StudioSSD/Projects/working/apple/CodexBar-upstream-v074`，分支 `upstream-sync/v0.74.1-mobile.2.8.0`（已取消对 `origin/mobile-dev` 的 upstream 跟踪，避免误推）。原 checkout 保持在 mobile-dev 不动。
- StudioSSD 已挂载，UUID `9D5FE511-B66C-4765-BB8F-61E5ACB3969D`，realpath 与可写检查通过。构建和日志 scratch 位于 `/Volumes/StudioSSD/Developer/BuildScratch/CodexBar/upstream-v074`。
- 所有调研、实现、版本号、测试、打包准备只在该分支进行。

## 版本号方案（docs/versioning.md）

| 字段 | 值 | 依据 |
|---|---|---|
| `MARKETING_VERSION` | `0.74.1.1` | 上游 tag v0.74.1 + fork 第 1 版 |
| `BUILD_NUMBER` | `167.1` | 上游 v0.74.1 `BUILD_NUMBER=167` + fork `.1` |
| `MOBILE_VERSION` | `2.8.0` | 本轮配套 iOS 版本（沿用 067/070 由 Mac 配套同轮 iOS 版本的做法） |
| `UPSTREAM_VERSION` | `v0.74.1` | |
| `UPSTREAM_SYNC_DATE` | `2026-10-11` | 上游 v0.74.1 发布日期 |
| Sparkle `sparkle:version` | `167.1.2.8.0` | `BUILD_NUMBER.MOBILE_VERSION`，大于已发布的 `165.1.2.6.0` |
| Tag | `v0.74.1.1-mobile.2.8.0` | |
| Zip | `CodexBar-0.74.1.1-mobile.2.8.0.zip` | |
| iOS | `2.8.0 (241)`，全部 target 同步 | 2.7.0 (240) 之后 |

如果签名前用户决定 Mac 先配套已上线的 iOS 版本，只调整 `MOBILE_VERSION` 和 tag，本轮上游内容不拆分。

## 文档

- [01-design.md](01-design.md) — 合并规则、Mac→iOS 数据通道设计、CloudKit 判断
- [02-implementation.md](02-implementation.md) — 冲突决策与实现记录
- [03-testing.md](03-testing.md) — 测试计划、命令证据、16 组合兼容矩阵
- [04-mac-release.md](04-mac-release.md) — Mac 签名、Draft 与发布状态
- [06-ios-impact-audit.md](06-ios-impact-audit.md) — 上游逐项 iOS 影响审计

## 授权边界

本 Goal 不包括 live release、TestFlight 上传、tag 发布、merge 与 push；遇到发布凭证、CloudKit schema deploy 或无法判断的 iOS scope 时暂停询问。2026-10-13 用户确认可以用本机凭证生成 Mac Draft。

## 合并（2026-10-14）

- 用户授权 push 与开 PR 后，按 fork PR 流程：本地独立 review 三轮（0 阻断）→ PR [#192](https://github.com/o1xhack/CodexBar-Mobile/pull/192) → Codex review 5 轮（记录见 02）→ 最终 head `3c631fb79` 上跑一次 lint 和 Mac/iOS 全量（见 03）→ `Scripts/check_pr_review_gate.sh 192` 通过后合并，merge commit `efd33c17f`。
- 合并后 Final CI 的结果和偶发失败的处理见 03“合并后 CI”。
- 还需要用户单独授权的事项：删除旧 Draft 并从 mobile-dev 重新生成、打 tag `v0.74.1.1-mobile.2.8.0` 并公开发布（之后回复并关闭 #190/#191）、iOS 2.8.0 (241) 上传 TestFlight 和提交审核。

## 最终交付状态（2026-10-13，合并前）

- **分支**：所有工作都在 `upstream-sync/v0.74.1-mobile.2.8.0`（worktree `CodexBar-upstream-v074`）完成，没有动 mobile-dev。本地 commit（未推送）：

  | Commit | 内容 |
  |---|---|
  | `cd7431995` | merge 上游 v0.74.1 + 冲突解决 + 编译修复 |
  | `b23b79928` | README 移植上游事实 + guard hash |
  | `300064fac` | Mac→iOS 桥接、QuotaProviderList、mock、strings 去重 |
  | `082e96bcc` | iOS 2.8.0 (241) |
  | `c90a62c74` | version.env / 根 CHANGELOG |
  | `2d3b1851e`、`477cae6ff`、`62311603c` | review 与全量测试中的修复 |
  | `c8d8b06c3`、`ea96a4f20`、`20f44a5a7` | Research 074、CloudKit 审计 |
  | `25f16e5f2` → 撤销 `4f4a83b19` | 误判后改成“重建 0.73.0.1 缓存”，真实日志验证后撤销（净改动为零） |
  | `1fec5c6ca`、`91b591816` | 0.73.0.1 前驱的补充测试、真实日志成本验证记录 |
  | 本次收尾提交 | 第 3 轮 review 的措辞修正 |

- **Mac**：已同步到上游 v0.74.1（包含 v0.74.0）。`0.74.1.1 / 167.1 / Mobile 2.8.0`（Sparkle `167.1.2.8.0`）已签名、公证、staple，并生成 **Draft**：https://github.com/o1xhack/CodexBar-Mobile/releases/tag/untagged-0c63a3892183d3ac95f7 （没有 tag，详见 04）。
- **iOS**：2.8.0 (241)，全部 target 同步；CHANGELOG、应用内说明（2.8.0 Latest，2.7.0 不再标 Latest）、AppStoreMetadata/2.8.0 四语言。没有上传 TestFlight。
- **测试**：
  - Mac `Scripts/test.sh` 两个分片共 153/153 组、1707 项首轮通过；
  - `lint.sh lint` 0 违规；
  - 多账号/多设备 filter 通过；
  - iOS 完整单测 TEST SUCCEEDED（Swift Testing 1085 项 + XCTest）；
  - iOS Release 设备构建 BUILD SUCCEEDED；
  - 四语言审计通过；
  - 真实日志成本验证：沿用 0.73.0.1 缓存升级后，与全新扫描、0.73.0.1 基线逐天一致，App 路径逐次刷新没有中间低值。
  - 详见 03。
- **同步兼容 gate**：16 个组合都已列出，均为 substituted（冻结 wire：64 次读取、32 次新旧合并，全部 PASS），没有 fail。
- **CloudKit**：`NO_DEPLOY`（已写入 `docs/cloudkit-deploy-audit.md`）。
- **Review**：独立 review agent 三轮，另有一次成本路径专项审计。第 1 轮有 1 个阻断、1 个应修和若干小问题，全部已修并复测；第 2 轮没有阻断或应修问题；第 3 轮（`477cae6ff..HEAD`）没有阻断问题，1 个应修（根 CHANGELOG 措辞）和 3 个文档小问题都已修正。最终阻断问题为 0。
- **issue**：#190、#191 保持 open。按发布清单，正式 release 公开后再回复并关闭。
- **未覆盖风险**：
  - 没有实体 2 Mac × 2 iPhone、Production CloudKit 收敛与 APNs 时序的验证；
  - 新 provider 没有真实账号数据；
  - 旧 iPhone 上的新 provider 显示为通用卡片（没有颜色、英文、无推送）；
  - 旧 iPhone 不显示 Claude 只有日期的续费日（新字段旧版会忽略，与 0.73.0.1 时相同）；
  - iOS widget 的百分比不加 `~`；
  - iOS 的 Accounts widget 没有做（后续候选）。
