///|
fn box_frame_width() -> Int {
  terminal_line_width()
}

///|
fn box_inner_width() -> Int {
  box_frame_width() - 4
}

///|
fn repeat_text(text : String, count : Int) -> String {
  let mut repeated = ""
  if count > 0 {
    for _ in 0..<count {
      repeated = repeated + text
    }
  }
  repeated
}

///|
fn box_title_line(title : String) -> String {
  let prefix = "╭─ \{title} "
  let suffix = "╮"
  let fill = box_frame_width() - display_width(prefix) - display_width(suffix)
  prefix + repeat_text("─", fill) + suffix
}

///|
fn box_body_line(text : String) -> String {
  "│  \{pad_right_display(text, box_inner_width())}│"
}

///|
fn box_bottom_line() -> String {
  let fill = repeat_text("─", box_frame_width() - 2)
  "╰\{fill}╯"
}

///|
fn append_box(
  lines : Array[String],
  title : String,
  body : Array[String],
) -> Unit {
  lines.push(box_title_line(title))
  for line in body {
    lines.push(box_body_line(line))
  }
  lines.push(box_bottom_line())
}
