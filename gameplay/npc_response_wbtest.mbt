// --- C7: NPC Response Structured Output Tests ---

///|
test "npc action label round-trip" {
  for action in NPCAction::all() {
    let label = action.label()
    let parsed = NPCAction::from_label(label)
    assert_true(parsed is Some(_))
    match parsed {
      Some(a) => assert_true(a == action)
      None => fail("should not reach")
    }
  }
}

///|
test "npc action from invalid label returns None" {
  assert_true(NPCAction::from_label("fly") is None)
  assert_true(NPCAction::from_label("") is None)
}

///|
test "npc emotion label round-trip" {
  for emotion in NPCEmotion::all() {
    let label = emotion.label()
    let parsed = NPCEmotion::from_label(label)
    assert_true(parsed is Some(_))
    match parsed {
      Some(e) => assert_true(e == emotion)
      None => fail("should not reach")
    }
  }
}

///|
test "npc emotion from invalid label returns None" {
  assert_true(NPCEmotion::from_label("angry") is None)
}

///|
test "valid npc response passes validation" {
  let response = NPCResponse::new(
    dialogue="Welcome, traveler.",
    action=Talk,
    emotion=Neutral,
    accepted=true,
    reason="friendly disposition",
    relationship_delta=1,
    information_disclosed=["the market is to the east"],
    narration="The innkeeper nods.",
  )
  assert_true(response.is_valid())
}

///|
test "empty dialogue fails validation" {
  let response = NPCResponse::new(
    dialogue="",
    action=Talk,
    emotion=Neutral,
    accepted=true,
    reason="ok",
    relationship_delta=0,
    information_disclosed=[],
    narration="",
  )
  let errors = response.validate()
  assert_true(errors.length() > 0)
  let has_empty = errors
    .iter()
    .any(fn(e) {
      match e {
        DialogueEmpty => true
        _ => false
      }
    })
  assert_true(has_empty)
}

///|
test "dialogue too long fails validation" {
  let long_text = "x".repeat(max_dialogue_length + 1)
  let response = NPCResponse::new(
    dialogue=long_text,
    action=Talk,
    emotion=Neutral,
    accepted=true,
    reason="ok",
    relationship_delta=0,
    information_disclosed=[],
    narration="",
  )
  let errors = response.validate()
  let has_too_long = errors
    .iter()
    .any(fn(e) {
      match e {
        DialogueTooLong(_) => true
        _ => false
      }
    })
  assert_true(has_too_long)
}

///|
test "relationship delta out of range fails validation" {
  let response = NPCResponse::new(
    dialogue="Hello.",
    action=Talk,
    emotion=Neutral,
    accepted=true,
    reason="ok",
    relationship_delta=10,
    information_disclosed=[],
    narration="",
  )
  let errors = response.validate()
  let has_out_of_range = errors
    .iter()
    .any(fn(e) {
      match e {
        RelationshipDeltaOutOfRange(_) => true
        _ => false
      }
    })
  assert_true(has_out_of_range)
}

///|
test "clamp relationship delta" {
  assert_eq(clamp_relationship_delta(0), 0)
  assert_eq(clamp_relationship_delta(3), 3)
  assert_eq(clamp_relationship_delta(-3), -3)
  assert_eq(clamp_relationship_delta(10), max_relationship_delta)
  assert_eq(clamp_relationship_delta(-10), min_relationship_delta)
}

///|
test "parse npc response success" {
  let result = parse_npc_response(
    dialogue="Take this silver.",
    action_label="talk",
    emotion_label="friendly",
    accepted=true,
    reason="bribed",
    relationship_delta=2,
    information_disclosed=["the stranger went east"],
    narration="The innkeeper smiles.",
  )
  match result {
    Success(response) => {
      assert_eq(response.dialogue, "Take this silver.")
      assert_true(response.action == Talk)
      assert_true(response.emotion == Friendly)
      assert_true(response.accepted)
      assert_eq(response.relationship_delta, 2)
      assert_eq(response.information_disclosed.length(), 1)
    }
    _ => fail("expected Success")
  }
}

///|
test "parse npc response recovers invalid action" {
  let result = parse_npc_response(
    dialogue="Hmm...",
    action_label="dance",
    emotion_label="neutral",
    accepted=false,
    reason="confused",
    relationship_delta=0,
    information_disclosed=[],
    narration="Confusion.",
  )
  match result {
    Recoverable(response, errors) => {
      assert_true(response.action == Talk) // fallback
      assert_true(errors.length() > 0)
    }
    _ => fail("expected Recoverable with invalid action")
  }
}

///|
test "parse npc response recovers invalid emotion" {
  let result = parse_npc_response(
    dialogue="Okay.",
    action_label="talk",
    emotion_label="ecstatic",
    accepted=false,
    reason="whatever",
    relationship_delta=0,
    information_disclosed=[],
    narration="...",
  )
  match result {
    Recoverable(response, errors) => {
      assert_true(response.emotion == Neutral) // fallback
      assert_true(errors.length() > 0)
    }
    _ => fail("expected Recoverable with invalid emotion")
  }
}

///|
test "parse npc response clamps out-of-range delta" {
  let result = parse_npc_response(
    dialogue="Begone!",
    action_label="talk",
    emotion_label="hostile",
    accepted=false,
    reason="angry",
    relationship_delta=100,
    information_disclosed=[],
    narration="Shooed away.",
  )
  match result {
    Recoverable(response, _errors) =>
      assert_eq(response.relationship_delta, max_relationship_delta)
    _ => fail("expected Recoverable with clamped delta")
  }
}

///|
test "parse npc response fails on empty required fields" {
  let result = parse_npc_response(
    dialogue="",
    action_label="talk",
    emotion_label="neutral",
    accepted=false,
    reason="",
    relationship_delta=0,
    information_disclosed=[],
    narration="",
  )
  match result {
    Failed(_errors) => assert_true(true)
    _ => fail("expected Failed for empty dialogue and reason")
  }
}

///|
test "should retry parse only on failed and within limit" {
  let success = Success(fallback_npc_response())
  assert_true(!should_retry_parse(success, 0))
  let recoverable = Recoverable(fallback_npc_response(), [])
  assert_true(!should_retry_parse(recoverable, 0))
  let failed = Failed([])
  assert_true(should_retry_parse(failed, 0))
  assert_true(should_retry_parse(failed, 1))
  assert_true(!should_retry_parse(failed, 2))
  assert_true(!should_retry_parse(failed, 3))
}

///|
test "fallback npc response is always valid" {
  let fb = fallback_npc_response()
  assert_true(fb.is_valid())
  assert_true(fb.action == Neutral)
  assert_true(fb.emotion == Neutral)
  assert_true(!fb.accepted)
  assert_eq(fb.relationship_delta, 0)
}
