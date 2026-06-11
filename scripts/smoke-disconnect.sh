#!/usr/bin/env bash
set -euo pipefail

# Smoke test for heartbeat timeout disconnect scenario.
# Uses very short heartbeat timeouts to verify that the host
# detects a disconnected player and ends the match.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

MOON="${MOON:-moon}"
PORT="${SMOKE_PORT:-17802}"
MATCH_ID="${SMOKE_MATCH_ID:-smoke-disconnect-$$}"
OUT_DIR="${SMOKE_OUT_DIR:-_build/smoke-disconnect}"
REPLAY_DIR="$OUT_DIR/replays"
REPLAY_PATH="$REPLAY_DIR/$MATCH_ID.json"
HOST_URL="ws://127.0.0.1:$PORT/match"
HOST_LOG="$OUT_DIR/host.out"
ALICE_LOG="$OUT_DIR/alice.out"
BOB_LOG="$OUT_DIR/bob.out"
META_LOG="$OUT_DIR/replay-metadata.out"
EVENTS_LOG="$OUT_DIR/replay-events.out"
ALICE_FIFO="$OUT_DIR/alice.in"
BOB_FIFO="$OUT_DIR/bob.in"

# Very short timeout: host will declare disconnect after 1s without heartbeat
HOST_HEARTBEAT_TIMEOUT_MS="1000"
HOST_HEARTBEAT_SCAN_MS="250"
# Alice sends heartbeat every 200ms (stays alive)
ALICE_HEARTBEAT_MS="200"
# Bob sends heartbeat every 200ms initially, then we kill him
BOB_HEARTBEAT_MS="200"

PIDS=()

cleanup() {
  set +e
  exec 3>&- 2>/dev/null
  exec 4>&- 2>/dev/null
  for pid in "${PIDS[@]}"; do
    kill "$pid" 2>/dev/null
  done
  for pid in "${PIDS[@]}"; do
    wait "$pid" 2>/dev/null
  done
  rm -f "$ALICE_FIFO" "$BOB_FIFO"
}

trap cleanup EXIT INT TERM

log() {
  printf '[smoke-disconnect] %s\n' "$*"
}

fail() {
  printf '[smoke-disconnect] failed: %s\n' "$*" >&2
  printf '[smoke-disconnect] host log: %s\n' "$HOST_LOG" >&2
  exit 1
}

wait_for_log() {
  local file="$1"
  local pattern="$2"
  local timeout="${3:-20}"
  local deadline=$((SECONDS + timeout))
  while (( SECONDS < deadline )); do
    if [[ -f "$file" ]] && grep -Fq "$pattern" "$file"; then
      return 0
    fi
    sleep 0.2
  done
  fail "timed out waiting for '$pattern' in $file"
}

require_log() {
  local file="$1"
  local pattern="$2"
  if ! grep -Fq "$pattern" "$file"; then
    fail "missing '$pattern' in $file"
  fi
}

shell_quote_args() {
  local quoted=""
  local arg
  for arg in "$@"; do
    local piece
    printf -v piece '%q' "$arg"
    quoted="${quoted}${piece} "
  done
  printf '%s' "$quoted"
}

run_with_pty() {
  local log_file="$1"
  shift
  local probe="$OUT_DIR/script-probe.out"
  if script -F -q "$probe" true >/dev/null 2>&1; then
    rm -f "$probe"
    script -F -q "$log_file" "$@"
  else
    rm -f "$probe"
    script -f -q -c "$(shell_quote_args "$@")" "$log_file"
  fi
}

rm -rf "$OUT_DIR"
mkdir -p "$REPLAY_DIR"
mkfifo "$ALICE_FIFO" "$BOB_FIFO"

# ============================================================
# Start host with very short heartbeat timeout
# ============================================================

