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
async fn send_replay_events(
  conn : @raw_ws.Conn,
  journal : @replay.ReplayEventJournal,
  subscription : @protocol.EventSubscription,
) -> Unit {
  for record in journal.records_from(subscription.from_event_id) {
    conn.send_text(record.event.to_wire_text())
  }
}

///|
pub async fn run_handshake_server(
  server : @http.Server,
  log : (String) -> Unit,
) -> Unit {
  let session = @host.MatchSession::new()
  let journal = @replay.ReplayEventJournal::new()
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
            let frame = msg.read_all().text()
            match @protocol.EventSubscription::from_wire_text(frame) {
              Some(subscription) =>
                send_replay_events(ws, journal, subscription)
              None => {
                let outcome = session.handle_frame_outcome(frame)
                ws.send_text(outcome.reply_text())
                log(outcome.reply_text())
                let events = outcome.server_events()
                for event in events {
                  ignore(journal.append(event))
                }
                broadcast_events(clients, events, log)
              }
            }
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
