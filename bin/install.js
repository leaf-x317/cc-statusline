#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const os = require('os');

const CLAUDE_DIR = path.join(os.homedir(), '.claude');
const SETTINGS_FILE = path.join(CLAUDE_DIR, 'settings.json');
const STATUSLINE_DEST = path.join(CLAUDE_DIR, 'statusline.sh');
const STATUSLINE_SRC = path.resolve(__dirname, 'statusline.sh');

const blue = '\x1b[38;2;0;153;255m';
const green = '\x1b[38;2;0;175;80m';
const red = '\x1b[38;2;255;85;85m';
const yellow = '\x1b[38;2;230;200;0m';
const dim = '\x1b[2m';
const reset = '\x1b[0m';

function log(msg) {
  console.log(`  ${msg}`);
}

function success(msg) {
  console.log(`  ${green}✓${reset} ${msg}`);
}

function warn(msg) {
  console.log(`  ${yellow}!${reset} ${msg}`);
}

function fail(msg) {
  console.error(`  ${red}✗${reset} ${msg}`);
}

function checkDeps() {
  const { execSync } = require('child_process');
  const missing = [];

  try {
    execSync('which jq', { stdio: 'ignore' });
  } catch {
    missing.push('jq');
  }

  try {
    execSync('which git', { stdio: 'ignore' });
  } catch {
    missing.push('git');
  }

  return missing;
}

function uninstall() {
  console.log();
  console.log(`  ${blue}Claude Statusline 卸载程序${reset}`);
  console.log(`  ${dim}─────────────────────────────${reset}`);
  console.log();

  // Validate settings.json before any file operations to avoid half-cleaned state
  if (fs.existsSync(SETTINGS_FILE)) {
    try {
      JSON.parse(fs.readFileSync(SETTINGS_FILE, 'utf-8'));
    } catch {
      fail(`无法解析 ${SETTINGS_FILE} — 请手动修复`);
      throw new Error('Settings parse failed');
    }
  }

  const backup = STATUSLINE_DEST + '.bak';

  if (fs.existsSync(backup)) {
    fs.copyFileSync(backup, STATUSLINE_DEST);
    fs.unlinkSync(backup);
    success(`已从 ${dim}statusline.sh.bak${reset} 恢复之前的 statusline`);
  } else if (fs.existsSync(STATUSLINE_DEST)) {
    fs.unlinkSync(STATUSLINE_DEST);
    success(`已删除 ${dim}statusline.sh${reset}`);
  } else {
    warn('未找到 statusline — 无需删除');
  }

  if (fs.existsSync(SETTINGS_FILE)) {
    const settings = JSON.parse(fs.readFileSync(SETTINGS_FILE, 'utf-8'));
    if (settings.statusLine) {
      delete settings.statusLine;
      fs.writeFileSync(SETTINGS_FILE, JSON.stringify(settings, null, 2) + '\n');
      success(`已从 ${dim}settings.json${reset} 移除 statusLine 配置`);
    } else {
      success('配置文件已清理');
    }
  }

  console.log();
  log(`${green}完成!${reset} 重启 Claude Code 以应用更改。`);
  console.log();
}

function run() {
  if (process.argv.includes('--uninstall')) {
    uninstall();
    return;
  }

  console.log();
  console.log(`  ${blue}Claude Statusline 安装程序${reset}`);
  console.log(`  ${dim}───────────────────────────${reset}`);
  console.log();

  const missing = checkDeps();
  if (missing.length > 0) {
    fail(`缺少必要的依赖: ${missing.join(', ')}`);
    log(`  请安装后重试。`);
    if (missing.includes('jq')) {
      log(`  ${dim}apt install jq${reset} 或 ${dim}yum install jq${reset}`);
    }
    throw new Error('Missing dependencies');
  }
  success('依赖检查通过 (jq, git)');

  if (!fs.existsSync(CLAUDE_DIR)) {
    fs.mkdirSync(CLAUDE_DIR, { recursive: true });
    success(`创建目录 ${CLAUDE_DIR}`);
  }

  if (!fs.existsSync(STATUSLINE_SRC)) {
    fail(`源文件不存在: ${STATUSLINE_SRC}`);
    throw new Error('Source file not found');
  }

  const backup = STATUSLINE_DEST + '.bak';
  if (fs.existsSync(STATUSLINE_DEST)) {
    if (!fs.existsSync(backup)) {
      fs.copyFileSync(STATUSLINE_DEST, backup);
      warn(`已备份现有 statusline 到 ${dim}statusline.sh.bak${reset}`);
    } else {
      const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
      const timestampBackup = `${STATUSLINE_DEST}.${timestamp}.bak`;
      fs.copyFileSync(STATUSLINE_DEST, timestampBackup);
      warn(`已备份现有 statusline 到 ${dim}${path.basename(timestampBackup)}${reset}`);
    }
  }

  fs.copyFileSync(STATUSLINE_SRC, STATUSLINE_DEST);
  fs.chmodSync(STATUSLINE_DEST, 0o755);
  success(`安装 statusline 到 ${dim}${STATUSLINE_DEST}${reset}`);

  let settings = {};
  if (fs.existsSync(SETTINGS_FILE)) {
    try {
      settings = JSON.parse(fs.readFileSync(SETTINGS_FILE, 'utf-8'));
    } catch {
      fail(`无法解析 ${SETTINGS_FILE} — 请手动修复`);
      throw new Error('Settings parse failed');
    }
  }

  const statusLineConfig = {
    type: 'command',
    command: `bash "${STATUSLINE_DEST}"`,
  };

  if (
    settings.statusLine &&
    settings.statusLine.type === 'command' &&
    settings.statusLine.command === statusLineConfig.command
  ) {
    success('配置已存在');
  } else {
    settings.statusLine = statusLineConfig;
    fs.writeFileSync(SETTINGS_FILE, JSON.stringify(settings, null, 2) + '\n');
    success(`已更新 ${dim}settings.json${reset} 中的 statusLine 配置`);
  }

  console.log();
  log(`${green}安装完成!${reset} 重启 Claude Code 查看新的状态行。`);
  console.log();
}

if (require.main === module) {
  try {
    run();
  } catch (error) {
    process.exitCode = 1;
  }
}