log "starting host with 1s heartbeat timeout on $HOST_URL"
run_with_pty "$HOST_LOG" "$MOON" run cmd/main --target native -- host \
  --port "$PORT" \
  --match-id "$MATCH_ID" \
  --seed 429 \
  --replay-dir "$REPLAY_DIR" \
  --heartbeat-timeout-ms "$HOST_HEARTBEAT_TIMEOUT_MS" \
  --heartbeat-scan-ms "$HOST_HEARTBEAT_SCAN_MS" \
  >/dev/null 2>&1 &
PIDS+=("$!")

wait_for_log "$HOST_LOG" "host started $HOST_URL match $MATCH_ID replay $REPLAY_PATH" 60

# ============================================================
# Start both players
# ============================================================

log "starting player A (Alice)"
"$MOON" run cmd/main --target native -- join \
  --name Alice \
  --lang zh \
  --host "$HOST_URL" \
  --heartbeat-interval-ms "$ALICE_HEARTBEAT_MS" \
  <"$ALICE_FIFO" >"$ALICE_LOG" 2>&1 &
ALICE_PID=$!
PIDS+=("$ALICE_PID")
exec 3>"$ALICE_FIFO"

wait_for_log "$HOST_LOG" "join accepted as A"

log "starting player B (Bob)"
"$MOON" run cmd/main --target native -- join \
  --name Bob \
  --lang zh \
  --host "$HOST_URL" \
  --heartbeat-interval-ms "$BOB_HEARTBEAT_MS" \
  <"$BOB_FIFO" >"$BOB_LOG" 2>&1 &
BOB_PID=$!
PIDS+=("$BOB_PID")
exec 4>"$BOB_FIFO"

wait_for_log "$HOST_LOG" "join accepted as B"

# ============================================================
# Start match
# ============================================================

log "sending /ready from both players"
printf '/ready\n' >&3
printf '/ready\n' >&4

wait_for_log "$HOST_LOG" "event match started"
wait_for_log "$HOST_LOG" "event window 1 opened"

log "match started and window 1 opened"

# ============================================================
# Kill Bob's process to simulate disconnect (no /leave, no heartbeat)
# ============================================================

log "killing Bob's process to simulate disconnect"
exec 4>&-
kill "$BOB_PID" 2>/dev/null || true
wait "$BOB_PID" 2>/dev/null || true

# Wait for host to detect Bob's heartbeat timeout and trigger disconnect
log "waiting for host to detect disconnect (timeout=${HOST_HEARTBEAT_TIMEOUT_MS}ms)"
wait_for_log "$HOST_LOG" "event B disconnected" 10
wait_for_log "$HOST_LOG" "event match ended: B disconnected"
wait_for_log "$HOST_LOG" "event replay saved: $REPLAY_PATH"

log "disconnect detected and match ended: OK"

# ============================================================
# Clean up Alice
# ============================================================

printf '/leave\n' >&3
sleep 0.5

# ============================================================
# Validate replay records the disconnect event
# ============================================================

[[ -f "$REPLAY_PATH" ]] || fail "replay was not saved at $REPLAY_PATH"

log "validating replay contains disconnect event"
"$MOON" run cmd/main --target native -- replay \
  --file "$REPLAY_PATH" \
  --view A \
  --mode events \
  >"$EVENTS_LOG" 2>&1

require_log "$EVENTS_LOG" "match started"
require_log "$EVENTS_LOG" "window 1 opened"
require_log "$EVENTS_LOG" "B disconnected"
require_log "$EVENTS_LOG" "match ended: B disconnected"
require_log "$EVENTS_LOG" "replay saved: $REPLAY_PATH"

log "validating replay metadata"
"$MOON" run cmd/main --target native -- replay \
  --file "$REPLAY_PATH" \
  --view A \
  --mode metadata \
  >"$META_LOG" 2>&1

require_log "$META_LOG" "replay $MATCH_ID metadata"

log "all checks passed"
log "replay: $REPLAY_PATH"
log "logs: $OUT_DIR"
