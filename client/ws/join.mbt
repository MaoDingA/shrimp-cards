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

///|
pub async fn send_heartbeat_once(
  host_url : String,
  side : @protocol.Side,
  timeout_ms : Int,
) -> Bool {
  match
    @websocket.send_text_once_with_timeout(
      host_url,
      @protocol.Heartbeat(side).to_wire_text(),
      timeout_ms,
    ) {
    Some(reply) =>
      match @protocol.InputResponse::from_wire_text(reply) {
        Some(@protocol.HeartbeatAck(ack_side)) => ack_side == side
        _ => false
      }
    None => false
  }
}

///|
pub struct LiveSession {
  priv conn : @raw_ws.Conn
}

///|
pub(all) struct LiveJoin {
  session : LiveSession
  response : @protocol.JoinResponse
}

///|
async fn read_text(conn : @raw_ws.Conn) -> String {
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
pub async fn connect_live(config : @client.ClientConfig) -> LiveJoin {
  let conn = @raw_ws.connect(config.host_url)
  conn.send_text(config.join_request().to_wire_text())
  let response = match @protocol.JoinResponse::from_wire_text(read_text(conn)) {
    Some(response) => response
    None => @protocol.JoinRejected("invalid host response")
  }
  { session: { conn, }, response }
}

///|
pub async fn subscribe_events(
  host_url : String,
  from_event_id : Int,
) -> LiveSession {
  let conn = @raw_ws.connect(host_url)
  conn.send_text(@protocol.EventSubscription::new(from_event_id).to_wire_text())
  { conn, }
}

///|
pub async fn LiveSession::recv_message(self : LiveSession) -> HostMessage {
  HostMessage::from_wire_text(read_text(self.conn))
}

///|
pub async fn LiveSession::send_input(
  self : LiveSession,
  input : @protocol.ClientInput,
) -> Unit {
  self.conn.send_text(input.to_wire_text())
}

///|
pub async fn LiveSession::send_heartbeat_loop(
  self : LiveSession,
  side : @protocol.Side,
  interval_ms : Int,
) -> Unit {
  let delay = if interval_ms <= 0 { 1000 } else { interval_ms }
  let mut running = true
  while running {
    @async.sleep(delay)
    self.conn.send_text(@protocol.Heartbeat(side).to_wire_text()) catch {
      _ => running = false
    }
  }
}

///|
pub fn LiveSession::close(self : LiveSession) -> Unit {
  self.conn.close()
}
