#!/usr/bin/env bash
# Status line script for Claude Code showing model, context, and token usage
# 支持主题配色 - 修改 THEME 变量来切换主题

# ==========================================
# 主题选择 - 修改这里来切换配色方案
# 可用主题: classic, matrix, ocean
# ==========================================
THEME="${CC_STATUSLINE_THEME:-classic}"  # &lt;-- 修改这里切换主题，或设置 CC_STATUSLINE_THEME 环境变量

# ==========================================
# 颜色主题定义
# ==========================================

# Theme colors
set_theme_colors() {
    case "$THEME" in
        matrix)
            COLOR_MODEL="32"      # green
            COLOR_EFFORT="92"     # bright green
            COLOR_THINKING="32"   # green
            COLOR_CONTEXT_LOW="32"  # green (same as classic)
            COLOR_CONTEXT_MED="33"  # yellow (same as classic)
            COLOR_CONTEXT_HIGH="31" # red (same as classic)
            COLOR_DURATION="92"     # bright green
            COLOR_CPU="92"          # bright green
            ;;
        ocean)
            COLOR_MODEL="36"      # cyan
            COLOR_EFFORT="94"     # bright blue
            COLOR_THINKING="96"   # bright cyan
            COLOR_CONTEXT_LOW="36"  # cyan
            COLOR_CONTEXT_MED="33"  # yellow
            COLOR_CONTEXT_HIGH="31" # red
            COLOR_DURATION="94"     # bright blue
            COLOR_CPU="94"          # bright blue
            ;;
        *) # classic - default
            COLOR_MODEL="94"    # bright blue
            COLOR_EFFORT="36"   # cyan
            COLOR_THINKING="35" # magenta
            COLOR_CONTEXT_LOW="32"  # green
            COLOR_CONTEXT_MED="33"   # yellow
            COLOR_CONTEXT_HIGH="31"  # red
            COLOR_DURATION="36"      # cyan
            COLOR_CPU="36"           # cyan
            ;;
    esac
    COLOR_GRAY="90" # gray for prefixes
}

# Apply theme
set_theme_colors

# ==========================================
# 主脚本逻辑
# ==========================================

# Read JSON input
input=$(cat)

