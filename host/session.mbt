///|
pub(all) struct MatchSession {
  lobby : Lobby
  mut side_a_ready : Bool
  mut side_b_ready : Bool
  mut started : Bool
  mut ended : Bool
  mut current_window_id : @protocol.WindowId?
  mut current_interventions : Array[@protocol.Intervention]
  mut game_state : @gameplay.GameState
  mut world_blackboard : @gameplay.WorldBlackboard
  mut llm_provider : @gameplay.LLMProvider
} derive(Debug)

///|
pub fn MatchSession::new() -> MatchSession {
  MatchSession::new_with_seed(seed=0)
}

///|
pub fn MatchSession::new_with_seed(seed~ : Int) -> MatchSession {
  {
    lobby: Lobby::new(),
    side_a_ready: false,
    side_b_ready: false,
    started: false,
    ended: false,
    current_window_id: None,
    current_interventions: [],
    game_state: @gameplay.GameState::initial(seed~),
    world_blackboard: @gameplay.WorldBlackboard::new(turn=1),
    llm_provider: @gameplay.mock_provider_with_default(),
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
fn MatchSession::interventions_for_side(
  self : MatchSession,
  side : @protocol.Side,
) -> Array[@protocol.Intervention] {
  let interventions : Array[@protocol.Intervention] = []
  for intervention in self.current_interventions {
    if intervention.side == side {
      interventions.push(intervention)
    }
  }
  interventions
}

///|
fn MatchSession::initial_plan(
  self : MatchSession,
  side : @protocol.Side,
  window_id : @protocol.WindowId,
) -> @protocol.AgentPlan {
  let observation = self.game_state.observe(side, window_id)
  let prompt = @gameplay.build_initial_plan_prompt(
    side,
    window_id,
    observation.state_summary,
    self.world_blackboard.to_context_string(),
  )
  let request = @gameplay.LLMRequest::new(
    kind=@gameplay.InitialPlan,
    side~,
    window_id~,
    prompt~,
    max_tokens=@gameplay.max_tokens_initial_plan,
    model_tier=@gameplay.Fast,
  )
  let (provider, response) = self.llm_provider.generate(request)
  self.llm_provider = provider
  @protocol.AgentPlan::new(
    side~,
    window_id~,
    phase=@protocol.InitialPlan,
    plan=response.content,
    reason=observation.state_summary,
  )
}

///|
fn MatchSession::final_plan(
  self : MatchSession,
  side : @protocol.Side,
  window_id : @protocol.WindowId,
) -> @protocol.AgentPlan {
  let observation = self.game_state.observe(side, window_id)
  let side_interventions = self.interventions_for_side(side)
  let prompt = @gameplay.build_final_plan_prompt(
    side,
    window_id,
    observation.state_summary,
    side_interventions,
    "pending",
  )
  let request = @gameplay.LLMRequest::new(
    kind=@gameplay.FinalPlan,
    side~,
    window_id~,
    prompt~,
    max_tokens=@gameplay.max_tokens_final_plan,
    model_tier=@gameplay.Standard,
  )
  let (provider, response) = self.llm_provider.generate(request)
  self.llm_provider = provider
  @protocol.AgentPlan::new(
    side~,
    window_id~,
    phase=@protocol.FinalPlan,
    plan=response.content,
    reason=observation.state_summary,
  )
}

///|
fn MatchSession::initial_plan_events(
  self : MatchSession,
  window_id : @protocol.WindowId,
) -> Array[@protocol.ServerEvent] {
  [
    @protocol.AgentPlanIssued(self.initial_plan(@protocol.A, window_id)),
    @protocol.AgentPlanIssued(self.initial_plan(@protocol.B, window_id)),
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
  for event in self.initial_plan_events(window_id) {
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
    // Gate 1: prompt defense check on intervention text
    let gate1 = @gameplay.gate1_check(intervention.text)
    if !gate1.passed {
      { response: @protocol.InputRejected(gate1.reason), events }
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
    @protocol.Heartbeat(side) => {
      let events : Array[@protocol.ServerEvent] = []
      if self.has_side(side) {
        { response: @protocol.HeartbeatAck(side), events }
      } else {
        { response: @protocol.InputRejected("side not seated"), events }
      }
    }
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
        let events : Array[@protocol.ServerEvent] = [
          @protocol.WindowLocked(window_id),
        ]
        // Use LLM provider for final plan generation
        let plan_a = self.final_plan(@protocol.A, window_id)
        let plan_b = self.final_plan(@protocol.B, window_id)
        events.push(@protocol.AgentPlanIssued(plan_a))
        events.push(@protocol.AgentPlanIssued(plan_b))
        // Use fake actions for resolve (real gameplay will replace this)
        let action_a = self.game_state.fake_action(
          @protocol.A,
          window_id,
          self.interventions_for_side(@protocol.A),
        )
        let action_b = self.game_state.fake_action(
          @protocol.B,
          window_id,
          self.interventions_for_side(@protocol.B),
        )
        let result = self.game_state.resolve_window(window_id, [
          action_a, action_b,
        ])
        self.game_state = result.state
        // Update world blackboard turn
        self.world_blackboard = @gameplay.WorldBlackboard::new(
          turn=self.game_state.executed_windows + 1,
        )
        // Check narrative consistency (placeholder: no claims extracted yet)
        let _consistency = @gameplay.check_consistency(
          [],
          self.world_blackboard,
        )
        // Violations logged but not blocking for now
        events.push(@protocol.WindowExecuted(window_id))
        for event in self.open_window_events(self.next_window()) {
          events.push(event)
        }
        events
      }
    }
  }
}
