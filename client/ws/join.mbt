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

///|
pub async fn send_input_once(
  host_url : String,
  input : @protocol.ClientInput,
) -> @protocol.InputResponse {
  let reply = @websocket.send_text_once(host_url, input.to_wire_text())
  match @protocol.InputResponse::from_wire_text(reply) {
    Some(response) => response
    None => @protocol.InputRejected("invalid host response")
  }
}
