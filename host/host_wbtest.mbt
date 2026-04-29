///|
test "host lobby assigns first two players to seats" {
  let lobby = Lobby::new()
  let first = lobby.accept_join(@protocol.JoinRequest::new("p1", "Alice"))
  let second = lobby.accept_join(@protocol.JoinRequest::new("p2", "Bob"))
  match first {
    Accepted(player) => assert_true(player.side == @protocol.A)
    _ => fail("expected first player to be accepted")
  }
  match second {
    Accepted(player) => assert_true(player.side == @protocol.B)
    _ => fail("expected second player to be accepted")
  }
  assert_true(lobby.is_ready_to_start())
}

///|
test "host lobby rejects third player" {
  let lobby = Lobby::new()
  ignore(lobby.accept_join(@protocol.JoinRequest::new("p1", "Alice")))
  ignore(lobby.accept_join(@protocol.JoinRequest::new("p2", "Bob")))
  let third = lobby.accept_join(@protocol.JoinRequest::new("p3", "Carol"))
  match third {
    Rejected(reason) => assert_eq(reason, "match is full")
    _ => fail("expected third player to be rejected")
  }
}

///|
test "host lobby handles join wire text" {
  let lobby = Lobby::new()
  let frame = @protocol.JoinRequest::new("p1", "Alice").to_wire_text()
  let reply = lobby.handle_join_frame(frame)
  match @protocol.JoinResponse::from_wire_text(reply) {
    Some(@protocol.JoinAccepted(player)) => {
      assert_eq(player.player_id, "p1")
      assert_eq(player.display_name, "Alice")
      assert_true(player.side == @protocol.A)
    }
    _ => fail("expected accepted response")
  }
}

///|
test "match session opens first window after both players are ready" {
  let session = MatchSession::new()
  ignore(
    session.handle_frame(
      @protocol.JoinRequest::new("p1", "Alice").to_wire_text(),
    ),
  )
  ignore(
    session.handle_frame(@protocol.JoinRequest::new("p2", "Bob").to_wire_text()),
  )
  let first = session.handle_frame(@protocol.Ready(@protocol.A).to_wire_text())
  match @protocol.InputResponse::from_wire_text(first) {
    Some(@protocol.ReadyAccepted(side)) => assert_true(side == @protocol.A)
    _ => fail("expected ready accepted")
  }
  let second = session.handle_frame(@protocol.Ready(@protocol.B).to_wire_text())
  match @protocol.InputResponse::from_wire_text(second) {
    Some(@protocol.WindowOpened(window_id)) =>
      assert_true(window_id == @protocol.WindowId::new(1))
    _ => fail("expected first window to open")
  }
}

///|
test "match session accepts intervention only for open window" {
  let session = MatchSession::new()
  ignore(
    session.handle_frame(
      @protocol.JoinRequest::new("p1", "Alice").to_wire_text(),
    ),
  )
  ignore(
    session.handle_frame(@protocol.JoinRequest::new("p2", "Bob").to_wire_text()),
  )
  let intervention = @protocol.Intervention::new(
    side=@protocol.A,
    window_id=@protocol.WindowId::new(1),
    sequence_id=@protocol.SequenceId::new(1),
    kind=@protocol.SoftPreference,
    text="/prefer defend",
  )
  let rejected = session.handle_frame(
    @protocol.SubmitIntervention(intervention).to_wire_text(),
  )
  match @protocol.InputResponse::from_wire_text(rejected) {
    Some(@protocol.InputRejected(reason)) =>
      assert_eq(reason, "no open input window")
    _ => fail("expected intervention to be rejected before ready")
  }
  ignore(session.handle_frame(@protocol.Ready(@protocol.A).to_wire_text()))
  ignore(session.handle_frame(@protocol.Ready(@protocol.B).to_wire_text()))
  let accepted = session.handle_frame(
    @protocol.SubmitIntervention(intervention).to_wire_text(),
  )
  match @protocol.InputResponse::from_wire_text(accepted) {
    Some(@protocol.InterventionAccepted(decoded)) =>
      assert_true(decoded.side == @protocol.A)
    _ => fail("expected intervention to be accepted")
  }
}

///|
test "match session handles leave input" {
  let session = MatchSession::new()
  ignore(
    session.handle_frame(
      @protocol.JoinRequest::new("p1", "Alice").to_wire_text(),
    ),
  )
  let reply = session.handle_frame(@protocol.Leave(@protocol.A).to_wire_text())
  match @protocol.InputResponse::from_wire_text(reply) {
    Some(@protocol.MatchLeft(side)) => assert_true(side == @protocol.A)
    _ => fail("expected leave response")
  }
}

