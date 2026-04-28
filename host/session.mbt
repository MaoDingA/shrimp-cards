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
fn MatchSession::handle_ready(
  self : MatchSession,
  side : @protocol.Side,
) -> @protocol.InputResponse {
  if !self.has_side(side) {
    @protocol.InputRejected("side not seated")
  } else {
    self.mark_ready(side)
    if self.both_ready() && self.current_window_id is None {
      let window_id = self.next_window()
      self.current_window_id = Some(window_id)
      @protocol.WindowOpened(window_id)
    } else {
      @protocol.ReadyAccepted(side)
    }
  }
}

///|
fn MatchSession::handle_intervention(
  self : MatchSession,
  intervention : @protocol.Intervention,
) -> @protocol.InputResponse {
  if !self.has_side(intervention.side) {
    @protocol.InputRejected("side not seated")
  } else {
    match self.current_window_id {
      None => @protocol.InputRejected("no open input window")
      Some(window_id) =>
        if intervention.is_for_window(window_id) {
          @protocol.InterventionAccepted(intervention)
        } else {
          @protocol.InputRejected("stale input window")
        }
    }
  }
}

///|
pub fn MatchSession::handle_input(
  self : MatchSession,
  input : @protocol.ClientInput,
) -> @protocol.InputResponse {
  match input {
    @protocol.Ready(side) => self.handle_ready(side)
    @protocol.Leave(side) => @protocol.MatchLeft(side)
    @protocol.SubmitIntervention(intervention) =>
      self.handle_intervention(intervention)
  }
}

///|
pub fn MatchSession::handle_frame(
  self : MatchSession,
  frame : String,
) -> String {
  match @protocol.JoinRequest::from_wire_text(frame) {
    Some(request) => self.lobby.accept_join_response(request).to_wire_text()
    None =>
      match @protocol.ClientInput::from_wire_text(frame) {
        Some(input) => self.handle_input(input).to_wire_text()
        None => @protocol.InputRejected("invalid input").to_wire_text()
      }
  }
}
