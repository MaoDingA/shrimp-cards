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
fn terminal_panel_lines(
  viewer : @protocol.Side,
  current : @protocol.WindowId?,
) -> Array[String] {
  [
    "[panel] seat \{viewer.label()} window \{window_label(current)}",
    terminal_input_line(current),
  ]
}

///|
fn should_refresh_panel(message : @client_ws.HostMessage) -> Bool {
  match message {
    EventMessage(InputWindowOpened(_)) => true
    EventMessage(WindowLocked(_)) => true
    EventMessage(WindowExecuted(_)) => true
    EventMessage(MatchStarted) => true
    EventMessage(MatchEnded(_)) => true
    EventMessage(ReplaySaved(_)) => true
    InputMessage(WindowOpened(_)) => true
    InputMessage(WindowLockedAck(_)) => true
    InputMessage(MatchLeft(_)) => true
    _ => false
  }
}

///|
fn terminal_host_message_lines(
  message : @client_ws.HostMessage,
  viewer : @protocol.Side,
  current : @protocol.WindowId?,
) -> Array[String] {
  let lines : Array[String] = []
  match visible_host_message_summary(message, viewer) {
    Some(summary) => lines.push("[log] \{summary}")
    None => ()
  }
  if should_refresh_panel(message) {
    for line in terminal_panel_lines(viewer, current) {
      lines.push(line)
    }
  }
  lines
}

///|
fn print_lines(lines : Array[String]) -> Unit {
  for line in lines {
    println(line)
  }
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
      let mut current_window_id : @protocol.WindowId? = None
      let mut sequence_id = 1
      print_lines(terminal_panel_lines(player.side, current_window_id))
      @async.with_task_group(group => {
        group.spawn_bg(no_wait=true, () => {
          try {
            for ;; {
              let message = live.session.recv_message()
              current_window_id = updated_window_from_host_message(
                message, current_window_id,
              )
              print_lines(
                terminal_host_message_lines(
                  message,
                  player.side,
                  current_window_id,
                ),
              )
            }
          } catch {
            _ => ()
          }
        })
        while @stdio.stdin.read_until("\n") is Some(line) {
          match
            @client.parse_supervisor_line(
              player.side,
              current_window_id,
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
            None => println("ignored input")
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
async fn run_replay(options : @cli.ReplayOptions) -> Unit {
  if options.file.is_empty() {
    println("replay file required")
  } else {
    match @replay.load_event_log(options.file) {
      Some(log) =>
        for line in replay_event_lines(log, options.view) {
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
      println("host started ws://\{options.bind_host}:\{options.port}/match")
      @host_ws.run_handshake_server(server, log_server_reply)
    }
    Join(options) => run_join(options)
    Replay(options) => run_replay(options)
    _ => println(@cli.parse_command(@env.args()).summary())
  }
}
