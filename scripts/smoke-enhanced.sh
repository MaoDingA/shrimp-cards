#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

MOON="${MOON:-moon}"
PORT="${SMOKE_PORT:-17801}"
MATCH_ID="${SMOKE_MATCH_ID:-smoke-enhanced-$$}"
OUT_DIR="${SMOKE_OUT_DIR:-_build/smoke-enhanced}"
REPLAY_DIR="$OUT_DIR/replays"
REPLAY_PATH="$REPLAY_DIR/$MATCH_ID.json"
HOST_URL="ws://127.0.0.1:$PORT/match"
HOST_LOG="$OUT_DIR/host.out"
ALICE_LOG="$OUT_DIR/alice.out"
BOB_LOG="$OUT_DIR/bob.out"
CHARLIE_LOG="$OUT_DIR/charlie.out"
META_LOG="$OUT_DIR/replay-metadata.out"
EVENTS_LOG="$OUT_DIR/replay-events.out"
WINDOWS_LOG="$OUT_DIR/replay-windows.out"
ALICE_FIFO="$OUT_DIR/alice.in"
BOB_FIFO="$OUT_DIR/bob.in"
CHARLIE_FIFO="$OUT_DIR/charlie.in"
JOIN_HEARTBEAT_MS="${SMOKE_JOIN_HEARTBEAT_MS:-500}"
HOST_HEARTBEAT_TIMEOUT_MS="${SMOKE_HOST_HEARTBEAT_TIMEOUT_MS:-5000}"
HOST_HEARTBEAT_SCAN_MS="${SMOKE_HOST_HEARTBEAT_SCAN_MS:-250}"

PIDS=()

cleanup() {
  set +e
  exec 3>&- 2>/dev/null
  exec 4>&- 2>/dev/null
  exec 5>&- 2>/dev/null
  for pid in "${PIDS[@]}"; do
    kill "$pid" 2>/dev/null
  done
  for pid in "${PIDS[@]}"; do
    wait "$pid" 2>/dev/null
  done
  rm -f "$ALICE_FIFO" "$BOB_FIFO" "$CHARLIE_FIFO"
}

trap cleanup EXIT INT TERM

log() {
  printf '[smoke-enhanced] %s\n' "$*"
}

