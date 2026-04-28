///|
fn assert_has_line_prefix(lines : Array[String], prefix : String) -> Unit raise {
  let mut found = false
  for line in lines {
    if line.has_prefix(prefix) {
      found = true
    }
  }
  assert_true(found)
}

///|
fn assert_has_styled_line(
  lines : Array[String],
  text : String,
  style : String,
) -> Unit raise {
  let mut found = false
  for line in lines {
    if line.contains(text) && line.contains(style) {
      found = true
    }
  }
  assert_true(found)
}

///|
test "v7 terminal renderer shows Chinese decision spine" {
  let state = TerminalViewState::new(@protocol.A)
  state.apply_host_message(
    @client_ws.EventMessage(
      @protocol.InputWindowOpened(@protocol.WindowId::new(2)),
    ),
  )
  state.apply_host_message(
    @client_ws.EventMessage(
      @protocol.AgentPlanIssued(
        @protocol.AgentPlan::new(
          side=@protocol.A,
          window_id=@protocol.WindowId::new(2),
          phase=@protocol.InitialPlan,
          plan="建立防御，保留能量给下一抽牌。",
          reason="对手下个窗口可能施压，贪输出风险偏高。",
        ),
      ),
    ),
  )
  state.logs.push("event B submitted intervention")
  let lines = state.v7_screen_lines(display_lang_from_code("zh"))
  assert_has_line_prefix(lines, "╭─ 小虾牌 Shrimp Cards")
  assert_has_line_prefix(lines, "╭─ window 02 · intervention open")
  assert_has_line_prefix(lines, "│  现在要不要改 Agent 的计划？")
  assert_has_line_prefix(lines, "│  agent intent")
  assert_has_line_prefix(
    lines, "│  │ 建立防御，保留能量给下一抽牌。",
  )
  assert_has_line_prefix(lines, "╭─ actions")
  assert_has_line_prefix(
    lines, "│  recommend                 forbid                    accept",
  )
  assert_has_line_prefix(
    lines, "│  /prefer 优先防守          /ban risky draw           /lock",
  )
  assert_has_line_prefix(lines, "╭─ context")
  assert_has_line_prefix(
    lines, "│  window 02                 只显示己方计划            中文 · /lang en",
  )
  assert_has_line_prefix(
    lines, "│  A:02 › /prefer 优先防守，除非出现斩杀",
  )
}

///|
test "v7 terminal renderer shows English decision spine" {
  let state = TerminalViewState::new(@protocol.B)
  state.apply_host_message(
    @client_ws.EventMessage(
      @protocol.InputWindowOpened(@protocol.WindowId::new(3)),
    ),
  )
  let lines = state.v7_screen_lines(display_lang_from_code("en"))
  assert_has_line_prefix(lines, "│  Should you change the agent plan now?")
  assert_has_line_prefix(lines, "│  agent intent")
  assert_has_line_prefix(lines, "│  │ waiting for the agent's initial plan")
  assert_has_line_prefix(
    lines, "│  window 03                 only your agent plan      English · /lang zh",
  )
  assert_has_line_prefix(
    lines, "│  B:03 › /prefer defend unless lethal appears",
  )
}

///|
test "language command parses client side display preference" {
  assert_true(parse_display_lang_command("/lang zh") == Some(Zh))
  assert_true(parse_display_lang_command("/lang en") == Some(En))
  assert_true(parse_display_lang_command("/lang jp") is None)
  assert_true(parse_display_lang_command("/prefer defend") is None)
}

///|
test "join startup screen uses v7 style" {
  let lines = join_startup_screen_lines(
    display_name="Alice",
    host_url="ws://127.0.0.1:7777/match",
    lang=Zh,
  )
  assert_has_line_prefix(lines, "╭─ 小虾牌 Shrimp Cards")
  assert_has_line_prefix(lines, "╭─ connecting")
  assert_has_line_prefix(lines, "│  host  ws://127.0.0.1:7777/match")
  assert_has_line_prefix(
    lines, "│  player                    status                    language",
  )
  assert_has_line_prefix(
    lines, "│  Alice                     connecting                中文 · /lang en",
  )
  assert_has_line_prefix(lines, "│  Alice:-- › connecting")
}

///|
test "join rejected screen uses v7 style" {
  let lines = join_rejected_screen_lines(
    display_name="Bob",
    host_url="ws://127.0.0.1:7777/match",
    lang=En,
    reason="match full",
  )
  assert_has_line_prefix(lines, "╭─ join rejected")
  assert_has_line_prefix(lines, "│  reason: match full")
  assert_has_line_prefix(lines, "│  host  ws://127.0.0.1:7777/match")
  assert_has_line_prefix(lines, "│  Bob:-- › reconnect later")
}

///|
test "v7 screen uses box drawing layout" {
  let state = TerminalViewState::new(@protocol.A)
  state.apply_host_message(
    @client_ws.EventMessage(
      @protocol.InputWindowOpened(@protocol.WindowId::new(2)),
    ),
  )
  let lines = state.screen_lines(Zh)
  assert_true(lines[0].has_prefix("╭─ 小虾牌 Shrimp Cards"))
  assert_has_line_prefix(lines, "╭─ actions")
  assert_has_line_prefix(lines, "╭─ context")
  assert_true(lines[lines.length() - 1].has_prefix("╰"))
}

///|
test "styled startup screen includes terminal visual hierarchy" {
  let styled = style_terminal_lines(
    join_startup_screen_lines(
      display_name="Alice",
      host_url="ws://127.0.0.1:7777/match",
      lang=Zh,
    ),
  )
  assert_has_styled_line(styled, "╭─ 小虾牌 Shrimp Cards", "\u{1B}[1m")
  assert_has_styled_line(styled, "╭─ connecting", "\u{1B}[38;2;94;234;212m")
  assert_has_styled_line(
    styled, "Alice:-- › connecting", "\u{1B}[38;2;94;234;212m",
  )
}
