///|
pub(all) struct GameState {
  seed : Int
  executed_windows : Int
  side_a_energy : Int
  side_b_energy : Int
} derive(Eq, Debug)

///|
pub(all) struct GameObservation {
  side : @protocol.Side
  window_id : @protocol.WindowId
  state_summary : String
} derive(Eq, Debug)

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
} derive(Eq, Debug)

///|
pub fn GameState::initial(seed~ : Int) -> GameState {
  { seed, executed_windows: 0, side_a_energy: 1, side_b_energy: 1 }
}

///|
pub fn GameState::summary(self : GameState) -> String {
  "seed \{self.seed} step \{self.executed_windows} energy A=\{self.side_a_energy} B=\{self.side_b_energy}"
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
pub fn GameState::resolve_window(
  self : GameState,
  window_id : @protocol.WindowId,
  actions : Array[GameAction],
) -> ResolveResult {
  ignore(actions)
  {
    state: {
      seed: self.seed,
      executed_windows: self.executed_windows + 1,
      side_a_energy: self.side_a_energy,
      side_b_energy: self.side_b_energy,
    },
    public_log: "window \{window_id.value()} resolved by minimal ruleset",
  }
}
