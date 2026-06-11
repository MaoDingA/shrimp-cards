///|
test "djb2 hash is deterministic" {
  let h1 = djb2_hash("hello world")
  let h2 = djb2_hash("hello world")
  assert_true(h1 == h2)
}

///|
test "djb2 hash differentiates strings" {
  let h1 = djb2_hash("state A")
  let h2 = djb2_hash("state B")
  assert_true(h1 != h2)
}

///|
test "state snapshot captures game state hash" {
  let state = @gameplay.GameState::initial(seed=42)
  let snapshot = make_snapshot(@protocol.WindowId::new(1), state)
  assert_true(snapshot.state_summary.contains("seed 42"))
}

///|
test "verify snapshot matches identical state" {
  let state = @gameplay.GameState::initial(seed=42)
  let snapshot = make_snapshot(@protocol.WindowId::new(1), state)
  assert_true(verify_snapshot(snapshot, state))
}

///|
test "verify snapshot rejects different state" {
  let state1 = @gameplay.GameState::initial(seed=42)
  let state2 = @gameplay.GameState::initial(seed=99)
  let snapshot = make_snapshot(@protocol.WindowId::new(1), state1)
  assert_true(!verify_snapshot(snapshot, state2))
}
