///|
fn window_number(window_id : @protocol.WindowId?) -> String {
  match window_id {
    Some(window_id) =>
      if window_id.value() < 10 {
        "0\{window_id.value()}"
      } else {
        "\{window_id.value()}"
      }
    None => "--"
  }
}

///|
fn window_state_number(state : TerminalWindowState) -> String {
  match state {
    Open(window_id) | Locked(window_id) | Resolving(window_id) =>
      window_number(Some(window_id))
    Waiting | Ended => "--"
  }
}

///|
fn window_phase(state : TerminalWindowState) -> String {
  match state {
    Open(window_id) =>
      "window \{window_number(Some(window_id))} · intervention open"
    Locked(window_id) => "window \{window_number(Some(window_id))} · locked"
    Resolving(window_id) =>
      "window \{window_number(Some(window_id))} · resolving"
    Waiting => "waiting · no intervention window"
    Ended => "match ended"
  }
}

///|
fn current_question(lang : DisplayLang) -> String {
  match lang {
    Zh => "现在要不要改 Agent 的计划？"
    En => "Should you change the agent plan now?"
  }
}

///|
fn current_brief(lang : DisplayLang) -> String {
  match lang {
    Zh =>
      "接受当前计划，或提交一条公开干预。窗口锁定后，Agent 会基于你的干预生成最终计划。"
    En =>
      "Accept the current plan, or submit one public intervention before the window locks."
  }
}

///|
fn recommend_command(lang : DisplayLang) -> String {
  match lang {
    Zh => "/prefer 优先防守"
    En => "/prefer defend"
  }
}

///|
fn prompt_command(lang : DisplayLang, state : TerminalWindowState) -> String {
  match state {
    Open(_) =>
      match lang {
        Zh => "/prefer 优先防守，除非出现斩杀"
        En => "/prefer defend unless lethal appears"
      }
    Waiting => "/ready"
    Locked(_) | Resolving(_) => lang.waiting_for_host()
    Ended => lang.match_ended()
  }
}

///|
fn recent_log_line(logs : Array[String]) -> String {
  if logs.length() == 0 {
    "recent  no public events yet"
  } else {
    match logs.get(logs.length() - 1) {
      Some(log) => "recent  \{log}"
      None => "recent  no public events yet"
    }
  }
}

///|
fn agent_plan_text(state : TerminalViewState, lang : DisplayLang) -> String {
  if state.agent_plan.is_empty() {
    lang.pending_plan()
  } else {
    state.agent_plan
  }
}

///|
fn agent_reason_text(state : TerminalViewState, lang : DisplayLang) -> String {
  if state.agent_reason.is_empty() {
    lang.pending_reason()
  } else {
    match lang {
      Zh => "理由：\{state.agent_reason}"
      En => "reason: \{state.agent_reason}"
    }
  }
}

///|
fn visibility_text(lang : DisplayLang) -> String {
  match lang {
    Zh => "只显示己方计划"
    En => "only your agent plan"
  }
}

///|
fn join_startup_screen_lines(
  display_name~ : String,
  host_url~ : String,
  lang~ : DisplayLang,
) -> Array[String] {
  [
    "小虾牌 Shrimp Cards",
    "terminal-first supervised card battle · \{lang.language_label()}",
    "────────────────────────────────────────────────────────────────────────",
    "connecting · \{host_url}",
    "准备加入本地对局 / Preparing local match session",
    "host  \{host_url}",
    "",
    three_column_line("player", "status", "language", 26),
    three_column_line(display_name, "connecting", lang.language_label(), 26),
    "",
    "recent  waiting for host response",
    "",
    "\{display_name}:-- › \{lang.connecting_prompt()}",
  ]
}

///|
fn join_rejected_screen_lines(
  display_name~ : String,
  host_url~ : String,
  lang~ : DisplayLang,
  reason~ : String,
) -> Array[String] {
  [
    "小虾牌 Shrimp Cards",
    "terminal-first supervised card battle · \{lang.language_label()}",
    "────────────────────────────────────────────────────────────────────────",
    "join rejected",
    "reason: \{reason}",
    "host  \{host_url}",
    "",
    three_column_line("player", "status", "language", 26),
    three_column_line(display_name, "rejected", lang.language_label(), 26),
    "",
    "\{display_name}:-- › \{lang.reconnect_later_prompt()}",
  ]
}

///|
fn TerminalViewState::v7_screen_lines(
  self : TerminalViewState,
  lang : DisplayLang,
) -> Array[String] {
  let window = window_state_number(self.window_state)
  [
    "小虾牌 Shrimp Cards",
    "A/B supervised agent card battle · \{self.viewer.label()} · \{lang.language_label()} · replay \{self.replay_label()}",
    "────────────────────────────────────────────────────────────────────────",
    window_phase(self.window_state),
    current_question(lang),
    current_brief(lang),
    "",
    "agent intent",
    agent_plan_text(self, lang),
    agent_reason_text(self, lang),
    "",
    three_column_line("recommend", "forbid", "accept", 26),
    three_column_line(recommend_command(lang), "/ban risky draw", "/lock", 26),
    "",
    three_column_line("match", "visibility", "language", 26),
    three_column_line(
      "window \{window}",
      visibility_text(lang),
      lang.language_label(),
      26,
    ),
    "",
    recent_log_line(self.logs),
    "",
    "\{self.viewer.label()}:\{window} › \{prompt_command(lang, self.window_state)}",
  ]
}
