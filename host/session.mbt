///|
pub(all) struct MatchSession {
  lobby : Lobby
  mut side_a_ready : Bool
  mut side_b_ready : Bool
  mut started : Bool
  mut ended : Bool
  mut current_window_id : @protocol.WindowId?
  mut current_interventions : Array[@protocol.Intervention]
} derive(Eq, Debug)

///|
pub fn MatchSession::new() -> MatchSession {
  {
    lobby: Lobby::new(),
    side_a_ready: false,
    side_b_ready: false,
    started: false,
    ended: false,
    current_window_id: None,
    current_interventions: [],
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
fn placeholder_plan(
  side : @protocol.Side,
  window_id : @protocol.WindowId,
  phase : @protocol.AgentPlanPhase,
  intervention_count : Int,
) -> @protocol.AgentPlan {
  match phase {
    @protocol.InitialPlan =>
      @protocol.AgentPlan::new(
        side~,
        window_id~,
        phase~,
        plan="hold placeholder action",
        reason="no gameplay rules loaded",
      )
    @protocol.FinalPlan =>
      @protocol.AgentPlan::new(
        side~,
        window_id~,
        phase~,
        plan="execute placeholder action",
        reason="\{intervention_count} supervisor interventions collected",
      )
  }
}

///|
fn agent_plan_events(
  window_id : @protocol.WindowId,
  phase : @protocol.AgentPlanPhase,
  intervention_count : Int,
) -> Array[@protocol.ServerEvent] {
  [
    @protocol.AgentPlanIssued(
      placeholder_plan(@protocol.A, window_id, phase, intervention_count),
    ),
    @protocol.AgentPlanIssued(
      placeholder_plan(@protocol.B, window_id, phase, intervention_count),
    ),
  ]
}

///|
fn MatchSession::open_window_events(
  self : MatchSession,
  window_id : @protocol.WindowId,
) -> Array[@protocol.ServerEvent] {
  self.current_window_id = Some(window_id)
  self.current_interventions = []
  let events : Array[@protocol.ServerEvent] = [
    @protocol.InputWindowOpened(window_id),
  ]
  for event in agent_plan_events(window_id, @protocol.InitialPlan, 0) {
    events.push(event)
  }
  events
}

///|
fn MatchSession::finish_match_events(
  self : MatchSession,
  reason : String,
) -> Array[@protocol.ServerEvent] {
  if self.ended {
    []
  } else {
    self.ended = true
    self.current_window_id = None
    [@protocol.MatchEnded(reason)]
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
  if self.ended {
    { response: @protocol.InputRejected("match ended"), events }
  } else if !self.has_side(side) {
    { response: @protocol.InputRejected("side not seated"), events }
  } else {
    self.mark_ready(side)
    events.push(@protocol.PlayerReady(side))
    if self.both_ready() && self.current_window_id is None {
      let window_id = self.next_window()
      if !self.started {
        self.started = true
        events.push(@protocol.MatchStarted)
      }
      for event in self.open_window_events(window_id) {
        events.push(event)
      }
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
  if self.ended {
    { response: @protocol.InputRejected("match ended"), events }
  } else if !self.has_side(intervention.side) {
    { response: @protocol.InputRejected("side not seated"), events }
  } else {
    match self.current_window_id {
      None =>
        { response: @protocol.InputRejected("no open input window"), events }
      Some(window_id) =>
        if intervention.is_for_window(window_id) {
          self.current_interventions.push(intervention)
          events.push(@protocol.InterventionSubmitted(intervention))
          { response: @protocol.InterventionAccepted(intervention), events }
        } else {
          { response: @protocol.InputRejected("stale input window"), events }
        }
    }
  }
}

///|
fn MatchSession::handle_lock_outcome(
  self : MatchSession,
  side : @protocol.Side,
  lock_window_id : @protocol.WindowId,
) -> InputOutcome {
  let events : Array[@protocol.ServerEvent] = []
  if self.ended {
    { response: @protocol.InputRejected("match ended"), events }
  } else if !self.has_side(side) {
    { response: @protocol.InputRejected("side not seated"), events }
  } else {
    match self.current_window_id {
      None =>
        { response: @protocol.InputRejected("no open input window"), events }
      Some(window_id) =>
        if window_id == lock_window_id {
          for event in self.lock_current_window() {
            events.push(event)
          }
          { response: @protocol.WindowLockedAck(lock_window_id), events }
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
    @protocol.LockWindow(side, window_id) =>
      self.handle_lock_outcome(side, window_id)
    @protocol.Leave(side) => {
      let events : Array[@protocol.ServerEvent] = []
      if self.ended {
        { response: @protocol.InputRejected("match ended"), events }
      } else if self.has_side(side) {
        events.push(@protocol.PlayerLeft(side))
        for event in self.finish_match_events("\{side.label()} left") {
          events.push(event)
        }
        { response: @protocol.MatchLeft(side), events }
      } else {
        { response: @protocol.InputRejected("side not seated"), events }
      }
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
            events: [@protocol.ProtocolError("invalid input")],
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

///|
pub fn MatchSession::handle_disconnect(
  self : MatchSession,
  side : @protocol.Side,
) -> Array[@protocol.ServerEvent] {
  if self.started && !self.ended && self.has_side(side) {
    let events : Array[@protocol.ServerEvent] = [
      @protocol.PlayerDisconnected(side),
    ]
    for event in self.finish_match_events("\{side.label()} disconnected") {
      events.push(event)
    }
    events
  } else {
    []
  }
}

///|
pub fn MatchSession::lock_current_window(
  self : MatchSession,
) -> Array[@protocol.ServerEvent] {
  if self.ended {
    []
  } else {
    match self.current_window_id {
      None => []
      Some(window_id) => {
        let intervention_count = self.current_interventions.length()
        let events : Array[@protocol.ServerEvent] = [
          @protocol.WindowLocked(window_id),
        ]
        for
          event in agent_plan_events(
            window_id,
            @protocol.FinalPlan,
            intervention_count,
          ) {
          events.push(event)
        }
        events.push(@protocol.WindowExecuted(window_id))
        for event in self.open_window_events(self.next_window()) {
          events.push(event)
        }
        events
      }
    }
  }
}
