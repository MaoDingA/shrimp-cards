///|
test "client websocket parses host response frames" {
  match
    HostMessage::from_wire_text(
      @protocol.JoinAccepted(
        @protocol.PlayerIdentity::new("p1", "Alice", @protocol.A),
      ).to_wire_text(),
    ) {
    JoinMessage(@protocol.JoinAccepted(player)) =>
      assert_true(player.side == @protocol.A)
    _ => fail("expected join host message")
  }
  match
    HostMessage::from_wire_text(
      @protocol.HeartbeatAck(@protocol.A).to_wire_text(),
    ) {
    InputMessage(@protocol.HeartbeatAck(side)) =>
      assert_true(side == @protocol.A)
    _ => fail("expected heartbeat host message")
  }
  match
    HostMessage::from_wire_text(
      @protocol.ReadyAccepted(@protocol.B).to_wire_text(),
    ) {
    InputMessage(@protocol.ReadyAccepted(side)) =>
      assert_true(side == @protocol.B)
    _ => fail("expected input host message")
  }
}

///|
test "client websocket parses host event frames" {
  match
    HostMessage::from_wire_text(
      @protocol.InputWindowOpened(@protocol.WindowId::new(1)).to_wire_text(),
    ) {
    EventMessage(@protocol.InputWindowOpened(window_id)) =>
      assert_true(window_id == @protocol.WindowId::new(1))
    _ => fail("expected event host message")
  }
}

///|
async test "client websocket heartbeat helper reports live connection" {
  @async.with_task_group(group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    let received : Array[String] = []
    group.spawn_bg(no_wait=true, () => {
      server.run_forever((request, _, conn) => {
        let ws = @raw_ws.from_http_server(request, conn)
        defer ws.close()
        let frame = recv_server_text(ws)
        received.push(frame)
        ws.send_text(@protocol.HeartbeatAck(@protocol.B).to_wire_text())
      })
    })
    @async.sleep(50)
    assert_true(
      send_heartbeat_once(
        "ws://localhost:\{addr.port()}/match",
        @protocol.B,
        1000,
      ),
    )
    assert_eq(received, [@protocol.Heartbeat(@protocol.B).to_wire_text()])
  })
}

///|
async test "client websocket heartbeat helper reports timeout" {
  @async.with_task_group(group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(no_wait=true, () => {
      server.run_forever((request, _, conn) => {
        let ws = @raw_ws.from_http_server(request, conn)
        defer ws.close()
        ignore(ws.recv())
        @async.sleep(200)
      })
    })
    @async.sleep(50)
    assert_false(
      send_heartbeat_once(
        "ws://localhost:\{addr.port()}/match",
        @protocol.B,
        50,
      ),
    )
  })
}

///|
async test "client websocket live session sends heartbeat loop" {
  @async.with_task_group(group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    let received : Array[String] = []
    group.spawn_bg(no_wait=true, () => {
      server.run_forever((request, _, conn) => {
        let ws = @raw_ws.from_http_server(request, conn)
        defer ws.close()
        received.push(recv_server_text(ws))
        ws.send_text(
          @protocol.JoinAccepted(
            @protocol.PlayerIdentity::new("p1", "Alice", @protocol.A),
          ).to_wire_text(),
        )
        received.push(recv_server_text(ws))
      })
    })
    @async.sleep(50)
    let live = connect_live(
      @client.ClientConfig::new(
        player_id="p1",
        display_name="Alice",
        host_url="ws://localhost:\{addr.port()}/match",
      ),
    )
    match live.response {
      @protocol.JoinAccepted(player) => assert_true(player.side == @protocol.A)
      _ => fail("expected live join response")
    }
    group.spawn_bg(no_wait=true, () => {
      live.session.send_heartbeat_loop(@protocol.A, 25)
    })
    @async.sleep(90)
    live.session.close()
    assert_eq(received, [
      @protocol.JoinRequest::new("p1", "Alice").to_wire_text(),
      @protocol.Heartbeat(@protocol.A).to_wire_text(),
    ])
  })
}

///|
async fn recv_server_text(conn : @raw_ws.Conn) -> String {
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
async test "client websocket live session uses one connection" {
  @async.with_task_group(group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    let received : Array[String] = []
    group.spawn_bg(no_wait=true, () => {
      server.run_forever((request, _, conn) => {
        let ws = @raw_ws.from_http_server(request, conn)
        defer ws.close()
        received.push(recv_server_text(ws))
        ws.send_text(
          @protocol.JoinAccepted(
            @protocol.PlayerIdentity::new("p1", "Alice", @protocol.A),
          ).to_wire_text(),
        )
        ws.send_text(
          @protocol.InputWindowOpened(@protocol.WindowId::new(1)).to_wire_text(),
        )
        received.push(recv_server_text(ws))
      })
    })
    @async.sleep(50)
    let live = connect_live(
      @client.ClientConfig::new(
        player_id="p1",
        display_name="Alice",
        host_url="ws://localhost:\{addr.port()}/match",
      ),
    )
    match live.response {
      @protocol.JoinAccepted(player) => assert_true(player.side == @protocol.A)
      _ => fail("expected live join response")
    }
    match live.session.recv_message() {
      EventMessage(@protocol.InputWindowOpened(window_id)) =>
        assert_true(window_id == @protocol.WindowId::new(1))
      _ => fail("expected live event")
    }
    live.session.send_input(@protocol.Ready(@protocol.A))
    @async.sleep(50)
    assert_eq(received, [
      @protocol.JoinRequest::new("p1", "Alice").to_wire_text(),
      @protocol.Ready(@protocol.A).to_wire_text(),
    ])
    live.session.close()
  })
}

///|
async test "client websocket subscribes to event stream from cursor" {
  @async.with_task_group(group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    let received : Array[String] = []
    group.spawn_bg(no_wait=true, () => {
      server.run_forever((request, _, conn) => {
        let ws = @raw_ws.from_http_server(request, conn)
        defer ws.close()
        received.push(recv_server_text(ws))
        ws.send_text(@protocol.PlayerReady(@protocol.A).to_wire_text())
      })
    })
    @async.sleep(50)
    let session = subscribe_events("ws://localhost:\{addr.port()}/match", 2)
    match session.recv_message() {
      EventMessage(@protocol.PlayerReady(side)) =>
        assert_true(side == @protocol.A)
      _ => fail("expected subscribed event")
    }
    assert_eq(received, [@protocol.EventSubscription::new(2).to_wire_text()])
    session.close()
  })
}
