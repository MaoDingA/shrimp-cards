/// Testability infrastructure for deterministic testing.
///
/// Provides:
///   - Mock LLM layer for testing without real API calls
///   - Test scenario builder for constructing game states
///   - Property assertion helpers for non-deterministic output

// --- Mock LLM Layer ---

/// A canned response that the mock LLM will return.

///|
pub(all) struct MockLLMResponse {
  /// The NPC response to return.
  response : NPCResponse
  /// Whether this response should be returned only once.
  consume : Bool
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn MockLLMResponse::once(response~ : NPCResponse) -> MockLLMResponse {
  { response, consume: true }
}

///|
pub fn MockLLMResponse::always(response~ : NPCResponse) -> MockLLMResponse {
  { response, consume: false }
}

/// A mock LLM that returns predetermined responses.
/// Supports pattern-based matching and one-shot responses.

///|
pub(all) struct MockLLM {
  /// Responses indexed by a pattern key (substring match on input).
  responses : Array[(String, MockLLMResponse)]
  /// Default response when no pattern matches.
  default_response : NPCResponse
  /// Number of times respond() was called.
  call_count : Int
  /// Record of all inputs received.
  input_log : Array[String]
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn MockLLM::new(default~ : NPCResponse) -> MockLLM {
  { responses: [], default_response: default, call_count: 0, input_log: [] }
}

///|
pub fn MockLLM::add_response(
  self : MockLLM,
  pattern : String,
  mock : MockLLMResponse,
) -> MockLLM {
  let responses = self.responses.copy()
  responses.push((pattern, mock))
  { ..self, responses, }
}

/// Simulate an LLM call. Returns the matched response or default.

///|
pub fn MockLLM::respond(
  self : MockLLM,
  input : String,
) -> (MockLLM, NPCResponse) {
  let mut found : NPCResponse? = None
  let remaining : Array[(String, MockLLMResponse)] = []
  for pair in self.responses {
    let (pattern, mock) = pair
    if found is None && input.contains(pattern) {
      found = Some(mock.response)
      if !mock.consume {
        remaining.push((pattern, mock))
      }
    } else {
      remaining.push((pattern, mock))
    }
  }
  let result = match found {
    Some(r) => r
    None => self.default_response
  }
  let log = self.input_log.copy()
  log.push(input)
  (
    {
      ..self,
      responses: remaining,
      call_count: self.call_count + 1,
      input_log: log,
    },
    result,
  )
}

///|
pub fn MockLLM::was_called(self : MockLLM) -> Bool {
  self.call_count > 0
}

///|
pub fn MockLLM::times_called(self : MockLLM) -> Int {
  self.call_count
}

///|
pub fn MockLLM::last_input(self : MockLLM) -> String? {
  if self.input_log.length() == 0 {
    None
  } else {
    Some(self.input_log[self.input_log.length() - 1])
  }
}

// --- Test Scenario Builder ---

/// Builder for constructing game states in tests.

///|
pub(all) struct TestScenario {
  seed : Int
  turn : Int
  side_a_alive : Bool
  side_b_alive : Bool
  side_a_potential : RoutePotential
  side_b_potential : RoutePotential
  blackboard : WorldBlackboard
  budget : TokenBudget
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn TestScenario::new() -> TestScenario {
  {
    seed: 42,
    turn: 1,
    side_a_alive: true,
    side_b_alive: true,
    side_a_potential: RoutePotential::zero(),
    side_b_potential: RoutePotential::zero(),
    blackboard: WorldBlackboard::new(turn=1),
    budget: TokenBudget::default(),
  }
}

///|
pub fn TestScenario::with_seed(self : TestScenario, seed : Int) -> TestScenario {
  { ..self, seed, }
}

///|
pub fn TestScenario::with_turn(self : TestScenario, turn : Int) -> TestScenario {
  { ..self, turn, blackboard: WorldBlackboard::new(turn~) }
}

///|
pub fn TestScenario::with_side_a_alive(
  self : TestScenario,
  alive : Bool,
) -> TestScenario {
  { ..self, side_a_alive: alive }
}

///|
pub fn TestScenario::with_side_b_alive(
  self : TestScenario,
  alive : Bool,
) -> TestScenario {
  { ..self, side_b_alive: alive }
}

///|
pub fn TestScenario::with_potential(
  self : TestScenario,
  side : @protocol.Side,
  route : VictoryRoute,
  value : Int,
) -> TestScenario {
  match side {
    @protocol.A => {
      let p = self.side_a_potential.add(route, value)
      { ..self, side_a_potential: p }
    }
    @protocol.B => {
      let p = self.side_b_potential.add(route, value)
      { ..self, side_b_potential: p }
    }
  }
}

///|
pub fn TestScenario::to_game_state(self : TestScenario) -> GameState {
  {
    seed: self.seed,
    executed_windows: self.turn - 1,
    side_a_alive: self.side_a_alive,
    side_b_alive: self.side_b_alive,
    side_a_potential: self.side_a_potential,
    side_b_potential: self.side_b_potential,
  }
}

// --- Property Assertion Helpers ---

/// Check that a value is within an expected range.

///|
pub fn check_in_range(value : Int, min : Int, max : Int) -> Bool {
  value >= min && value <= max
}

/// Check that a string is non-empty and within max length.

///|
pub fn check_valid_text(text : String, max_length : Int) -> Bool {
  text.length() > 0 && text.length() <= max_length
}
