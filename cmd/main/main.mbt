///|

///|
fn log_join_reply(frame : String) -> Unit {
  match @protocol.JoinResponse::from_wire_text(frame) {
    Some(response) => println("join \{response.summary()}")
    None => println("join invalid response")
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
      @host_ws.run_handshake_server(server, log_join_reply)
    }
    Join(options) => {
      let response = @client_ws.join_once(
        @client.ClientConfig::new(
          player_id=options.display_name,
          display_name=options.display_name,
          host_url=options.host_url,
        ),
      )
      println(response.summary())
    }
    _ => println(@cli.parse_command(@env.args()).summary())
  }
}
