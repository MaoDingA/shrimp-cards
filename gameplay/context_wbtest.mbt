// --- C1: Context Window Management Tests ---

// --- World Blackboard ---

///|
test "blackboard new has correct defaults" {
  let bb = WorldBlackboard::new(turn=1)
  assert_eq(bb.turn, 1)
  assert_true(bb.get_character_location(@protocol.A) is None)
  assert_true(bb.get_character_location(@protocol.B) is None)
  assert_true(bb.get_npc_location("innkeeper") is None)
  assert_eq(bb.get_npc_mood("innkeeper"), 0)
}

///|
test "blackboard set and get character location" {
  let bb = WorldBlackboard::new(turn=1)
  let bb2 = bb.set_character_location(@protocol.A, "tavern")
  assert_true(bb2.get_character_location(@protocol.A) == Some("tavern"))
  assert_true(bb2.get_character_location(@protocol.B) is None)
  // Update existing
  let bb3 = bb2.set_character_location(@protocol.A, "market")
  assert_true(bb3.get_character_location(@protocol.A) == Some("market"))
}

///|
test "blackboard set and get npc location" {
  let bb = WorldBlackboard::new(turn=1)
  let bb2 = bb.set_npc_location("innkeeper", "tavern")
  assert_true(bb2.get_npc_location("innkeeper") == Some("tavern"))
  assert_true(bb2.get_npc_location("blacksmith") is None)
}

///|
test "blackboard set and get fact" {
  let bb = WorldBlackboard::new(turn=1)
  let fact = WorldFact::new(
    key="npc_innkeeper_location",
    value="tavern",
    established_turn=1,
    source="scene_init",
  )
  let bb2 = bb.set_fact(fact)
  let retrieved = bb2.get_fact("npc_innkeeper_location")
  assert_true(retrieved is Some(_))
  match retrieved {
    Some(f) => {
      assert_eq(f.value, "tavern")
      assert_eq(f.source, "scene_init")
    }
    None => fail("expected fact")
  }
}

///|
test "blackboard fact update overwrites existing" {
  let bb = WorldBlackboard::new(turn=1)
  let fact1 = WorldFact::new(
    key="key1",
    value="v1",
    established_turn=1,
    source="s1",
  )
  let fact2 = WorldFact::new(
    key="key1",
    value="v2",
    established_turn=2,
    source="s2",
  )
  let bb2 = bb.set_fact(fact1).set_fact(fact2)
  match bb2.get_fact("key1") {
    Some(f) => {
      assert_eq(f.value, "v2")
      assert_eq(f.established_turn, 2)
    }
    None => fail("expected updated fact")
  }
}

///|
test "blackboard set and get npc mood" {
  let bb = WorldBlackboard::new(turn=1)
  let bb2 = bb.set_npc_mood("innkeeper", 3)
  assert_eq(bb2.get_npc_mood("innkeeper"), 3)
  let bb3 = bb2.set_npc_mood("innkeeper", -2)
  assert_eq(bb3.get_npc_mood("innkeeper"), -2)
}

///|
test "blackboard to context string includes all sections" {
  let bb = WorldBlackboard::new(turn=5)
    .set_character_location(@protocol.A, "tavern")
    .set_npc_location("innkeeper", "tavern")
    .set_npc_mood("innkeeper", 2)
    .set_fact(
      WorldFact::new(
        key="bribe_attempted",
        value="true",
        established_turn=3,
        source="engine",
      ),
    )
  let ctx = bb.to_context_string()
  assert_true(ctx.contains("turn: 5"))
  assert_true(ctx.contains("A: tavern"))
  assert_true(ctx.contains("innkeeper: tavern"))
  assert_true(ctx.contains("mood: 2"))
  assert_true(ctx.contains("bribe_attempted: true"))
}

// --- NPC Memory Store ---

