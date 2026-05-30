/// Latency and real-time response management.
///
/// Implements:
///   - Tiered model routing (Fast/Standard/Premium)
///   - Streaming response pipeline simulation
///   - Precomputation strategy hints
///   - Timeout and fallback strategy

// --- Model Tier Routing ---

/// Model tier for LLM calls. Determines cost, latency, and quality tradeoffs.

///|
pub(all) enum ModelTier {
  /// Fast: small model for simple interactions (idle chat, info queries).
  /// ~300ms, lowest cost.
  Fast
  /// Standard: mid model for normal interactions (persuasion, trading).
  /// ~2-3s, standard cost.
  Standard
  /// Premium: large model for key narrative moments (kill attempts, endings).
  /// ~5-8s, highest cost, best quality.
  Premium
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn ModelTier::label(self : ModelTier) -> String {
  match self {
    Fast => "fast"
    Standard => "standard"
    Premium => "premium"
  }
}

///|
/// Estimated latency in milliseconds for each tier.
pub let latency_fast : Int = 300

///|
pub let latency_standard : Int = 2500

///|
pub let latency_premium : Int = 6000

///|
/// Timeout thresholds in milliseconds.
pub let timeout_primary : Int = 3000

///|
pub let timeout_fallback : Int = 10000

///|
pub fn ModelTier::estimated_latency_ms(self : ModelTier) -> Int {
  match self {
    Fast => latency_fast
    Standard => latency_standard
    Premium => latency_premium
  }
}

///|
/// Relative cost multiplier for each tier (1x = baseline).
pub let cost_multiplier_fast : Int = 1

///|
pub let cost_multiplier_standard : Int = 5

///|
pub let cost_multiplier_premium : Int = 25

///|
pub fn ModelTier::cost_multiplier(self : ModelTier) -> Int {
  match self {
    Fast => cost_multiplier_fast
    Standard => cost_multiplier_standard
    Premium => cost_multiplier_premium
  }
}

/// Route to the appropriate model tier based on interaction context.
/// Uses intent type and game state to determine the right quality/cost balance.

///|
pub(all) struct RoutingContext {
  /// The classified player intent from Gate 2.
  intent : PlayerIntent
  /// Whether this is a kill attempt (narrative climax).
  is_kill_attempt : Bool
  /// Whether this is an endgame scene.
  is_endgame : Bool
  /// Current turn number.
  turn : Int
  /// Token budget remaining for this game session.
  token_budget_remaining : Int
  /// Whether token conservation mode is active.
  conservation_mode : Bool
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn RoutingContext::new(
  intent~ : PlayerIntent,
  is_kill_attempt~ : Bool,
  is_endgame~ : Bool,
  turn~ : Int,
  token_budget_remaining~ : Int,
  conservation_mode~ : Bool,
) -> RoutingContext {
  {
    intent,
    is_kill_attempt,
    is_endgame,
    turn,
    token_budget_remaining,
    conservation_mode,
  }
}

/// Decide the model tier for a given interaction.

///|
pub fn route_model(ctx : RoutingContext) -> ModelTier {
  // Conservation mode: everything goes to Fast
  if ctx.conservation_mode {
    // Exception: endgame always gets at least Standard
    if ctx.is_endgame {
      return Standard
    }
    return Fast
  }
  // Kill attempts and endgame: always Premium
  if ctx.is_kill_attempt || ctx.is_endgame {
    return Premium
  }
  // Intent-based routing
  match ctx.intent {
    // Low-complexity: fast model
    Inquire => Fast
    Explore => Fast
    Move => Fast
    // Medium complexity: standard model
    Persuade => Standard
    Bribe => Standard
    Threaten => Standard
    // High complexity: standard model with option to upgrade
    Attack => Standard
    Investigate => Standard
    Other => Fast
  }
}

// --- Streaming Response Pipeline ---

/// Stage of a streaming NPC response.

///|
pub(all) enum ResponseStage {
  /// Player input received, waiting for intent classification.
  Received
  /// Intent classification complete (Gate 2), evaluating effect.
  Classifying
  /// Effect evaluation complete (Gate 3), generating NPC response.
  Evaluating
  /// NPC response streaming in progress.
  Streaming
  /// Response complete, state update pending.
  Complete
  /// Response failed, using fallback.
  Fallback
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn ResponseStage::label(self : ResponseStage) -> String {
  match self {
    Received => "received"
    Classifying => "classifying"
    Evaluating => "evaluating"
    Streaming => "streaming"
    Complete => "complete"
    Fallback => "fallback"
  }
}

/// A snapshot of the streaming response progress.

///|
pub(all) struct ResponseProgress {
  /// Current stage.
  stage : ResponseStage
  /// Estimated total time in ms.
  estimated_total_ms : Int
  /// Elapsed time in ms.
  elapsed_ms : Int
  /// Partial text received so far (during Streaming stage).
  partial_text : String
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn ResponseProgress::new(
  stage~ : ResponseStage,
  estimated_total_ms~ : Int,
  elapsed_ms~ : Int,
  partial_text~ : String,
) -> ResponseProgress {
  { stage, estimated_total_ms, elapsed_ms, partial_text }
}

///|
pub fn ResponseProgress::progress_fraction(self : ResponseProgress) -> Int {
  if self.estimated_total_ms == 0 {
    return 100
  }
  let frac = self.elapsed_ms * 100 / self.estimated_total_ms
  if frac > 100 {
    100
  } else {
    frac
  }
}

// --- Precomputation Strategy ---

/// Types of precomputed content that can be generated between windows.

///|
pub(all) enum PrecomputeType {
  /// Idle dialogue lines for each NPC.
  NPCIdleDialogue
  /// Scene branch descriptions for common actions.
  SceneBranches
  /// Standard responses for common queries.
  StandardResponses
} derive(Eq, Debug, ToJson, FromJson)

/// A precomputation request.

///|
pub(all) struct PrecomputeRequest {
  /// What to precompute.
  precompute_type : PrecomputeType
  /// Target NPC name (if applicable).
  npc_name : String
  /// Estimated token cost.
  token_cost : Int
  /// Priority (higher = precompute first).
  priority : Int
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn PrecomputeRequest::new(
  precompute_type~ : PrecomputeType,
  npc_name~ : String,
  token_cost~ : Int,
  priority~ : Int,
) -> PrecomputeRequest {
  { precompute_type, npc_name, token_cost, priority }
}

/// Decide what to precompute between windows.

///|
pub fn plan_precomputation(
  npc_names : Array[String],
  token_budget : Int,
) -> Array[PrecomputeRequest] {
  let requests : Array[PrecomputeRequest] = []
  let mut budget_used = 0
  // NPC idle dialogue is highest priority
  for name in npc_names {
    let cost = 200
    if budget_used + cost <= token_budget {
      requests.push(
        PrecomputeRequest::new(
          precompute_type=NPCIdleDialogue,
          npc_name=name,
          token_cost=cost,
          priority=3,
        ),
      )
      budget_used = budget_used + cost
    }
  }
  // Scene branches are medium priority
  if budget_used + 500 <= token_budget {
    requests.push(
      PrecomputeRequest::new(
        precompute_type=SceneBranches,
        npc_name="",
        token_cost=500,
        priority=2,
      ),
    )
    budget_used = budget_used + 500
  }
  // Standard responses are lowest priority
  if budget_used + 300 <= token_budget {
    requests.push(
      PrecomputeRequest::new(
        precompute_type=StandardResponses,
        npc_name="",
        token_cost=300,
        priority=1,
      ),
    )
  }
  requests
}

// --- Timeout and Fallback ---

/// Result of a timeout check.

///|
pub(all) enum TimeoutAction {
  /// Continue waiting, response is coming.
  Continue
  /// Downgrade to a faster model.
  Downgrade(ModelTier)
  /// Return a preset fallback response.
  UseFallback
} derive(Eq, Debug, ToJson, FromJson)

/// Decide timeout action based on elapsed time and current tier.

///|
pub fn check_timeout(
  elapsed_ms : Int,
  current_tier : ModelTier,
) -> TimeoutAction {
  if elapsed_ms >= timeout_fallback {
    return UseFallback
  }
  if elapsed_ms >= timeout_primary {
    // Downgrade: Premium -> Standard -> Fast
    match current_tier {
      Premium => Downgrade(Standard)
      Standard => Downgrade(Fast)
      Fast => UseFallback
    }
  } else {
    Continue
  }
}
