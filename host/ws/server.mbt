///|
pub async fn run_handshake_server(
  server : @http.Server,
  log : (String) -> Unit,
) -> Unit {
  let lobby = @host.Lobby::new()
  @websocket.run_text_server(server, frame => {
    let reply = lobby.handle_join_frame(frame)
    log(reply)
    reply
  })
}
