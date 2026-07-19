#!/bin/bash
# Claude Code statusline: context window usage + 5h/weekly rate-limit bars
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

now=$(date +%s)

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

model_disp="$model_name"
[ -n "$effort" ] && model_disp="${model_disp} (${effort})"

printf "%swindow %s%% %s/%s%s  %s5h %s %s%%%s%s  %sWk %s %s%%%s%s  %s%s%s\n" \
  "$CYAN" "$ctx_pct_disp" "$ctx_used_h" "$ctx_size_h" "$RESET" \
  "$YELLOW" "$five_bar" "$five_pct_disp" "${five_time:+ $five_time}" "$RESET" \
  "$MAGENTA" "$week_bar" "$week_pct_disp" "${week_time:+ $week_time}" "$RESET" \
  "$GREEN" "$model_disp" "$RESET"
