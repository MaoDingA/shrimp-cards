// --- C10: Testability Infrastructure Tests ---

// --- Mock LLM ---

///|
test "mock llm returns default when no patterns match" {
  let mock = MockLLM::new(default=fallback_npc_response())
  let (mock2, response) = mock.respond("Hello innkeeper!")
  assert_true(mock2.was_called())
  assert_eq(mock2.times_called(), 1)
  assert_true(response.action == Neutral)
}

///|
test "mock llm matches pattern" {
  let custom = NPCResponse::new(
    dialogue="Welcome, traveler!",
    action=Talk,
    emotion=Friendly,
    accepted=true,
    reason="friendly",
    relationship_delta=1,
    information_disclosed=[],
    narration="The innkeeper smiles.",
  )
  let mock = MockLLM::new(default=fallback_npc_response()).add_response(
    "innkeeper",
    MockLLMResponse::always(response=custom),
  )
  let (mock2, resp) = mock.respond("Talk to the innkeeper.")
  assert_eq(resp.dialogue, "Welcome, traveler!")
  assert_true(resp.emotion == Friendly)
  assert_eq(mock2.times_called(), 1)
}

///|
test "mock llm one-shot response is consumed" {
  let custom = NPCResponse::new(
    dialogue="Secret info.",
    action=Talk,
    emotion=Neutral,
    accepted=true,
    reason="one-time",
    relationship_delta=0,
    information_disclosed=["a secret"],
    narration="Whispers.",
  )
  let mock = MockLLM::new(default=fallback_npc_response()).add_response(
    "secret",
    MockLLMResponse::once(response=custom),
  )
  let (mock2, resp1) = mock.respond("Tell me the secret.")
  assert_eq(resp1.dialogue, "Secret info.")
  let (mock3, resp2) = mock2.respond("Tell me the secret again.")
  // Second call should return default since one-shot was consumed
  assert_true(resp2.dialogue != "Secret info.")
  assert_eq(mock3.times_called(), 2)
}

///|
test "mock llm logs inputs" {
  let mock = MockLLM::new(default=fallback_npc_response())
  let (mock2, _) = mock.respond("first input")
  let (mock3, _) = mock2.respond("second input")
  assert_eq(mock3.last_input(), Some("second input"))
  assert_eq(mock3.times_called(), 2)
}

///|
test "mock llm always response is not consumed" {
  let custom = NPCResponse::new(
    dialogue="Always here.",
    action=Talk,
    emotion=Neutral,
    accepted=true,
    reason="permanent",
    relationship_delta=0,
    information_disclosed=[],
    narration=".",
  )
  let mock = MockLLM::new(default=fallback_npc_response()).add_response(
    "hello",
    MockLLMResponse::always(response=custom),
  )
  let (mock2, resp1) = mock.respond("hello there")
  assert_eq(resp1.dialogue, "Always here.")
  let (mock3, resp2) = mock2.respond("hello again")
  assert_eq(resp2.dialogue, "Always here.")
  assert_eq(mock3.times_called(), 2)
}

// --- Test Scenario Builder ---

///|
test "test scenario default values" {
  let scenario = TestScenario::new()
  assert_eq(scenario.seed, 42)
  assert_true(scenario.side_a_alive)
  assert_true(scenario.side_b_alive)
  assert_eq(scenario.side_a_potential.total(), 0)
}

///|
test "test scenario builder chains" {
  let scenario = TestScenario::new()
    .with_seed(100)
    .with_turn(5)
    .with_side_b_alive(false)
    .with_potential(@protocol.A, Law, 7)
  assert_eq(scenario.seed, 100)
  assert_eq(scenario.turn, 5)
  assert_true(scenario.side_a_alive)
  assert_true(!scenario.side_b_alive)
  assert_eq(scenario.side_a_potential.get(Law), 7)
}

///|
test "test scenario to game state" {
  let scenario = TestScenario::new()
    .with_turn(3)
    .with_potential(@protocol.B, Assassination, 5)
  let state = scenario.to_game_state()
  assert_eq(state.seed, 42)
  assert_eq(state.executed_windows, 2)
  assert_true(state.side_a_alive)
  assert_eq(state.side_b_potential.get(Assassination), 5)
}

// --- Property Assertions ---

///|
test "check in range passes for valid value" {
  assert_true(check_in_range(5, 0, 10))
  assert_true(!check_in_range(-1, 0, 10))
  assert_true(!check_in_range(11, 0, 10))
  assert_true(check_in_range(0, 0, 10))
  assert_true(check_in_range(10, 0, 10))
}

///|
test "check valid text passes for normal text" {
  assert_true(check_valid_text("Hello world", 100))
  assert_true(!check_valid_text("", 100))
  assert_true(!check_valid_text("x".repeat(101), 100))
}
