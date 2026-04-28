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

///|
test "player host event summary uses visibility filter" {
  match
    visible_host_message_summary(
      @client_ws.EventMessage(@protocol.PlayerReady(@protocol.A)),
      @protocol.B,
    ) {
    Some(summary) => assert_eq(summary, "event A ready")
    None => fail("expected visible event summary")
  }
}

///|
test "terminal panel lines show seat window and input area" {
  assert_eq(terminal_panel_lines(@protocol.A, None), [
    "[panel] seat A window waiting", "[input] /ready | /leave",
  ])
  assert_eq(
    terminal_panel_lines(@protocol.B, Some(@protocol.WindowId::new(2))),
    [
      "[panel] seat B window 2", "[input] /prefer <text> | /ban <text> | /lock | /leave",
    ],
  )
}

///|
test "terminal host message lines include log and refreshed panel" {
  assert_eq(
    terminal_host_message_lines(
      @client_ws.EventMessage(
        @protocol.InputWindowOpened(@protocol.WindowId::new(3)),
      ),
      @protocol.A,
      Some(@protocol.WindowId::new(3)),
    ),
    [
      "[log] event window 3 opened", "[panel] seat A window 3", "[input] /prefer <text> | /ban <text> | /lock | /leave",
    ],
  )
}

///|
test "replay command formats event stream lines" {
  let log = @replay.ReplayEventLog::new(
    @replay.ReplayHeader::new(
      "match-1", "2026-04-28T00:00:00Z", 42, @protocol.protocol_version, @replay.replay_format_version,
    ),
    [
      @replay.ReplayEventRecord::{
        event_id: 0,
        event: @protocol.PlayerJoined(
          @protocol.PlayerIdentity::new("p1", "Alice", @protocol.A),
        ),
      },
      @replay.ReplayEventRecord::{
        event_id: 1,
        event: @protocol.PlayerReady(@protocol.A),
      },
    ],
  )
  assert_eq(replay_event_lines(log, "A"), [
    "replay match-1 view A", "#0 Alice joined as A", "#1 A ready",
  ])
}

///|
test "replay command rejects unknown view labels" {
  let log = @replay.ReplayEventLog::new(
    @replay.ReplayHeader::new(
      "match-1", "2026-04-28T00:00:00Z", 42, @protocol.protocol_version, @replay.replay_format_version,
    ),
    [],
  )
  assert_eq(replay_event_lines(log, "spectator"), [
    "invalid replay view: spectator",
  ])
}
