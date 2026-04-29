#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

MOON="${MOON:-moon}"
PORT="${SMOKE_PORT:-7797}"
MATCH_ID="${SMOKE_MATCH_ID:-smoke-local-$$}"
OUT_DIR="${SMOKE_OUT_DIR:-_build/smoke-local}"
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
JOIN_HEARTBEAT_MS="${SMOKE_JOIN_HEARTBEAT_MS:-500}"
HOST_HEARTBEAT_TIMEOUT_MS="${SMOKE_HOST_HEARTBEAT_TIMEOUT_MS:-5000}"
HOST_HEARTBEAT_SCAN_MS="${SMOKE_HOST_HEARTBEAT_SCAN_MS:-250}"

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
  printf '[smoke] %s\n' "$*"
}

fail() {
  printf '[smoke] failed: %s\n' "$*" >&2
  printf '[smoke] host log: %s\n' "$HOST_LOG" >&2
  printf '[smoke] alice log: %s\n' "$ALICE_LOG" >&2
  printf '[smoke] bob log: %s\n' "$BOB_LOG" >&2
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
mkfifo "$ALICE_FIFO" "$BOB_FIFO"

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

log "starting player A"
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

log "starting player B"
"$MOON" run cmd/main --target native -- join \
  --name Bob \
  --lang zh \
  --host "$HOST_URL" \
  --heartbeat-interval-ms "$JOIN_HEARTBEAT_MS" \
  <"$BOB_FIFO" >"$BOB_LOG" 2>&1 &
PIDS+=("$!")
exec 4>"$BOB_FIFO"

wait_for_log "$HOST_LOG" "join accepted as B"
wait_for_log "$HOST_LOG" "event Bob joined as B"

log "sending ready commands"
printf '/ready\n' >&3
printf '/ready\n' >&4

wait_for_log "$HOST_LOG" "event match started"
wait_for_log "$HOST_LOG" "event window 1 opened"
wait_for_log "$HOST_LOG" "input A heartbeat"
wait_for_log "$HOST_LOG" "input B heartbeat"

log "ending match through player A"
printf '/leave\n' >&3

wait_for_log "$HOST_LOG" "event match ended: A left"
wait_for_log "$HOST_LOG" "event replay saved: $REPLAY_PATH"

printf '/leave\n' >&4
sleep 0.5

[[ -f "$REPLAY_PATH" ]] || fail "replay was not saved at $REPLAY_PATH"

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

log "validating replay events"
"$MOON" run cmd/main --target native -- replay \
  --file "$REPLAY_PATH" \
  --view A \
  --mode events \
  >"$EVENTS_LOG" 2>&1

require_log "$EVENTS_LOG" "#0 Alice joined as A"
require_log "$EVENTS_LOG" "#1 Bob joined as B"
require_log "$EVENTS_LOG" "match started"
require_log "$EVENTS_LOG" "window 1 opened"
require_log "$EVENTS_LOG" "match ended: A left"
require_log "$EVENTS_LOG" "replay saved: $REPLAY_PATH"
reject_log "$EVENTS_LOG" "disconnected"

log "passed"
log "replay: $REPLAY_PATH"
log "logs: $OUT_DIR"
