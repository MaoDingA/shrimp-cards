///|
fn char_display_width(char : Char) -> Int {
  if char.is_control() {
    0
  } else if char.is_ascii() {
    1
  } else {
    2
  }
}

///|
fn display_width(text : String) -> Int {
  text.iter().fold(init=0, (width, char) => width + char_display_width(char))
}

///|
fn pad_right_display(text : String, width : Int) -> String {
  let current = display_width(text)
  if current >= width {
    text
  } else {
    let mut padded = text
    for _ in 0..<(width - current) {
      padded = padded + " "
    }
    padded
  }
}

///|
fn three_column_line(
  first : String,
  second : String,
  third : String,
  column_width : Int,
) -> String {
  "\{pad_right_display(first, column_width)}\{pad_right_display(second, column_width)}\{third}"
}
