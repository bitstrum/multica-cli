# Multica CLI Skill

> 为 [Multica](https://github.com/multica-ai/multica) 打造 —— 一个开源的、用于运行和管理编码 agent 的可复用 skill 平台。

一个可移植的 skill，教任意本地编码 agent（Claude Code、Codex、Cursor 等）通过已认证的
`multica` CLI 操作 [Multica](https://github.com/multica-ai/multica)：读取与
triage issue、安全地回复评论、管理 metadata，以及处理 mention / status 等副作用。

[English](./README.md) | 简体中文

## 它不会做什么

本仓库**本身不会**授予任何 Multica 访问权限。权限只来自用户本机已登录的 CLI、所选
profile、当前 workspace，以及对每条命令的显式授权。这个 skill 教的是「如何安全地」
操作 Multica，绝不会绕过 workspace 权限，也不会保存任何密钥。

## 覆盖范围

- 检查 CLI 登录、profile、workspace 状态（以及如何登录）
- 读取 issue、comment、metadata、label、自定义 property、subscriber、project、
  agent、squad、runtime、repo、skill、autopilot、attachment
- 跨标题、描述与评论正文搜索 issue
- 低成本地读评论历史 —— 线程扫描、`--compact`、已解决线程的折叠行为
- 用 `--content-file` 安全地写 issue 评论，含文件参数的工作目录限制
- 创建 / 更新 issue 和高价值 metadata
- 处理 mention、status、assignment、rerun、子 issue 等副作用，并用 `--no-start`
  避免误触发 agent run
- 查看 run 历史与 token 用量；在被要求时取消 run
- 把 pull request 关联回 Multica issue
- CLI 做不到的事直说，并指向 Multica Web，而不是假装已完成

## 安装

skill 位于 `skills/multica-cli/`，按你使用的工具选择安装方式。

### Claude Code（插件市场）

```text
/plugin marketplace add bitstrum/multica-cli
/plugin install multica-cli@multica-cli
```

skill 会跟随每个 Multica 版本更新，所以请让 Claude Code 自动拉取更新：在
`/plugin` → Marketplaces 中为 `multica-cli` 开启自动更新，或在
`~/.claude/settings.json` 中声明：

```json
"extraKnownMarketplaces": {
  "multica-cli": {
    "source": { "source": "github", "repo": "bitstrum/multica-cli" },
    "autoUpdate": true
  }
}
```

### Codex（skill 安装器）

```bash
install-skill-from-github.py --repo bitstrum/multica-cli --path skills/multica-cli
```

安装新 skill 后请重启 Codex。

### Cursor

把 skill 复制到你的 Cursor 个人 skills 目录：

```bash
mkdir -p ~/.cursor/skills/multica-cli
cp -R skills/multica-cli/* ~/.cursor/skills/multica-cli/
```

或者把项目规则 [`.cursor/rules/multica-cli.mdc`](.cursor/rules/multica-cli.mdc)
放进某个项目的 `.cursor/rules/` 目录。详见 [CURSOR.md](./CURSOR.md)。

### 其他 agent

把 [`skills/multica-cli/SKILL.md`](skills/multica-cli/SKILL.md) 复制到你的工具
加载 skill / 指令的位置即可。

## 前置条件

- 本机已安装 `multica` CLI，且 CLI 和 Multica 服务端版本都 **不低于 v0.6.0**。skill
  始终描述最新版本，并把 v0.6.0 之后新增的内容标注为引入它的版本，例如 `(v0.10.0+)`。
  agent 会检查 CLI（`multica version`）和服务端（其公开的 `/api/config`；Multica Cloud
  始终运行最新版本），只使用两者中较旧一方支持的功能，并告诉你升级后能用什么。
- 用户已通过 `multica login`（或 `multica setup`）完成认证。
- 已选择目标 workspace / profile，或通过 `--workspace-id`、`--profile` 显式传入。

## 用法

安装后，让你的 agent 操作 Multica，例如：

```text
用 multica CLI 读一下 MUL-123，帮我起草一条回复让我 review。
```

对于写操作（评论、状态变更、mention、新建 issue），除非用户已经明确授权这个具体动作，
否则 agent 应在改动状态前先确认。更多示例见 [EXAMPLES.md](./EXAMPLES.md)。

## 参与开发

这个 skill 只有在与它所描述的 CLI 保持一致时才有价值，所以文档会对着真实的
`multica` 二进制做 lint：

```bash
scripts/lint-skill-commands.py              # 对照 PATH 上的 multica；加 --verbose 可看到每一条检查
scripts/lint-skill-commands.py --versions   # 最低版本以及标注中出现的每个版本
```

当文档里写的命令或 flag 在其标注版本（或最低版本）中不存在、或者最新 CLI 里有
`SKILL.md` 从未提及的命令时，lint 会失败。新增功能请加版本标注（正文里写
`(vX.Y.Z+)`，代码块里写 `# vX.Y.Z+`），而不是提高最低版本；有意不写的部分请加进
该脚本的 `UNDOCUMENTED_OK` 并注明原因。

CI 在每次 push 和 pull request 时，对最低版本、每个标注版本和最新版本运行 lint。每日
定时任务检查最新版本：新版本增加或修改命令时，它会创建或更新一个 `cli-drift` issue，
而不是让运行失败。

agent 提交的 PR 在所有检查通过后会自动合并，所以仓库所有者以外的 PR 还必须通过：

- `scripts/check-pr-scope.py`：只能改文档、manifest 和 lint 脚本中的 `UNDOCUMENTED_OK`
  区域（不能改 CI、测试、eval 或最低版本）；标注不高于最新版本；不删除 SKILL.md 的标题；
  插件版本号已提升。
- `scripts/run-evals.sh`：`evals/` 中的行为 eval（用 `claude plugin eval` 对着一个
  stub `multica` 运行，不会接触任何服务端），例如“读取 inbox 不改变任何状态”和
  “删除时绝不擅自加 `--yes`”。
- `scripts/check-claims.sh`：由 LLM 检查 PR 新增的每条行为描述都有 CLI `--help` 支持。

## 许可证

[MIT](./LICENSE)
