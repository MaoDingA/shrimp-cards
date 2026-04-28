///|
enum DisplayLang {
  Zh
  En
} derive(Eq, Debug)

///|
fn display_lang_from_code(code : String) -> DisplayLang {
  match code {
    "en" => En
    _ => Zh
  }
}

///|
fn parse_display_lang_command(line : String) -> DisplayLang? {
  match line.trim().to_string() {
    "/lang zh" => Some(Zh)
    "/lang en" => Some(En)
    _ => None
  }
}

///|
fn DisplayLang::language_label(self : DisplayLang) -> String {
  match self {
    Zh => "中文 · /lang en"
    En => "English · /lang zh"
  }
}

///|
fn DisplayLang::pending_plan(self : DisplayLang) -> String {
  match self {
    Zh => "等待 Agent 的初始计划"
    En => "waiting for the agent's initial plan"
  }
}

///|
fn DisplayLang::pending_reason(self : DisplayLang) -> String {
  match self {
    Zh => "双方 ready 后会打开第一个决策窗口。"
    En => "the first decision window opens after both players are ready."
  }
}

///|
fn DisplayLang::waiting_for_host(self : DisplayLang) -> String {
  match self {
    Zh => "等待 host 结算"
    En => "waiting for host"
  }
}

///|
fn DisplayLang::match_ended(self : DisplayLang) -> String {
  match self {
    Zh => "对局已结束"
    En => "match ended"
  }
}

///|
fn DisplayLang::connecting_prompt(self : DisplayLang) -> String {
  match self {
    Zh => "connecting"
    En => "connecting"
  }
}

///|
fn DisplayLang::reconnect_later_prompt(self : DisplayLang) -> String {
  match self {
    Zh => "稍后重连"
    En => "reconnect later"
  }
}
