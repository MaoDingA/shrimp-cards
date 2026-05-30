///|
pub(all) struct GameState {
  seed : Int
  executed_windows : Int
  side_a_alive : Bool
  side_b_alive : Bool
  side_a_potential : RoutePotential
  side_b_potential : RoutePotential
} derive(Eq, Debug)

///|
pub fn GameState::initial(seed~ : Int) -> GameState {
  {
    seed,
    executed_windows: 0,
    side_a_alive: true,
    side_b_alive: true,
    side_a_potential: RoutePotential::zero(),
    side_b_potential: RoutePotential::zero(),
  }
}

///|
pub fn GameState::summary(self : GameState) -> String {
  let status_a = if self.side_a_alive { "alive" } else { "dead" }
  let status_b = if self.side_b_alive { "alive" } else { "dead" }
  "seed \{self.seed} step \{self.executed_windows} A=\{status_a}(\{self.side_a_potential.total()}) B=\{status_b}(\{self.side_b_potential.total()})"
}

///|
pub fn GameState::is_alive(self : GameState, side : @protocol.Side) -> Bool {
  match side {
    @protocol.A => self.side_a_alive
    @protocol.B => self.side_b_alive
  }
}

///|
pub fn GameState::potential(
  self : GameState,
  side : @protocol.Side,
) -> RoutePotential {
  match side {
    @protocol.A => self.side_a_potential
    @protocol.B => self.side_b_potential
  }
}

///|
pub(all) struct GameObservation {
  side : @protocol.Side
  window_id : @protocol.WindowId
  state_summary : String
} derive(Eq, Debug)

///|
pub fn GameObservation::new(
  side~ : @protocol.Side,
  window_id~ : @protocol.WindowId,
  state_summary~ : String,
) -> GameObservation {
  { side, window_id, state_summary }
}

///|
pub fn GameState::observe(
  self : GameState,
  side : @protocol.Side,
  window_id : @protocol.WindowId,
) -> GameObservation {
  { side, window_id, state_summary: self.summary() }
}

///|
pub(all) struct GameAction {
  side : @protocol.Side
  window_id : @protocol.WindowId
  label : String
  detail : String
} derive(Eq, Debug)

///|
pub(all) struct ResolveResult {
  state : GameState
  public_log : String
  ending : GameEnding?
} derive(Eq, Debug)

///|
fn intervention_word(count : Int) -> String {
  if count == 1 {
    "intervention"
  } else {
    "interventions"
  }
}

///|
pub fn GameState::fake_action(
  self : GameState,
  side : @protocol.Side,
  window_id : @protocol.WindowId,
  interventions : Array[@protocol.Intervention],
) -> GameAction {
  ignore(self)
  let count = interventions.length()
  {
    side,
    window_id,
    label: "fake-action-\{side.label()}",
    detail: "minimal action with \{count} \{intervention_word(count)}",
  }
}

///|
/// Check for game ending based on current state. Returns Some(ending) if the
/// game should end, None otherwise.
fn GameState::check_ending(self : GameState) -> GameEnding? {
  // Both eliminated in the same window
  if !self.side_a_alive && !self.side_b_alive {
    return Some(BothEliminated("both sides eliminated in the same window"))
  }
  // Side A eliminated → B wins
  if !self.side_a_alive {
    let (route, _) = self.side_b_potential.highest_route()
    return Some(
      SideVictory(@protocol.B, route, "B survives while A is eliminated"),
    )
  }
  // Side B eliminated → A wins
  if !self.side_b_alive {
    let (route, _) = self.side_a_potential.highest_route()
    return Some(
      SideVictory(@protocol.A, route, "A survives while B is eliminated"),
    )
  }
  // Forced end: max windows reached
  if self.executed_windows >= max_windows {
    return Some(ForcedEnd("max windows (\{max_windows}) reached"))
  }
  None
}

///|
pub fn GameState::resolve_window(
  self : GameState,
  window_id : @protocol.WindowId,
  actions : Array[GameAction],
) -> ResolveResult {
  ignore(actions)
  let new_state : GameState = {
    seed: self.seed,
    executed_windows: self.executed_windows + 1,
    side_a_alive: self.side_a_alive,
    side_b_alive: self.side_b_alive,
    side_a_potential: self.side_a_potential,
    side_b_potential: self.side_b_potential,
  }
  let ending = new_state.check_ending()
  {
    state: new_state,
    public_log: "window \{window_id.value()} resolved by minimal ruleset",
    ending,
  }
}
