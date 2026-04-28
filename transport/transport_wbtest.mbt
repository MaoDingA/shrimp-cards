///|
test "local endpoint builds websocket and http urls" {
  let endpoint = Endpoint::localhost(7777)
  assert_eq(endpoint.bind_host, "127.0.0.1")
  assert_eq(endpoint.port, 7777)
  assert_eq(endpoint.ws_url("/match"), "ws://127.0.0.1:7777/match")
  assert_eq(endpoint.http_url("/poll"), "http://127.0.0.1:7777/poll")
}

///|
test "transport envelope carries version window and sequence" {
  let envelope = TransportEnvelope::new(
    match_id="match-1",
    window_id=Some(@protocol.WindowId::new(3)),
    sequence_id=@protocol.SequenceId::new(4),
    kind=ClientJoin,
    payload="{\"display_name\":\"Alice\"}",
  )
  assert_true(envelope.is_compatible())
  assert_true(envelope.is_for_window(@protocol.WindowId::new(3)))
  assert_false(envelope.is_for_window(@protocol.WindowId::new(2)))
}
