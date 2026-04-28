///|
pub async fn run_text_server(
  server : @http.Server,
  handler : async (String) -> String,
) -> Unit {
  server.run_forever((request, _, conn) => {
    let ws = @ws.from_http_server(request, conn)
    defer ws.close()
    try {
      for ;; {
        let msg = ws.recv()
        match msg.kind {
          Text => {
            let reply = handler(msg.read_all().text())
            ws.send_text(reply)
          }
          Binary => {
            ignore(msg.read_all().binary())
            ws.send_close(code=UnsupportedData, reason="text frames only")
          }
        }
      }
    } catch {
      @ws.ConnectionClosed(_, _) => ()
      _ => ()
    }
  })
}

///|
pub async fn send_text_once(url : String, text : String) -> String {
  let ws = @ws.connect(url)
  defer ws.close()
  ws.send_text(text)
  let msg = ws.recv()
  match msg.kind {
    Text => msg.read_all().text()
    Binary => {
      ignore(msg.read_all().binary())
      ""
    }
  }
}
