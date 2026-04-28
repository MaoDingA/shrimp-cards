///|
pub fn side_from_view(view : String) -> @protocol.Side? {
  match view {
    "A" | "a" => Some(@protocol.A)
    "B" | "b" => Some(@protocol.B)
    _ => None
  }
}

///|
pub fn visible_event_for_side(
  event : @protocol.ServerEvent,
  _viewer : @protocol.Side,
) -> @protocol.ServerEvent? {
  Some(event)
}
