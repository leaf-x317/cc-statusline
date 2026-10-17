# cc-statusline

[![npm version](https://img.shields.io/npm/v/@zlemon317/cc-statusline)](https://www.npmjs.com/package/@zlemon317/cc-statusline)
[![npm downloads](https://img.shields.io/npm/dm/@zlemon317/cc-statusline)](https://www.npmjs.com/package/@zlemon317/cc-statusline)
[![license](https://img.shields.io/npm/l/@zlemon317/cc-statusline)](LICENSE)

A custom status line for Claude Code — shows model name, context usage, session duration, CPU utilization, repo name, git branch, and code change stats at a glance.

[中文说明](#中文说明)

classic theme:

![classic theme](assets/theme-classic.png)

matrix theme:

![matrix theme](assets/theme-matrix.png)

ocean theme:

![ocean theme](assets/theme-ocean.png)

## Features

- Current model name
- Model effort level and thinking mode status
- Context usage percentage with progress bar
- Context usage measured against the window Claude Code actually uses (1M for `[1m]`-suffixed model IDs, 200k otherwise)
- Session duration
- CPU utilization (Linux, including WSL; hidden on macOS and native Windows, which lack `/proc/stat`)
- Current working directory and repository name
- Git branch
- Code change stats (added / removed lines)
- Switchable themes (classic / matrix / ocean)

## Installation

### Via npx (recommended)

```bash
npx @zlemon317/cc-statusline@latest
```

### Global install

```bash
# 1. Install the package
npm install -g @zlemon317/cc-statusline

# 2. Run the setup script
cc-statusline
```

The installer copies the status line script to `~/.claude/statusline.sh` (backing up any existing one) and writes the `statusLine` config into `~/.claude/settings.json`.

## Uninstall

```bash
npx @zlemon317/cc-statusline@latest --uninstall
```

Restores your previous status line from backup (or removes it) and cleans up `settings.json`.

## Dependencies

- `jq` — JSON processing (`apt install jq` / `yum install jq` / `brew install jq` / `winget install jqlang.jq`)
- `git` — branch and diff stats
- `bash` — required on Windows (ships with [Git for Windows](https://git-scm.com/download/win)); preinstalled on macOS/Linux

> **Windows note:** the installer locates `bash`, `jq`, and `git` via your `PATH`. Git for Windows' default setup only adds `Git\cmd` to `PATH`, which contains `git.exe` but **not** `bash.exe` — add `Git\usr\bin` to your `PATH` as well. After installing dependencies or editing `PATH`, open a **new** terminal window before running the installer (existing windows keep the old `PATH`).

## Themes

Edit `~/.claude/statusline.sh` and change the `THEME` variable:

```bash
THEME="classic"  # classic theme (blue)
THEME="matrix"   # matrix theme (green)
THEME="ocean"    # ocean theme (cyan)
```

Or set the `CC_STATUSLINE_THEME` environment variable — it survives reinstalls. Add it to the `env` section of `~/.claude/settings.json`:

```json
"env": {
  "CC_STATUSLINE_THEME": "matrix"
}
```

## Sample output

```
✦ kimi-k3 (high, thinking) | ◼ /workspace | ⎔ cc-statusline | ⌥ main
◔ Context: ████████░░ 82% (165k/200k) | ◷ Duration: 5m32s | ▣ CPU: 23% | Δ +128 -45
```

## Context window

Claude Code determines the context window itself and reports it in the status line JSON as `context_window_size`: models whose ID carries the `[1m]` suffix get 1M tokens, everything else defaults to 200k. The status line uses that value as-is, so its percentage always matches the window Claude Code actually compacts against. There is no model-name mapping table to maintain.

`[1m]` is a suffix Claude Code appends to the model ID for 1M-context models (e.g. `deepseek-v4-flash[1m]`) — it is not a separate model ID. If `context_window_size` is missing, the script applies the same rule as a fallback: `[1m]` suffix → 1M, otherwise → 200k.

## Releasing

Publishing is automated via GitHub Actions (`.github/workflows/publish.yml`):

```bash
git tag v1.0.0
git push origin v1.0.0
```

The workflow syncs the `package.json` version from the tag and publishes to the public npm registry (requires an `NPM_TOKEN` repository secret).

## License

[MIT](LICENSE)

---

## 中文说明

Claude Code 自定义状态行工具，实时展示模型名称、上下文使用率、会话时长、CPU 使用率、代码仓库、Git 分支与代码变更统计等。

### 安装

```bash
npx @zlemon317/cc-statusline@latest
```

### 卸载

```bash
npx @zlemon317/cc-statusline@latest --uninstall
```

### 依赖

- `jq` - JSON 处理工具（`apt install jq` / `yum install jq` / `brew install jq` / `winget install jqlang.jq`）
- `git` - 版本控制工具
- `bash` - 仅 Windows 需要（随 [Git for Windows](https://git-scm.com/download/win) 提供）；macOS/Linux 已预装

> **Windows 提示：** 安装程序通过 `PATH` 查找 `bash`、`jq`、`git`。Git for Windows 默认安装只把 `Git\cmd` 加入 `PATH`（其中有 `git.exe` 但**没有** `bash.exe`），需手动将 `Git\usr\bin` 也加入 `PATH`。安装依赖或修改 `PATH` 后，请**重新打开终端窗口**再运行安装程序（已打开的窗口仍使用旧的 `PATH`）。

### 主题配置

编辑 `~/.claude/statusline.sh` 文件，修改 `THEME` 变量：

```bash
THEME="classic"  # 经典主题（蓝色系）
THEME="matrix"   # 矩阵主题（绿色系）
THEME="ocean"    # 海洋主题（青色系）
```

也可以设置 `CC_STATUSLINE_THEME` 环境变量——重装不会丢失。在 `~/.claude/settings.json` 的 `env` 中添加：

```json
"env": {
  "CC_STATUSLINE_THEME": "matrix"
}
```

### 示例输出

```
✦ kimi-k3 (high, thinking) | ◼ /workspace | ⎔ cc-statusline | ⌥ main
◔ Context: ████████░░ 82% (165k/200k) | ◷ Duration: 5m32s | ▣ CPU: 23% | Δ +128 -45
```

### 上下文窗口

Claude Code 会自行判定上下文窗口，并通过状态行 JSON 的 `context_window_size` 上报：模型 ID 带 `[1m]` 后缀（如 `deepseek-v4-flash[1m]`）时为 1M，其余默认 200k。状态行直接使用该值，因此显示的百分比与 Claude Code 实际压缩所依据的窗口一致，无需维护模型名映射表。

若 JSON 未提供 `context_window_size`，脚本按同样的规则兜底：带 `[1m]` 后缀 → 1M，否则 → 200k。

### 许可证

[MIT](LICENSE)
