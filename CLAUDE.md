# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is `cc-statusline`, a CLI tool that installs a custom status line for Claude Code. It displays model info, context usage percentage, session duration, CPU utilization, repository name, git branch, and code change stats.

## Architecture

The project consists of two components:

- **`bin/install.js`** — Node.js entry point and install script. Copies `bin/statusline.sh` to `~/.claude/statusline.sh`, backs up any existing status line, and writes the `statusLine` config into `~/.claude/settings.json`.
- **`bin/statusline.sh`** — Bash script that receives JSON via stdin (from Claude Code's status line hook), parses it with `jq`, and renders colored output. Supports three themes (`classic`, `matrix`, `ocean`) controlled by the `THEME` variable in the script.

No build step, no bundler, no transpilation. The npm package is published as-is.

## Dependencies

- `jq` — JSON parsing in the status line script
- `git` — branch and diff stats in the status line script

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
npx cc-statusline
```

## Key Files

- `.github/workflows/publish.yml` — GitHub Actions workflow for npm publishing on tag push
- `package.json` — npm package metadata
- `bin/install.js` — install/uninstall logic and dependency checks
- `bin/statusline.sh` — the actual status line renderer (bash + jq)