# Extract all fields in one jq call
OLDIFS="$IFS"
IFS=$'\t' read -r model effort thinking used_percent context_window_size context_total_input context_total_output session_duration cwd < <(
    echo "$input" | jq -r '[
        (.model.display_name // .model.id // "model"),
        (.effort.level // "-"),
        (.thinking.enabled // false),
        (.context_window.used_percentage // .context.used_percent // .usage.context_used_percent // 0),
        (.context_window.context_window_size // 0),
        (.context_window.total_input_tokens // 0),
        (.context_window.total_output_tokens // 0),
        (.cost.total_duration_ms // 0),
        (.workspace.current_dir // .cwd // "")
    ] | @tsv' | tr -d '\r'
)
IFS="$OLDIFS"
# Restore placeholder for empty effort (Bash read swallows empty TSV fields)
[ "$effort" = "-" ] && effort=""
[[ "$context_total_input" =~ ^[0-9]+$ ]] || context_total_input=0
[[ "$context_total_output" =~ ^[0-9]+$ ]] || context_total_output=0
context_used=$((context_total_input + context_total_output))

# context_pct is recalculated below from actual usage vs actual window size
context_pct=0

# CPU utilization measurement using /proc/stat with temp file caching
# Uses deltas between successive calls to compute near-instantaneous CPU usage
get_cpu_usage() {
    local tmp_file cpu_user cpu_nice cpu_system cpu_idle cpu_iowait cpu_irq cpu_softirq cpu_steal
    local cpu_total cpu_used cpu_usage prev_used prev_total cpu_used_diff cpu_total_diff

    # /proc/stat is Linux-only; bail out on macOS so the caller can hide the segment
    [ -r /proc/stat ] || return 1

    tmp_file="/tmp/claude-statusline-cpu.${USER:-default}.tmp"

    read -r _ cpu_user cpu_nice cpu_system cpu_idle cpu_iowait cpu_irq cpu_softirq cpu_steal _ < /proc/stat

    cpu_total=$(( ${cpu_user:-0} + ${cpu_nice:-0} + ${cpu_system:-0} + ${cpu_idle:-0} + ${cpu_iowait:-0} + ${cpu_irq:-0} + ${cpu_softirq:-0} + ${cpu_steal:-0} ))
    cpu_used=$(( ${cpu_user:-0} + ${cpu_nice:-0} + ${cpu_system:-0} + ${cpu_irq:-0} + ${cpu_softirq:-0} + ${cpu_steal:-0} ))

    if [ -f "$tmp_file" ] && read -r prev_used prev_total < "$tmp_file" 2>/dev/null; then
        cpu_used_diff=$((cpu_used - prev_used))
        cpu_total_diff=$((cpu_total - prev_total))
        cpu_usage=$(( cpu_total_diff > 0 ? (cpu_used_diff * 100) / cpu_total_diff : 0 ))
    else
        cpu_usage=0
    fi

    echo "$cpu_used $cpu_total" > "$tmp_file"
    printf "%d" "$cpu_usage"
}


# Map model name to its context window size (in tokens)
# Returns 0 for unknown models so the caller can fall back to the
# JSON-provided value, then to a 200k default
# Priority: model name map > JSON-provided value > 200k default
get_model_context_window() {
    local model_lower
    model_lower=$(echo "$1" | tr '[:upper:]' '[:lower:]')

    case "$model_lower" in
        # Qwen series
        *qwen3.8-max-preview*)      printf "1048576" ;; # 1M
        *qwen3.7-max*)              printf "1048576" ;; # 1M
        *qwen3.7-plus*)             printf "1048576" ;; # 1M
        *qwen3.6-plus*)             printf "1048576" ;; # 1M
        *qwen3.6-flash*)            printf "1048576" ;; # 1M
        # DeepSeek series
        *deepseek-v4-pro*)          printf "1048576" ;; # 1M
        *deepseek-v4-flash*)        printf "1048576" ;; # 1M
        *deepseek-v3.2*)            printf "131072" ;; # 128k
        # GLM series
        *glm-5.2*)                  printf "1048576" ;; # 1M
        *glm-5.1*)                  printf "204800"  ;; # 200k
        *glm-5*)                    printf "204800"  ;; # 200k
        # Kimi series
        *k3-256k*)                  printf "262144" ;; # 256k
        *k3*)                       printf "1048576" ;; # 1M
        *kimi-k3*)                  printf "1048576" ;; # 1M
        *k3[[]1m[]]*)               printf "1048576" ;; # 1M (k3[1m] variant)
        *kimi-k2.7-code-highspeed*) printf "262144" ;;  # 256k
        *kimi-k2.7-code*)           printf "262144" ;;  # 256k
        *kimi-k2.6*)                printf "262144" ;;  # 256k
        *kimi-k2.5*)                printf "262144" ;;  # 256k
        *kimi-for-coding-highspeed*) printf "262144" ;; # 256k
        *kimi-for-coding*)          printf "262144" ;;  # 256k
        *kimi*)                     printf "131072" ;;  # 128k (legacy fallback)
        # MiniMax series
        *minimax-m3*)               printf "1048576" ;; # 1M
        *minimax*)                  printf "204800"  ;; # 204.8k (M2 / M2.5 / M2.7)
        # OpenAI series
        *gpt-5.5*)                  printf "1048576" ;; # 1M
        *gpt-5*)                    printf "400000"  ;; # 400k (5 Pro / 5.1 / 5.3 / 5.4 Codex)
        *gpt-4.1*)                  printf "1048576" ;; # 1M
        *gpt-4*)                    printf "131072"  ;; # 128k (4o / 4-turbo)
        # Google series
        *gemini*)                   printf "1048576" ;; # 1M (Gemini 3 / 3.1 family)
        # xAI series
        *grok-4.1-fast*)            printf "2000000" ;; # 2M
        *grok-4.20*)                printf "2000000" ;; # 2M
        *grok-4.5*)                 printf "500000"  ;; # 500k
        *grok*)                     printf "256000"  ;; # 256k (Grok 4)
        # Claude: intentionally no entry — native Claude Code provides an accurate
        # context_window_size in JSON (200k standard / 1M beta); the 200k fallback
        # below covers gateway usage without a JSON value.
        # No match: return 0 so the caller falls back to the JSON-provided value,
        # then to the 200k default
        *)                          printf "0" ;;
    esac
}

