/// Context window management for NPC interactions.
///
/// Implements the layered prompt architecture:
///   Layer 0: Game rules (system prompt, ~2k tokens)
///   Layer 1: World state blackboard (dynamic summary, ~3k tokens)
///   Layer 2: NPC core memory (vector-like retrieval, ~2k tokens)
///   Layer 3: Recent dialogue history (sliding window, ~3k tokens)
///   Layer 4: Current interaction request (~variable)
///
/// Total budget: ~15k tokens per LLM call.

///|
/// Token budget constants (approximate token counts).
/// These are rough estimates; actual tokenization depends on the model.
pub let budget_game_rules : Int = 2000

///|
pub let budget_world_state : Int = 3000

///|
pub let budget_npc_memory : Int = 2000

///|
pub let budget_recent_history : Int = 3000

///|
pub let budget_total : Int = 15000

///|
pub fn budget_remaining() -> Int {
  budget_total -
  budget_game_rules -
  budget_world_state -
  budget_npc_memory -
  budget_recent_history
}

/// A single memory entry for an NPC.

///|
pub(all) struct NPCMemoryEntry {
  /// The factual content (e.g., "Player A bribed the innkeeper").
  fact : String
  /// Importance weight (0-10). Higher = more likely to be recalled.
  importance : Int
  /// Turn number when this memory was created.
  turn : Int
  /// Associated scene or location context.
  context : String
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn NPCMemoryEntry::new(
  fact~ : String,
  importance~ : Int,
  turn~ : Int,
  context~ : String,
) -> NPCMemoryEntry {
  { fact, importance, turn, context }
}

/// Approximate token count for a memory entry (rough: 1 token per 4 chars).

///|
pub fn NPCMemoryEntry::estimated_tokens(self : NPCMemoryEntry) -> Int {
  (self.fact.length() + self.context.length()) / 4 + 10
}

/// Memory store for a single NPC. Supports importance-weighted retrieval
/// and time-based decay.

///|
pub(all) struct NPCMemoryStore {
  entries : Array[NPCMemoryEntry]
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn NPCMemoryStore::new() -> NPCMemoryStore {
  { entries: [] }
}

///|
pub fn NPCMemoryStore::add(
  self : NPCMemoryStore,
  entry : NPCMemoryEntry,
) -> NPCMemoryStore {
  let entries = self.entries.copy()
  entries.push(entry)
  { entries, }
}

///|
pub fn NPCMemoryStore::length(self : NPCMemoryStore) -> Int {
  self.entries.length()
}

/// Retrieve the top-K most relevant memories, sorted by a composite score
/// of importance and recency. Fits within the given token budget.

///|
pub fn NPCMemoryStore::retrieve(
  self : NPCMemoryStore,
  current_turn~ : Int,
  max_tokens~ : Int,
  max_count~ : Int,
) -> Array[NPCMemoryEntry] {
  // Score each entry
  let scored : Array[(NPCMemoryEntry, Int)] = []
  for entry in self.entries {
    let age = current_turn - entry.turn
    let recency_bonus = if age <= 0 { 10 } else { 10 - age / 2 }
    let score = entry.importance + recency_bonus
    scored.push((entry, score))
  }
  // Sort by score descending
  let scored = sort_by_score_desc(scored)
  // Take entries within budget
  let result : Array[NPCMemoryEntry] = []
  let mut tokens_used = 0
  let mut count = 0
  for pair in scored {
    if count >= max_count {
      break
    }
    let (entry, _score) = pair
    let t = entry.estimated_tokens()
    if tokens_used + t > max_tokens {
      continue
    }
    result.push(entry)
    tokens_used = tokens_used + t
    count = count + 1
  }
  result
}

///|
/// Simple insertion sort by score descending.
fn sort_by_score_desc(
  items : Array[(NPCMemoryEntry, Int)],
) -> Array[(NPCMemoryEntry, Int)] {
  let result = items.copy()
  let n = result.length()
  let mut i = 1
  while i < n {
    let mut j = i
    while j > 0 {
      let (_, score_j) = result[j]
      let (_, score_j_minus_1) = result[j - 1]
      if score_j > score_j_minus_1 {
        let temp = result[j]
        result[j] = result[j - 1]
        result[j - 1] = temp
      }
      j = j - 1
    }
    i = i + 1
  }
  result
}

///|
fn[T] reverse_array(arr : Array[T]) -> Unit {
  let n = arr.length()
  let mut i = 0
  while i < n / 2 {
    let j = n - 1 - i
    let temp = arr[i]
    arr[i] = arr[j]
    arr[j] = temp
    i = i + 1
  }
}

/// Decay importance of old memories. Returns a new store with aged entries.
/// Entries that drop below importance threshold are pruned.

///|
pub let memory_importance_floor : Int = 1

///|
pub fn NPCMemoryStore::decay(
  self : NPCMemoryStore,
  decay_amount~ : Int,
) -> NPCMemoryStore {
  let entries : Array[NPCMemoryEntry] = []
  for entry in self.entries {
    let new_importance = entry.importance - decay_amount
    if new_importance >= memory_importance_floor {
      entries.push(
        NPCMemoryEntry::new(
          fact=entry.fact,
          importance=new_importance,
          turn=entry.turn,
          context=entry.context,
        ),
      )
    }
  }
  { entries, }
}

// --- World State Blackboard ---

/// A fact known in the world, trackable for consistency checking.

///|
pub(all) struct WorldFact {
  /// Unique key for deduplication (e.g., "npc_innkeeper_location").
  key : String
  /// The fact value (e.g., "tavern").
  value : String
  /// Turn when this fact was established.
  established_turn : Int
  /// Source of the fact (e.g., "rule_engine", "npc_dialogue").
  source : String
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn WorldFact::new(
  key~ : String,
  value~ : String,
  established_turn~ : Int,
  source~ : String,
) -> WorldFact {
  { key, value, established_turn, source }
}

/// The world state blackboard is the authoritative, engine-maintained state.
/// It is NOT modified by LLM output directly — the engine extracts state
/// changes from LLM responses and updates this structure.

///|
pub(all) struct WorldBlackboard {
  /// Current turn number.
  turn : Int
  /// Character locations: side label -> location name.
  character_locations : Array[(String, String)]
  /// NPC locations: npc name -> location name.
  npc_locations : Array[(String, String)]
  /// Known facts (deduplicated by key).
  facts : Array[WorldFact]
  /// NPC moods: npc name -> mood value (-5 to 5).
  npc_moods : Array[(String, Int)]
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn WorldBlackboard::new(turn~ : Int) -> WorldBlackboard {
  { turn, character_locations: [], npc_locations: [], facts: [], npc_moods: [] }
}

///|
pub fn WorldBlackboard::get_character_location(
  self : WorldBlackboard,
  side : @protocol.Side,
) -> String? {
  let key = side.label()
  for pair in self.character_locations {
    let (k, v) = pair
    if k == key {
      return Some(v)
    }
  }
  None
}

///|
pub fn WorldBlackboard::set_character_location(
  self : WorldBlackboard,
  side : @protocol.Side,
  location : String,
) -> WorldBlackboard {
  let key = side.label()
  let locations : Array[(String, String)] = []
  let mut found = false
  for pair in self.character_locations {
    let (k, v) = pair
    if k == key {
      locations.push((key, location))
      found = true
    } else {
      locations.push((k, v))
    }
  }
  if !found {
    locations.push((key, location))
  }
  { ..self, character_locations: locations }
}

///|
pub fn WorldBlackboard::get_npc_location(
  self : WorldBlackboard,
  npc_name : String,
) -> String? {
  for pair in self.npc_locations {
    let (k, v) = pair
    if k == npc_name {
      return Some(v)
    }
  }
  None
}

///|
pub fn WorldBlackboard::set_npc_location(
  self : WorldBlackboard,
  npc_name : String,
  location : String,
) -> WorldBlackboard {
  let locations : Array[(String, String)] = []
  let mut found = false
  for pair in self.npc_locations {
    let (k, v) = pair
    if k == npc_name {
      locations.push((npc_name, location))
      found = true
    } else {
      locations.push((k, v))
    }
  }
  if !found {
    locations.push((npc_name, location))
  }
  { ..self, npc_locations: locations }
}

///|
pub fn WorldBlackboard::get_fact(
  self : WorldBlackboard,
  key : String,
) -> WorldFact? {
  for fact in self.facts {
    if fact.key == key {
      return Some(fact)
    }
  }
  None
}

///|
pub fn WorldBlackboard::set_fact(
  self : WorldBlackboard,
  fact : WorldFact,
) -> WorldBlackboard {
  let facts : Array[WorldFact] = []
  let mut found = false
  for f in self.facts {
    if f.key == fact.key {
      facts.push(fact)
      found = true
    } else {
      facts.push(f)
    }
  }
  if !found {
    facts.push(fact)
  }
  { ..self, facts, }
}

///|
pub fn WorldBlackboard::get_npc_mood(
  self : WorldBlackboard,
  npc_name : String,
) -> Int {
  for pair in self.npc_moods {
    let (k, v) = pair
    if k == npc_name {
      return v
    }
  }
  0
}

///|
pub fn WorldBlackboard::set_npc_mood(
  self : WorldBlackboard,
  npc_name : String,
  mood : Int,
) -> WorldBlackboard {
  let moods : Array[(String, Int)] = []
  let mut found = false
  for pair in self.npc_moods {
    let (k, v) = pair
    if k == npc_name {
      moods.push((npc_name, mood))
      found = true
    } else {
      moods.push((k, v))
    }
  }
  if !found {
    moods.push((npc_name, mood))
  }
  { ..self, npc_moods: moods }
}

/// Serialize the blackboard to a compact string for prompt injection.

///|
pub fn WorldBlackboard::to_context_string(self : WorldBlackboard) -> String {
  let lines : Array[String] = []
  lines.push("turn: \{self.turn}")
  if self.character_locations.length() > 0 {
    lines.push("characters:")
    for pair in self.character_locations {
      let (side, loc) = pair
      lines.push("  \{side}: \{loc}")
    }
  }
  if self.npc_locations.length() > 0 {
    lines.push("npcs:")
    for pair in self.npc_locations {
      let (name, loc) = pair
      lines.push("  \{name}: \{loc} (mood: \{self.get_npc_mood(name)})")
    }
  }
  if self.facts.length() > 0 {
    lines.push("facts:")
    for fact in self.facts {
      lines.push("  \{fact.key}: \{fact.value}")
    }
  }
  lines.join("\n")
}

// --- Dialogue History (Sliding Window) ---

/// A single turn of dialogue in an NPC interaction.

///|
pub(all) struct DialogueTurn {
  /// Who spoke: "player" or "npc".
  speaker : String
  /// What was said.
  text : String
  /// Turn number.
  turn : Int
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn DialogueTurn::new(
  speaker~ : String,
  text~ : String,
  turn~ : Int,
) -> DialogueTurn {
  { speaker, text, turn }
}

/// Approximate token count for a dialogue turn.

///|
pub fn DialogueTurn::estimated_tokens(self : DialogueTurn) -> Int {
  self.text.length() / 4 + 15
}

/// Sliding window of recent dialogue history.

///|
pub(all) struct DialogueHistory {
  turns : Array[DialogueTurn]
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn DialogueHistory::new() -> DialogueHistory {
  { turns: [] }
}

///|
pub fn DialogueHistory::add(
  self : DialogueHistory,
  turn : DialogueTurn,
) -> DialogueHistory {
  let turns = self.turns.copy()
  turns.push(turn)
  { turns, }
}

/// Retrieve recent turns fitting within the token budget.
/// Returns the most recent N turns whose total tokens fit in budget.

///|
pub fn DialogueHistory::recent_within_budget(
  self : DialogueHistory,
  max_tokens~ : Int,
  max_turns~ : Int,
) -> Array[DialogueTurn] {
  let result : Array[DialogueTurn] = []
  let mut tokens_used = 0
  let mut count = 0
  let n = self.turns.length()
  let mut i = 0
  while i < n {
    if count >= max_turns {
      break
    }
    let idx = n - 1 - i
    let turn = self.turns[idx]
    let t = turn.estimated_tokens()
    if tokens_used + t > max_tokens {
      break
    }
    result.push(turn)
    tokens_used = tokens_used + t
    count = count + 1
    i = i + 1
  }
  // Reverse to get chronological order
  reverse_array(result)
  result
}

///|
pub fn DialogueHistory::length(self : DialogueHistory) -> Int {
  self.turns.length()
}

// --- Layered Prompt Assembler ---

/// Assembled prompt context for an NPC interaction.

///|
pub(all) struct PromptContext {
  /// Layer 0: game rules text.
  rules_text : String
  /// Layer 1: world state blackboard summary.
  world_state_text : String
  /// Layer 2: retrieved NPC memories.
  memory_entries : Array[NPCMemoryEntry]
  /// Layer 3: recent dialogue history.
  recent_dialogue : Array[DialogueTurn]
  /// Layer 4: current player request text.
  player_request : String
} derive(Eq, Debug)

///|
pub fn PromptContext::estimated_total_tokens(self : PromptContext) -> Int {
  let mut total = self.rules_text.length() / 4
  total = total + self.world_state_text.length() / 4
  for entry in self.memory_entries {
    total = total + entry.estimated_tokens()
  }
  for turn in self.recent_dialogue {
    total = total + turn.estimated_tokens()
  }
  total = total + self.player_request.length() / 4
  total
}

/// Whether the assembled prompt exceeds the total budget.

///|
pub fn PromptContext::exceeds_budget(self : PromptContext) -> Bool {
  self.estimated_total_tokens() > budget_total
}
