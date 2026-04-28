///|

///|
fn log_server_reply(frame : String) -> Unit {
  println(@client_ws.HostMessage::from_wire_text(frame).summary())
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
enum TerminalWindowState {
  Waiting
  Open(@protocol.WindowId)
  Locked(@protocol.WindowId)
  Resolving(@protocol.WindowId)
  Ended
} derive(Eq, Debug)

///|
struct TerminalViewState {
  viewer : @protocol.Side
  mut current_window_id : @protocol.WindowId?
  mut window_state : TerminalWindowState
  mut ended : Bool
  mut replay_path : String
  mut agent_plan : String
  mut agent_reason : String
  logs : Array[String]
} derive(Eq, Debug)

///|
fn TerminalViewState::new(viewer : @protocol.Side) -> TerminalViewState {
  {
    viewer,
    current_window_id: None,
    window_state: Waiting,
    ended: false,
    replay_path: "",
    agent_plan: "",
    agent_reason: "",
    logs: [],
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
  match message.opened_window() {
    Some(window_id) => {
      self.current_window_id = Some(window_id)
      self.window_state = Open(window_id)
    }
    None => ()
  }
  match message {
    EventMessage(WindowLocked(window_id)) => {
      self.current_window_id = None
      self.window_state = Locked(window_id)
    }
    EventMessage(WindowExecuted(window_id)) => {
      self.current_window_id = None
      self.window_state = Resolving(window_id)
    }
    EventMessage(MatchEnded(_)) => {
      self.ended = true
      self.current_window_id = None
      self.window_state = Ended
    }
    EventMessage(ReplaySaved(path)) => self.replay_path = path
    EventMessage(AgentPlanIssued(plan)) =>
      if plan.side == self.viewer {
        self.agent_plan = plan.plan
        self.agent_reason = plan.reason
      }
    _ => ()
  }
  match visible_host_message_summary(message, self.viewer) {
    Some(summary) => self.logs.push(summary)
    None => ()
  }
}

///|
fn TerminalViewState::screen_lines(
  self : TerminalViewState,
  lang : DisplayLang,
) -> Array[String] {
  self.v7_screen_lines(lang)
}

///|
fn print_lines(lines : Array[String]) -> Unit {
  for line in lines {
    println(line)
  }
}

///|
fn print_screen_lines(lines : Array[String]) -> Unit {
  println("\u{1B}[2J\u{1B}[H")
  print_lines(lines)
}

///|
fn print_terminal_screen(state : TerminalViewState, lang : DisplayLang) -> Unit {
  print_screen_lines(state.screen_lines(lang))
}

///|
async fn run_join(options : @cli.JoinOptions) -> Unit {
  let mut lang = display_lang_from_code(options.lang)
  print_screen_lines(
    join_startup_screen_lines(
      display_name=options.display_name,
      host_url=options.host_url,
      lang~,
    ),
  )
  let config = @client.ClientConfig::new(
    player_id=options.display_name,
    display_name=options.display_name,
    host_url=options.host_url,
  )
  let live = @client_ws.connect_live(config)
  match live.response {
    JoinAccepted(player) => {
      let terminal = TerminalViewState::new(player.side)
      let mut sequence_id = 1
      print_terminal_screen(terminal, lang)
      @async.with_task_group(group => {
        group.spawn_bg(no_wait=true, () => {
          try {
            for ;; {
              let message = live.session.recv_message()
              terminal.apply_host_message(message)
              print_terminal_screen(terminal, lang)
            }
          } catch {
            _ => ()
          }
        })
        while @stdio.stdin.read_until("\n") is Some(line) {
          match parse_display_lang_command(line) {
            Some(next_lang) => {
              lang = next_lang
              terminal.logs.push("language changed")
              print_terminal_screen(terminal, lang)
            }
            None =>
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
                  print_terminal_screen(terminal, lang)
                }
              }
          }
        }
        live.session.close()
      })
    }
    JoinRejected(reason) => {
      print_screen_lines(
        join_rejected_screen_lines(
          display_name=options.display_name,
          host_url=options.host_url,
          lang~,
          reason~,
        ),
      )
      live.session.close()
    }
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
