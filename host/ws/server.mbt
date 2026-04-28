///|
priv struct ClientConn {
  id : Int
  conn : @raw_ws.Conn
  mut side : @protocol.Side?
}

///|
pub(all) struct HandshakeServerConfig {
  match_id : String
  replay_dir : String
  seed : Int
  created_at : String
} derive(Eq, Debug)

///|
pub fn HandshakeServerConfig::new(
  match_id~ : String,
  replay_dir~ : String,
  seed~ : Int,
) -> HandshakeServerConfig {
  { match_id, replay_dir, seed, created_at: "local" }
}

///|
fn normalized_replay_dir(replay_dir : String) -> String {
  if replay_dir.is_empty() {
    "replays"
  } else if replay_dir.has_suffix("/") {
    replay_dir[:replay_dir.length() - 1].to_string()
  } else {
    replay_dir
  }
}

///|
pub fn HandshakeServerConfig::replay_path(
  self : HandshakeServerConfig,
) -> String {
  "\{normalized_replay_dir(self.replay_dir)}/\{self.match_id}.json"
}

///|
pub fn HandshakeServerConfig::replay_header(
  self : HandshakeServerConfig,
) -> @replay.ReplayHeader {
  @replay.ReplayHeader::new(
    self.match_id,
    self.created_at,
    self.seed,
    @protocol.protocol_version,
    @replay.replay_format_version,
  )
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
fn assigned_side(events : Array[@protocol.ServerEvent]) -> @protocol.Side? {
  let mut side : @protocol.Side? = None
  for event in events {
    match event {
      @protocol.PlayerJoined(player) => side = Some(player.side)
      _ => ()
    }
  }
  side
}

///|
fn includes_match_end(events : Array[@protocol.ServerEvent]) -> Bool {
  let mut found = false
  for event in events {
    match event {
      @protocol.MatchEnded(_) => found = true
      _ => ()
    }
  }
  found
}

///|
async fn publish_events(
  clients : Array[ClientConn],
  journal : @replay.ReplayEventJournal,
  events : Array[@protocol.ServerEvent],
  log : (String) -> Unit,
) -> Unit {
  for event in events {
    ignore(journal.append(event))
  }
  broadcast_events(clients, events, log)
}

///|
async fn save_replay_and_publish(
  clients : Array[ClientConn],
  journal : @replay.ReplayEventJournal,
  config : HandshakeServerConfig,
  log : (String) -> Unit,
) -> Unit {
  let replay_path = config.replay_path()
  let event = @protocol.ReplaySaved(replay_path)
  ignore(journal.append(event))
  journal.to_event_log(config.replay_header()).save(replay_path) catch {
    _ => ()
  }
  broadcast_events(clients, [event], log)
}

///|
async fn publish_outcome_events(
  clients : Array[ClientConn],
  journal : @replay.ReplayEventJournal,
  events : Array[@protocol.ServerEvent],
  config : HandshakeServerConfig,
  log : (String) -> Unit,
) -> Unit {
  publish_events(clients, journal, events, log)
  if includes_match_end(events) {
    save_replay_and_publish(clients, journal, config, log)
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
  run_handshake_server_with_config(
    server,
    HandshakeServerConfig::new(
      match_id="match-\{server.addr.port()}",
      replay_dir="replays",
      seed=0,
    ),
    log,
  )
}

///|
pub async fn run_handshake_server_with_config(
  server : @http.Server,
  config : HandshakeServerConfig,
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
    let client : ClientConn = { id: client_id, conn: ws, side: None }
    clients.push(client)
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
                match assigned_side(events) {
                  Some(side) => client.side = Some(side)
                  None => ()
                }
                publish_outcome_events(clients, journal, events, config, log)
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
      @raw_ws.ConnectionClosed(_, _) =>
        match client.side {
          Some(side) => {
            let events = session.handle_disconnect(side)
            publish_outcome_events(clients, journal, events, config, log)
          }
          None => ()
        }
      _ => ()
    }
  })
}
