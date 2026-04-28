///|

///|
fn log_server_reply(frame : String) -> Unit {
  println(@client_ws.HostMessage::from_wire_text(frame).summary())
}

///|
fn updated_window_from_host_message(
  message : @client_ws.HostMessage,
  current : @protocol.WindowId?,
) -> @protocol.WindowId? {
  match message.opened_window() {
    Some(window_id) => Some(window_id)
    None => current
  }
}

///|
fn should_print_host_message(message : @client_ws.HostMessage) -> Bool {
  match message {
    EventMessage(_) => true
    InputMessage(InputRejected(_)) => true
    JoinMessage(JoinRejected(_)) => true
    UnknownHostFrame(_) => true
    _ => false
  }
}

///|
fn visible_host_message_summary(
  message : @client_ws.HostMessage,
  viewer : @protocol.Side,
) -> String? {
  match message {
    EventMessage(event) =>
      match @visibility.visible_event_for_side(event, viewer) {
        Some(visible) => Some(@client_ws.EventMessage(visible).summary())
        None => None
      }
    _ =>
      if should_print_host_message(message) {
        Some(message.summary())
      } else {
        None
      }
  }
}

///|
fn window_label(current : @protocol.WindowId?) -> String {
  match current {
    Some(window_id) => "\{window_id.value()}"
    None => "waiting"
  }
}

///|
fn terminal_input_line(current : @protocol.WindowId?) -> String {
  match current {
    Some(_) => "[input] /prefer <text> | /ban <text> | /lock | /leave"
    None => "[input] /ready | /leave"
  }
}

///|
struct TerminalViewState {
  viewer : @protocol.Side
  mut current_window_id : @protocol.WindowId?
  mut ended : Bool
  mut replay_path : String
  logs : Array[String]
} derive(Eq, Debug)

///|
fn TerminalViewState::new(viewer : @protocol.Side) -> TerminalViewState {
  { viewer, current_window_id: None, ended: false, replay_path: "", logs: [] }
}

///|
fn TerminalViewState::status_label(self : TerminalViewState) -> String {
  if self.ended {
    "ended"
  } else {
    "active"
  }
}

///|
fn TerminalViewState::replay_label(self : TerminalViewState) -> String {
  if self.replay_path.is_empty() {
    "pending"
  } else {
    self.replay_path
  }
}

///|
fn TerminalViewState::apply_host_message(
  self : TerminalViewState,
  message : @client_ws.HostMessage,
) -> Unit {
  self.current_window_id = updated_window_from_host_message(
    message,
    self.current_window_id,
  )
  match message {
    EventMessage(MatchEnded(_)) => self.ended = true
    EventMessage(ReplaySaved(path)) => self.replay_path = path
    _ => ()
  }
  match visible_host_message_summary(message, self.viewer) {
    Some(summary) => self.logs.push(summary)
    None => ()
  }
}

///|
fn TerminalViewState::screen_lines(self : TerminalViewState) -> Array[String] {
  let lines : Array[String] = [
    "[panel] seat \{self.viewer.label()} | window \{window_label(self.current_window_id)} | status \{self.status_label()} | replay \{self.replay_label()}",
    "[log]",
  ]
  let start = if self.logs.length() > 8 { self.logs.length() - 8 } else { 0 }
  for index in start..<self.logs.length() {
    lines.push(self.logs[index])
  }
  lines.push(terminal_input_line(self.current_window_id))
  lines
}

///|
fn print_lines(lines : Array[String]) -> Unit {
  for line in lines {
    println(line)
  }
}

///|
fn print_terminal_screen(state : TerminalViewState) -> Unit {
  println("\u{1B}[2J\u{1B}[H")
  print_lines(state.screen_lines())
}

