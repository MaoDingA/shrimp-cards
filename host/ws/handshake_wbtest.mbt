///|
async test "websocket host accepts two join clients" {
  @async.with_task_group(group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(no_wait=true, () => run_handshake_server(server, _ => ()))
    @async.sleep(50)
    let url = "ws://localhost:\{addr.port()}/match"
    let first = @client_ws.join_once(
      @client.ClientConfig::new(
        player_id="p1",
        display_name="Alice",
        host_url=url,
      ),
    )
    let second = @client_ws.join_once(
      @client.ClientConfig::new(
        player_id="p2",
        display_name="Bob",
        host_url=url,
      ),
    )
    match first {
      @protocol.JoinAccepted(player) => assert_true(player.side == @protocol.A)
      _ => fail("expected first player to be A")
    }
    match second {
      @protocol.JoinAccepted(player) => assert_true(player.side == @protocol.B)
      _ => fail("expected second player to be B")
    }
  })
}

///|
async test "websocket host opens input window after both ready frames" {
  @async.with_task_group(group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(no_wait=true, () => run_handshake_server(server, _ => ()))
    @async.sleep(50)
    let url = "ws://localhost:\{addr.port()}/match"
    ignore(
      @websocket.send_text_once(
        url,
        @protocol.JoinRequest::new("p1", "Alice").to_wire_text(),
      ),
    )
    ignore(
      @websocket.send_text_once(
        url,
        @protocol.JoinRequest::new("p2", "Bob").to_wire_text(),
      ),
    )
    let first = @client_ws.send_input_once(url, @protocol.Ready(@protocol.A))
    match first {
      @protocol.ReadyAccepted(side) => assert_true(side == @protocol.A)
      _ => fail("expected first ready to be acknowledged")
    }
    let second = @client_ws.send_input_once(url, @protocol.Ready(@protocol.B))
    match second {
      @protocol.WindowOpened(window_id) =>
        assert_true(window_id == @protocol.WindowId::new(1))
      _ => fail("expected second ready to open window")
    }
  })
}

///|
async fn recv_text_frame(conn : @raw_ws.Conn) -> String {
  let msg = conn.recv()
  match msg.kind {
    Text => msg.read_all().text()
    Binary => {
      ignore(msg.read_all().binary())
      ""
    }
  }
}

///|
async fn recv_text(conn : @raw_ws.Conn) -> String? {
  @async.with_timeout_opt(200, () => recv_text_frame(conn))
}

///|
async fn recv_join(conn : @raw_ws.Conn) -> @protocol.JoinResponse? {
  match recv_text(conn) {
    Some(frame) => @protocol.JoinResponse::from_wire_text(frame)
    None => None
  }
}

///|
async fn recv_event(conn : @raw_ws.Conn) -> @protocol.ServerEvent? {
  @async.with_timeout_opt(200, () => recv_next_event(conn))
}

///|
async fn recv_next_event(conn : @raw_ws.Conn) -> @protocol.ServerEvent {
  match @protocol.ServerEvent::from_wire_text(recv_text_frame(conn)) {
    Some(event) => event
    None => recv_next_event(conn)
  }
}

///|
async test "websocket host broadcasts events to connected clients" {
  @async.with_task_group(group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(no_wait=true, () => run_handshake_server(server, _ => ()))
    @async.sleep(50)
    let url = "ws://localhost:\{addr.port()}/match"
    let alice = @raw_ws.connect(url)
    defer alice.close()
    alice.send_text(@protocol.JoinRequest::new("p1", "Alice").to_wire_text())
    match recv_join(alice) {
      Some(@protocol.JoinAccepted(player)) =>
        assert_true(player.side == @protocol.A)
      _ => fail("expected Alice join response")
    }
    match recv_event(alice) {
      Some(@protocol.PlayerJoined(player)) =>
        assert_true(player.side == @protocol.A)
      _ => fail("expected Alice joined event")
    }
    let bob = @raw_ws.connect(url)
    defer bob.close()
    bob.send_text(@protocol.JoinRequest::new("p2", "Bob").to_wire_text())
    match recv_join(bob) {
      Some(@protocol.JoinAccepted(player)) =>
        assert_true(player.side == @protocol.B)
      _ => fail("expected Bob join response")
    }
    match recv_event(alice) {
      Some(@protocol.PlayerJoined(player)) =>
        assert_true(player.side == @protocol.B)
      _ => fail("expected Bob joined event for Alice")
    }
    match recv_event(bob) {
      Some(@protocol.PlayerJoined(player)) =>
        assert_true(player.side == @protocol.B)
      _ => fail("expected Bob joined event")
    }
    alice.send_text(@protocol.Ready(@protocol.A).to_wire_text())
    match recv_event(bob) {
      Some(@protocol.PlayerReady(side)) => assert_true(side == @protocol.A)
      _ => fail("expected Alice ready event for Bob")
    }
    bob.send_text(@protocol.Ready(@protocol.B).to_wire_text())
    match recv_event(alice) {
      Some(@protocol.PlayerReady(side)) => assert_true(side == @protocol.A)
      _ => fail("expected Alice ready event for Alice")
    }
    match recv_event(alice) {
      Some(@protocol.PlayerReady(side)) => assert_true(side == @protocol.B)
      _ => fail("expected Bob ready event for Alice")
    }
    match recv_event(alice) {
      Some(@protocol.InputWindowOpened(window_id)) =>
        assert_true(window_id == @protocol.WindowId::new(1))
      _ => fail("expected window event for Alice")
    }
    match recv_event(bob) {
      Some(@protocol.PlayerReady(side)) => assert_true(side == @protocol.B)
      _ => fail("expected Bob ready event for Bob")
    }
    match recv_event(bob) {
      Some(@protocol.InputWindowOpened(window_id)) =>
        assert_true(window_id == @protocol.WindowId::new(1))
      _ => fail("expected window event for Bob")
    }
  })
}
