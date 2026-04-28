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
