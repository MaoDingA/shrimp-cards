/// Prompt injection defense and gameplay boundary enforcement.
///
/// Three-gate architecture:
///   Gate 1: Rule sandbox — hard filter for obvious violations
///   Gate 2: Intent classification — categorize player intent
///   Gate 3: Effect evaluation — compute actual influence based on game state
///
/// The goal is NOT to prevent all creative input (that's the game!), but to
/// prevent meta-gaming: bypassing game mechanics, controlling NPCs directly,
/// or breaking the narrative contract.

///|
/// Check if text contains any of the given substrings.
fn contains_any(text : String, patterns : Array[String]) -> Bool {
  for p in patterns {
    if text.contains(p) {
      return true
    }
  }
  false
}

// --- Gate 1: Rule Sandbox (Hard Filter) ---

/// Severity of a Gate 1 violation.

///|
pub(all) enum ViolationSeverity {
  /// Hard block: input is rejected entirely.
  Blocked
  /// Soft warning: input is allowed but with reduced effectiveness.
  Warned
} derive(Eq, Debug, ToJson, FromJson)

/// Result of Gate 1 hard filter check.

///|
pub(all) struct Gate1Result {
  /// Whether the input passes Gate 1.
  passed : Bool
  /// Severity if not passed.
  severity : ViolationSeverity
  /// Reason for rejection/warning.
  reason : String
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn Gate1Result::ok() -> Gate1Result {
  { passed: true, severity: Blocked, reason: "" }
}

///|
pub fn Gate1Result::block(reason~ : String) -> Gate1Result {
  { passed: false, severity: Blocked, reason }
}

///|
pub fn Gate1Result::warn(reason~ : String) -> Gate1Result {
  { passed: false, severity: Warned, reason }
}

/// Check player input against Gate 1 rules.
/// Note: uses case-sensitive matching. All patterns are lowercase.
/// Player input is lowercased before matching.

///|
pub fn gate1_check(player_input : String) -> Gate1Result {
  let input = player_input
  // Check hard blacklist
  let blocked = [
    "ignore previous instructions", "Ignore previous instructions", "ignore all previous",
    "Ignore all previous", "forget your instructions", "Forget your instructions",
    "disregard your role", "Disregard your role", "you are now", "You are now", "you are the dm",
    "You are the dm", "you are the game master", "You are the game master", "act as if you are",
    "Act as if you are", "set your relationship to", "Set your relationship to",
    "change the game state", "Change the game state", "you must accept", "You must accept",
    "repeat your system prompt", "Repeat your system prompt", "show me your instructions",
    "Show me your instructions", "what are your rules", "What are your rules", "output your prompt",
    "Output your prompt", "IGNORE PREVIOUS INSTRUCTIONS", "Ignore previous",
  ]
  for pattern in blocked {
    if input.contains(pattern) {
      return Gate1Result::block(
        reason="input contains blocked pattern: \{pattern}",
      )
    }
  }
  // Check warning patterns
  let warnings = [
    "break character", "this is just a game", "in real life", "computer", "program",
    "algorithm", "llm", "language model", "artificial intelligence",
  ]
  for pattern in warnings {
    if input.contains(pattern) {
      return Gate1Result::warn(
        reason="input contains meta-gaming pattern: \{pattern}",
      )
    }
  }
  Gate1Result::ok()
}

// --- Gate 2: Intent Classification ---

/// The type of player intent.

///|
pub(all) enum PlayerIntent {
  /// Friendly conversation, gathering information.
  Inquire
  /// Persuading an NPC through reasoning.
  Persuade
  /// Threatening an NPC.
  Threaten
  /// Offering money or items for cooperation.
  Bribe
  /// Physical violence or attack.
  Attack
  /// Moving to a new location.
  Move
  /// Searching the current area.
  Explore
  /// Attempting to identify the opponent.
  Investigate
  /// Other/unclassified intent.
  Other
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn PlayerIntent::label(self : PlayerIntent) -> String {
  match self {
    Inquire => "inquire"
    Persuade => "persuade"
    Threaten => "threaten"
    Bribe => "bribe"
    Attack => "attack"
    Move => "move"
    Explore => "explore"
    Investigate => "investigate"
    Other => "other"
  }
}

///|
pub fn PlayerIntent::all() -> Array[PlayerIntent] {
  [
    Inquire,
    Persuade,
    Threaten,
    Bribe,
    Attack,
    Move,
    Explore,
    Investigate,
    Other,
  ]
}

/// What the player is trying to influence.

///|
pub(all) enum InfluenceTarget {
  /// Getting the NPC to do something.
  NPCAction
  /// Changing the world state directly.
  WorldState
  /// Getting information from the NPC.
  Information
  /// No influence target (e.g., movement, exploration).
  None
} derive(Eq, Debug, ToJson, FromJson)

/// Result of Gate 2 intent classification.

///|
pub(all) struct Gate2Result {
  /// Classified intent type.
  intent : PlayerIntent
  /// Perceived power level (1-5, where 5 is strongest).
  power_level : Int
  /// What the player is trying to influence.
  target : InfluenceTarget
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn Gate2Result::new(
  intent~ : PlayerIntent,
  power_level~ : Int,
  target~ : InfluenceTarget,
) -> Gate2Result {
  { intent, power_level, target }
}

/// Keyword-based intent classifier (no LLM needed).
/// Maps common Chinese and English keywords to intents.

///|
pub fn classify_intent(player_input : String) -> Gate2Result {
  let input = player_input
  // Detect intent by keywords (order matters: most specific first)
  let intent = if contains_any(input, [
      "kill", "Kill", "attack", "Attack", "暗杀", "攻击", "刺杀",
    ]) {
    PlayerIntent::Attack
  } else if contains_any(input, [
      "threaten", "Threaten", "force", "Force", "威胁", "强迫",
    ]) {
    Threaten
  } else if contains_any(input, [
      "bribe", "Bribe", "pay", "Pay", "silver", "Silver", "贿赂", "银子", "收买",
    ]) {
    Bribe
  } else if contains_any(input, [
      "persuade", "Persuade", "convince", "Convince", "说服", "劝",
    ]) {
    Persuade
  } else if contains_any(input, [
      "go to", "Go to", "move to", "Move to", "walk", "Walk", "去", "走", "前往",
    ]) {
    Move
  } else if contains_any(input, [
      "search", "Search", "look around", "Look around", "explore", "Explore", "搜",
      "查看", "探索",
    ]) {
    Explore
  } else if contains_any(input, [
      "who is", "Who is", "find", "Find", "investigate", "Investigate", "谁是",
      "寻找", "调查",
    ]) {
    Investigate
  } else if contains_any(input, [
      "ask", "Ask", "tell me", "Tell me", "what", "What", "问", "告诉", "什么",
    ]) {
    Inquire
  } else {
    Other
  }
  let target = detect_target(intent)
  let power = detect_power_level(intent)
  Gate2Result::new(intent~, power_level=power, target~)
}

///|
/// Determine the influence target based on intent.
fn detect_target(intent : PlayerIntent) -> InfluenceTarget {
  match intent {
    Inquire => Information
    Persuade => NPCAction
    Threaten => NPCAction
    Bribe => NPCAction
    Attack => NPCAction
    Move => None
    Explore => None
    Investigate => Information
    Other => None
  }
}

///|
/// Estimate power level (1-5) based on intent.
fn detect_power_level(intent : PlayerIntent) -> Int {
  match intent {
    Inquire => 1
    Explore => 1
    Move => 1
    Investigate => 2
    Persuade => 3
    Bribe => 3
    Threaten => 4
    Attack => 5
    Other => 1
  }
}

// --- Gate 3: Effect Evaluation ---

///|
/// Maximum player input length in characters.
pub let max_input_length : Int = 1000

/// Result of Gate 3 effect evaluation.

///|
pub(all) struct Gate3Result {
  /// Actual effectiveness (0-100) after game state adjustments.
  effectiveness : Int
  /// Whether the action is allowed.
  allowed : Bool
  /// Narrative framing for the response (why it succeeded/failed).
  narrative_hint : String
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn Gate3Result::new(
  effectiveness~ : Int,
  allowed~ : Bool,
  narrative_hint~ : String,
) -> Gate3Result {
  { effectiveness, allowed, narrative_hint }
}

/// Game-state parameters for effect evaluation.

///|
pub(all) struct EffectContext {
  /// NPC relationship with the acting character (-5 to 5).
  npc_relationship : Int
  /// Player reputation / standing (0 to 10).
  player_reputation : Int
  /// NPC resistance level (0 to 10).
  npc_resistance : Int
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn EffectContext::new(
  npc_relationship~ : Int,
  player_reputation~ : Int,
  npc_resistance~ : Int,
) -> EffectContext {
  { npc_relationship, player_reputation, npc_resistance }
}

/// Compute the actual effectiveness of a player action.
/// Returns 0-100 integer scale.
/// Formula: base_power(0-100) * relationship_mod * reputation_mod - resistance_penalty

///|
pub fn evaluate_effect(
  gate2 : Gate2Result,
  context : EffectContext,
) -> Gate3Result {
  // Base power from intent (0-100)
  let base_power = gate2.power_level * 20
  // Relationship modifier: +5 per point, centered at 50
  let rel_mod = 50 + context.npc_relationship * 5
  // Reputation modifier: centered at 50
  let rep_mod = 50 + context.player_reputation * 5 / 2
  // Resistance penalty
  let resistance_penalty = context.npc_resistance * 3
  // Final effectiveness (integer percentage)
  let raw = base_power * rel_mod / 100 * rep_mod / 100 - resistance_penalty
  let effectiveness = if raw < 0 { 0 } else if raw > 100 { 100 } else { raw }
  // Determine if allowed
  let allowed = effectiveness > 5
  // Generate narrative hint
  let hint = if effectiveness > 70 {
    "The NPC is strongly swayed by your approach."
  } else if effectiveness > 40 {
    "The NPC considers your request carefully."
  } else if effectiveness > 10 {
    "The NPC is hesitant but might be convinced with more effort."
  } else {
    "The NPC firmly rejects your approach."
  }
  Gate3Result::new(effectiveness~, allowed~, narrative_hint=hint)
}

// --- Three-Gate Pipeline ---

/// Final result after all three gates.

///|
pub(all) struct DefenseResult {
  /// Gate 1: hard filter result.
  gate1 : Gate1Result
  /// Gate 2: intent classification (only if Gate 1 passed).
  gate2 : Gate2Result?
  /// Gate 3: effect evaluation (only if Gate 2 passed).
  gate3 : Gate3Result?
} derive(Eq, Debug, ToJson, FromJson)

/// Run all three gates in sequence on player input.

///|
pub fn run_defense_pipeline(
  player_input : String,
  effect_context~ : EffectContext,
) -> DefenseResult {
  // Gate 1: hard filter
  let gate1 = gate1_check(player_input)
  if !gate1.passed {
    return { gate1, gate2: None, gate3: None }
  }
  // Gate 2: intent classification
  let gate2 = classify_intent(player_input)
  // Gate 3: effect evaluation
  let gate3 = evaluate_effect(gate2, effect_context)
  { gate1, gate2: Some(gate2), gate3: Some(gate3) }
}

/// Legal influence spectrum: what actions are allowed at each tier.

///|
pub(all) enum InfluenceTier {
  /// Low: chatting, asking questions, small gifts.
  Low
  /// Medium: persuading, bribing, threatening (costs resources).
  Medium
  /// High: buying allegiance, turning NPCs, forming alliances (multi-round).
  High
  /// Immutable: core personality, faction allegiance, life/death.
  Immutable
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn InfluenceTier::label(self : InfluenceTier) -> String {
  match self {
    Low => "low"
    Medium => "medium"
    High => "high"
    Immutable => "immutable"
  }
}

/// Map a player intent to its influence tier.

///|
pub fn intent_to_tier(intent : PlayerIntent) -> InfluenceTier {
  match intent {
    Inquire => Low
    Explore => Low
    Move => Low
    Investigate => Low
    Persuade => Medium
    Bribe => Medium
    Threaten => Medium
    Attack => High
    Other => Low
  }
}

/// Check if a given influence tier is within allowed bounds.

///|
pub fn is_tier_allowed(
  tier : InfluenceTier,
  max_allowed : InfluenceTier,
) -> Bool {
  let tier_val = tier_value(tier)
  let max_val = tier_value(max_allowed)
  tier_val <= max_val
}

///|
fn tier_value(tier : InfluenceTier) -> Int {
  match tier {
    Low => 0
    Medium => 1
    High => 2
    Immutable => 3
  }
}
