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
      @async.with_task_group(group => {
        group.spawn_bg(no_wait=true, () => {
          try {
            for ;; {
              let message = live.session.recv_message()
              current_window_id = updated_window_from_host_message(
                message, current_window_id,
              )
              if should_print_host_message(message) {
                println(message.summary())
              }
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
    _ => println(@cli.parse_command(@env.args()).summary())
  }
}
