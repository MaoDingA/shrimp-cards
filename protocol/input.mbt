///|
pub(all) enum ClientInput {
  Ready(Side)
  Leave(Side)
  SubmitIntervention(Intervention)
} derive(Eq, Debug)

///|
pub fn ClientInput::to_wire_text(self : ClientInput) -> String {
  match self {
    Ready(side) => "ready\t\{side.label()}"
    Leave(side) => "leave\t\{side.label()}"
    SubmitIntervention(intervention) =>
      "intervention\t\{intervention.side.label()}\t\{intervention.window_id.value()}\t\{intervention.sequence_id.value()}\t\{intervention.kind.wire_label()}\t\{intervention.text}"
  }
}

///|
fn parse_side(raw : String) -> Side? {
  side_from_label(raw)
}

///|
pub fn ClientInput::from_wire_text(frame : String) -> ClientInput? {
  match split_wire_text(frame) {
    ["ready", side_label] =>
      match parse_side(side_label) {
        Some(side) => Some(Ready(side))
        None => None
      }
    ["leave", side_label] =>
      match parse_side(side_label) {
        Some(side) => Some(Leave(side))
        None => None
      }
    ["intervention", side_label, window_raw, sequence_raw, kind_label, text] =>
      match
        (
          parse_side(side_label),
          parse_version(window_raw),
          parse_version(sequence_raw),
          InterventionKind::from_wire_label(kind_label),
        ) {
        (Some(side), Some(window), Some(sequence), Some(kind)) =>
          Some(
            SubmitIntervention(
              Intervention::new(
                side~,
                window_id=WindowId::new(window),
                sequence_id=SequenceId::new(sequence),
                kind~,
                text~,
              ),
            ),
          )
        _ => None
      }
    _ => None
  }
}

///|
pub(all) enum InputResponse {
  ReadyAccepted(Side)
  WindowOpened(WindowId)
  MatchLeft(Side)
  InterventionAccepted(Intervention)
  InputRejected(String)
} derive(Eq, Debug)

///|
pub fn InputResponse::to_wire_text(self : InputResponse) -> String {
  match self {
    ReadyAccepted(side) => "ready_ok\t\{side.label()}"
    WindowOpened(window_id) => "window_open\t\{window_id.value()}"
    MatchLeft(side) => "left\t\{side.label()}"
    InterventionAccepted(intervention) =>
      "intervention_ok\t\{intervention.side.label()}\t\{intervention.window_id.value()}\t\{intervention.sequence_id.value()}"
    InputRejected(reason) => "rejected\t\{reason}"
  }
}

///|
pub fn InputResponse::from_wire_text(frame : String) -> InputResponse? {
  match split_wire_text(frame) {
    ["ready_ok", side_label] =>
      match parse_side(side_label) {
        Some(side) => Some(ReadyAccepted(side))
        None => None
      }
    ["window_open", window_raw] =>
      match parse_version(window_raw) {
        Some(window) => Some(WindowOpened(WindowId::new(window)))
        None => None
      }
    ["left", side_label] =>
      match parse_side(side_label) {
        Some(side) => Some(MatchLeft(side))
        None => None
      }
    ["intervention_ok", side_label, window_raw, sequence_raw] =>
      match
        (
          parse_side(side_label),
          parse_version(window_raw),
          parse_version(sequence_raw),
        ) {
        (Some(side), Some(window), Some(sequence)) =>
          Some(
            InterventionAccepted(
              Intervention::new(
                side~,
                window_id=WindowId::new(window),
                sequence_id=SequenceId::new(sequence),
                kind=SoftPreference,
                text="",
              ),
            ),
          )
        _ => None
      }
    ["rejected", reason] => Some(InputRejected(reason))
    _ => None
  }
}

///|
pub fn InputResponse::summary(self : InputResponse) -> String {
  match self {
    ReadyAccepted(side) => "\{side.label()} ready"
    WindowOpened(window_id) => "window \{window_id.value()} opened"
    MatchLeft(side) => "\{side.label()} left"
    InterventionAccepted(intervention) =>
      "intervention accepted for \{intervention.side.label()}"
    InputRejected(reason) => "rejected: \{reason}"
  }
}
