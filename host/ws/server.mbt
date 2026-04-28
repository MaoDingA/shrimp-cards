///|
priv struct ClientConn {
  id : Int
  conn : @raw_ws.Conn
}

///|
async fn broadcast_events(
  clients : Array[ClientConn],
  events : Array[@protocol.ServerEvent],
  log : (String) -> Unit,
) -> Unit {
  for event in events {
    let frame = event.to_wire_text()
    for client in clients {
      client.conn.send_text(frame) catch {
        _ => ()
      }
    }
    log(frame)
  }
}

///|
pub async fn run_handshake_server(
  server : @http.Server,
  log : (String) -> Unit,
) -> Unit {
  let session = @host.MatchSession::new()
  let clients : Array[ClientConn] = []
  let mut next_client_id = 1
  server.run_forever((request, _, conn) => {
    let ws = @raw_ws.from_http_server(request, conn)
    let client_id = next_client_id
    next_client_id += 1
    clients.push({ id: client_id, conn: ws })
    defer {
      clients.retain(client => client.id != client_id)
      ws.close()
    }
    try {
      for ;; {
        let msg = ws.recv()
        match msg.kind {
          Text => {
            let outcome = session.handle_frame_outcome(msg.read_all().text())
            ws.send_text(outcome.reply_text())
            log(outcome.reply_text())
            broadcast_events(clients, outcome.server_events(), log)
          }
          Binary => {
            ignore(msg.read_all().binary())
            ws.send_close(code=UnsupportedData, reason="text frames only")
          }
        }
      }
    } catch {
      @raw_ws.ConnectionClosed(_, _) => ()
      _ => ()
    }
  })
}
