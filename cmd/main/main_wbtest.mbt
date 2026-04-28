///|
test "join command tracks input windows from host messages" {
  let from_response = updated_window_from_host_message(
    @client_ws.InputMessage(@protocol.WindowOpened(@protocol.WindowId::new(1))),
    None,
  )
  assert_true(from_response == Some(@protocol.WindowId::new(1)))
  let from_event = updated_window_from_host_message(
    @client_ws.EventMessage(
      @protocol.InputWindowOpened(@protocol.WindowId::new(2)),
    ),
    from_response,
  )
  assert_true(from_event == Some(@protocol.WindowId::new(2)))
  let unchanged = updated_window_from_host_message(
    @client_ws.EventMessage(@protocol.PlayerReady(@protocol.A)),
    from_event,
  )
  assert_true(unchanged == Some(@protocol.WindowId::new(2)))
}
