# Mac 0.76.0.1 签名、公证与 Draft

Status: `done`（第二次 Draft 已生成，未公开；第一次 Draft 因第三轮 review 后 Sources 变更已删除）
Date: 2026-10-16

## 授权与边界

- Goal 规定：Mac Draft 按发布流程生成，但不做 live release、TestFlight 上传、tag publish、merge 与 push；遇到发布凭证问题暂停询问。与 074 相同，使用 `./Scripts/release.sh --draft-no-tag-push`：只在 `o1xhack/CodexBar-Mobile` 上创建 Draft 并上传资产，Draft 的 target 先填占位的 `mobile-dev`，不创建 tag、不推分支、不更新 appcast。
- 前置：`Provisioning/CodexBar_Dev.provisionprofile` 已从主 checkout 复制到 worktree（gitignore，074 第一次打包就因缺它而中断）；Sparkle 工具在 `.build/artifacts/sparkle/Sparkle/bin`；release secrets 在 `~/.codexbar-secrets/`。

## 计划命令

```bash
export PATH="$PWD/.build/artifacts/sparkle/Sparkle/bin:$PATH"
TMPDIR=$S/release-tmp CODEXBAR_RELEASE_STAGE_BASE=$S/release-stage \
  ./Scripts/release.sh --draft-no-tag-push
```

`$S` = `/Volumes/StudioSSD/Developer/BuildScratch/CodexBar/upstream-v076`。

## 过程

- 第一次（mac-release-draft0-nohup-failed.log）：用 `nohup` 启动，phase1 的 `lint.sh lint` 在 `test_swift_test_process_cleanup.py` 的 `test_keyboard_interrupt_drains_children_and_propagates` 失败——`nohup` 把 SIGINT 设为忽略，测试依赖 SIGINT 触发 `KeyboardInterrupt`。在构建、签名、上传之前就停止，GitHub 上没有留下任何东西。
- 第二次（mac-release-draft1.log）：改用 Python `os.setsid()` 脱离会话（保留默认信号处理）启动。lint 0 违规 → Release 构建（arm64 + x86_64）→ Widget 扩展 → 签名 → 公证 `Accepted` → staple → dSYM 配对 → 启动 smoke（无 Aqua 会话，只检查 resource-bundle fatal 签名）→ Draft 创建，退出码 0。

- 第三轮 review 修改了 `CostUsageScanner+ForkParserRevision.swift`（Sources 变更），按发布清单删除第一次 Draft（`untagged-091dead320bd4660a6c2`，`CodexGitCommit=9c43d67c9`，zip SHA256 `f99b8b37…`），在最终 HEAD 的全量测试通过后重新打包（mac-release-draft2.log，同样用 setsid 启动）：lint 0 违规 → Release 构建 → 签名 → 公证 `Accepted` → staple → Draft 创建，退出码 0。

## 版本与资产（第二次 Draft，当前有效）

- `0.76.0.1` / `169.1` / Mobile `2.9.0`；包内 `CFBundleVersion = 169.1.2.9.0`，`CFBundleShortVersionString = 0.76.0.1`。
- 构建源码：`0e6408597`（包内 `CodexGitCommit=0e6408597`）。相对最终全量测试所用的 `ca74e7954`，Sources/Shared/Package/打包脚本/version.env/WidgetExtension 无差异（`git diff --stat` 为空），只多了 Research 文档提交。
- Draft：https://github.com/o1xhack/CodexBar-Mobile/releases/tag/untagged-87deca90011959e5f109（`isDraft=true`，标题 `CodexBar 0.76.0.1 Mobile 2.9.0`，tag 名 `v0.76.0.1-mobile.2.9.0` 尚未创建，target 占位 `mobile-dev`）。
- `CodexBar-0.76.0.1-mobile.2.9.0.zip`：88,965,680 bytes，SHA256 `6a25018122450fe769d95ad3881c04e89b8a0ec6c71da62eed46031d50ef1456`。
- `CodexBar-0.76.0.1-mobile.2.9.0.dSYM.zip`：71,582,260 bytes，SHA256 `cb8a7c87ee20601504cd60385840929b5470533ed6b2a48f7490fb091f551fb0`。
- 本地 SHA256 与 GitHub asset digest 一致。没有创建 tag，没有推送分支，`appcast.xml` 与 mobile-dev 相同。
- 包验证（`$S/verify-zip2`）：`x86_64 arm64`；`codesign --verify --deep --strict` 通过；Gatekeeper `source=Notarized Developer ID`；`stapler validate` 通过；entitlements `icloud-container-environment = Production`、容器 `iCloud.com.o1xhack.codexbar`、无 `aps-environment`；`embedded.provisionprofile` 存在。

