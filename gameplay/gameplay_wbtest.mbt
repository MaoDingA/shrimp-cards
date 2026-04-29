///|
test "minimal game state exposes deterministic observations" {
  let state = GameState::initial(seed=429)
  let observation = state.observe(@protocol.A, @protocol.WindowId::new(1))
  assert_true(observation.side == @protocol.A)
  assert_true(observation.window_id == @protocol.WindowId::new(1))
  assert_eq(observation.state_summary, "seed 429 step 0 energy A=1 B=1")
}

///|
test "minimal ruleset chooses fake actions and resolves a window" {
  let state = GameState::initial(seed=7)
  let window_id = @protocol.WindowId::new(1)
  let intervention = @protocol.Intervention::new(
    side=@protocol.A,
    window_id~,
    sequence_id=@protocol.SequenceId::new(1),
    kind=@protocol.SoftPreference,
    text="/prefer test the slot",
  )
  let action_a = state.fake_action(@protocol.A, window_id, [intervention])
  let action_b = state.fake_action(@protocol.B, window_id, [])
  assert_eq(action_a.label, "fake-action-A")
  assert_eq(action_a.detail, "minimal action with 1 intervention")
  assert_eq(action_b.label, "fake-action-B")
  assert_eq(action_b.detail, "minimal action with 0 interventions")
  let result = state.resolve_window(window_id, [action_a, action_b])
  assert_eq(result.public_log, "window 1 resolved by minimal ruleset")
  assert_eq(result.state.executed_windows, 1)
  assert_eq(result.state.side_a_energy, 1)
  assert_eq(result.state.side_b_energy, 1)
}
