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

///|
test "join request carries player identity and protocol version" {
  let request = JoinRequest::new("player-1", "Alice")
  assert_eq(request.player_id, "player-1")
  assert_eq(request.display_name, "Alice")
  assert_eq(request.protocol_version, protocol_version)
  assert_true(request.is_compatible())
}

///|
test "join request round trips wire text" {
  let request = JoinRequest::new("player-1", "Alice")
  let decoded = JoinRequest::from_wire_text(request.to_wire_text())
  match decoded {
    Some(decoded) => {
      assert_eq(decoded.player_id, "player-1")
      assert_eq(decoded.display_name, "Alice")
      assert_true(decoded.is_compatible())
    }
    None => fail("expected join request")
  }
}

///|
test "join response round trips accepted seat" {
  let response = JoinAccepted(PlayerIdentity::new("player-1", "Alice", A))
  let decoded = JoinResponse::from_wire_text(response.to_wire_text())
  match decoded {
    Some(JoinAccepted(player)) => {
      assert_eq(player.player_id, "player-1")
      assert_eq(player.display_name, "Alice")
      assert_true(player.side == A)
    }
    _ => fail("expected accepted response")
  }
}

///|
test "client ready and leave inputs round trip wire text" {
  let ready = Ready(A)
  match ClientInput::from_wire_text(ready.to_wire_text()) {
    Some(Ready(side)) => assert_true(side == A)
    _ => fail("expected ready input")
  }
  let leave = Leave(B)
  match ClientInput::from_wire_text(leave.to_wire_text()) {
    Some(Leave(side)) => assert_true(side == B)
    _ => fail("expected leave input")
  }
}

///|
test "client intervention input round trips wire text" {
  let intervention = Intervention::new(
    side=A,
    window_id=WindowId::new(1),
    sequence_id=SequenceId::new(2),
    kind=SoftPreference,
    text="/prefer defend",
  )
  let input = SubmitIntervention(intervention)
  match ClientInput::from_wire_text(input.to_wire_text()) {
    Some(SubmitIntervention(decoded)) => {
      assert_true(decoded.side == A)
      assert_true(decoded.window_id == WindowId::new(1))
      assert_true(decoded.sequence_id == SequenceId::new(2))
      assert_true(decoded.kind == SoftPreference)
      assert_eq(decoded.text, "/prefer defend")
    }
    _ => fail("expected intervention input")
  }
}

///|
test "host input response round trips window opened" {
  let response = WindowOpened(WindowId::new(1))
  match InputResponse::from_wire_text(response.to_wire_text()) {
    Some(WindowOpened(window_id)) => assert_true(window_id == WindowId::new(1))
    _ => fail("expected window opened response")
  }
}

///|
test "server event round trips ready and window opened" {
  let ready = PlayerReady(A)
  match ServerEvent::from_wire_text(ready.to_wire_text()) {
    Some(PlayerReady(side)) => assert_true(side == A)
    _ => fail("expected ready event")
  }
  let opened = InputWindowOpened(WindowId::new(1))
  match ServerEvent::from_wire_text(opened.to_wire_text()) {
    Some(InputWindowOpened(window_id)) =>
      assert_true(window_id == WindowId::new(1))
    _ => fail("expected window event")
  }
}

///|
test "server event round trips intervention and leave" {
  let intervention = Intervention::new(
    side=B,
    window_id=WindowId::new(2),
    sequence_id=SequenceId::new(3),
    kind=HardConstraint,
    text="/ban strike",
  )
  let submitted = InterventionSubmitted(intervention)
  match ServerEvent::from_wire_text(submitted.to_wire_text()) {
    Some(InterventionSubmitted(decoded)) => {
      assert_true(decoded.side == B)
      assert_true(decoded.window_id == WindowId::new(2))
      assert_true(decoded.sequence_id == SequenceId::new(3))
      assert_true(decoded.kind == HardConstraint)
      assert_eq(decoded.text, "/ban strike")
    }
    _ => fail("expected intervention event")
  }
  let left = PlayerLeft(A)
  match ServerEvent::from_wire_text(left.to_wire_text()) {
    Some(PlayerLeft(side)) => assert_true(side == A)
    _ => fail("expected leave event")
  }
}

///|
test "event subscription round trips cursor wire text" {
  let subscription = EventSubscription::new(3)
  assert_eq(subscription.from_event_id, 3)
  match EventSubscription::from_wire_text(subscription.to_wire_text()) {
    Some(decoded) => assert_eq(decoded.from_event_id, 3)
    None => fail("expected event subscription")
  }
}