///|
test "match session acknowledges heartbeat for seated side" {
  let session = MatchSession::new()
  ignore(
    session.handle_frame(
      @protocol.JoinRequest::new("p1", "Alice").to_wire_text(),
    ),
  )
  let outcome = session.handle_frame_outcome(
    @protocol.Heartbeat(@protocol.A).to_wire_text(),
  )
  match @protocol.InputResponse::from_wire_text(outcome.reply_text()) {
    Some(@protocol.HeartbeatAck(side)) => assert_true(side == @protocol.A)
    _ => fail("expected heartbeat ack")
  }
  match outcome.server_events() {
    [] => ()
    _ => fail("heartbeat should not create replay events")
  }
}

///|
test "match session emits public event when player joins" {
  let session = MatchSession::new()
  let events = session.handle_frame_events(
    @protocol.JoinRequest::new("p1", "Alice").to_wire_text(),
  )
  match events {
    [@protocol.PlayerJoined(player)] => {
      assert_eq(player.display_name, "Alice")
      assert_true(player.side == @protocol.A)
    }
    _ => fail("expected joined event")
  }
}

///|
test "match session emits ready then window opened events" {
  let session = MatchSession::new()
  ignore(
    session.handle_frame_events(
      @protocol.JoinRequest::new("p1", "Alice").to_wire_text(),
    ),
  )
  ignore(
    session.handle_frame_events(
      @protocol.JoinRequest::new("p2", "Bob").to_wire_text(),
    ),
  )
  match
    session.handle_frame_events(@protocol.Ready(@protocol.A).to_wire_text()) {
    [@protocol.PlayerReady(side)] => assert_true(side == @protocol.A)
    _ => fail("expected A ready event")
  }
  match
    session.handle_frame_events(@protocol.Ready(@protocol.B).to_wire_text()) {
    [
      @protocol.PlayerReady(side),
      @protocol.MatchStarted,
      @protocol.InputWindowOpened(window_id),
      @protocol.AgentPlanIssued(plan_a),
      @protocol.AgentPlanIssued(plan_b),
    ] => {
      assert_true(side == @protocol.B)
      assert_true(window_id == @protocol.WindowId::new(1))
      assert_true(plan_a.side == @protocol.A)
      assert_true(plan_a.phase == @protocol.InitialPlan)
      assert_true(plan_b.side == @protocol.B)
      assert_true(plan_b.phase == @protocol.InitialPlan)
    }
    _ => fail("expected B ready, match started, window and initial plans")
  }
}

///|
test "match session emits intervention and leave events" {
  let session = MatchSession::new()
  ignore(
    session.handle_frame_events(
      @protocol.JoinRequest::new("p1", "Alice").to_wire_text(),
    ),
  )
  ignore(
    session.handle_frame_events(
      @protocol.JoinRequest::new("p2", "Bob").to_wire_text(),
    ),
  )
  ignore(
    session.handle_frame_events(@protocol.Ready(@protocol.A).to_wire_text()),
  )
  ignore(
    session.handle_frame_events(@protocol.Ready(@protocol.B).to_wire_text()),
  )
  let intervention = @protocol.Intervention::new(
    side=@protocol.A,
    window_id=@protocol.WindowId::new(1),
    sequence_id=@protocol.SequenceId::new(1),
    kind=@protocol.SoftPreference,
    text="/prefer defend",
  )
  match
    session.handle_frame_events(
      @protocol.SubmitIntervention(intervention).to_wire_text(),
    ) {
    [@protocol.InterventionSubmitted(decoded)] =>
      assert_true(decoded.side == @protocol.A)
    _ => fail("expected intervention event")
  }
  match
    session.handle_frame_events(@protocol.Leave(@protocol.B).to_wire_text()) {
    [@protocol.PlayerLeft(side), @protocol.MatchEnded(reason)] => {
      assert_true(side == @protocol.B)
      assert_eq(reason, "B left")
    }
    _ => fail("expected leave and match ended events")
  }
}

///|
test "match session emits protocol error for invalid frame" {
  let session = MatchSession::new()
  let outcome = session.handle_frame_outcome("not a protocol frame")
  match @protocol.InputResponse::from_wire_text(outcome.reply_text()) {
    Some(@protocol.InputRejected(reason)) => assert_eq(reason, "invalid input")
    _ => fail("expected invalid input response")
  }
  match outcome.server_events() {
    [@protocol.ProtocolError(reason)] => assert_eq(reason, "invalid input")
    _ => fail("expected public protocol error event")
  }
}

