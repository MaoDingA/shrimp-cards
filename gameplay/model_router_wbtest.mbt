// --- C4: Latency and Real-time Response Tests ---

// --- Model Tier Routing ---

///|
test "model tier labels" {
  assert_eq(Fast.label(), "fast")
  assert_eq(Standard.label(), "standard")
  assert_eq(Premium.label(), "premium")
}

///|
test "model tier latency estimates" {
  assert_true(Fast.estimated_latency_ms() < Standard.estimated_latency_ms())
  assert_true(Standard.estimated_latency_ms() < Premium.estimated_latency_ms())
}

///|
test "model tier cost multipliers" {
  assert_eq(Fast.cost_multiplier(), 1)
  assert_eq(Standard.cost_multiplier(), 5)
  assert_eq(Premium.cost_multiplier(), 25)
}

///|
test "route simple intents to fast" {
  let ctx = RoutingContext::new(
    intent=Inquire,
    is_kill_attempt=false,
    is_endgame=false,
    turn=5,
    token_budget_remaining=10000,
    conservation_mode=false,
  )
  assert_true(route_model(ctx) == Fast)
}

///|
test "route medium intents to standard" {
  let ctx = RoutingContext::new(
    intent=Persuade,
    is_kill_attempt=false,
    is_endgame=false,
    turn=5,
    token_budget_remaining=10000,
    conservation_mode=false,
  )
  assert_true(route_model(ctx) == Standard)
}

///|
test "route kill attempts to premium" {
  let ctx = RoutingContext::new(
    intent=Attack,
    is_kill_attempt=true,
    is_endgame=false,
    turn=10,
    token_budget_remaining=5000,
    conservation_mode=false,
  )
  assert_true(route_model(ctx) == Premium)
}

///|
test "route endgame to premium" {
  let ctx = RoutingContext::new(
    intent=Inquire,
    is_kill_attempt=false,
    is_endgame=true,
    turn=18,
    token_budget_remaining=2000,
    conservation_mode=false,
  )
  assert_true(route_model(ctx) == Premium)
}

///|
test "conservation mode routes to fast except endgame" {
  let ctx_normal = RoutingContext::new(
    intent=Persuade,
    is_kill_attempt=false,
    is_endgame=false,
    turn=5,
    token_budget_remaining=1000,
    conservation_mode=true,
  )
  assert_true(route_model(ctx_normal) == Fast)
  let ctx_endgame = RoutingContext::new(
    intent=Persuade,
    is_kill_attempt=false,
    is_endgame=true,
    turn=18,
    token_budget_remaining=1000,
    conservation_mode=true,
  )
  assert_true(route_model(ctx_endgame) == Standard)
}

// --- Streaming Response ---

///|
test "response stage labels" {
  assert_eq(Received.label(), "received")
  assert_eq(Streaming.label(), "streaming")
  assert_eq(Complete.label(), "complete")
  assert_eq(Fallback.label(), "fallback")
}

///|
test "progress fraction calculation" {
  let progress = ResponseProgress::new(
    stage=Streaming,
    estimated_total_ms=1000,
    elapsed_ms=500,
    partial_text="Hello...",
  )
  assert_eq(progress.progress_fraction(), 50)
}

///|
test "progress fraction capped at 100" {
  let progress = ResponseProgress::new(
    stage=Streaming,
    estimated_total_ms=1000,
    elapsed_ms=2000,
    partial_text="done",
  )
  assert_eq(progress.progress_fraction(), 100)
}

///|
test "progress fraction handles zero total" {
  let progress = ResponseProgress::new(
    stage=Received,
    estimated_total_ms=0,
    elapsed_ms=100,
    partial_text="",
  )
  assert_eq(progress.progress_fraction(), 100)
}

// --- Precomputation ---

///|
test "plan precomputation within budget" {
  let npcs = ["innkeeper", "blacksmith", "guard"]
  let requests = plan_precomputation(npcs, 2000)
  // 3 NPC idle dialogues (200 each) + 1 scene branches (500) + 1 standard (300)
  assert_true(requests.length() >= 3)
  let mut has_idle = false
  let mut has_scene = false
  for req in requests {
    match req.precompute_type {
      NPCIdleDialogue => has_idle = true
      SceneBranches => has_scene = true
      StandardResponses => ignore(0)
    }
  }
  assert_true(has_idle)
  assert_true(has_scene)
}

///|
test "plan precomputation respects budget" {
  let npcs = ["innkeeper", "blacksmith", "guard"]
  let requests = plan_precomputation(npcs, 100)
  // Budget too small for any precomputation
  assert_eq(requests.length(), 0)
}

// --- Timeout ---

///|
test "timeout continue when within limit" {
  assert_true(check_timeout(1000, Standard) == Continue)
}

///|
test "timeout downgrade after primary threshold" {
  match check_timeout(3500, Premium) {
    Downgrade(Standard) => assert_true(true)
    _ => fail("expected Downgrade to Standard")
  }
  match check_timeout(3500, Standard) {
    Downgrade(Fast) => assert_true(true)
    _ => fail("expected Downgrade to Fast")
  }
}

///|
test "timeout fallback after secondary threshold" {
  assert_true(check_timeout(11000, Fast) == UseFallback)
}

///|
test "timeout fast model has no downgrade" {
  match check_timeout(3500, Fast) {
    UseFallback => assert_true(true)
    _ => fail("expected UseFallback for Fast model timeout")
  }
}
