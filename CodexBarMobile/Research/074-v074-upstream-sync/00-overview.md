# v0.74.0–v0.74.1 单版本上游同步 + iOS 2.8.0

Status: `in-progress`
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

本 Goal 不包括 live release、TestFlight 上传、tag 发布、merge 与 push；遇到发布凭证、CloudKit schema deploy 或无法判断的 iOS scope 时暂停询问。
