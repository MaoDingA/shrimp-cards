///|
test "replay header is compatible with current versions" {
  let header = ReplayHeader::new(
    "match-1", "2026-04-28T00:00:00Z", 42, @protocol.protocol_version, replay_format_version,
  )
  assert_true(header.is_compatible())
}

///|
test "replay header rejects mismatched protocol version" {
  let header = ReplayHeader::new(
    "match-1",
    "2026-04-28T00:00:00Z",
    42,
    @protocol.protocol_version + 1,
    replay_format_version,
  )
  assert_false(header.is_compatible())
}

///|
test "replay window record requires both final plans" {
  let intervention = @protocol.Intervention::new(
    side=@protocol.A,
    window_id=@protocol.WindowId::new(1),
    sequence_id=@protocol.SequenceId::new(1),
    kind=@protocol.SoftPreference,
    text="/prefer defend",
  )
  let record = ReplayWindowRecord::new(
    window_id=@protocol.WindowId::new(1),
    sequence_id=@protocol.SequenceId::new(1),
    initial_agent_plan_a="A initial",
    initial_agent_plan_b="B initial",
    final_agent_plan_a="A final",
    final_agent_plan_b="B final",
    public_interventions=[intervention],
    public_events=[
      @protocol.PublicEvent::new("window_closed", "Window 1 closed"),
    ],
  )
  assert_true(record.has_complete_agent_plans())
  assert_eq(record.public_event_count(), 1)
}

///|
test "replay log requires compatible versions and both player seats" {
  let header = ReplayHeader::new(
    "match-1", "2026-04-28T00:00:00Z", 42, @protocol.protocol_version, replay_format_version,
  )
  let log = ReplayLog::new(
    header,
    [
      @protocol.PlayerIdentity::new("p1", "Alice", @protocol.A),
      @protocol.PlayerIdentity::new("p2", "Bob", @protocol.B),
    ],
    [],
  )
  assert_true(log.can_play())
}