///|
test "memory store add and retrieve" {
  let store = NPCMemoryStore::new()
  let store2 = store
    .add(
      NPCMemoryEntry::new(
        fact="Player A asked about the stranger",
        importance=7,
        turn=1,
        context="tavern dialogue",
      ),
    )
    .add(
      NPCMemoryEntry::new(
        fact="Player B bought a sword",
        importance=3,
        turn=2,
        context="market",
      ),
    )
    .add(
      NPCMemoryEntry::new(
        fact="Player A offered silver",
        importance=9,
        turn=3,
        context="tavern bribe",
      ),
    )
  assert_eq(store2.length(), 3)
  // Retrieve top 2 by score
  let results = store2.retrieve(current_turn=3, max_tokens=500, max_count=2)
  assert_eq(results.length(), 2)
  // The most important recent one should be first
  assert_true(results[0].fact.contains("offered silver"))
  assert_true(results[1].fact.contains("asked about"))
}

///|
test "memory store respects token budget" {
  let store = NPCMemoryStore::new()
  let store2 = store
    .add(
      NPCMemoryEntry::new(fact="short fact", importance=5, turn=1, context=""),
    )
    .add(
      NPCMemoryEntry::new(
        fact="this is a much longer fact that uses more tokens in the prompt",
        importance=5,
        turn=1,
        context="and some context too",
      ),
    )
  // Small budget should limit results
  let results = store2.retrieve(current_turn=1, max_tokens=30, max_count=10)
  assert_true(results.length() < 2)
}

///|
test "memory store decay prunes low importance" {
  let store = NPCMemoryStore::new()
    .add(
      NPCMemoryEntry::new(fact="important", importance=8, turn=1, context=""),
    )
    .add(NPCMemoryEntry::new(fact="minor", importance=2, turn=1, context=""))
  let decayed = store.decay(decay_amount=2)
  assert_eq(decayed.length(), 1)
  assert_eq(decayed.entries[0].importance, 6)
}

// --- Dialogue History ---

///|
test "dialogue history recent within budget" {
  let history = DialogueHistory::new()
    .add(DialogueTurn::new(speaker="player", text="Hello there", turn=1))
    .add(
      DialogueTurn::new(
        speaker="npc",
        text="Welcome, traveler. What brings you here?",
        turn=1,
      ),
    )
    .add(
      DialogueTurn::new(
        speaker="player",
        text="I'm looking for information.",
        turn=2,
      ),
    )
  let recent = history.recent_within_budget(max_tokens=500, max_turns=10)
  assert_eq(recent.length(), 3)
  // Should be in chronological order
  assert_true(recent[0].speaker == "player")
  assert_true(recent[2].text.contains("information"))
}

///|
test "dialogue history respects max turns" {
  let history = DialogueHistory::new()
    .add(DialogueTurn::new(speaker="player", text="hi", turn=1))
    .add(DialogueTurn::new(speaker="npc", text="hello", turn=1))
    .add(DialogueTurn::new(speaker="player", text="bye", turn=2))
  let recent = history.recent_within_budget(max_tokens=500, max_turns=2)
  assert_eq(recent.length(), 2)
  // Should return the 2 most recent
  assert_true(recent[0].text.contains("hello"))
  assert_true(recent[1].text.contains("bye"))
}

///|
test "dialogue history respects token budget" {
  let history = DialogueHistory::new()
    .add(DialogueTurn::new(speaker="player", text="short", turn=1))
    .add(
      DialogueTurn::new(
        speaker="npc",
        text="this is a very very long response that should consume many many tokens",
        turn=1,
      ),
    )
  // Very small budget - should only fit first turn
  let recent = history.recent_within_budget(max_tokens=20, max_turns=10)
  assert_true(recent.length() <= 1)
}

// --- Prompt Context ---

///|
test "prompt context estimated tokens is non-negative" {
  let ctx : PromptContext = {
    rules_text: "You are a game NPC.",
    world_state_text: "turn 1",
    memory_entries: [],
    recent_dialogue: [],
    player_request: "Talk to the innkeeper.",
  }
  let tokens = ctx.estimated_total_tokens()
  assert_true(tokens > 0)
}

///|
test "prompt context budget remaining is positive" {
  let remaining = budget_remaining()
  assert_true(remaining > 0)
  // Total budget should equal sum of layer budgets + remaining
  assert_eq(
    budget_game_rules +
    budget_world_state +
    budget_npc_memory +
    budget_recent_history +
    remaining,
    budget_total,
  )
}
