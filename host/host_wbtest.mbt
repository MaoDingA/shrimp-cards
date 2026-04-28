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
