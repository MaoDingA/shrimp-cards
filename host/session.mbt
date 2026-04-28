///|
pub(all) struct MatchSession {
  lobby : Lobby
  mut side_a_ready : Bool
  mut side_b_ready : Bool
  mut current_window_id : @protocol.WindowId?
} derive(Eq, Debug)

///|
pub fn MatchSession::new() -> MatchSession {
  {
    lobby: Lobby::new(),
    side_a_ready: false,
    side_b_ready: false,
    current_window_id: None,
  }
}

///|
fn MatchSession::has_side(self : MatchSession, side : @protocol.Side) -> Bool {
  let mut found = false
  for player in self.lobby.players {
    if player.side == side {
      found = true
    }
  }
  found
}

///|
fn MatchSession::mark_ready(self : MatchSession, side : @protocol.Side) -> Unit {
  match side {
    @protocol.A => self.side_a_ready = true
    @protocol.B => self.side_b_ready = true
  }
}

///|
fn MatchSession::both_ready(self : MatchSession) -> Bool {
  self.side_a_ready && self.side_b_ready
}

///|
fn MatchSession::next_window(self : MatchSession) -> @protocol.WindowId {
  match self.current_window_id {
    Some(window_id) => @protocol.WindowId::new(window_id.value() + 1)
    None => @protocol.WindowId::new(1)
  }
}

///|
struct InputOutcome {
  response : @protocol.InputResponse
  events : Array[@protocol.ServerEvent]
} derive(Eq, Debug)

///|
pub struct FrameOutcome {
  priv reply : String
  priv events : Array[@protocol.ServerEvent]
} derive(Eq, Debug)

///|
pub fn FrameOutcome::reply_text(self : FrameOutcome) -> String {
  self.reply
}

///|
pub fn FrameOutcome::server_events(
  self : FrameOutcome,
) -> Array[@protocol.ServerEvent] {
  self.events
}

///|
fn MatchSession::handle_ready_outcome(
  self : MatchSession,
  side : @protocol.Side,
) -> InputOutcome {
  let events : Array[@protocol.ServerEvent] = []
  if !self.has_side(side) {
    { response: @protocol.InputRejected("side not seated"), events }
  } else {
    self.mark_ready(side)
    events.push(@protocol.PlayerReady(side))
    if self.both_ready() && self.current_window_id is None {
      let window_id = self.next_window()
      self.current_window_id = Some(window_id)
      events.push(@protocol.InputWindowOpened(window_id))
      { response: @protocol.WindowOpened(window_id), events }
    } else {
      { response: @protocol.ReadyAccepted(side), events }
    }
  }
}

///|
fn MatchSession::handle_intervention_outcome(
  self : MatchSession,
  intervention : @protocol.Intervention,
) -> InputOutcome {
  let events : Array[@protocol.ServerEvent] = []
  if !self.has_side(intervention.side) {
    { response: @protocol.InputRejected("side not seated"), events }
  } else {
    match self.current_window_id {
      None =>
        { response: @protocol.InputRejected("no open input window"), events }
      Some(window_id) =>
        if intervention.is_for_window(window_id) {
          events.push(@protocol.InterventionSubmitted(intervention))
          { response: @protocol.InterventionAccepted(intervention), events }
        } else {
          { response: @protocol.InputRejected("stale input window"), events }
        }
    }
  }
}

///|
fn MatchSession::handle_input_outcome(
  self : MatchSession,
  input : @protocol.ClientInput,
) -> InputOutcome {
  match input {
    @protocol.Ready(side) => self.handle_ready_outcome(side)
    @protocol.Leave(side) => {
      let events : Array[@protocol.ServerEvent] = []
      if self.has_side(side) {
        events.push(@protocol.PlayerLeft(side))
      }
      { response: @protocol.MatchLeft(side), events }
    }
    @protocol.SubmitIntervention(intervention) =>
      self.handle_intervention_outcome(intervention)
  }
}

///|
pub fn MatchSession::handle_input(
  self : MatchSession,
  input : @protocol.ClientInput,
) -> @protocol.InputResponse {
  self.handle_input_outcome(input).response
}

///|
pub fn MatchSession::handle_frame_outcome(
  self : MatchSession,
  frame : String,
) -> FrameOutcome {
  match @protocol.JoinRequest::from_wire_text(frame) {
    Some(request) =>
      match self.lobby.accept_join(request) {
        Accepted(player) =>
          {
            reply: @protocol.JoinAccepted(player).to_wire_text(),
            events: [@protocol.PlayerJoined(player)],
          }
        Rejected(reason) =>
          { reply: @protocol.JoinRejected(reason).to_wire_text(), events: [] }
      }
    None =>
      match @protocol.ClientInput::from_wire_text(frame) {
        Some(input) => {
          let outcome = self.handle_input_outcome(input)
          { reply: outcome.response.to_wire_text(), events: outcome.events }
        }
        None =>
          {
            reply: @protocol.InputRejected("invalid input").to_wire_text(),
            events: [],
          }
      }
  }
}

///|
pub fn MatchSession::handle_frame(
  self : MatchSession,
  frame : String,
) -> String {
  self.handle_frame_outcome(frame).reply_text()
}

///|
pub fn MatchSession::handle_frame_events(
  self : MatchSession,
  frame : String,
) -> Array[@protocol.ServerEvent] {
  self.handle_frame_outcome(frame).events
}
