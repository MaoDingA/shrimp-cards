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
  MatchStarted
  InputWindowOpened(WindowId)
  InterventionSubmitted(Intervention)
  WindowLocked(WindowId)
  AgentPlanIssued(AgentPlan)
  WindowExecuted(WindowId)
  PlayerLeft(Side)
  PlayerDisconnected(Side)
  MatchEnded(String)
  ReplaySaved(String)
  ReplaySaveFailed(String, String)
  ProtocolError(String)
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn ServerEvent::to_wire_text(self : ServerEvent) -> String {
  match self {
    PlayerJoined(player) =>
      "event_joined\t\{encode_wire_field(player.player_id)}\t\{encode_wire_field(player.display_name)}\t\{player.side.label()}"
    PlayerReady(side) => "event_ready\t\{side.label()}"
    MatchStarted => "event_match_started"
    InputWindowOpened(window_id) => "event_window_opened\t\{window_id.value()}"
    InterventionSubmitted(intervention) =>
      "event_intervention\t\{intervention.side.label()}\t\{intervention.window_id.value()}\t\{intervention.sequence_id.value()}\t\{intervention.kind.wire_label()}\t\{encode_wire_field(intervention.text)}"
    WindowLocked(window_id) => "event_window_locked\t\{window_id.value()}"
    AgentPlanIssued(plan) =>
      "event_agent_plan\t\{plan.phase.wire_label()}\t\{plan.side.label()}\t\{plan.window_id.value()}\t\{encode_wire_field(plan.plan)}\t\{encode_wire_field(plan.reason)}"
    WindowExecuted(window_id) => "event_window_executed\t\{window_id.value()}"
    PlayerLeft(side) => "event_left\t\{side.label()}"
    PlayerDisconnected(side) => "event_disconnected\t\{side.label()}"
    MatchEnded(reason) => "event_match_ended\t\{encode_wire_field(reason)}"
    ReplaySaved(path) => "event_replay_saved\t\{encode_wire_field(path)}"
    ReplaySaveFailed(path, reason) =>
      "event_replay_save_failed\t\{encode_wire_field(path)}\t\{encode_wire_field(reason)}"
    ProtocolError(reason) =>
      "event_protocol_error\t\{encode_wire_field(reason)}"
  }
}

///|
pub fn ServerEvent::from_wire_text(frame : String) -> ServerEvent? {
  match split_wire_text(frame) {
    ["event_joined", player_id, display_name, side_label] =>
      match
        (
          decode_wire_field(player_id),
          decode_wire_field(display_name),
          side_from_label(side_label),
        ) {
        (Some(player_id), Some(display_name), Some(side)) =>
          Some(PlayerJoined(PlayerIdentity::new(player_id, display_name, side)))
        _ => None
      }
    ["event_ready", side_label] =>
      match side_from_label(side_label) {
        Some(side) => Some(PlayerReady(side))
        None => None
      }
    ["event_match_started"] => Some(MatchStarted)
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
          decode_wire_field(text),
        ) {
        (Some(side), Some(window), Some(sequence), Some(kind), Some(text)) =>
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
    ["event_window_locked", window_raw] =>
      match parse_version(window_raw) {
        Some(window) => Some(WindowLocked(WindowId::new(window)))
        None => None
      }
    ["event_agent_plan", phase_label, side_label, window_raw, plan, reason] =>
      match
        (
          AgentPlanPhase::from_wire_label(phase_label),
          side_from_label(side_label),
          parse_version(window_raw),
          decode_wire_field(plan),
          decode_wire_field(reason),
        ) {
        (Some(phase), Some(side), Some(window), Some(plan), Some(reason)) =>
          Some(
            AgentPlanIssued(
              AgentPlan::new(
                side~,
                window_id=WindowId::new(window),
                phase~,
                plan~,
                reason~,
              ),
            ),
          )
        _ => None
      }
    ["event_window_executed", window_raw] =>
      match parse_version(window_raw) {
        Some(window) => Some(WindowExecuted(WindowId::new(window)))
        None => None
      }
    ["event_left", side_label] =>
      match side_from_label(side_label) {
        Some(side) => Some(PlayerLeft(side))
        None => None
      }
    ["event_disconnected", side_label] =>
      match side_from_label(side_label) {
        Some(side) => Some(PlayerDisconnected(side))
        None => None
      }
    ["event_match_ended", reason] =>
      match decode_wire_field(reason) {
        Some(reason) => Some(MatchEnded(reason))
        None => None
      }
    ["event_replay_saved", path] =>
      match decode_wire_field(path) {
        Some(path) => Some(ReplaySaved(path))
        None => None
      }
    ["event_replay_save_failed", path, reason] =>
      match (decode_wire_field(path), decode_wire_field(reason)) {
        (Some(path), Some(reason)) => Some(ReplaySaveFailed(path, reason))
        _ => None
      }
    ["event_protocol_error", reason] =>
      match decode_wire_field(reason) {
        Some(reason) => Some(ProtocolError(reason))
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
    MatchStarted => "match started"
    InputWindowOpened(window_id) => "window \{window_id.value()} opened"
    InterventionSubmitted(intervention) =>
      "intervention from \{intervention.side.label()}"
    WindowLocked(window_id) => "window \{window_id.value()} locked"
    AgentPlanIssued(plan) =>
      "\{plan.phase.wire_label()} plan for \{plan.side.label()}: \{plan.plan}"
    WindowExecuted(window_id) => "window \{window_id.value()} executed"
    PlayerLeft(side) => "\{side.label()} left"
    PlayerDisconnected(side) => "\{side.label()} disconnected"
    MatchEnded(reason) => "match ended: \{reason}"
    ReplaySaved(path) => "replay saved: \{path}"
    ReplaySaveFailed(path, reason) => "replay save failed: \{path} (\{reason})"
    ProtocolError(reason) => "protocol error: \{reason}"
  }
}
