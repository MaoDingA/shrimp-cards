///|
pub async fn run_handshake_server(
  server : @http.Server,
  log : (String) -> Unit,
) -> Unit {
  let session = @host.MatchSession::new()
  @websocket.run_text_server(server, frame => {
    let reply = session.handle_frame(frame)
    log(reply)
    reply
  })
}
