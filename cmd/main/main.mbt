///|

///|
fn log_server_reply(frame : String) -> Unit {
  match @protocol.JoinResponse::from_wire_text(frame) {
    Some(response) => println("join \{response.summary()}")
    None =>
      match @protocol.InputResponse::from_wire_text(frame) {
        Some(response) => println("input \{response.summary()}")
        None => println("invalid response")
      }
  }
}

///|
fn updated_window(
  response : @protocol.InputResponse,
  current : @protocol.WindowId?,
) -> @protocol.WindowId? {
  match response {
    WindowOpened(window_id) => Some(window_id)
    _ => current
  }
}

///|
async fn run_join(options : @cli.JoinOptions) -> Unit {
  let config = @client.ClientConfig::new(
    player_id=options.display_name,
    display_name=options.display_name,
    host_url=options.host_url,
  )
  let response = @client_ws.join_once(config)
  println(response.summary())
  match response {
    JoinAccepted(player) => {
      let mut current_window_id : @protocol.WindowId? = None
      let mut sequence_id = 1
      while @stdio.stdin.read_until("\n") is Some(line) {
        match
          @client.parse_supervisor_line(
            player.side,
            current_window_id,
            @protocol.SequenceId::new(sequence_id),
            line,
          ) {
          Some(input) => {
            let reply = @client_ws.send_input_once(options.host_url, input)
            println(reply.summary())
            current_window_id = updated_window(reply, current_window_id)
            sequence_id += 1
            if reply is MatchLeft(_) {
              break
            }
          }
          None => println("ignored input")
        }
      }
    }
    JoinRejected(_) => ()
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