fail() {
  printf '[smoke-enhanced] failed: %s\n' "$*" >&2
  printf '[smoke-enhanced] host log: %s\n' "$HOST_LOG" >&2
  printf '[smoke-enhanced] alice log: %s\n' "$ALICE_LOG" >&2
  printf '[smoke-enhanced] bob log: %s\n' "$BOB_LOG" >&2
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

reject_log() {
  local file="$1"
  local pattern="$2"
  if grep -Fq "$pattern" "$file"; then
    fail "unexpected '$pattern' in $file"
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
mkfifo "$ALICE_FIFO" "$BOB_FIFO" "$CHARLIE_FIFO"

# ============================================================
# Phase 1: Start host and two players
# ============================================================

log "starting host on $HOST_URL"
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

log "starting player A (Alice, Chinese)"
"$MOON" run cmd/main --target native -- join \
  --name Alice \
  --lang zh \
  --host "$HOST_URL" \
  --heartbeat-interval-ms "$JOIN_HEARTBEAT_MS" \
  <"$ALICE_FIFO" >"$ALICE_LOG" 2>&1 &
PIDS+=("$!")
exec 3>"$ALICE_FIFO"

wait_for_log "$HOST_LOG" "join accepted as A"
wait_for_log "$HOST_LOG" "event Alice joined as A"

log "starting player B (Bob, English)"
"$MOON" run cmd/main --target native -- join \
  --name Bob \
  --lang en \
  --host "$HOST_URL" \
  --heartbeat-interval-ms "$JOIN_HEARTBEAT_MS" \
  <"$BOB_FIFO" >"$BOB_LOG" 2>&1 &
PIDS+=("$!")
exec 4>"$BOB_FIFO"

wait_for_log "$HOST_LOG" "join accepted as B"
wait_for_log "$HOST_LOG" "event Bob joined as B"

# ============================================================
# Phase 2: Third player rejection
# ============================================================

log "testing third player rejection"
"$MOON" run cmd/main --target native -- join \
  --name Charlie \
  --lang en \
  --host "$HOST_URL" \
  --heartbeat-interval-ms "$JOIN_HEARTBEAT_MS" \
  <"$CHARLIE_FIFO" >"$CHARLIE_LOG" 2>&1 &
CHARLIE_PID=$!
PIDS+=("$!")
exec 5>"$CHARLIE_FIFO"

# Charlie should be rejected. Wait a bit for the rejection to arrive.
sleep 1
# Close Charlie's stdin so the process exits
exec 5>&-

# Check that host logged a rejection for Charlie (third join)
wait_for_log "$HOST_LOG" "join rejected: match is full" 5

# Kill Charlie's client process
kill "$CHARLIE_PID" 2>/dev/null || true
wait "$CHARLIE_PID" 2>/dev/null || true

log "third player rejection: OK"

# ============================================================
# Phase 3: Both ready -> match starts
# ============================================================

log "sending /ready from both players"
printf '/ready\n' >&3
printf '/ready\n' >&4

wait_for_log "$HOST_LOG" "event match started"
wait_for_log "$HOST_LOG" "event window 1 opened"

# Verify initial plans were generated
wait_for_log "$HOST_LOG" "initial plan for A"
wait_for_log "$HOST_LOG" "initial plan for B"

# Verify heartbeats are working
wait_for_log "$HOST_LOG" "input A heartbeat"
wait_for_log "$HOST_LOG" "input B heartbeat"

log "match started and window 1 opened: OK"

# ============================================================
# Phase 4: Intervention commands
# ============================================================

log "testing intervention commands in window 1"

# Alice submits a soft preference
printf '/prefer defend the left flank\n' >&3
wait_for_log "$HOST_LOG" "intervention accepted for A" 5
wait_for_log "$HOST_LOG" "event intervention from A" 5

# Bob submits a hard constraint
printf '/ban assassination\n' >&4
wait_for_log "$HOST_LOG" "intervention accepted for B" 5
wait_for_log "$HOST_LOG" "event intervention from B" 5

log "interventions submitted: OK"

# ============================================================
# Phase 5: Lock window -> execution -> next window
# ============================================================

log "locking window 1"
printf '/lock\n' >&3

wait_for_log "$HOST_LOG" "event window 1 locked"
wait_for_log "$HOST_LOG" "event window 1 executed"
wait_for_log "$HOST_LOG" "event window 2 opened"

# Verify final plans were generated after lock
require_log "$HOST_LOG" "final plan for A"
require_log "$HOST_LOG" "final plan for B"

log "window 1 lock -> execute -> window 2 open: OK"

# ============================================================
# Phase 6: Second window with interventions then lock
# ============================================================

log "testing window 2 flow"
printf '/prefer gather intel\n' >&3
printf '/prefer negotiate\n' >&4
wait_for_log "$HOST_LOG" "intervention accepted for A" 5
wait_for_log "$HOST_LOG" "intervention accepted for B" 5

printf '/lock\n' >&3
wait_for_log "$HOST_LOG" "event window 2 locked"
wait_for_log "$HOST_LOG" "event window 2 executed"
wait_for_log "$HOST_LOG" "event window 3 opened"

log "window 2 complete: OK"

# ============================================================
# Phase 7: Leave -> match end
# ============================================================

log "ending match through player B"
printf '/leave\n' >&4

wait_for_log "$HOST_LOG" "event match ended: B left"
wait_for_log "$HOST_LOG" "event replay saved: $REPLAY_PATH"

printf '/leave\n' >&3
sleep 0.5

[[ -f "$REPLAY_PATH" ]] || fail "replay was not saved at $REPLAY_PATH"

log "match ended and replay saved: OK"

# ============================================================
# Phase 8: Replay validation
# ============================================================

log "validating replay metadata"
"$MOON" run cmd/main --target native -- replay \
  --file "$REPLAY_PATH" \
  --view A \
  --mode metadata \
  >"$META_LOG" 2>&1

require_log "$META_LOG" "replay $MATCH_ID metadata"
require_log "$META_LOG" "seed 429"
require_log "$META_LOG" "protocol 4"
require_log "$META_LOG" "format 1"

log "validating replay events (view A)"
"$MOON" run cmd/main --target native -- replay \
  --file "$REPLAY_PATH" \
  --view A \
  --mode events \
  >"$EVENTS_LOG" 2>&1

require_log "$EVENTS_LOG" "#0 Alice joined as A"
require_log "$EVENTS_LOG" "#1 Bob joined as B"
require_log "$EVENTS_LOG" "match started"
require_log "$EVENTS_LOG" "window 1 opened"
require_log "$EVENTS_LOG" "initial plan for A"
require_log "$EVENTS_LOG" "window 1 locked"
require_log "$EVENTS_LOG" "window 1 executed"
require_log "$EVENTS_LOG" "window 2 opened"
require_log "$EVENTS_LOG" "window 2 locked"
require_log "$EVENTS_LOG" "window 2 executed"
require_log "$EVENTS_LOG" "window 3 opened"
require_log "$EVENTS_LOG" "match ended: B left"
require_log "$EVENTS_LOG" "replay saved: $REPLAY_PATH"
reject_log "$EVENTS_LOG" "disconnected"

log "validating replay windows mode (view B)"
"$MOON" run cmd/main --target native -- replay \
  --file "$REPLAY_PATH" \
  --view B \
  --mode windows \
  >"$WINDOWS_LOG" 2>&1

require_log "$WINDOWS_LOG" "window 1"
require_log "$WINDOWS_LOG" "window 2"

log "replay validation: OK"

# ============================================================
# Summary
# ============================================================

log "all checks passed"
log "replay: $REPLAY_PATH"
log "logs: $OUT_DIR"
