/// Mock LLM provider adapter.
///
/// Connects the existing MockLLM infrastructure to the LLMProvider interface.
/// This is the default provider used by the host for testing and development.

/// Build a prompt summary from an LLM request for MockLLM pattern matching.

///|
fn request_prompt_text(request : LLMRequest) -> String {
  request.kind.label() +
  " " +
  request.side.label() +
  " " +
  request.window_id.value().to_string() +
  " " +
  request.prompt
}

/// Mock LLM provider generate function.
///
/// Uses the MockLLM's respond() method to return canned responses.
/// Converts NPCResponse to LLMResponse text.

///|
pub fn mock_llm_generate(
  state : MockLLM,
  request : LLMRequest,
) -> (MockLLM, LLMResponse) {
  let prompt_text = request_prompt_text(request)
  let (new_state, npc_response) = state.respond(prompt_text)
  let content = match request.kind {
    InitialPlan | FinalPlan =>
      npc_response.action.label() + "|" + npc_response.reason
    NPCDialogue =>
      npc_response.dialogue +
      "|" +
      npc_response.action.label() +
      "|" +
      npc_response.narration
    Narration => npc_response.narration
    Precompute => npc_response.dialogue
  }
  let estimated_tokens = content.length() / 4 + 1
  (
    new_state,
    LLMResponse::new(
      content~,
      tokens_used=estimated_tokens,
      actual_tier=request.model_tier,
      is_fallback=false,
    ),
  )
}

/// Create a mock LLM provider with a default fallback NPC response.

///|
pub fn mock_provider_with_default() -> LLMProvider {
  LLMProvider::new(
    state=MockLLM::new(default=fallback_npc_response()),
    generate_fn=mock_llm_generate,
  )
}

/// Create a mock LLM provider with a custom default response.

///|
pub fn mock_provider(custom_default : NPCResponse) -> LLMProvider {
  LLMProvider::new(
    state=MockLLM::new(default=custom_default),
    generate_fn=mock_llm_generate,
  )
}

/// Create a mock LLM provider with pattern-based responses.

///|
pub fn mock_provider_with_patterns(
  default_response : NPCResponse,
  patterns : Array[(String, MockLLMResponse)],
) -> LLMProvider {
  let mut state = MockLLM::new(default=default_response)
  for entry in patterns {
    let (pattern, response) = entry
    state = state.add_response(pattern, response)
  }
  LLMProvider::new(state~, generate_fn=mock_llm_generate)
}
