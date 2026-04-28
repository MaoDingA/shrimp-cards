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
