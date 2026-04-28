///|
test "display width treats Chinese as double width" {
  assert_eq(display_width("abc"), 3)
  assert_eq(display_width("中文"), 4)
  assert_eq(display_width("A中文"), 5)
}

///|
test "pad right uses display width" {
  assert_eq(pad_right_display("A", 4), "A   ")
  assert_eq(pad_right_display("中文", 6), "中文  ")
}

///|
test "three column line aligns display widths" {
  assert_eq(
    three_column_line("推荐", "forbid", "accept", 10),
    "推荐      forbid    accept",
  )
}