///|
async fn run_join(options : @cli.JoinOptions) -> Unit {
  let config = @client.ClientConfig::new(
    player_id=options.display_name,
    display_name=options.display_name,
    host_url=options.host_url,
  )
  let live = @client_ws.connect_live(config)
  println(live.response.summary())
  match live.response {
    JoinAccepted(player) => {
      let terminal = TerminalViewState::new(player.side)
      let mut sequence_id = 1
      print_terminal_screen(terminal)
      @async.with_task_group(group => {
        group.spawn_bg(no_wait=true, () => {
          try {
            for ;; {
              let message = live.session.recv_message()
              terminal.apply_host_message(message)
              print_terminal_screen(terminal)
            }
          } catch {
            _ => ()
          }
        })
        while @stdio.stdin.read_until("\n") is Some(line) {
          match
            @client.parse_supervisor_line(
              player.side,
              terminal.current_window_id,
              @protocol.SequenceId::new(sequence_id),
              line,
            ) {
            Some(input) => {
              live.session.send_input(input)
              sequence_id += 1
              if input is Leave(_) {
                break
              }
            }
            None => {
              terminal.logs.push("ignored input")
              print_terminal_screen(terminal)
            }
          }
        }
        live.session.close()
      })
    }
    JoinRejected(_) => live.session.close()
  }
}

///|
fn replay_event_lines(
  log : @replay.ReplayEventLog,
  view : String,
) -> Array[String] {
  let lines : Array[String] = []
  match @visibility.side_from_view(view) {
    None => lines.push("invalid replay view: \{view}")
    Some(side) => {
      lines.push("replay \{log.match_id()} view \{view}")
      for record in log.records_from(0) {
        match @visibility.visible_event_for_side(record.event, side) {
          Some(event) => lines.push("#\{record.event_id} \{event.summary()}")
          None => ()
        }
      }
    }
  }
  lines
}

///|
fn replay_metadata_lines(log : @replay.ReplayEventLog) -> Array[String] {
  [
    "replay \{log.match_id()} metadata",
    "created_at \{log.created_at()}",
    "seed \{log.seed()}",
    "protocol \{log.protocol_version()}",
    "format \{log.format_version()}",
    "events \{log.event_count()}",
  ]
}

///|
fn replay_window_lines(
  log : @replay.ReplayEventLog,
  view : String,
) -> Array[String] {
  let lines : Array[String] = []
  match @visibility.side_from_view(view) {
    None => lines.push("invalid replay view: \{view}")
    Some(side) => {
      lines.push("replay \{log.match_id()} view \{view} windows")
      for group in log.window_groups() {
        lines.push("window \{group.window_id.value()}")
        for record in group.records {
          match @visibility.visible_event_for_side(record.event, side) {
            Some(event) => lines.push("#\{record.event_id} \{event.summary()}")
            None => ()
          }
        }
      }
    }
  }
  lines
}

///|
fn replay_lines(
  log : @replay.ReplayEventLog,
  view : String,
  mode : String,
) -> Array[String] {
  match mode {
    "events" => replay_event_lines(log, view)
    "windows" => replay_window_lines(log, view)
    "metadata" => replay_metadata_lines(log)
    _ => ["invalid replay mode: \{mode}"]
  }
}

///|
async fn run_replay(options : @cli.ReplayOptions) -> Unit {
  if options.file.is_empty() {
    println("replay file required")
  } else {
    match @replay.load_event_log(options.file) {
      Some(log) =>
        for line in replay_lines(log, options.view, options.mode) {
          println(line)
        }
      None => println("invalid or incompatible replay")
    }
  }
}

///|
async fn main {
  match @cli.parse_command(@env.args()) {
    Host(options) => {
      let server = @http.Server(
        @socket.Addr::parse("\{options.bind_host}:\{options.port}"),
      )
      let config = @host_ws.HandshakeServerConfig::new(
        match_id=options.match_id,
        replay_dir=options.replay_dir,
        seed=options.seed,
      )
      println(
        "host started ws://\{options.bind_host}:\{options.port}/match match \{options.match_id} replay \{config.replay_path()}",
      )
      @host_ws.run_handshake_server_with_config(
        server, config, log_server_reply,
      )
    }
    Join(options) => run_join(options)
    Replay(options) => run_replay(options)
    _ => println(@cli.parse_command(@env.args()).summary())
  }
}
