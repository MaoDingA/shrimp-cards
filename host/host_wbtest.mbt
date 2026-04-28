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
