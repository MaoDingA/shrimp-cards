///|
test "protocol exposes stable version and side labels" {
  assert_eq(protocol_version, 1)
  assert_eq(A.label(), "A")
  assert_eq(B.label(), "B")
}

///|
test "player identity serializes to public json" {
  let identity = PlayerIdentity::new("player-1", "Alice", A)
  let encoded = identity.to_json().stringify()
  assert_true(encoded.contains("\"player_id\":\"player-1\""))
  assert_true(encoded.contains("\"display_name\":\"Alice\""))
  assert_true(encoded.contains("\"side\":\"A\""))
}

///|
test "window id rejects stale input" {
  let current = WindowId::new(3)
  assert_true(current.accepts(WindowId::new(3)))
  assert_false(current.accepts(WindowId::new(2)))
}

///|
test "sequence id accepts only newer messages" {
  let last_seen = SequenceId::new(4)
  assert_true(SequenceId::new(5).is_newer_than(last_seen))
  assert_false(SequenceId::new(4).is_newer_than(last_seen))
  assert_false(SequenceId::new(3).is_newer_than(last_seen))
}

///|
test "intervention carries side window sequence and public text" {
  let intervention = Intervention::new(
    side=A,
    window_id=WindowId::new(7),
    sequence_id=SequenceId::new(2),
    kind=SoftPreference,
    text="/prefer defend",
  )
  assert_true(intervention.side == A)
  assert_true(intervention.window_id == WindowId::new(7))
  assert_true(intervention.sequence_id == SequenceId::new(2))
  assert_true(intervention.kind == SoftPreference)
  assert_eq(intervention.text, "/prefer defend")
  assert_true(intervention.is_for_window(WindowId::new(7)))
  assert_false(intervention.is_for_window(WindowId::new(8)))
}

///|
test "public event serializes with code and message" {
  let event = PublicEvent::new("player_left", "A left the match")
  let encoded = event.to_json().stringify()
  assert_true(encoded.contains("\"code\":\"player_left\""))
  assert_true(encoded.contains("\"message\":\"A left the match\""))
}
