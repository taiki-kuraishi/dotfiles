#!/bin/bash
input=$(cat)

fmt_tokens() {
  local n=$1
  if [ -z "$n" ] || [ "$n" = "null" ]; then echo "0"; return; fi
  awk -v n="$n" 'BEGIN {
    if (n >= 1000000) printf "%.1fM", n/1000000;
    else if (n >= 1000) printf "%.0fk", n/1000;
    else printf "%d", n;
  }'
}

fmt_duration() {
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

file_age() {
  local f=$1 m
  if [ -e "$f" ]; then
    m=$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo "$now")
    echo $(( now - m ))
  else
    echo 999999
  fi
}

strip_ansi() { sed $'s/\x1b\\[[0-9;]*m//g'; }

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

used_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
ctx_used_h=$(fmt_tokens "$used_tokens")
ctx_size_h=$(fmt_tokens "$ctx_size")
ctx_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
ctx_pct_disp="--"
[ -n "$ctx_pct" ] && ctx_pct_disp=$(awk -v p="$ctx_pct" 'BEGIN{printf "%.0f", p}')

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

cost_usd=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
cost_disp=""
if [ -n "$cost_usd" ]; then
  cost_disp=$(awk -v c="$cost_usd" 'BEGIN{ printf "$%.2f", c }')
fi

model_name=$(echo "$input" | jq -r '.model.display_name // empty')
effort=$(echo "$input" | jq -r '.effort.level // empty')

DIM=$'\033[2m'
RESET=$'\033[0m'
CYAN=$'\033[2;36m'
YELLOW=$'\033[2;33m'
MAGENTA=$'\033[2;35m'
GREEN=$'\033[2;32m'
BLUE=$'\033[2;34m'

model_disp="$model_name"
[ -n "$effort" ] && model_disp="${model_disp} (${effort})"

session_id=$(echo "$input" | jq -r '.session_id // "nosession"')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
prci_cache="${TMPDIR:-/tmp}/cc-prci-${session_id}"
prci_lock="${prci_cache}.lock"
PRCI_MAX_AGE=15
LOCK_MAX_AGE=60

if [ -d "$prci_lock" ] && [ "$(file_age "$prci_lock")" -gt "$LOCK_MAX_AGE" ]; then
  rmdir "$prci_lock" 2>/dev/null
fi

if [ -n "$cwd" ] && command -v gh >/dev/null 2>&1 \
   && [ "$(file_age "$prci_cache")" -gt "$PRCI_MAX_AGE" ] \
   && mkdir "$prci_lock" 2>/dev/null; then
  (
    cd "$cwd" 2>/dev/null || { rmdir "$prci_lock" 2>/dev/null; exit; }
    tmp="${prci_cache}.tmp.$$"
    raw="${prci_cache}.raw.$$"
    ESC=$'\033'; BEL=$'\007'

    gh_bounded 12 "$raw" pr view --json number,url
    num=$(strip_ansi < "$raw" | jq -r '.number // empty' 2>/dev/null)
    url=$(strip_ansi < "$raw" | jq -r '.url // empty'    2>/dev/null)

    pr_part=""
    if [ -n "$num" ]; then
      pr_part=$(printf '\033[2;34m%s]8;;%s%s#%s%s]8;;%s\033[0m' \
                "$ESC" "$url" "$BEL" "$num" "$ESC" "$BEL")
    fi

    branch=$(git branch --show-current 2>/dev/null)
    ci_part=""
    if [ -n "$branch" ]; then
      gh_bounded 12 "$raw" run list --branch "$branch" --limit 20 \
        --json status,conclusion,headSha
      states=$(strip_ansi < "$raw" | jq -r '
        (.[0].headSha // "") as $sha | .[] | select(.headSha == $sha)
        | if .status != "completed" then
            (if .status == "in_progress" then "running" else "queued" end)
          elif .conclusion == "success" then "pass"
          elif .conclusion == "skipped" or .conclusion == "neutral" then "skipped"
          else "fail" end' 2>/dev/null)
      if [ -n "$states" ]; then
        cnt() { printf '%s\n' "$states" | grep -c "^$1$"; }
        np=$(cnt pass); nf=$(cnt fail); nq=$(cnt queued); nr=$(cnt running); ns=$(cnt skipped)
        ci_part=$'\033[2mCI\033[0m'
        [ "$np" -gt 0 ] && ci_part+=$(printf ' \033[2;32m✓%d\033[0m' "$np")
        [ "$nf" -gt 0 ] && ci_part+=$(printf ' \033[2;31m✗%d\033[0m' "$nf")
        [ "$nq" -gt 0 ] && ci_part+=$(printf ' \033[2;37m○%d\033[0m' "$nq")
        [ "$nr" -gt 0 ] && ci_part+=$(printf ' \033[2;33m●%d\033[0m' "$nr")
        [ "$ns" -gt 0 ] && ci_part+=$(printf ' \033[2;90m⊘%d\033[0m' "$ns")
      fi
    fi

    sep=""
    [ -n "$pr_part" ] && [ -n "$ci_part" ] && sep="  "
    printf '%s%s%s' "$pr_part" "$sep" "$ci_part" > "$tmp"

    rm -f "$raw"
    mv "$tmp" "$prci_cache" 2>/dev/null
    rmdir "$prci_lock" 2>/dev/null
  ) >/dev/null 2>&1 &
  disown 2>/dev/null
fi

prci_disp=""
[ -s "$prci_cache" ] && prci_disp=$(cat "$prci_cache")

segs=()
segs+=("$(printf '%swindow %s%% %s/%s%s' "$CYAN" "$ctx_pct_disp" "$ctx_used_h" "$ctx_size_h" "$RESET")")
segs+=("$(printf '%s5h %s %s%%%s%s' "$YELLOW" "$five_bar" "$five_pct_disp" "${five_time:+ $five_time}" "$RESET")")
segs+=("$(printf '%sWk %s %s%%%s%s' "$MAGENTA" "$week_bar" "$week_pct_disp" "${week_time:+ $week_time}" "$RESET")")
[ -n "$cost_disp" ] && segs+=("${BLUE}${cost_disp}${RESET}")
segs+=("${GREEN}${model_disp}${RESET}")
[ -n "$prci_disp" ] && segs+=("$prci_disp")

term_cols=$(stty size 2>/dev/null </dev/tty | awk '{print $2}')
[ -n "$term_cols" ] || term_cols=${COLUMNS:-9999}

vlen() {
  printf '%s' "$1" \
    | sed $'s/\x1b]8;;[^\x07]*\x07//g; s/\x1b\\[[0-9;]*m//g' \
    | LC_ALL=en_US.UTF-8 wc -m | tr -d ' '
}

line=""; llen=0
for seg in "${segs[@]}"; do
  slen=$(vlen "$seg")
  if [ -z "$line" ]; then
    line="$seg"; llen=$slen
  elif [ $((llen + 2 + slen)) -le "$term_cols" ]; then
    line="${line}  ${seg}"; llen=$((llen + 2 + slen))
  else
    printf '%s\n' "$line"
    line="$seg"; llen=$slen
  fi
done
printf '%s\n' "$line"
