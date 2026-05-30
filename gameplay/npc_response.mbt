/// NPC interaction response schema. The LLM (or future rule engine) must
/// produce one of these for every character-NPC interaction. All fields are
/// validated; parsing failures trigger retry or fallback.

///|
pub(all) enum NPCAction {
  Talk
  Move
  GiveItem
  Attack
  Flee
  Neutral
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn NPCAction::label(self : NPCAction) -> String {
  match self {
    Talk => "talk"
    Move => "move"
    GiveItem => "give_item"
    Attack => "attack"
    Flee => "flee"
    Neutral => "neutral"
  }
}

///|
pub fn NPCAction::from_label(label : String) -> NPCAction? {
  match label {
    "talk" => Some(Talk)
    "move" => Some(Move)
    "give_item" => Some(GiveItem)
    "attack" => Some(Attack)
    "flee" => Some(Flee)
    "neutral" => Some(Neutral)
    _ => None
  }
}

///|
pub fn NPCAction::all() -> Array[NPCAction] {
  [Talk, Move, GiveItem, Attack, Flee, Neutral]
}

///|
pub(all) enum NPCEmotion {
  Friendly
  Neutral
  Suspicious
  Hostile
  Fearful
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn NPCEmotion::label(self : NPCEmotion) -> String {
  match self {
    Friendly => "friendly"
    Neutral => "neutral"
    Suspicious => "suspicious"
    Hostile => "hostile"
    Fearful => "fearful"
  }
}

///|
pub fn NPCEmotion::from_label(label : String) -> NPCEmotion? {
  match label {
    "friendly" => Some(Friendly)
    "neutral" => Some(Neutral)
    "suspicious" => Some(Suspicious)
    "hostile" => Some(Hostile)
    "fearful" => Some(Fearful)
    _ => None
  }
}

///|
pub fn NPCEmotion::all() -> Array[NPCEmotion] {
  [Friendly, Neutral, Suspicious, Hostile, Fearful]
}

///|
/// Maximum allowed dialogue length in characters.
pub let max_dialogue_length : Int = 500

///|
/// Relationship delta must be in this range.
pub let min_relationship_delta : Int = -5

///|
pub let max_relationship_delta : Int = 5

///|
pub(all) struct NPCResponse {
  /// What the NPC says (in-character dialogue).
  dialogue : String
  /// What the NPC does in response.
  action : NPCAction
  /// The NPC's emotional state after the interaction.
  emotion : NPCEmotion
  /// Whether the NPC accepted the character's request.
  accepted : Bool
  /// Why the NPC accepted or rejected (for replay/debugging).
  reason : String
  /// Change in relationship with the interacting character (-5 to 5).
  relationship_delta : Int
  /// Information the NPC discloses (if any).
  information_disclosed : Array[String]
  /// Narrator description of the scene (shown to player).
  narration : String
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn NPCResponse::new(
  dialogue~ : String,
  action~ : NPCAction,
  emotion~ : NPCEmotion,
  accepted~ : Bool,
  reason~ : String,
  relationship_delta~ : Int,
  information_disclosed~ : Array[String],
  narration~ : String,
) -> NPCResponse {
  {
    dialogue,
    action,
    emotion,
    accepted,
    reason,
    relationship_delta,
    information_disclosed,
    narration,
  }
}

/// Validation error for NPCResponse fields.

///|
pub(all) enum ValidationError {
  DialogueEmpty
  DialogueTooLong(Int) // actual length
  InvalidAction(String) // bad label
  InvalidEmotion(String) // bad label
  ReasonEmpty
  RelationshipDeltaOutOfRange(Int) // actual value
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn ValidationError::message(self : ValidationError) -> String {
  match self {
    DialogueEmpty => "dialogue must not be empty"
    DialogueTooLong(len) =>
      "dialogue too long: \{len} chars (max \{max_dialogue_length})"
    InvalidAction(label) => "invalid action: \{label}"
    InvalidEmotion(label) => "invalid emotion: \{label}"
    ReasonEmpty => "reason must not be empty"
    RelationshipDeltaOutOfRange(delta) =>
      "relationship_delta \{delta} out of range [\{min_relationship_delta}, \{max_relationship_delta}]"
  }
}

/// Validate an NPCResponse. Returns array of errors (empty if valid).

///|
pub fn NPCResponse::validate(self : NPCResponse) -> Array[ValidationError] {
  let errors : Array[ValidationError] = []
  if self.dialogue.length() == 0 {
    errors.push(DialogueEmpty)
  }
  if self.dialogue.length() > max_dialogue_length {
    errors.push(DialogueTooLong(self.dialogue.length()))
  }
  if self.reason.length() == 0 {
    errors.push(ReasonEmpty)
  }
  let out_of_range = self.relationship_delta < min_relationship_delta ||
    self.relationship_delta > max_relationship_delta
  if out_of_range {
    errors.push(RelationshipDeltaOutOfRange(self.relationship_delta))
  }
  errors
}

///|
pub fn NPCResponse::is_valid(self : NPCResponse) -> Bool {
  self.validate().length() == 0
}

/// Clamp relationship delta to the valid range.

///|
pub fn clamp_relationship_delta(delta : Int) -> Int {
  if delta < min_relationship_delta {
    min_relationship_delta
  } else if delta > max_relationship_delta {
    max_relationship_delta
  } else {
    delta
  }
}

// --- Parsing from raw string fields (post-JSON-decode) ---

/// Result of attempting to parse a raw response map into NPCResponse.

///|
pub(all) enum ParseResult {
  Success(NPCResponse)
  Recoverable(NPCResponse, Array[ValidationError]) // parsed with auto-fixes
  Failed(Array[ValidationError])
} derive(Eq, Debug)

/// Try to parse an NPCResponse from raw field strings.
/// Applies auto-recovery where possible (clamp delta, default emotion/action).

///|
pub fn parse_npc_response(
  dialogue~ : String,
  action_label~ : String,
  emotion_label~ : String,
  accepted~ : Bool,
  reason~ : String,
  relationship_delta~ : Int,
  information_disclosed~ : Array[String],
  narration~ : String,
) -> ParseResult {
  let errors : Array[ValidationError] = []
  let mut recovered = false

  // Parse action with fallback
  let action = match NPCAction::from_label(action_label) {
    Some(a) => a
    None => {
      errors.push(InvalidAction(action_label))
      recovered = true
      Talk // safe default
    }
  }

  // Parse emotion with fallback
  let emotion = match NPCEmotion::from_label(emotion_label) {
    Some(e) => e
    None => {
      errors.push(InvalidEmotion(emotion_label))
      recovered = true
      Neutral // safe default
    }
  }

  // Clamp relationship delta
  let delta = clamp_relationship_delta(relationship_delta)
  if delta != relationship_delta {
    errors.push(RelationshipDeltaOutOfRange(relationship_delta))
    recovered = true
  }

  // Check required text fields
  if dialogue.length() == 0 {
    errors.push(DialogueEmpty)
  }
  if reason.length() == 0 {
    errors.push(ReasonEmpty)
  }

  let response = NPCResponse::new(
    dialogue~,
    action~,
    emotion~,
    accepted~,
    reason~,
    relationship_delta=delta,
    information_disclosed~,
    narration~,
  )

  // Additional validation on the recovered response
  let remaining = response.validate()
  for e in remaining {
    errors.push(e)
  }

  if errors.length() == 0 {
    Success(response)
  } else if dialogue.length() > 0 && reason.length() > 0 {
    Recoverable(response, errors)
  } else {
    Failed(errors)
  }
}

/// Safe fallback NPCResponse for when parsing completely fails.

///|
pub fn fallback_npc_response() -> NPCResponse {
  {
    dialogue: "......",
    action: Neutral,
    emotion: Neutral,
    accepted: false,
    reason: "fallback: could not parse LLM output",
    relationship_delta: 0,
    information_disclosed: [],
    narration: "The other person seems lost in thought.",
  }
}

///|
/// Maximum retry attempts for LLM output parsing.
pub let max_parse_retries : Int = 2

///|
pub(all) struct NPCResponseParseAttempt {
  pub attempts : Int
  pub result : ParseResult
} derive(Eq, Debug)

/// Simulate retry logic: given a parse result, decide whether to retry.
/// In production, this would call the LLM again with adjusted parameters.
/// Returns the attempt with retry count.

///|
pub fn should_retry_parse(result : ParseResult, attempt : Int) -> Bool {
  match result {
    Success(_) => false
    Recoverable(_, _) => false // auto-recovered, no retry needed
    Failed(_) => attempt < max_parse_retries
  }
}
