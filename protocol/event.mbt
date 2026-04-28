///|
pub(all) struct PublicEvent {
  code : String
  message : String
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn PublicEvent::new(code : String, message : String) -> PublicEvent {
  { code, message }
}

///|
pub(all) enum ServerEvent {
  PlayerJoined(PlayerIdentity)
  PlayerReady(Side)
  InputWindowOpened(WindowId)
  InterventionSubmitted(Intervention)
  PlayerLeft(Side)
} derive(Eq, Debug)

///|
pub fn ServerEvent::to_wire_text(self : ServerEvent) -> String {
  match self {
    PlayerJoined(player) =>
      "event_joined\t\{player.player_id}\t\{player.display_name}\t\{player.side.label()}"
    PlayerReady(side) => "event_ready\t\{side.label()}"
    InputWindowOpened(window_id) => "event_window_opened\t\{window_id.value()}"
    InterventionSubmitted(intervention) =>
      "event_intervention\t\{intervention.side.label()}\t\{intervention.window_id.value()}\t\{intervention.sequence_id.value()}\t\{intervention.kind.wire_label()}\t\{intervention.text}"
    PlayerLeft(side) => "event_left\t\{side.label()}"
  }
}

///|
pub fn ServerEvent::from_wire_text(frame : String) -> ServerEvent? {
  match split_wire_text(frame) {
    ["event_joined", player_id, display_name, side_label] =>
      match side_from_label(side_label) {
        Some(side) =>
          Some(PlayerJoined(PlayerIdentity::new(player_id, display_name, side)))
        None => None
      }
    ["event_ready", side_label] =>
      match side_from_label(side_label) {
        Some(side) => Some(PlayerReady(side))
        None => None
      }
    ["event_window_opened", window_raw] =>
      match parse_version(window_raw) {
        Some(window) => Some(InputWindowOpened(WindowId::new(window)))
        None => None
      }
    [
      "event_intervention",
      side_label,
      window_raw,
      sequence_raw,
      kind_label,
      text,
    ] =>
      match
        (
          side_from_label(side_label),
          parse_version(window_raw),
          parse_version(sequence_raw),
          InterventionKind::from_wire_label(kind_label),
        ) {
        (Some(side), Some(window), Some(sequence), Some(kind)) =>
          Some(
            InterventionSubmitted(
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
    ["event_left", side_label] =>
      match side_from_label(side_label) {
        Some(side) => Some(PlayerLeft(side))
        None => None
      }
    _ => None
  }
}

///|
pub fn ServerEvent::summary(self : ServerEvent) -> String {
  match self {
    PlayerJoined(player) =>
      "\{player.display_name} joined as \{player.side.label()}"
    PlayerReady(side) => "\{side.label()} ready"
    InputWindowOpened(window_id) => "window \{window_id.value()} opened"
    InterventionSubmitted(intervention) =>
      "intervention from \{intervention.side.label()}"
    PlayerLeft(side) => "\{side.label()} left"
  }
}
