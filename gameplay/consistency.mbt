/// Narrative consistency checking and fact verification.
///
/// After LLM generates NPC responses, this module extracts verifiable
/// claims and cross-checks them against the world state blackboard.
/// Contradictions trigger retry or correction.

// --- Claim Types ---

/// A claim extracted from an NPC response that can be verified.

///|
pub(all) enum ClaimType {
  /// Character location claim (e.g., "the stranger went east").
  CharacterLocation
  /// NPC location claim (e.g., "the blacksmith is at the forge").
  NPCLocation
  /// A factual statement (e.g., "Player A offered silver").
  FactStatement
  /// A relationship claim (e.g., "the innkeeper likes you").
  Relationship
  /// An item claim (e.g., "he has a sword").
  ItemPossession
  /// An event claim (e.g., "there was a fight last night").
  Event
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn ClaimType::label(self : ClaimType) -> String {
  match self {
    CharacterLocation => "character_location"
    NPCLocation => "npc_location"
    FactStatement => "fact_statement"
    Relationship => "relationship"
    ItemPossession => "item_possession"
    Event => "event"
  }
}

/// A single claim extracted from NPC output.

///|
pub(all) struct Claim {
  /// What kind of claim this is.
  claim_type : ClaimType
  /// The subject (e.g., "innkeeper", "player_a").
  subject : String
  /// The claimed value (e.g., "tavern", "friendly").
  value : String
  /// Confidence in extraction (0-100).
  confidence : Int
  /// Source text snippet.
  source_text : String
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn Claim::new(
  claim_type~ : ClaimType,
  subject~ : String,
  value~ : String,
  confidence~ : Int,
  source_text~ : String,
) -> Claim {
  { claim_type, subject, value, confidence, source_text }
}

// --- Consistency Check Result ---

/// Severity of a consistency violation.

///|
pub(all) enum ViolationLevel {
  /// Minor detail mismatch, auto-correct and continue.
  Minor
  /// Moderate contradiction, regenerate the response.
  Moderate
  /// Severe contradiction with core facts, discard response.
  Severe
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn ViolationLevel::label(self : ViolationLevel) -> String {
  match self {
    Minor => "minor"
    Moderate => "moderate"
    Severe => "severe"
  }
}

/// A single consistency violation.

///|
pub(all) struct ConsistencyViolation {
  /// The claim that conflicts with the blackboard.
  claim : Claim
  /// The blackboard fact it contradicts.
  blackboard_key : String
  /// Expected value from blackboard.
  expected_value : String
  /// Actual claimed value.
  claimed_value : String
  /// Severity level.
  level : ViolationLevel
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn ConsistencyViolation::new(
  claim~ : Claim,
  blackboard_key~ : String,
  expected_value~ : String,
  claimed_value~ : String,
  level~ : ViolationLevel,
) -> ConsistencyViolation {
  { claim, blackboard_key, expected_value, claimed_value, level }
}

/// Overall result of consistency checking.

///|
pub(all) struct ConsistencyResult {
  /// All violations found.
  violations : Array[ConsistencyViolation]
  /// Whether the response is acceptable (no severe violations).
  acceptable : Bool
  /// Whether corrections were auto-applied.
  corrected : Bool
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn ConsistencyResult::pass() -> ConsistencyResult {
  { violations: [], acceptable: true, corrected: false }
}

///|
pub fn ConsistencyResult::with_violations(
  violations~ : Array[ConsistencyViolation],
) -> ConsistencyResult {
  let mut found_severe = false
  for v in violations {
    match v.level {
      Severe => found_severe = true
      Minor => ignore(0)
      Moderate => ignore(0)
    }
  }
  { violations, acceptable: !found_severe, corrected: false }
}

///|
pub fn ConsistencyResult::violation_count(self : ConsistencyResult) -> Int {
  self.violations.length()
}

///|
pub fn ConsistencyResult::has_minor(self : ConsistencyResult) -> Bool {
  for v in self.violations {
    match v.level {
      Minor => return true
      Moderate => ignore(0)
      Severe => ignore(0)
    }
  }
  false
}

///|
pub fn ConsistencyResult::has_moderate(self : ConsistencyResult) -> Bool {
  for v in self.violations {
    match v.level {
      Moderate => return true
      Minor => ignore(0)
      Severe => ignore(0)
    }
  }
  false
}

///|
pub fn ConsistencyResult::has_severe(self : ConsistencyResult) -> Bool {
  for v in self.violations {
    match v.level {
      Severe => return true
      Minor => ignore(0)
      Moderate => ignore(0)
    }
  }
  false
}

// --- Consistency Checker ---

/// Check claims against the world blackboard.
/// Returns violations where claims contradict known facts.

///|
pub fn check_consistency(
  claims : Array[Claim],
  blackboard : WorldBlackboard,
) -> ConsistencyResult {
  let violations : Array[ConsistencyViolation] = []
  for claim in claims {
    let violation = check_single_claim(claim, blackboard)
    match violation {
      Some(v) => violations.push(v)
      None => ignore(0)
    }
  }
  if violations.length() == 0 {
    ConsistencyResult::pass()
  } else {
    ConsistencyResult::with_violations(violations~)
  }
}

///|
/// Check a single claim against the blackboard.
fn check_single_claim(
  claim : Claim,
  blackboard : WorldBlackboard,
) -> ConsistencyViolation? {
  match claim.claim_type {
    // Check character location claims
    CharacterLocation => {
      let expected = blackboard.get_fact("character_location_\{claim.subject}")
      match expected {
        Some(fact) =>
          if fact.value != claim.value {
            Some(
              ConsistencyViolation::new(
                claim~,
                blackboard_key="character_location_\{claim.subject}",
                expected_value=fact.value,
                claimed_value=claim.value,
                level=Moderate,
              ),
            )
          } else {
            None
          }
        None => None
      }
    }
    // Check NPC location claims
    NPCLocation => {
      let expected = blackboard.get_npc_location(claim.subject)
      match expected {
        Some(loc) =>
          if loc != claim.value {
            Some(
              ConsistencyViolation::new(
                claim~,
                blackboard_key="npc_location_\{claim.subject}",
                expected_value=loc,
                claimed_value=claim.value,
                level=Severe,
              ),
            )
          } else {
            None
          }
        None => None
      }
    }
    // Check fact statements
    FactStatement => {
      let expected = blackboard.get_fact(claim.subject)
      match expected {
        Some(fact) =>
          if fact.value != claim.value {
            Some(
              ConsistencyViolation::new(
                claim~,
                blackboard_key=claim.subject,
                expected_value=fact.value,
                claimed_value=claim.value,
                level=classify_fact_mismatch(fact.value, claim.value),
              ),
            )
          } else {
            None
          }
        None => None
      }
    }
    // Relationship and item claims are less strict
    Relationship => None
    ItemPossession => None
    Event => None
  }
}

///|
/// Classify the severity of a fact mismatch.
fn classify_fact_mismatch(
  expected : String,
  claimed : String,
) -> ViolationLevel {
  // If the values are completely different, it's severe
  // If they share some commonality, it might be minor
  if expected == claimed {
    Minor
  } else if expected.length() > 3 &&
    claimed.contains(expected) &&
    claimed.length() < expected.length() * 3 {
    // Claimed value contains the expected value and isn't much longer
    // (e.g., expected="tavern", claimed="the tavern" → Minor)
    // Avoids false positives like expected="king", claimed="asking"
    Minor
  } else {
    Moderate
  }
}

// --- Retry Strategy ---

///|
/// Maximum retries for consistency failures.
pub let max_consistency_retries : Int = 2

/// Whether to retry based on violation level.

///|
pub fn should_retry_consistency(
  result : ConsistencyResult,
  attempt : Int,
) -> Bool {
  if attempt >= max_consistency_retries {
    return false
  }
  // Retry on moderate violations, accept minor, reject severe
  result.has_moderate()
}
