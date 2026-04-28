///|
test "player view exposes own plan and hides opponent plan" {
  let state = WindowSecrets::new(
    side_a_plan="A defends",
    side_b_plan="B attacks",
    public_interventions=["A:/prefer defend", "B:/focus A"],
  )
  let view = state.view_for(@protocol.A)
  assert_true(view.viewer == @protocol.A)
  assert_eq(view.own_agent_plan, "A defends")
  assert_eq(view.opponent_agent_plan, None)
  assert_eq(view.public_interventions.length(), 2)
}

///|
test "replay window view uses the same hidden-plan boundary" {
  let intervention = @protocol.Intervention::new(
    side=@protocol.A,
    window_id=@protocol.WindowId::new(1),
    sequence_id=@protocol.SequenceId::new(1),
    kind=@protocol.SoftPreference,
    text="/prefer defend",
  )
  let record = @replay.ReplayWindowRecord::new(
    window_id=@protocol.WindowId::new(1),
    sequence_id=@protocol.SequenceId::new(1),
    initial_agent_plan_a="A initial",
    initial_agent_plan_b="B initial",
    final_agent_plan_a="A final",
    final_agent_plan_b="B final",
    public_interventions=[intervention],
    public_events=[],
  )
  let view = view_replay_window(record, @protocol.B)
  assert_true(view.viewer == @protocol.B)
  assert_eq(view.own_agent_plan, "B final")
  assert_eq(view.opponent_agent_plan, None)
  assert_eq(view.public_interventions.length(), 1)
}
