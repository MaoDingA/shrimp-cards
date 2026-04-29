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
async fn recv_replay_saved_path(conn : @raw_ws.Conn) -> String? {
  match recv_event(conn) {
    Some(@protocol.ReplaySaved(path)) => Some(path)
    Some(_) => recv_replay_saved_path(conn)
    None => None
  }
}

///|
async fn recv_replay_save_failed(conn : @raw_ws.Conn) -> @protocol.ServerEvent? {
  match recv_event(conn) {
    Some(@protocol.ReplaySaveFailed(_, _) as event) => Some(event)
    Some(_) => recv_replay_save_failed(conn)
    None => None
  }
}

///|
async fn recv_disconnected_side(conn : @raw_ws.Conn) -> @protocol.Side? {
  match recv_event(conn) {
    Some(@protocol.PlayerDisconnected(side)) => Some(side)
    Some(_) => recv_disconnected_side(conn)
    None => None
  }
}

///|
async fn recv_match_end_reason(conn : @raw_ws.Conn) -> String? {
  match recv_event(conn) {
    Some(@protocol.MatchEnded(reason)) => Some(reason)
    Some(_) => recv_match_end_reason(conn)
    None => None
  }
}

///|
test "connection activity expires stale side once" {
  let activity = ConnectionActivity::new(timeout_ms=100)
  activity.mark_seen(@protocol.A, 1000)
  activity.mark_seen(@protocol.B, 1050)
  match activity.expired_sides(1099) {
    [] => ()
    _ => fail("expected no stale sides before timeout")
  }
  match activity.expired_sides(1100) {
    [@protocol.A] => ()
    _ => fail("expected A to expire first")
  }
  match activity.expired_sides(1150) {
    [@protocol.B] => ()
    _ => fail("expected B to expire second")
  }
  match activity.expired_sides(1200) {
    [] => ()
    _ => fail("expected expired sides to be reported once")
  }
}

///|
test "websocket host config builds replay metadata" {
  let config = HandshakeServerConfig::new(
    match_id="local-match",
    replay_dir="_build/custom-replays/",
    seed=42,
  )
  assert_eq(config.replay_path(), "_build/custom-replays/local-match.json")
  let header = config.replay_header()
  assert_eq(header.match_id, "local-match")
  assert_eq(header.seed, 42)
  assert_eq(config.heartbeat_timeout_ms, 30000)
  assert_eq(config.heartbeat_scan_ms, 1000)
  let heartbeat_config = config.with_heartbeat(timeout_ms=120, scan_ms=30)
  assert_eq(heartbeat_config.heartbeat_timeout_ms, 120)
  assert_eq(heartbeat_config.heartbeat_scan_ms, 30)
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
      Some(@protocol.MatchStarted) => ()
      _ => fail("expected match started event for Alice")
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
      Some(@protocol.MatchStarted) => ()
      _ => fail("expected match started event for Bob")
    }
    match recv_event(bob) {
      Some(@protocol.InputWindowOpened(window_id)) =>
        assert_true(window_id == @protocol.WindowId::new(1))
      _ => fail("expected window event for Bob")
    }
  })
}

///|
async test "websocket host replays subscribed events from cursor" {
  @async.with_task_group(group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(no_wait=true, () => run_handshake_server(server, _ => ()))
    @async.sleep(50)
    let url = "ws://localhost:\{addr.port()}/match"
    let alice = @raw_ws.connect(url)
    defer alice.close()
    alice.send_text(@protocol.JoinRequest::new("p1", "Alice").to_wire_text())
    ignore(recv_join(alice))
    ignore(recv_event(alice))
    let bob = @raw_ws.connect(url)
    defer bob.close()
    bob.send_text(@protocol.JoinRequest::new("p2", "Bob").to_wire_text())
    ignore(recv_join(bob))
    ignore(recv_event(alice))
    ignore(recv_event(bob))
    let watcher = @raw_ws.connect(url)
    defer watcher.close()
    watcher.send_text(@protocol.EventSubscription::new(1).to_wire_text())
    match recv_event(watcher) {
      Some(@protocol.PlayerJoined(player)) =>
        assert_true(player.side == @protocol.B)
      _ => fail("expected replayed Bob joined event")
    }
    alice.send_text(@protocol.Ready(@protocol.A).to_wire_text())
    match recv_event(watcher) {
      Some(@protocol.PlayerReady(side)) => assert_true(side == @protocol.A)
      _ => fail("expected live ready event for watcher")
    }
  })
}

