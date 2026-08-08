# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is `cc-statusline`, a CLI tool that installs a custom status line for Claude Code. It displays model info, context usage percentage, session duration, CPU utilization, repository name, git branch, and code change stats.

## Architecture

The project consists of two components:

- **`bin/install.js`** — Node.js entry point and install script. Copies `bin/statusline.sh` to `~/.claude/statusline.sh`, backs up any existing status line, and writes the `statusLine` config into `~/.claude/settings.json`.
- **`bin/statusline.sh`** — Bash script that receives JSON via stdin (from Claude Code's status line hook), parses it with `jq`, and renders colored output. Supports three themes (`classic`, `matrix`, `ocean`) controlled by the `THEME` variable in the script, overridable via the `CC_STATUSLINE_THEME` environment variable (survives reinstalls).

Behavior notes for `bin/statusline.sh`:

- Context window size resolution priority: **model-name mapping in `get_model_context_window()` > JSON-provided `context_window_size` > 200k default**. The mapping returns 0 for unknown models — do not give it a nonzero catch-all, or the JSON branch becomes dead code. Claude models intentionally have no mapping entry (native Claude Code reports the accurate value; 200k fallback matches the standard window).
- Number formatting in `format_number()` uses binary units only when the value is a multiple of 1024 but not of 1000 (262144→256k; 256000→256k decimal).
- CPU segment reads Linux `/proc/stat` and is hidden when unreadable (macOS). The cache lives in a per-user 700-mode dir under `${TMPDIR:-/tmp}`.

### Model context-window mapping conventions

The mapping lives in `get_model_context_window()` in `bin/statusline.sh` and is mirrored as the table in `README.md`:

- **Substring globs, case-insensitive.** The model name is lowercased, then matched with globs, so `*qwen3.8-max*)` matches any name containing `qwen3.8-max` — `qwen3.8-max`, `qwen3.8-max-preview`, dated builds, etc. Prefer one broad pattern per family; do **not** add entries for variants the broad pattern already covers.
- **Specific-before-broad only when the window differs.** Bash `case` is first-match-wins. If a variant maps to a *different* window than its family, list it above the broader pattern: `*k3-256k*)` (256k) before `*k3*)` (1M), `*gpt-5.6*)` / `*gpt-5.5*)` before `*gpt-5*)` (400k), `*kimi-k2.7-code-highspeed*)` before `*kimi-k2.7-code*)`.
- **`[1m]` suffix override.** Claude Code appends `[1m]` to model IDs for 1M-context models (e.g. `deepseek-v4-flash[1m]`). The `*\[1m\]*)` pattern sits at the top of the case and forces any `[1m]`-suffixed name to 1M — so a base name that maps to a smaller window still reads as 1M when suffixed (e.g. `glm-5.1[1m]`). It is generic, not a per-family entry, so it has no README table row.
- **Raw token counts with a readable comment.** Values are raw tokens (`1048576`, `204800`) annotated with the display form (`# 1M`, `# 204.8k`).
- **`*)` returns 0** (no nonzero catch-all — see the resolution-priority note above), and Claude gets no entry.
- **Keep the README table in sync.** README rows group patterns by family (comma-separated representative names plus variant annotations like `(+ -highspeed variants)`, `(legacy)`), not one row per pattern. When a pattern is added, merged, or renamed, update the matching README row in the same change.

No build step, no bundler, no transpilation. The npm package is published as-is.

## Dependencies

- `jq` — JSON parsing in the status line script
- `git` — branch and diff stats in the status line script
- `bash` — required on Windows (ships with Git for Windows); preinstalled on macOS/Linux

## Development Commands

There is no test suite, no linter, no build process. Relevant commands:

- **Test install locally:** `node bin/install.js`
- **Uninstall:** `node bin/install.js --uninstall`
- **Test the status line script manually:** `echo '{"model":{"display_name":"test"}}' | bash bin/statusline.sh`

## Release Process

Publishing is automated via GitHub Actions (`.github/workflows/publish.yml`):

1. Create and push a git tag:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
2. The workflow updates the `package.json` version from the tag and publishes to the public npm registry (requires an `NPM_TOKEN` repository secret).

Install via npx:

```bash
npx @zlemon317/cc-statusline
```

## Key Files

- `.github/workflows/publish.yml` — GitHub Actions workflow for npm publishing on tag push
- `package.json` — npm package metadata
- `bin/install.js` — install/uninstall logic and dependency checks
- `bin/statusline.sh` — the actual status line renderer (bash + jq)
