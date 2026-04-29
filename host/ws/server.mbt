///|
priv struct ClientConn {
  id : Int
  conn : @raw_ws.Conn
  send_lock : @async.Semaphore
  mut side : @protocol.Side?
}

///|
pub(all) struct HandshakeServerConfig {
  match_id : String
  replay_dir : String
  seed : Int
  created_at : String
  heartbeat_timeout_ms : Int
  heartbeat_scan_ms : Int
} derive(Eq, Debug)

///|
pub fn HandshakeServerConfig::new(
  match_id~ : String,
  replay_dir~ : String,
  seed~ : Int,
) -> HandshakeServerConfig {
  {
    match_id,
    replay_dir,
    seed,
    created_at: "local",
    heartbeat_timeout_ms: 30000,
    heartbeat_scan_ms: 1000,
  }
}

///|
pub fn HandshakeServerConfig::with_heartbeat(
  self : HandshakeServerConfig,
  timeout_ms~ : Int,
  scan_ms~ : Int,
) -> HandshakeServerConfig {
  {
    match_id: self.match_id,
    replay_dir: self.replay_dir,
    seed: self.seed,
    created_at: self.created_at,
    heartbeat_timeout_ms: timeout_ms,
    heartbeat_scan_ms: scan_ms,
  }
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
async fn ClientConn::send_text(self : ClientConn, frame : String) -> Unit {
  self.send_lock.acquire()
  defer self.send_lock.release()
  self.conn.send_text(frame) catch {
    _ => ()
  }
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
      client.send_text(frame)
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
fn input_side_from_frame(frame : String) -> @protocol.Side? {
  match @protocol.ClientInput::from_wire_text(frame) {
    Some(@protocol.Heartbeat(side)) => Some(side)
    Some(@protocol.Ready(side)) => Some(side)
    Some(@protocol.Leave(side)) => Some(side)
    Some(@protocol.LockWindow(side, _)) => Some(side)
    Some(@protocol.SubmitIntervention(intervention)) => Some(intervention.side)
    None => None
  }
}

///|
fn input_response_is_accepted(reply : String) -> Bool {
  match @protocol.InputResponse::from_wire_text(reply) {
    Some(@protocol.InputRejected(_)) => false
    Some(_) => true
    None => false
  }
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
  let saved = @protocol.ReplaySaved(replay_path)
  try {
    journal
    .to_event_log_with_event(config.replay_header(), saved)
    .save(replay_path)
    ignore(journal.append(saved))
    broadcast_events(clients, [saved], log)
  } catch {
    _ => {
      let failed = @protocol.ReplaySaveFailed(
        replay_path, "could not write replay",
      )
      ignore(journal.append(failed))
      broadcast_events(clients, [failed], log)
    }
  }
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
async fn publish_timeout_events(
  clients : Array[ClientConn],
  journal : @replay.ReplayEventJournal,
  session : @host.MatchSession,
  activity : ConnectionActivity,
  config : HandshakeServerConfig,
  log : (String) -> Unit,
) -> Unit {
  if config.heartbeat_timeout_ms > 0 && config.heartbeat_scan_ms > 0 {
    for ;; {
      @async.sleep(config.heartbeat_scan_ms)
      let events : Array[@protocol.ServerEvent] = []
      for side in activity.expired_sides(@async.now()) {
        for event in session.handle_disconnect(side) {
          events.push(event)
        }
      }
      if !events.is_empty() {
        publish_outcome_events(clients, journal, events, config, log)
      }
    }
  }
}

///|
async fn send_replay_events(
  client : ClientConn,
  journal : @replay.ReplayEventJournal,
  subscription : @protocol.EventSubscription,
) -> Unit {
  for record in journal.records_from(subscription.from_event_id) {
    client.send_text(record.event.to_wire_text())
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
  let session = @host.MatchSession::new_with_seed(seed=config.seed)
  let journal = @replay.ReplayEventJournal::new()
  let activity = ConnectionActivity::new(timeout_ms=config.heartbeat_timeout_ms)
  let clients : Array[ClientConn] = []
  let mut next_client_id = 1
  @async.with_task_group(group => {
    group.spawn_bg(no_wait=true, () => {
      publish_timeout_events(clients, journal, session, activity, config, log)
    })
    server.run_forever((request, _, conn) => {
      let ws = @raw_ws.from_http_server(request, conn)
      let client_id = next_client_id
      next_client_id += 1
      let client : ClientConn = {
        id: client_id,
        conn: ws,
        send_lock: @async.Semaphore::new(1),
        side: None,
      }
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
                  send_replay_events(client, journal, subscription)
                None => {
                  let input_side = input_side_from_frame(frame)
                  let outcome = session.handle_frame_outcome(frame)
                  let reply = outcome.reply_text()
                  client.send_text(reply)
                  log(reply)
                  match input_side {
                    Some(side) =>
                      if input_response_is_accepted(reply) {
                        activity.mark_seen(side, @async.now())
                      }
                    None => ()
                  }
                  let events = outcome.server_events()
                  match assigned_side(events) {
                    Some(side) => {
                      client.side = Some(side)
                      activity.mark_seen(side, @async.now())
                    }
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
  })
}
