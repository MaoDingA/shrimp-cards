///|
async test "websocket loopback sends text frames" {
  @async.with_task_group(group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(no_wait=true, () => {
      run_text_server(server, msg => "ack:\{msg}")
    })
    @async.sleep(50)
    let reply = send_text_once("ws://localhost:\{addr.port()}", "ping")
    assert_eq(reply, "ack:ping")
  })
}
