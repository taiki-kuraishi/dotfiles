#!/usr/bin/env bats
# Display tests for statusline-command.sh — gh/stty mocked, happy path only.
# Run: bats ~/.claude/statusline-command.bats

# resolve the script relative to this test file, so it works both in $HOME and in CI checkouts
SCRIPT="$BATS_TEST_DIRNAME/statusline-command.sh"

setup_file() {
  export FAKE_BIN="$BATS_FILE_TMPDIR/fake-bin"
  export FAKE_REPO="$BATS_FILE_TMPDIR/fake-repo"
  export PLAIN_DIR="$BATS_FILE_TMPDIR/plain-dir"
  export SID_PREFIX="bats-$$"
  mkdir -p "$FAKE_BIN" "$FAKE_REPO" "$PLAIN_DIR"

  git -C "$FAKE_REPO" init -q -b feat
  git -C "$FAKE_REPO" -c user.email=t@e -c user.name=t -c commit.gpgsign=false \
    commit -q --allow-empty -m x

  # fake gh: fails outside a git repo (like the real one), canned JSON inside
  cat > "$FAKE_BIN/gh" <<'EOF'
#!/bin/bash
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 1
case "$1 $2" in
  "pr view") echo '{"number":123,"url":"https://github.com/o/r/pull/123"}' ;;
  "run list") cat <<'JSON'
[
 {"status":"completed","conclusion":"success","headSha":"aaa"},
 {"status":"completed","conclusion":"success","headSha":"aaa"},
 {"status":"completed","conclusion":"failure","headSha":"aaa"},
 {"status":"in_progress","conclusion":"","headSha":"aaa"},
 {"status":"queued","conclusion":"","headSha":"aaa"},
 {"status":"completed","conclusion":"skipped","headSha":"aaa"},
 {"status":"completed","conclusion":"success","headSha":"bbb"}
]
JSON
  ;;
esac
EOF

  # fake stty: terminal width injected via FAKE_COLS
  printf '#!/bin/bash\necho "50 $FAKE_COLS"\n' > "$FAKE_BIN/stty"
  chmod +x "$FAKE_BIN/gh" "$FAKE_BIN/stty"
}

teardown_file() {
  rm -f "${TMPDIR:-/tmp}/cc-prci-${SID_PREFIX}"*
}

# ---- helpers ----

make_input() { # $1 = session_id, $2 = current_dir
  printf '{"session_id":"%s","workspace":{"current_dir":"%s"},"context_window":{"total_input_tokens":50000,"context_window_size":200000,"used_percentage":25},"rate_limits":{"five_hour":{"used_percentage":34,"resets_at":%s},"seven_day":{"used_percentage":62,"resets_at":%s}},"cost":{"total_cost_usd":1.23},"model":{"display_name":"Fable 5"},"effort":{"level":"high"}}' \
    "$1" "$2" "$(( $(date +%s) + 13260 ))" "$(( $(date +%s) + 316800 ))"
}

render() { # $1 = width, $2 = session_id, $3 = current_dir
  make_input "$2" "$3" \
    | FAKE_COLS=$1 COLUMNS=$1 PATH="$FAKE_BIN:$PATH" bash "$SCRIPT"
}

strip_esc() { sed $'s/\x1b]8;;[^\x07]*\x07//g; s/\x1b\\[[0-9;]*m//g'; }

vlen() { printf '%s' "$1" | strip_esc | LC_ALL=en_US.UTF-8 wc -m | tr -d ' '; }

wait_cache() { # $1 = session_id; waits until the cache file exists ($2=size: non-empty)
  local f="${TMPDIR:-/tmp}/cc-prci-$1" i
  for i in $(seq 1 25); do
    if [ "${2:-}" = "size" ]; then [ -s "$f" ] && return 0; else [ -e "$f" ] && return 0; fi
    sleep 0.2
  done
  echo "timeout waiting for cache $f"
  return 1
}

assert_contains() {
  [[ "$1" == *"$2"* ]] && return 0
  echo "missing '$2' in: $(printf '%s' "$1" | strip_esc)"
  return 1
}

# ---- tests ----

@test "basic_render_wide: 幅200で1行に全セグメントが並ぶ" {
  run render 200 "${SID_PREFIX}-basic" "$PLAIN_DIR"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  assert_contains "$output" "window 25% 50k/200k"
  assert_contains "$output" "5h "
  assert_contains "$output" "34%"
  assert_contains "$output" "Wk "
  assert_contains "$output" "62%"
  assert_contains "$output" "\$1.23"
  assert_contains "$output" "Fable 5 (high)"
}

@test "wrap_narrow: 幅40で複数行に折り返し、各行が幅内に収まる" {
  run render 40 "${SID_PREFIX}-narrow" "$PLAIN_DIR"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -ge 2 ]
  local l n
  for l in "${lines[@]}"; do
    n=$(vlen "$l")
    [ "$n" -le 40 ] || { echo "line over 40 cols ($n): $(printf '%s' "$l" | strip_esc)"; return 1; }
  done
}

@test "pr_and_ci_display: PRリンクとCI状態別カウントが表示される" {
  local sid="${SID_PREFIX}-prci"
  render 200 "$sid" "$FAKE_REPO" >/dev/null   # 1回目: バックグラウンドフェッチを起動
  wait_cache "$sid" size
  run render 200 "$sid" "$FAKE_REPO"          # 2回目: キャッシュから表示
  [ "$status" -eq 0 ]
  assert_contains "$output" "#123"
  assert_contains "$output" "CI"
  assert_contains "$output" "✓2"
  assert_contains "$output" "✗1"
  assert_contains "$output" "○1"
  assert_contains "$output" "●1"
  assert_contains "$output" "⊘1"
  # 旧コミット(sha=bbb)の run が混ざっていないこと
  [[ "$output" != *"✓3"* ]]
}

@test "no_repo_no_ci: repo外ではPR/CIセグメントが出ない" {
  local sid="${SID_PREFIX}-norepo"
  render 200 "$sid" "$PLAIN_DIR" >/dev/null
  wait_cache "$sid"                            # repo外はキャッシュが空のまま作られる
  run render 200 "$sid" "$PLAIN_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" != *"CI"* ]]
  [[ "$output" != *"#"* ]]
}
