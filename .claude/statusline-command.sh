#!/bin/bash
# Claude Code statusline: context window usage + 5h/weekly rate-limit bars
#   + PR number (OSC 8 clickable) + CI status.
# PR/CI are derived from `gh` (NOT the stdin .pr field, which is absent in
# fork-based repos), fetched in the background and cached so we never block.
input=$(cat)

# ---- helpers ----
fmt_tokens() {
  # $1 = raw token count -> human readable (e.g. 1.0M, 128k)
  local n=$1
  if [ -z "$n" ] || [ "$n" = "null" ]; then echo "0"; return; fi
  awk -v n="$n" 'BEGIN {
    if (n >= 1000000) printf "%.1fM", n/1000000;
    else if (n >= 1000) printf "%.0fk", n/1000;
    else printf "%d", n;
  }'
}

fmt_duration() {
  # $1 = seconds remaining -> "3h41m" or "3d16h"
  local s=$1
  if [ -z "$s" ] || [ "$s" -le 0 ] 2>/dev/null; then echo "0m"; return; fi
  local days=$(( s / 86400 ))
  local hours=$(( (s % 86400) / 3600 ))
  local mins=$(( (s % 3600) / 60 ))
  if [ "$days" -gt 0 ]; then
    printf "%dd%dh" "$days" "$hours"
  else
    printf "%dh%dm" "$hours" "$mins"
  fi
}

bar() {
  # $1 = percentage (0-100), $2 = width (default 8)
  local pct=$1
  local width=${2:-8}
  if [ -z "$pct" ] || [ "$pct" = "null" ]; then
    awk -v w="$width" -v e="┄" 'BEGIN { s=""; for(i=0;i<w;i++) s=s e; print s }'
    return
  fi
  awk -v pct="$pct" -v w="$width" -v f="━" -v e="┄" 'BEGIN {
    filled = int((pct/100.0)*w + 0.5);
    if (filled > w) filled = w;
    if (filled < 0) filled = 0;
    s = "";
    for (i=0;i<filled;i++) s = s f;
    for (i=filled;i<w;i++) s = s e;
    print s;
  }'
}

# file mtime age in seconds (BSD stat -f, GNU stat -c); large number if missing
file_age() {
  local f=$1 m
  if [ -e "$f" ]; then
    m=$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo "$now")
    echo $(( now - m ))
  else
    echo 999999
  fi
}

# strip ANSI SGR color codes from stdin. Needed because CLICOLOR_FORCE/FORCE_COLOR
# in this environment make `gh` colorize even its --json output, which breaks jq.
strip_ansi() { sed $'s/\x1b\\[[0-9;]*m//g'; }

# run gh with a portable kill-watchdog (no timeout(1) on macOS).
# usage: gh_bounded <seconds> <outfile> <gh args...>
gh_bounded() {
  local secs=$1 out=$2; shift 2
  gh "$@" > "$out" 2>/dev/null &
  local p=$!
  ( sleep "$secs"; kill "$p" 2>/dev/null ) 2>/dev/null &
  local w=$!
  wait "$p" 2>/dev/null
  kill "$w" 2>/dev/null
}

now=$(date +%s)

# ---- context window ----
used_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
ctx_used_h=$(fmt_tokens "$used_tokens")
ctx_size_h=$(fmt_tokens "$ctx_size")
ctx_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
ctx_pct_disp="--"
[ -n "$ctx_pct" ] && ctx_pct_disp=$(awk -v p="$ctx_pct" 'BEGIN{printf "%.0f", p}')

# ---- rate limits ----
five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
week_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
week_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

five_bar=$(bar "$five_pct")
week_bar=$(bar "$week_pct")

five_pct_disp="--"
[ -n "$five_pct" ] && five_pct_disp=$(awk -v p="$five_pct" 'BEGIN{printf "%.0f", p}')
week_pct_disp="--"
[ -n "$week_pct" ] && week_pct_disp=$(awk -v p="$week_pct" 'BEGIN{printf "%.0f", p}')

five_time=""
if [ -n "$five_reset" ]; then
  five_remaining=$(( five_reset - now ))
  five_time=$(fmt_duration "$five_remaining")
fi
week_time=""
if [ -n "$week_reset" ]; then
  week_remaining=$(( week_reset - now ))
  week_time=$(fmt_duration "$week_remaining")
fi

# ---- session cost ----
cost_usd=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
cost_disp=""
if [ -n "$cost_usd" ]; then
  cost_disp=$(awk -v c="$cost_usd" 'BEGIN{ printf "$%.2f", c }')
fi

# ---- model / effort ----
model_name=$(echo "$input" | jq -r '.model.display_name // empty')
effort=$(echo "$input" | jq -r '.effort.level // empty')

