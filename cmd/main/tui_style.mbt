///|
fn ansi_reset() -> String {
  "\u{1B}[0m"
}

///|
fn ansi_bold() -> String {
  "\u{1B}[1m"
}

///|
fn ansi_fg(r : Int, g : Int, b : Int) -> String {
  "\u{1B}[38;2;\{r};\{g};\{b}m"
}

///|
fn ansi_bg(r : Int, g : Int, b : Int) -> String {
  "\u{1B}[48;2;\{r};\{g};\{b}m"
}

///|
fn dark_bg() -> String {
  ansi_bg(7, 11, 10)
}

///|
fn main_fg() -> String {
  ansi_fg(213, 223, 220)
}

///|
fn strong_fg() -> String {
  ansi_fg(241, 250, 247)
}

///|
fn dim_fg() -> String {
  ansi_fg(101, 113, 109)
}

///|
fn accent_fg() -> String {
  ansi_fg(94, 234, 212)
}

///|
fn warning_fg() -> String {
  ansi_fg(240, 208, 113)
}

///|
fn terminal_line_width() -> Int {
  86
}

///|
fn style_prefix_for_line(line : String) -> String {
  if line.has_prefix("╭─ 小虾牌 Shrimp Cards") {
    ansi_bold() + strong_fg()
  } else if line.has_prefix("╭─ actions") ||
    line.has_prefix("╭─ context") ||
    line.has_prefix("╭─ connecting") ||
    line.contains("intervention open") ||
    line.contains("locked") ||
    line.contains("resolving") {
    accent_fg()
  } else if line.has_prefix("╭─ join rejected") || line.contains("reason:") {
    warning_fg()
  } else if line.has_prefix("╰") ||
    line.has_prefix("│  terminal-first") ||
    line.has_prefix("│  A/B supervised") ||
    line.has_prefix("│  local PVE/PVP") ||
    line.has_prefix("│  viewer ") ||
    line.has_prefix("│  recent") ||
    line.has_prefix("│  agent intent") ||
    line.has_prefix("│  player") ||
    line.has_prefix("│  match") ||
    line.has_prefix("│  host  ") {
    dim_fg()
  } else if line.contains("现在要不要") ||
    line.contains("Should you change") {
    ansi_bold() + strong_fg()
  } else if line.contains("/prefer") ||
    line.contains("/ban") ||
    line.contains("/lock") ||
    line.contains("connecting") {
    accent_fg()
  } else if line.contains(" › ") {
    accent_fg()
  } else if line.is_empty() {
    main_fg()
  } else {
    main_fg()
  }
}

///|
fn style_terminal_line(line : String) -> String {
  dark_bg() +
  style_prefix_for_line(line) +
  pad_right_display(line, terminal_line_width()) +
  ansi_reset()
}

///|
fn style_terminal_lines(lines : Array[String]) -> Array[String] {
  let styled : Array[String] = []
  for line in lines {
    styled.push(style_terminal_line(line))
  }
  styled
}

///|
fn TerminalViewState::styled_screen_lines(
  self : TerminalViewState,
  lang : DisplayLang,
) -> Array[String] {
  style_terminal_lines(self.screen_lines(lang))
}
