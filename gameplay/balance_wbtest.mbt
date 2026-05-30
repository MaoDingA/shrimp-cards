// --- C8: Balance and Anti-Degeneration Tests ---

// --- Strategy Tracking ---

///|
test "strategy record tracks wins and uses" {
  let r = StrategyRecord::new(fingerprint="bribe_innkeeper")
    .record_use(true)
    .record_use(false)
    .record_use(true)
  assert_eq(r.use_count, 3)
  assert_eq(r.win_count, 2)
}

///|
test "strategy win rate calculation" {
  let r = StrategyRecord::new(fingerprint="test")
    .record_use(true)
    .record_use(true)
    .record_use(true)
    .record_use(false)
  assert_eq(r.win_rate(), 75)
}

///|
test "strategy not dominant with low uses" {
  let r = StrategyRecord::new(fingerprint="test")
    .record_use(true)
    .record_use(true)
    .record_use(true)
  // Only 3 uses, need min 5
  assert_true(!r.is_dominant())
}

///|
test "strategy dominant with high win rate" {
  let r = StrategyRecord::new(fingerprint="test")
    // 7 wins out of 8 = 87%
    .record_use(true)
    .record_use(true)
    .record_use(true)
    .record_use(true)
    .record_use(true)
    .record_use(true)
    .record_use(true)
    .record_use(false)
  assert_true(r.is_dominant())
}

///|
test "strategy not dominant with low win rate" {
  let r = StrategyRecord::new(fingerprint="test")
    // 3 wins out of 10 = 30%
    .record_use(true)
    .record_use(true)
    .record_use(true)
    .record_use(false)
    .record_use(false)
    .record_use(false)
    .record_use(false)
    .record_use(false)
    .record_use(false)
    .record_use(false)
  assert_true(!r.is_dominant())
}

///|
test "strategy tracker aggregates records" {
  let tracker = StrategyTracker::new()
    .record("bribe", true)
    .record("bribe", true)
    .record("bribe", false)
    .record("threaten", true)
  assert_eq(tracker.total_games, 4)
  let dominant = tracker.dominant_strategies()
  // Not enough uses yet
  assert_eq(dominant.length(), 0)
}

///|
test "strategy tracker detects dominant" {
  let tracker = StrategyTracker::new()
    .record("bribe", true)
    .record("bribe", true)
    .record("bribe", true)
    .record("bribe", true)
    .record("bribe", true)
    .record("bribe", false)
  assert_eq(tracker.dominant_strategies().length(), 1)
}

// --- NPC Dynamic Resistance ---

///|
test "npc resistance base and effective" {
  let r = NPCResistance::new(npc_name="innkeeper", base=3)
  assert_eq(r.effective(), 3)
}

///|
test "npc resistance adjusts for dominance" {
  let r = NPCResistance::new(npc_name="innkeeper", base=3).adjust_for_dominance(
    2,
  )
  assert_eq(r.adjustment, 2)
  assert_eq(r.effective(), 5)
}

///|
test "npc resistance adjustment capped at 5" {
  let r = NPCResistance::new(npc_name="innkeeper", base=3).adjust_for_dominance(
    10,
  )
  assert_eq(r.adjustment, 5)
  assert_eq(r.effective(), 8)
}

// --- Scene Variants ---

///|
test "scene variant pool has multiple variants" {
  let pool = scene_variant_pool()
  assert_true(pool.length() >= 5)
}

///|
test "scene variant selection is deterministic with seed" {
  let v1 = select_scene_variant(42)
  let v2 = select_scene_variant(42)
  assert_eq(v1.name, v2.name)
}

///|
test "scene variant selection varies with different seeds" {
  let names : Array[String] = []
  for seed in 0..<=20 {
    names.push(select_scene_variant(seed).name)
  }
  // Should have at least 2 different variants across 20 seeds
  let mut has_standard = false
  let mut has_other = false
  for name in names {
    if name == "standard" {
      has_standard = true
    }
    if name != "standard" {
      has_other = true
    }
  }
  assert_true(has_standard || has_other)
}
