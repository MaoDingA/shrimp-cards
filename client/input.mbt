///|
fn make_intervention(
  side : @protocol.Side,
  window_id : @protocol.WindowId?,
  sequence_id : @protocol.SequenceId,
  kind : @protocol.InterventionKind,
  text : String,
) -> @protocol.ClientInput? {
  match window_id {
    Some(window_id) =>
      Some(
        @protocol.SubmitIntervention(
          @protocol.Intervention::new(
            side~,
            window_id~,
            sequence_id~,
            kind~,
            text~,
          ),
        ),
      )
    None => None
  }
}

///|
fn make_lock_window(
  side : @protocol.Side,
  window_id : @protocol.WindowId?,
) -> @protocol.ClientInput? {
  match window_id {
    Some(window_id) => Some(@protocol.LockWindow(side, window_id))
    None => None
  }
}

///|
pub fn parse_supervisor_line(
  side : @protocol.Side,
  window_id : @protocol.WindowId?,
  sequence_id : @protocol.SequenceId,
  line : String,
) -> @protocol.ClientInput? {
  let input = line.trim().to_string()
  match input {
    "/ready" => Some(@protocol.Ready(side))
    "/leave" => Some(@protocol.Leave(side))
    "/lock" => make_lock_window(side, window_id)
    _ if input.has_prefix("/ban ") =>
      make_intervention(
        side,
        window_id,
        sequence_id,
        @protocol.HardConstraint,
        input,
      )
    _ if input.has_prefix("/prefer ") =>
      make_intervention(
        side,
        window_id,
        sequence_id,
        @protocol.SoftPreference,
        input,
      )
    _ => None
  }
}
