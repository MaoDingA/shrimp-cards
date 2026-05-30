// --- C6: Narrative Consistency Tests ---

///|
test "empty claims pass consistency" {
  let bb = WorldBlackboard::new(turn=1)
  let result = check_consistency([], bb)
  assert_true(result.acceptable)
  assert_eq(result.violation_count(), 0)
}

///|
test "matching npc location claim passes" {
  let bb = WorldBlackboard::new(turn=1).set_npc_location("innkeeper", "tavern")
  let claims = [
    Claim::new(
      claim_type=NPCLocation,
      subject="innkeeper",
      value="tavern",
      confidence=90,
      source_text="The innkeeper is at the tavern.",
    ),
  ]
  let result = check_consistency(claims, bb)
  assert_true(result.acceptable)
  assert_eq(result.violation_count(), 0)
}

///|
test "contradictory npc location claim is severe" {
  let bb = WorldBlackboard::new(turn=1).set_npc_location("innkeeper", "tavern")
  let claims = [
    Claim::new(
      claim_type=NPCLocation,
      subject="innkeeper",
      value="market",
      confidence=80,
      source_text="The innkeeper went to the market.",
    ),
  ]
  let result = check_consistency(claims, bb)
  assert_true(!result.acceptable)
  assert_true(result.has_severe())
  assert_eq(result.violation_count(), 1)
}

///|
test "contradictory fact claim is moderate" {
  let bb = WorldBlackboard::new(turn=1).set_fact(
    WorldFact::new(
      key="bribe_attempted",
      value="true",
      established_turn=1,
      source="engine",
    ),
  )
  let claims = [
    Claim::new(
      claim_type=FactStatement,
      subject="bribe_attempted",
      value="false",
      confidence=70,
      source_text="Nobody tried to bribe anyone.",
    ),
  ]
  let result = check_consistency(claims, bb)
  assert_true(result.has_moderate())
}

///|
test "matching fact claim passes" {
  let bb = WorldBlackboard::new(turn=1).set_fact(
    WorldFact::new(
      key="weather",
      value="sunny",
      established_turn=1,
      source="scene",
    ),
  )
  let claims = [
    Claim::new(
      claim_type=FactStatement,
      subject="weather",
      value="sunny",
      confidence=95,
      source_text="It's a sunny day.",
    ),
  ]
  let result = check_consistency(claims, bb)
  assert_true(result.acceptable)
  assert_eq(result.violation_count(), 0)
}

///|
test "relationship claims never violate" {
  let bb = WorldBlackboard::new(turn=1)
  let claims = [
    Claim::new(
      claim_type=Relationship,
      subject="innkeeper",
      value="hostile",
      confidence=50,
      source_text="The innkeeper glares at you.",
    ),
  ]
  let result = check_consistency(claims, bb)
  assert_true(result.acceptable)
  assert_eq(result.violation_count(), 0)
}

///|
test "event claims never violate" {
  let bb = WorldBlackboard::new(turn=1)
  let claims = [
    Claim::new(
      claim_type=Event,
      subject="fight",
      value="occurred",
      confidence=60,
      source_text="There was a fight last night.",
    ),
  ]
  let result = check_consistency(claims, bb)
  assert_true(result.acceptable)
}

///|
test "character location mismatch is moderate" {
  let bb = WorldBlackboard::new(turn=1).set_fact(
    WorldFact::new(
      key="character_location_A",
      value="tavern",
      established_turn=1,
      source="engine",
    ),
  )
  let claims = [
    Claim::new(
      claim_type=CharacterLocation,
      subject="A",
      value="market",
      confidence=80,
      source_text="Player A is at the market.",
    ),
  ]
  let result = check_consistency(claims, bb)
  assert_true(result.has_moderate())
}

///|
test "should retry on moderate violations" {
  let result = ConsistencyResult::with_violations(violations=[
    ConsistencyViolation::new(
      claim=Claim::new(
        claim_type=FactStatement,
        subject="test",
        value="wrong",
        confidence=80,
        source_text="test",
      ),
      blackboard_key="test",
      expected_value="right",
      claimed_value="wrong",
      level=Moderate,
    ),
  ])
  assert_true(should_retry_consistency(result, 0))
  assert_true(should_retry_consistency(result, 1))
  assert_true(!should_retry_consistency(result, 2))
}

///|
test "should not retry on minor only" {
  let result = ConsistencyResult::with_violations(violations=[
    ConsistencyViolation::new(
      claim=Claim::new(
        claim_type=FactStatement,
        subject="test",
        value="close",
        confidence=80,
        source_text="test",
      ),
      blackboard_key="test",
      expected_value="right",
      claimed_value="close",
      level=Minor,
    ),
  ])
  assert_true(!should_retry_consistency(result, 0))
}

///|
test "multiple violations detected" {
  let bb = WorldBlackboard::new(turn=1)
    .set_npc_location("innkeeper", "tavern")
    .set_npc_location("blacksmith", "forge")
  let claims = [
    Claim::new(
      claim_type=NPCLocation,
      subject="innkeeper",
      value="market",
      confidence=80,
      source_text="The innkeeper is at the market.",
    ),
    Claim::new(
      claim_type=NPCLocation,
      subject="blacksmith",
      value="market",
      confidence=80,
      source_text="The blacksmith is also at the market.",
    ),
  ]
  let result = check_consistency(claims, bb)
  assert_eq(result.violation_count(), 2)
  assert_true(!result.acceptable)
}
