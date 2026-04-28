///|
test "client config builds compatible join request" {
  let config = ClientConfig::new(
    player_id="player-1",
    display_name="Alice",
    host_url="ws://127.0.0.1:7777/match",
  )
  let request = config.join_request()
  assert_eq(request.player_id, "player-1")
  assert_eq(request.display_name, "Alice")
  assert_true(request.is_compatible())
}

///|
test "client parses ready and leave terminal lines" {
  match
    parse_supervisor_line(
      @protocol.A,
      Some(@protocol.WindowId::new(1)),
      @protocol.SequenceId::new(1),
      "/ready",
    ) {
    Some(@protocol.Ready(side)) => assert_true(side == @protocol.A)
    _ => fail("expected ready input")
  }
  match
    parse_supervisor_line(
      @protocol.B,
      Some(@protocol.WindowId::new(1)),
      @protocol.SequenceId::new(1),
      "/leave",
    ) {
    Some(@protocol.Leave(side)) => assert_true(side == @protocol.B)
    _ => fail("expected leave input")
  }
}

///|
test "client parses intervention terminal lines when window is open" {
  match
    parse_supervisor_line(
      @protocol.A,
      Some(@protocol.WindowId::new(2)),
      @protocol.SequenceId::new(3),
      "/prefer defend",
    ) {
    Some(@protocol.SubmitIntervention(intervention)) => {
      assert_true(intervention.side == @protocol.A)
      assert_true(intervention.window_id == @protocol.WindowId::new(2))
      assert_true(intervention.sequence_id == @protocol.SequenceId::new(3))
      assert_true(intervention.kind == @protocol.SoftPreference)
      assert_eq(intervention.text, "/prefer defend")
    }
    _ => fail("expected soft intervention")
  }
  match
    parse_supervisor_line(
      @protocol.A,
      Some(@protocol.WindowId::new(2)),
      @protocol.SequenceId::new(4),
      "/ban strike",
    ) {
    Some(@protocol.SubmitIntervention(intervention)) =>
      assert_true(intervention.kind == @protocol.HardConstraint)
    _ => fail("expected hard intervention")
  }
}

///|
test "client parses lock terminal line when window is open" {
  match
    parse_supervisor_line(
      @protocol.A,
      Some(@protocol.WindowId::new(2)),
      @protocol.SequenceId::new(3),
      "/lock",
    ) {
    Some(@protocol.LockWindow(side, window_id)) => {
      assert_true(side == @protocol.A)
      assert_true(window_id == @protocol.WindowId::new(2))
    }
    _ => fail("expected lock window input")
  }
}

///|
test "client rejects intervention terminal line without open window" {
  match
    parse_supervisor_line(
      @protocol.A,
      None,
      @protocol.SequenceId::new(1),
      "/prefer defend",
    ) {
    None => ()
    _ => fail("expected no input without open window")
  }
}

///|
test "client rejects lock terminal line without open window" {
  match
    parse_supervisor_line(
      @protocol.A,
      None,
      @protocol.SequenceId::new(1),
      "/lock",
    ) {
    None => ()
    _ => fail("expected no lock input without open window")
  }
}
