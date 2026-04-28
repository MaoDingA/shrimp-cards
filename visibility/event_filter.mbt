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
  viewer : @protocol.Side,
) -> @protocol.ServerEvent? {
  match event {
    AgentPlanIssued(plan) =>
      if plan.side == viewer {
        Some(event)
      } else {
        None
      }
    _ => Some(event)
  }
}