# Determine context window size: model-name mapping > JSON value > 200k default
model_window=$(get_model_context_window "$model")
if [ "$model_window" -gt 0 ] 2>/dev/null; then
    context_window_size="$model_window"
elif [ "$context_window_size" -gt 0 ] 2>/dev/null; then
    : # use JSON-provided value as-is
else
    context_window_size=200000  # default 200k
fi

# Recalculate context percentage from actual usage vs actual window size
# This fixes the bug where JSON's used_percent was calculated with a wrong denominator
if [ "$context_window_size" -gt 0 ] 2>/dev/null && [ "$context_used" -gt 0 ] 2>/dev/null; then
    context_pct=$(( (context_used * 100) / context_window_size ))
fi
[[ "$context_pct" =~ ^[0-9]+$ ]] || context_pct=0
if [ "$context_pct" -lt 0 ] 2>/dev/null; then
    context_pct=0
elif [ "$context_pct" -gt 100 ] 2>/dev/null; then
    context_pct=100
fi

# Format number
# Binary units when the value is an exact multiple of 1024 (131072→128k,
# 204800→200k, 262144→256k, 1048576→1M); decimal otherwise (400000→400k,
# 500000→500k, 2000000→2M)
format_number() {
    local num=$1
    if ! [[ "$num" =~ ^[0-9]+$ ]]; then num=0; fi
    local base=1000
    if [ "$num" -gt 0 ] && [ $((num % 1024)) -eq 0 ]; then base=1024; fi
    if [ "$num" -ge $((base * base)) ]; then
        local millions=$((num / (base * base) ))
        local fraction=$(((num % (base * base)) / (base * base / 10) ))
        if [ "$fraction" -eq 0 ]; then
            printf "%dM" "$millions"
        else
            printf "%d.%dM" "$millions" "$fraction"
        fi
    elif [ "$num" -ge "$base" ]; then
        local thousands=$((num / base))
        local fraction=$(((num % base) / (base / 10) ))
        if [ "$fraction" -eq 0 ]; then
            printf "%dk" "$thousands"
        else
            printf "%d.%dk" "$thousands" "$fraction"
        fi
    else
        printf "%d" "$num"
    fi
}

# Simple progress bar
num_blocks=$((context_pct / 10))
bar=""
for ((i=0; i<10; i++)); do
    if [ "$i" -lt "$num_blocks" ]; then
        bar="$bar█"
    else
        bar="$bar░"
    fi
done

# Choose context color
context_color="$COLOR_CONTEXT_LOW"
if [ "$context_pct" -ge 85 ]; then
    context_color="$COLOR_CONTEXT_HIGH"
elif [ "$context_pct" -ge 70 ]; then
    context_color="$COLOR_CONTEXT_MED"
fi

# Format duration from ms to readable string
format_duration() {
    local ms=$1
    if ! [[ "$ms" =~ ^[0-9]+$ ]]; then ms=0; fi
    local seconds=$((ms / 1000))
    local minutes=$((seconds / 60))
    local hours=$((minutes / 60))
    seconds=$((seconds % 60))
    minutes=$((minutes % 60))

    if [ "$hours" -gt 0 ]; then
        printf "%dh%dm" "$hours" "$minutes"
    elif [ "$minutes" -gt 0 ]; then
        printf "%dm%ds" "$minutes" "$seconds"
    else
        printf "%ds" "$seconds"
    fi
}

# Get current directory name
dir_name=$(basename "$cwd" 2>/dev/null || echo "")