# ---- colors (dim, since statusline renders dimmed) ----
DIM=$'\033[2m'
RESET=$'\033[0m'
CYAN=$'\033[2;36m'
YELLOW=$'\033[2;33m'
MAGENTA=$'\033[2;35m'
GREEN=$'\033[2;32m'
BLUE=$'\033[2;34m'

model_disp="$model_name"
[ -n "$effort" ] && model_disp="${model_disp} (${effort})"

# ---- PR + CI (derived from gh; cached; refreshed in background) ----
session_id=$(echo "$input" | jq -r '.session_id // "nosession"')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
prci_cache="${TMPDIR:-/tmp}/cc-prci-${session_id}"
prci_lock="${prci_cache}.lock"
PRCI_MAX_AGE=15   # seconds a reading is considered fresh
LOCK_MAX_AGE=60   # seconds before a leftover lock (crashed fetch) is force-released

# release a stale lock from a fetch that died before cleanup
if [ -d "$prci_lock" ] && [ "$(file_age "$prci_lock")" -gt "$LOCK_MAX_AGE" ]; then
  rmdir "$prci_lock" 2>/dev/null
fi

# refresh in background if stale (atomic mkdir lock -> only one refresher at a time)
if [ -n "$cwd" ] && command -v gh >/dev/null 2>&1 \
   && [ "$(file_age "$prci_cache")" -gt "$PRCI_MAX_AGE" ] \
   && mkdir "$prci_lock" 2>/dev/null; then
  (
    cd "$cwd" 2>/dev/null || { rmdir "$prci_lock" 2>/dev/null; exit; }
    tmp="${prci_cache}.tmp.$$"
    raw="${prci_cache}.raw.$$"
    ESC=$'\033'; BEL=$'\007'

    # 1) PR number + url for the current branch
    gh_bounded 12 "$raw" pr view --json number,url
    num=$(strip_ansi < "$raw" | jq -r '.number // empty' 2>/dev/null)
    url=$(strip_ansi < "$raw" | jq -r '.url // empty'    2>/dev/null)

    if [ -z "$num" ]; then
      : > "$tmp"                       # no open PR -> empty segment
    else
      # clickable "#NNN" via OSC 8, dim blue
      pr_part=$(printf '\033[2;34m%s]8;;%s%s#%s%s]8;;%s\033[0m' \
                "$ESC" "$url" "$BEL" "$num" "$ESC" "$BEL")

      # 2) CI status for that PR
      gh_bounded 12 "$raw" pr checks "$num" --json bucket -q '.[].bucket'
      buckets=$(strip_ansi < "$raw" 2>/dev/null)
      ci_part=""
      if [ -n "$buckets" ]; then
        fail=$(printf '%s\n' "$buckets" | grep -c '^fail$')
        pend=$(printf '%s\n' "$buckets" | grep -c '^pending$')
        pass=$(printf '%s\n' "$buckets" | grep -c '^pass$')
        if   [ "$fail" -gt 0 ]; then ci_part=$(printf '  \033[2;31m✗CI %d\033[0m' "$fail")
        elif [ "$pend" -gt 0 ]; then ci_part=$(printf '  \033[2;33m●CI %d\033[0m' "$pend")
        elif [ "$pass" -gt 0 ]; then ci_part=$(printf '  \033[2;32m✓CI\033[0m')
        fi
      fi
      printf '%s%s' "$pr_part" "$ci_part" > "$tmp"
    fi

    rm -f "$raw"
    mv "$tmp" "$prci_cache" 2>/dev/null
    rmdir "$prci_lock" 2>/dev/null
  ) >/dev/null 2>&1 &
  disown 2>/dev/null
fi

prci_disp=""
[ -s "$prci_cache" ] && prci_disp=$(cat "$prci_cache")

# ---- render (single line) ----
printf "%swindow %s%% %s/%s%s  %s5h %s %s%%%s%s  %sWk %s %s%%%s%s%s  %s%s%s" \
  "$CYAN" "$ctx_pct_disp" "$ctx_used_h" "$ctx_size_h" "$RESET" \
  "$YELLOW" "$five_bar" "$five_pct_disp" "${five_time:+ $five_time}" "$RESET" \
  "$MAGENTA" "$week_bar" "$week_pct_disp" "${week_time:+ $week_time}" "$RESET" \
  "${cost_disp:+  ${BLUE}${cost_disp}${RESET}}" \
  "$GREEN" "$model_disp" "$RESET"

# PR + CI (already fully colored in cache); add a leading separator if present
printf "%s\n" "${prci_disp:+  ${prci_disp}}"
