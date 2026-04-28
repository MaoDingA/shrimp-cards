///|
test "join command tracks input windows from host messages" {
  let state = TerminalViewState::new(@protocol.A)
  state.apply_host_message(
    @client_ws.InputMessage(@protocol.WindowOpened(@protocol.WindowId::new(1))),
  )
  assert_true(state.current_window_id == Some(@protocol.WindowId::new(1)))
  assert_true(state.window_state == Open(@protocol.WindowId::new(1)))
  state.apply_host_message(
    @client_ws.EventMessage(
      @protocol.InputWindowOpened(@protocol.WindowId::new(2)),
    ),
  )
  assert_true(state.current_window_id == Some(@protocol.WindowId::new(2)))
  assert_true(state.window_state == Open(@protocol.WindowId::new(2)))
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
test "player host event summary hides opponent agent plan" {
  let plan = @protocol.AgentPlan::new(
    side=@protocol.B,
    window_id=@protocol.WindowId::new(1),
    phase=@protocol.InitialPlan,
    plan="B secret plan",
    reason="private reason",
  )
  match
    visible_host_message_summary(
      @client_ws.EventMessage(@protocol.AgentPlanIssued(plan)),
      @protocol.A,
    ) {
    None => ()
    Some(_) => fail("expected opponent plan summary to be hidden")
  }
}

///|
test "terminal screen renderer uses v7 decision spine" {
  let state = TerminalViewState::new(@protocol.A)
  state.apply_host_message(
    @client_ws.EventMessage(
      @protocol.InputWindowOpened(@protocol.WindowId::new(2)),
    ),
  )
  state.apply_host_message(
    @client_ws.EventMessage(@protocol.ReplaySaved("replays/match-1.json")),
  )
  let lines = state.screen_lines(display_lang_from_code("zh"))
  assert_true(lines.contains("小虾牌 Shrimp Cards"))
  assert_true(lines.contains("window 02 · intervention open"))
  assert_true(lines.contains("现在要不要改 Agent 的计划？"))
  assert_true(
    lines.contains("A:02 › /prefer 优先防守，除非出现斩杀"),
  )
}

///|
test "terminal screen renderer keeps recent log lines" {
  let state = TerminalViewState::new(@protocol.A)
  for index in 1..<=10 {
    state.logs.push("event \{index}")
  }
  let lines = state.screen_lines(display_lang_from_code("zh"))
  assert_false(lines.contains("event 1"))
  assert_false(lines.contains("event 2"))
  assert_true(lines.contains("recent  event 10"))
}

///|
test "terminal clears input window after lock" {
  let state = TerminalViewState::new(@protocol.A)
  state.apply_host_message(
    @client_ws.EventMessage(
      @protocol.InputWindowOpened(@protocol.WindowId::new(2)),
    ),
  )
  state.apply_host_message(
    @client_ws.EventMessage(@protocol.WindowLocked(@protocol.WindowId::new(2))),
  )
  assert_true(state.current_window_id is None)
  let lines = state.screen_lines(display_lang_from_code("zh"))
  assert_true(lines.contains("window 02 · locked"))
  assert_true(lines.contains("A:02 › 等待 host 结算"))
}

///|
test "terminal shows ended state without intervention prompt" {
  let state = TerminalViewState::new(@protocol.B)
  state.apply_host_message(
    @client_ws.EventMessage(
      @protocol.InputWindowOpened(@protocol.WindowId::new(3)),
    ),
  )
  state.apply_host_message(
    @client_ws.EventMessage(@protocol.MatchEnded("B left")),
  )
  assert_true(state.current_window_id is None)
  let lines = state.screen_lines(display_lang_from_code("en"))
  assert_true(lines.contains("match ended"))
  assert_true(lines.contains("B:-- › match ended"))
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
