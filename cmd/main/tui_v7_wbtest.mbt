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
  assert_true(lines.contains("小虾牌 Shrimp Cards"))
  assert_true(lines.contains("window 02 · intervention open"))
  assert_true(lines.contains("现在要不要改 Agent 的计划？"))
  assert_true(lines.contains("agent intent"))
  assert_true(lines.contains("建立防御，保留能量给下一抽牌。"))
  assert_true(
    lines.contains("recommend                 forbid                    accept"),
  )
  assert_true(
    lines.contains(
      "/prefer 优先防守          /ban risky draw           /lock",
    ),
  )
  assert_true(
    lines.contains(
      "window 02                 只显示己方计划            中文 · /lang en",
    ),
  )
  assert_true(
    lines.contains("A:02 › /prefer 优先防守，除非出现斩杀"),
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
  assert_true(lines.contains("Should you change the agent plan now?"))
  assert_true(lines.contains("agent intent"))
  assert_true(lines.contains("waiting for the agent's initial plan"))
  assert_true(
    lines.contains(
      "window 03                 only your agent plan      English · /lang zh",
    ),
  )
  assert_true(lines.contains("B:03 › /prefer defend unless lethal appears"))
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
  assert_true(lines.contains("小虾牌 Shrimp Cards"))
  assert_true(lines.contains("connecting · ws://127.0.0.1:7777/match"))
  assert_true(lines.contains("host  ws://127.0.0.1:7777/match"))
  assert_true(
    lines.contains(
      "player                    status                    language",
    ),
  )
  assert_true(
    lines.contains(
      "Alice                     connecting                中文 · /lang en",
    ),
  )
  assert_true(lines.contains("Alice:-- › connecting"))
}

///|
test "join rejected screen uses v7 style" {
  let lines = join_rejected_screen_lines(
    display_name="Bob",
    host_url="ws://127.0.0.1:7777/match",
    lang=En,
    reason="match full",
  )
  assert_true(lines.contains("join rejected"))
  assert_true(lines.contains("reason: match full"))
  assert_true(lines.contains("host  ws://127.0.0.1:7777/match"))
  assert_true(lines.contains("Bob:-- › reconnect later"))
}