///|
async test "websocket host saves replay when player leaves" {
  @async.with_task_group(group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(no_wait=true, () => run_handshake_server(server, _ => ()))
    @async.sleep(50)
    let url = "ws://localhost:\{addr.port()}/match"
    let alice = @raw_ws.connect(url)
    defer alice.close()
    alice.send_text(@protocol.JoinRequest::new("p1", "Alice").to_wire_text())
    ignore(recv_join(alice))
    ignore(recv_event(alice))
    let bob = @raw_ws.connect(url)
    defer bob.close()
    bob.send_text(@protocol.JoinRequest::new("p2", "Bob").to_wire_text())
    ignore(recv_join(bob))
    ignore(recv_event(alice))
    ignore(recv_event(bob))
    alice.send_text(@protocol.Ready(@protocol.A).to_wire_text())
    ignore(recv_event(alice))
    ignore(recv_event(bob))
    bob.send_text(@protocol.Ready(@protocol.B).to_wire_text())
    ignore(recv_event(alice))
    ignore(recv_event(alice))
    ignore(recv_event(alice))
    ignore(recv_event(alice))
    ignore(recv_event(alice))
    alice.send_text(@protocol.Leave(@protocol.A).to_wire_text())
    match recv_replay_saved_path(bob) {
      Some(path) =>
        match @replay.load_event_log(path) {
          Some(log) => {
            @fs.remove(path) catch {
              _ => ()
            }
            let records = log.records_from(0)
            assert_true(records.length() > 0)
            match records.get(records.length() - 1) {
              Some(record) =>
                match record.event {
                  @protocol.ReplaySaved(saved) => assert_eq(saved, path)
                  _ =>
                    fail("expected saved replay to include replay saved event")
                }
              None => fail("expected replay records")
            }
          }
          None => fail("expected saved replay event log")
        }
      None => fail("expected replay saved event")
    }
  })
}

///|
async test "websocket host publishes replay save failure" {
  @async.with_task_group(group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    let bad_parent = "_build/replay-save-failure-parent-\{addr.port()}"
    @fs.write_file(bad_parent, "not a directory", create_mode=CreateOrTruncate)
    let config = HandshakeServerConfig::new(
      match_id="match",
      replay_dir=bad_parent,
      seed=1,
    )
    group.spawn_bg(no_wait=true, () => {
      run_handshake_server_with_config(server, config, _ => ())
    })
    @async.sleep(50)
    let url = "ws://localhost:\{addr.port()}/match"
    let alice = @raw_ws.connect(url)
    defer alice.close()
    alice.send_text(@protocol.JoinRequest::new("p1", "Alice").to_wire_text())
    ignore(recv_join(alice))
    ignore(recv_event(alice))
    alice.send_text(@protocol.Leave(@protocol.A).to_wire_text())
    match recv_replay_save_failed(alice) {
      Some(@protocol.ReplaySaveFailed(path, reason)) => {
        assert_eq(path, "\{bad_parent}/match.json")
        assert_eq(reason, "could not write replay")
      }
      _ => fail("expected replay save failure event")
    }
    @fs.remove(bad_parent) catch {
      _ => ()
    }
  })
}

///|
async test "websocket host ends match when heartbeat times out" {
  @async.with_task_group(group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    let replay_dir = "_build/heartbeat-timeout-\{addr.port()}"
    let config = HandshakeServerConfig::new(
      match_id="match",
      replay_dir~,
      seed=1,
    ).with_heartbeat(timeout_ms=160, scan_ms=30)
    group.spawn_bg(no_wait=true, () => {
      run_handshake_server_with_config(server, config, _ => ())
    })
    @async.sleep(50)
    let url = "ws://localhost:\{addr.port()}/match"
    let alice = @raw_ws.connect(url)
    defer alice.close()
    alice.send_text(@protocol.JoinRequest::new("p1", "Alice").to_wire_text())
    ignore(recv_join(alice))
    ignore(recv_event(alice))
    let bob = @raw_ws.connect(url)
    defer bob.close()
    bob.send_text(@protocol.JoinRequest::new("p2", "Bob").to_wire_text())
    ignore(recv_join(bob))
    ignore(recv_event(alice))
    ignore(recv_event(bob))
    alice.send_text(@protocol.Ready(@protocol.A).to_wire_text())
    bob.send_text(@protocol.Ready(@protocol.B).to_wire_text())
    match recv_disconnected_side(alice) {
      Some(side) => assert_true(side == @protocol.A)
      None => fail("expected heartbeat timeout disconnect")
    }
    match recv_match_end_reason(alice) {
      Some(reason) => assert_eq(reason, "A disconnected")
      None => fail("expected heartbeat timeout to end match")
    }
    match recv_replay_saved_path(alice) {
      Some(path) => @fs.remove(path) catch { _ => () }
      None => fail("expected timeout replay to be saved")
    }
  })
}
