# Mac 0.74.1.1 签名、公证与 Draft

Status: `superseded`（这个 Draft 由 `ea96a4f20` 生成；PR #192 review 修复改动了 Mac 源码 `SyncCoordinator.swift` 和 Shared 模型，打包输入已不同。合并后需删除该 Draft，再从 mobile-dev 重新生成）
Date: 2026-10-13

## 授权与边界

- 2026-10-13 用户在本 Goal 中确认：可以使用本机凭证（Developer ID、Apple 公证、Sparkle 私钥）生成 Draft。
- 按 Goal 的边界，本轮**没有**推 tag、推分支、开 PR、merge、更新 appcast、公开发布，也没有上传 TestFlight。因此使用 `./Scripts/release.sh --draft-no-tag-push`：只在 `o1xhack/CodexBar-Mobile` 上创建 Draft 并上传资产，Draft 的 target 先填占位的 `mobile-dev`。

## 命令

```bash
export PATH="$PWD/.build/artifacts/sparkle/Sparkle/bin:$PATH"
TMPDIR=$S/release-tmp CODEXBAR_RELEASE_STAGE_BASE=$S/release-stage \
  ./Scripts/release.sh --draft-no-tag-push
```

`$S` = `/Volumes/StudioSSD/Developer/BuildScratch/CodexBar/upstream-v074`。staging 与 TMPDIR 都在 SSD 上。

## 过程

- 第一次（mac-release-draft1.log）：CHANGELOG 校验、appcast 单调性（0.74.1.1 / 167.1 大于所有已有条目）、`lint.sh lint`（0 个违规）、Release 构建都通过，但在 Widget appex 签名之后停下：`FATAL: provisioning profile not found at …/Provisioning/CodexBar_Dev.provisionprofile`。这个文件被 gitignore，新 worktree 里没有。按脚本提示从主仓库复制 `Provisioning/` 后重跑。失败发生在公证和上传之前，GitHub 上没有留下任何东西。
- 第二次（mac-release-draft2.log）：构建、签名、公证、staple、dSYM 配对、启动 smoke（在不可读的 checkout 外存活 2 秒）全部通过，Draft 已创建，退出码 0。

## 版本与资产

- `0.74.1.1` / `167.1` / Mobile `2.8.0`；包内 `CFBundleVersion = 167.1.2.8.0`（= Sparkle `sparkle:version`），`CFBundleShortVersionString = 0.74.1.1`。
- 构建源码：分支 `upstream-sync/v0.74.1-mobile.2.8.0` 的 `ea96a4f20885da06ee704c532d76e5b7b1661e49`（包内 `CodexGitCommit=ea96a4f20`）。之后的提交只改文档和测试；`25f16e5f2` 的源码改动已被 `4f4a83b19` 完整撤销，`git diff --stat ea96a4f20 HEAD -- <ARTIFACT_INPUTS>` 为空。根 CHANGELOG 有一句措辞在 Draft 之后修正过，Draft 正文需在 tag 提升（`gh release edit`）时一并同步。
- Draft：https://github.com/o1xhack/CodexBar-Mobile/releases/tag/untagged-0c63a3892183d3ac95f7（`isDraft=true`，标题 `CodexBar 0.74.1.1 Mobile 2.8.0`，tag 名 `v0.74.1.1-mobile.2.8.0` 尚未创建，target 占位为 `mobile-dev`）。说明正文是根 CHANGELOG 的 fork 0.74.1.1 段，末尾注明候选构建所用的本地 commit。
- `CodexBar-0.74.1.1-mobile.2.8.0.zip`：86,146,754 bytes，SHA256 `7c50273596aae5672061060bd1a88e66ae67a8fcd5e07b9d042392c86e8f28a9`。
- `CodexBar-0.74.1.1-mobile.2.8.0.dSYM.zip`：69,491,790 bytes，SHA256 `d250d5589413fa8f6263d608137dee42d9a714a3abb1003d31bb176dc96f4a3c`。
- 本地 SHA256 与 GitHub asset digest 一致。`git ls-remote origin "refs/tags/v0.74.1.1*"` 为空，本地也没有这个 tag；`appcast.xml` 与 mobile-dev 相同。

## 实际包验证

从发行 ZIP 解包（`$S/verify-zip`）：
- 架构 `x86_64 arm64`；
- `codesign --verify --deep --strict`：valid on disk，satisfies its Designated Requirement；
- Gatekeeper：`accepted`，`source=Notarized Developer ID`；
- `stapler validate`：The validate action worked；
- entitlements：`com.apple.developer.icloud-container-environment = Production`，容器 `iCloud.com.o1xhack.codexbar`，没有 `aps-environment`；
- `Contents/embedded.provisionprofile` 存在。

## 公开发布前还需要（需另行授权）

1. push 分支并开 PR → Codex Code Review 循环直到当前 head clean → `Scripts/check_pr_review_gate.sh <pr>` → merge 到 mobile-dev。
2. 如果 review 修改改动了 Mac 二进制的输入，删除这个 Draft 后从合并后的 mobile-dev 重新生成；否则按脚本输出的步骤在 mobile-dev 上打 tag、push tag，并把 Draft 的 target 改到 reviewed commit。
3. 合并后 Final CI 通过、用户 QA 通过 → `./Scripts/release.sh --finalize`（公开发布 + 签名 appcast + push）。
4. 公开发布后逐个回复并关闭 #190、#191；iOS 2.8.0 (241) 的 TestFlight 与送审另行授权。