## 版本与资产（第一次 Draft，已删除）

- `0.76.0.1` / `169.1` / Mobile `2.9.0`；包内 `CFBundleVersion = 169.1.2.9.0`（= Sparkle `sparkle:version`，大于已发布的 `167.1.2.8.0`），`CFBundleShortVersionString = 0.76.0.1`。
- 构建源码：分支 `upstream-sync/v0.76.0-mobile.2.9.0` 的 `9c43d67c9`（包内 `CodexGitCommit=9c43d67c9`）。它与最终全量测试所用的 `ee6084b0e` 相比只多了测试文件与 Research 文档（`e76becc4b`、`9c43d67c9`），Sources/Shared/Package/打包脚本/version.env 无差异。
- Draft：https://github.com/o1xhack/CodexBar-Mobile/releases/tag/untagged-091dead320bd4660a6c2（`isDraft=true`，标题 `CodexBar 0.76.0.1 Mobile 2.9.0`，tag 名 `v0.76.0.1-mobile.2.9.0` 尚未创建，target 占位为 `mobile-dev`）。说明正文是根 CHANGELOG 的 fork 0.76.0.1 段。
- `CodexBar-0.76.0.1-mobile.2.9.0.zip`：88,967,383 bytes，SHA256 `f99b8b37ae42d293a832455f87b5fad7bd38750d04fb6b9421f2a35104a392a9`。
- `CodexBar-0.76.0.1-mobile.2.9.0.dSYM.zip`：71,583,011 bytes，SHA256 `b72a0baf86fb2850208dbd025c9f96c442bed121d8f0c51367f0f07be1c253d6`。
- 本地 SHA256 与 GitHub asset digest 一致。没有创建 tag，没有推送分支，`appcast.xml` 与 mobile-dev 相同。

## 实际包验证

从发行 ZIP 解包（`$S/verify-zip`）：
- 架构 `x86_64 arm64`；
- `codesign --verify --deep --strict`：valid on disk，satisfies its Designated Requirement；
- Gatekeeper：`source=Notarized Developer ID`，`Developer ID Application: Yuxiao Wang (3TUERHN53E)`；
- `stapler validate`：The validate action worked；
- entitlements：`com.apple.developer.icloud-container-environment = Production`，容器 `iCloud.com.o1xhack.codexbar`，没有 `aps-environment`；
- `Contents/embedded.provisionprofile` 存在。

## 公开发布前还需要（需另行授权）

1. push 分支并开 PR → Codex Code Review 循环直到当前 head clean → `Scripts/check_pr_review_gate.sh <pr>` → merge 到 mobile-dev。（2026-10-16 已获授权执行：PR [#194](https://github.com/o1xhack/CodexBar-Mobile/pull/194)。）
2. 如果 review 修改改动了 Mac 二进制的输入，删除这个 Draft 后从合并后的 mobile-dev 重新生成；否则按脚本输出的步骤在 mobile-dev 上打 tag、push tag，并把 Draft 的 target 改到 reviewed commit。
3. 合并后 Final CI 通过、用户 QA 通过 → `./Scripts/release.sh --finalize`（公开发布 + 签名 appcast + push）。
4. 公开发布后回复并关闭 #193（以及 monitor 为 v0.76.0 自动创建的 issue）；iOS 2.9.0 (242) 的 TestFlight 与送审另行授权（2.8.0 仍在审核中，MOBILE_VERSION/tag 已指向 2.9.0，发布顺序需注意）。