///|
test "match session ends on player disconnect after start" {
  let session = MatchSession::new()
  ignore(
    session.handle_frame_events(
      @protocol.JoinRequest::new("p1", "Alice").to_wire_text(),
    ),
  )
  ignore(
    session.handle_frame_events(
      @protocol.JoinRequest::new("p2", "Bob").to_wire_text(),
    ),
  )
  ignore(
    session.handle_frame_events(@protocol.Ready(@protocol.A).to_wire_text()),
  )
  ignore(
    session.handle_frame_events(@protocol.Ready(@protocol.B).to_wire_text()),
  )
  match session.handle_disconnect(@protocol.A) {
    [@protocol.PlayerDisconnected(side), @protocol.MatchEnded(reason)] => {
      assert_true(side == @protocol.A)
      assert_eq(reason, "A disconnected")
    }
    _ => fail("expected disconnect and match ended events")
  }
  match session.handle_disconnect(@protocol.A) {
    [] => ()
    _ => fail("expected duplicate disconnect to be ignored")
  }
}

///|
test "match session locks window executes placeholder and opens next window" {
  let session = MatchSession::new()
  ignore(
    session.handle_frame_events(
      @protocol.JoinRequest::new("p1", "Alice").to_wire_text(),
    ),
  )
  ignore(
    session.handle_frame_events(
      @protocol.JoinRequest::new("p2", "Bob").to_wire_text(),
    ),
  )
  ignore(
    session.handle_frame_events(@protocol.Ready(@protocol.A).to_wire_text()),
  )
  ignore(
    session.handle_frame_events(@protocol.Ready(@protocol.B).to_wire_text()),
  )
  let intervention = @protocol.Intervention::new(
    side=@protocol.A,
    window_id=@protocol.WindowId::new(1),
    sequence_id=@protocol.SequenceId::new(1),
    kind=@protocol.SoftPreference,
    text="/prefer defend",
  )
  ignore(
    session.handle_frame_events(
      @protocol.SubmitIntervention(intervention).to_wire_text(),
    ),
  )
  match session.lock_current_window() {
    [
      @protocol.WindowLocked(locked),
      @protocol.AgentPlanIssued(final_a),
      @protocol.AgentPlanIssued(final_b),
      @protocol.WindowExecuted(executed),
      @protocol.InputWindowOpened(next),
      @protocol.AgentPlanIssued(initial_a),
      @protocol.AgentPlanIssued(initial_b),
    ] => {
      assert_true(locked == @protocol.WindowId::new(1))
      assert_true(final_a.side == @protocol.A)
      assert_true(final_a.phase == @protocol.FinalPlan)
      assert_true(final_b.side == @protocol.B)
      assert_true(final_b.phase == @protocol.FinalPlan)
      assert_true(executed == @protocol.WindowId::new(1))
      assert_true(next == @protocol.WindowId::new(2))
      assert_true(initial_a.phase == @protocol.InitialPlan)
      assert_true(initial_b.phase == @protocol.InitialPlan)
    }
    _ => fail("expected lock, final plans, execution and next window")
  }
}

///|
test "match session handles lock input for current window" {
  let session = MatchSession::new()
  ignore(
    session.handle_frame_events(
      @protocol.JoinRequest::new("p1", "Alice").to_wire_text(),
    ),
  )
  ignore(
    session.handle_frame_events(
      @protocol.JoinRequest::new("p2", "Bob").to_wire_text(),
    ),
  )
  ignore(
    session.handle_frame_events(@protocol.Ready(@protocol.A).to_wire_text()),
  )
  ignore(
    session.handle_frame_events(@protocol.Ready(@protocol.B).to_wire_text()),
  )
  let reply = session.handle_frame(
    @protocol.LockWindow(@protocol.A, @protocol.WindowId::new(1)).to_wire_text(),
  )
  match @protocol.InputResponse::from_wire_text(reply) {
    Some(@protocol.WindowLockedAck(window_id)) =>
      assert_true(window_id == @protocol.WindowId::new(1))
    _ => fail("expected window lock acknowledgement")
  }
  let stale = @protocol.Intervention::new(
    side=@protocol.B,
    window_id=@protocol.WindowId::new(1),
    sequence_id=@protocol.SequenceId::new(2),
    kind=@protocol.SoftPreference,
    text="/prefer wait",
  )
  match
    @protocol.InputResponse::from_wire_text(
      session.handle_frame(@protocol.SubmitIntervention(stale).to_wire_text()),
    ) {
    Some(@protocol.InputRejected(reason)) =>
      assert_eq(reason, "stale input window")
    _ => fail("expected stale intervention after lock")
  }
}
