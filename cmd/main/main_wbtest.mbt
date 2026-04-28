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
test "terminal screen renderer shows status log and input areas" {
  let state = TerminalViewState::new(@protocol.A)
  state.apply_host_message(
    @client_ws.EventMessage(
      @protocol.InputWindowOpened(@protocol.WindowId::new(2)),
    ),
  )
  state.apply_host_message(
    @client_ws.EventMessage(@protocol.ReplaySaved("replays/match-1.json")),
  )
  assert_eq(state.screen_lines(), [
    "[panel] seat A | window 2 | status active | replay replays/match-1.json", "[log]",
    "event window 2 opened", "event replay saved: replays/match-1.json", "[input] /prefer <text> | /ban <text> | /lock | /leave",
  ])
}

///|
test "terminal screen renderer keeps recent log lines" {
  let state = TerminalViewState::new(@protocol.A)
  for index in 1..<=10 {
    state.logs.push("event \{index}")
  }
  let lines = state.screen_lines()
  assert_false(lines.contains("event 1"))
  assert_false(lines.contains("event 2"))
  assert_true(lines.contains("event 3"))
  assert_true(lines.contains("event 10"))
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
test "replay command formats metadata and window views" {
  let log = @replay.ReplayEventLog::new(
    @replay.ReplayHeader::new(
      "match-1", "2026-04-28T00:00:00Z", 42, @protocol.protocol_version, @replay.replay_format_version,
    ),
    [
      @replay.ReplayEventRecord::{ event_id: 0, event: @protocol.MatchStarted },
      @replay.ReplayEventRecord::{
        event_id: 1,
        event: @protocol.InputWindowOpened(@protocol.WindowId::new(1)),
      },
      @replay.ReplayEventRecord::{
        event_id: 2,
        event: @protocol.WindowLocked(@protocol.WindowId::new(1)),
      },
      @replay.ReplayEventRecord::{
        event_id: 3,
        event: @protocol.InputWindowOpened(@protocol.WindowId::new(2)),
      },
    ],
  )
  assert_eq(replay_metadata_lines(log), [
    "replay match-1 metadata", "created_at 2026-04-28T00:00:00Z", "seed 42", "protocol 2",
    "format 1", "events 4",
  ])
  assert_eq(replay_window_lines(log, "A"), [
    "replay match-1 view A windows", "window 1", "#1 window 1 opened", "#2 window 1 locked",
    "window 2", "#3 window 2 opened",
  ])
}

///|
test "replay command rejects unknown mode" {
  let log = @replay.ReplayEventLog::new(
    @replay.ReplayHeader::new(
      "match-1", "2026-04-28T00:00:00Z", 42, @protocol.protocol_version, @replay.replay_format_version,
    ),
    [],
  )
  assert_eq(replay_lines(log, "A", "timeline"), [
    "invalid replay mode: timeline",
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