# Get git info if available
git_branch=""
git_added=0
git_removed=0
repo_name=""
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    # Repo name from git remote URL, fallback to git root directory name
    repo_name=$(basename "$(git -C "$cwd" remote get-url origin 2>/dev/null)" .git 2>/dev/null)
    [ -z "$repo_name" ] && repo_name=$(basename "$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null)
    # Branch name
    git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
    # Added/removed lines from git diff --numstat (tracked files)
    while read -r added removed file; do
        [ "$added" = "-" ] && added=0
        [ "$removed" = "-" ] && removed=0
        [[ "$added" =~ ^[0-9]+$ ]] || added=0
        [[ "$removed" =~ ^[0-9]+$ ]] || removed=0
        git_added=$((git_added + added))
        git_removed=$((git_removed + removed))
    done <<EOF
$(git -C "$cwd" diff --numstat HEAD 2>/dev/null)
EOF
    # Add untracked files (new files)
    while IFS= read -r file; do
        [ ! -f "$cwd/$file" ] && continue
        # Count lines in new file
        lines=$(wc -l < "$cwd/$file" 2>/dev/null || echo 0)
        git_added=$((git_added + lines))
    done <<EOF
$(git -C "$cwd" ls-files --others --exclude-standard 2>/dev/null)
EOF
    unset -v added removed file lines
fi


# First line: model (effort, thinking) | ◼ workdir | ⌥ branch
printf "\033[%sm✦\033[0m \033[%sm%s\033[0m" "$COLOR_GRAY" "$COLOR_MODEL" "$model"

# Build effort/thinking part in parentheses
effort_thinking=""
if [ -n "$effort" ] && [ "$thinking" = "true" ]; then
    effort_thinking="(\033[${COLOR_EFFORT}m${effort}\033[0m, \033[${COLOR_THINKING}mthinking\033[0m)"
elif [ -n "$effort" ]; then
    effort_thinking="(\033[${COLOR_EFFORT}m${effort}\033[0m)"
elif [ "$thinking" = "true" ]; then
    effort_thinking="(\033[${COLOR_THINKING}mthinking\033[0m)"
fi

if [ -n "$effort_thinking" ]; then
    printf " %b" "$effort_thinking"
fi

need_sep=1
if [ -n "$cwd" ]; then
    [ "$need_sep" -eq 1 ] && printf " \033[%sm|\033[0m" "$COLOR_GRAY"
    printf " \033[%sm◼\033[0m \033[37m%s\033[0m" "$COLOR_GRAY" "$cwd"
    need_sep=1
fi

if [ -n "$repo_name" ]; then
    [ "$need_sep" -eq 1 ] && printf " \033[%sm|\033[0m" "$COLOR_GRAY"
    printf " \033[%sm⎔\033[0m \033[37m%s\033[0m" "$COLOR_GRAY" "$repo_name"
    need_sep=1
fi

if [ -n "$git_branch" ]; then
    [ "$need_sep" -eq 1 ] && printf " \033[%sm|\033[0m" "$COLOR_GRAY"
    printf " \033[%sm⌥\033[0m \033[37m%s\033[0m" "$COLOR_GRAY" "$git_branch"
    need_sep=1
fi
printf "\n"

# Second line: Context progress | Duration | CPU | Changes
printf "\033[%sm◔\033[0m Context: \033[%sm%s\033[0m \033[%sm%d%%\033[0m" "$COLOR_GRAY" "$context_color" "$bar" "$context_color" "$context_pct"


if [ "$context_window_size" -gt 0 ] 2>/dev/null; then
    printf " \033[%sm(%s/%s)\033[0m" "$COLOR_GRAY" "$(format_number "$context_used")" "$(format_number "$context_window_size")"
fi

printf " \033[%sm|\033[0m \033[%sm◷\033[0m Duration: \033[%sm%s\033[0m" \
    "$COLOR_GRAY" "$COLOR_GRAY" "$COLOR_DURATION" "$(format_duration "$session_duration")"

# CPU utilization (hidden on platforms without /proc/stat, e.g. macOS)
if cpu_pct=$(get_cpu_usage); then
    printf " \033[%sm|\033[0m \033[%sm▣\033[0m CPU: \033[%sm%d%%\033[0m" \
        "$COLOR_GRAY" "$COLOR_GRAY" "$COLOR_CPU" "$cpu_pct"
fi

if [ "$git_added" -gt 0 ] || [ "$git_removed" -gt 0 ]; then
    printf " \033[%sm|\033[0m \033[%smΔ\033[0m Changes:" "$COLOR_GRAY" "$COLOR_GRAY"
    [ "$git_added" -gt 0 ] && printf " \033[32m+%d\033[0m" "$git_added"
    [ "$git_removed" -gt 0 ] && printf " \033[31m-%d\033[0m" "$git_removed"
fi
printf "\n"
