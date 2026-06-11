///|
test "mock provider returns default response for initial plan" {
  let provider = mock_provider_with_default()
  let request = LLMRequest::new(
    kind=InitialPlan,
    side=@protocol.A,
    window_id=@protocol.WindowId::new(1),
    prompt="game state summary",
    max_tokens=max_tokens_initial_plan,
    model_tier=Fast,
  )
  let (provider2, response) = provider.generate(request)
  assert_true(response.content.length() > 0)
  assert_true(!response.is_fallback)
  assert_true(provider2.current_state().times_called() == 1)
}

///|
test "mock provider with patterns matches requests" {
  let custom = NPCResponse::new(
    dialogue="I will help you.",
    action=Talk,
    emotion=Friendly,
    accepted=true,
    reason="persuaded",
    relationship_delta=1,
    information_disclosed=["secret passage"],
    narration="The innkeeper nods slowly.",
  )
  let provider = mock_provider_with_patterns(fallback_npc_response(), [
    ("persuade", MockLLMResponse::once(response=custom)),
  ])
  let request = LLMRequest::new(
    kind=NPCDialogue,
    side=@protocol.A,
    window_id=@protocol.WindowId::new(1),
    prompt="persuade the innkeeper to reveal secrets",
    max_tokens=max_tokens_npc_dialogue,
    model_tier=Standard,
  )
  let (provider2, response) = provider.generate(request)
  assert_true(response.content.contains("I will help you"))
  // Second call should fall back to default (pattern was consumed)
  let (_, response2) = provider2.generate(request)
  assert_true(!response2.content.contains("I will help you"))
}

///|
test "build initial plan prompt contains key info" {
  let prompt = build_initial_plan_prompt(
    @protocol.A,
    @protocol.WindowId::new(3),
    "seed 42 step 2 A=alive(5) B=alive(3)",
    "turn: 3, A: tavern",
  )
  assert_true(prompt.contains("player A"))
  assert_true(prompt.contains("Window 3"))
  assert_true(prompt.contains("seed 42"))
  assert_true(prompt.contains("tavern"))
}

///|
test "build final plan prompt includes interventions" {
  let interventions = [
    @protocol.Intervention::new(
      side=@protocol.A,
      window_id=@protocol.WindowId::new(1),
      sequence_id=@protocol.SequenceId::new(1),
      kind=@protocol.SoftPreference,
      text="/prefer defend",
    ),
  ]
  let prompt = build_final_plan_prompt(
    @protocol.A,
    @protocol.WindowId::new(1),
    "state summary",
    interventions,
    "initial: observe",
  )
  assert_true(prompt.contains("soft"))
  assert_true(prompt.contains("prefer defend"))
  assert_true(prompt.contains("initial: observe"))
}

///|
test "build npc dialogue prompt contains all sections" {
  let prompt = build_npc_dialogue_prompt(
    "innkeeper", "Player A asked about stranger yesterday", "Tell me about the mysterious visitor.",
    "turn 5, tavern, evening",
  )
  assert_true(prompt.contains("innkeeper"))
  assert_true(prompt.contains("stranger"))
  assert_true(prompt.contains("mysterious visitor"))
  assert_true(prompt.contains("tavern"))
}
