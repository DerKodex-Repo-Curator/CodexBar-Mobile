# Mac 0.76.0.1 签名、公证与 Draft

Status: `in-progress`
Date: 2026-10-15

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

（待填：在 Mac 全量测试、lint 与 review 清零之后执行。）
