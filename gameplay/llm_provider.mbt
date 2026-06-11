/// LLM provider abstraction layer.
///
/// Defines the interface between the game engine and any LLM backend.
/// The host/session calls this interface to generate agent plans,
/// NPC responses, and narrative content.
///
/// Two implementations exist:
///   - MockLLMProvider: deterministic canned responses (for testing)
///   - (future) HttpLLMProvider: real API calls to OpenAI/Anthropic/etc.
///
/// Integration points in host/session:
///   1. Initial plan generation (window opened)
///   2. Final plan generation (window locked, interventions applied)
///   3. NPC dialogue generation
///   4. Narrative narration generation

/// The kind of content being requested from the LLM.

///|
pub(all) enum LLMRequestKind {
  /// Agent initial plan for a decision window.
  InitialPlan
  /// Agent final plan after player interventions.
  FinalPlan
  /// NPC dialogue and action response.
  NPCDialogue
  /// Scene narration text.
  Narration
  /// Precomputation (idle dialogue, scene branches).
  Precompute
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn LLMRequestKind::label(self : LLMRequestKind) -> String {
  match self {
    InitialPlan => "initial_plan"
    FinalPlan => "final_plan"
    NPCDialogue => "npc_dialogue"
    Narration => "narration"
    Precompute => "precompute"
  }
}

/// A structured request to the LLM.

///|
pub(all) struct LLMRequest {
  /// What kind of content is being requested.
  kind : LLMRequestKind
  /// Which side is requesting (A or B).
  side : @protocol.Side
  /// Current window ID.
  window_id : @protocol.WindowId
  /// The assembled prompt context.
  prompt : String
  /// Maximum tokens allowed for the response.
  max_tokens : Int
  /// Model tier hint for the backend.
  model_tier : ModelTier
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn LLMRequest::new(
  kind~ : LLMRequestKind,
  side~ : @protocol.Side,
  window_id~ : @protocol.WindowId,
  prompt~ : String,
  max_tokens~ : Int,
  model_tier~ : ModelTier,
) -> LLMRequest {
  { kind, side, window_id, prompt, max_tokens, model_tier }
}

/// A structured response from the LLM.

///|
pub(all) struct LLMResponse {
  /// The generated text content.
  content : String
  /// How many tokens were actually used.
  tokens_used : Int
  /// Which model tier was actually used (may differ from request).
  actual_tier : ModelTier
  /// Whether the response is from a fallback.
  is_fallback : Bool
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn LLMResponse::new(
  content~ : String,
  tokens_used~ : Int,
  actual_tier~ : ModelTier,
  is_fallback~ : Bool,
) -> LLMResponse {
  { content, tokens_used, actual_tier, is_fallback }
}

/// The LLM provider.
///
/// Wraps a MockLLM state and a generate function. The generate function
/// takes the current state and a request, returns (new_state, response).
/// This allows the provider to be stateless per-call while tracking
/// call counts and input logs internally.

///|
pub(all) struct LLMProvider {
  mut state : MockLLM
  generate_fn : (MockLLM, LLMRequest) -> (MockLLM, LLMResponse)
} derive(Debug)

///|
pub fn LLMProvider::new(
  state~ : MockLLM,
  generate_fn~ : (MockLLM, LLMRequest) -> (MockLLM, LLMResponse),
) -> LLMProvider {
  { state, generate_fn }
}

/// Call the provider and return the updated provider + response.

///|
pub fn LLMProvider::generate(
  self : LLMProvider,
  request : LLMRequest,
) -> (LLMProvider, LLMResponse) {
  let (new_state, response) = (self.generate_fn)(self.state, request)
  self.state = new_state
  (self, response)
}

///|
pub fn LLMProvider::current_state(self : LLMProvider) -> MockLLM {
  self.state
}

// --- Prompt Building ---

/// Assemble a prompt for initial agent plan generation.

///|
pub fn build_initial_plan_prompt(
  side : @protocol.Side,
  window_id : @protocol.WindowId,
  state_summary : String,
  blackboard_text : String,
) -> String {
  "You are the strategic agent for player " +
  side.label() +
  ". Window " +
  window_id.value().to_string() +
  " has opened. Game state: " +
  state_summary +
  ". World context: " +
  blackboard_text +
  ". Generate an initial action plan for this window. Format: <action_label>|<reasoning>"
}

/// Assemble a prompt for final agent plan with interventions.

///|
pub fn build_final_plan_prompt(
  side : @protocol.Side,
  window_id : @protocol.WindowId,
  state_summary : String,
  interventions : Array[@protocol.Intervention],
  initial_plan : String,
) -> String {
  let intervention_texts : Array[String] = []
  for iv in interventions {
    if iv.side == side {
      intervention_texts.push("[" + iv.kind.wire_label() + "] " + iv.text)
    }
  }
  let iv_block = intervention_texts.join(", ")
  "You are the strategic agent for player " +
  side.label() +
  ". Window " +
  window_id.value().to_string() +
  " is being finalized. Game state: " +
  state_summary +
  ". Your initial plan: " +
  initial_plan +
  ". Player interventions: " +
  iv_block +
  ". Generate the final action plan incorporating interventions. Format: <action_label>|<reasoning>"
}

/// Assemble a prompt for NPC dialogue generation.

///|
pub fn build_npc_dialogue_prompt(
  npc_name : String,
  npc_memory : String,
  player_input : String,
  world_context : String,
) -> String {
  "NPC: " +
  npc_name +
  ". Memory: " +
  npc_memory +
  ". World: " +
  world_context +
  ". Player says: " +
  player_input +
  ". Generate the NPC response as JSON with fields: dialogue, action (talk/gift/attack/flee/stall), emotion (neutral/friendly/hostile/suspicious/fearful), accepted (bool), reason, relationship_delta, narration."
}

// --- Default Token Budgets ---

///|
pub let max_tokens_initial_plan : Int = 200

///|
pub let max_tokens_final_plan : Int = 300

///|
pub let max_tokens_npc_dialogue : Int = 400

///|
pub let max_tokens_narration : Int = 150
