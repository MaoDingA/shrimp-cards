///|
pub async fn join_once(config : @client.ClientConfig) -> @protocol.JoinResponse {
  let reply = @websocket.send_text_once(
    config.host_url,
    config.join_request().to_wire_text(),
  )
  match @protocol.JoinResponse::from_wire_text(reply) {
    Some(response) => response
    None => @protocol.JoinRejected("invalid host response")
  }
}
