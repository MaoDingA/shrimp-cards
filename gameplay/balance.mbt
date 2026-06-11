/// Balance and anti-degeneration (meta-game prevention).
///
/// Implements:
///   - Strategy tracking and win-rate monitoring
///   - NPC dynamic resistance adjustment
///   - Scene variant pool for variety

// --- Strategy Tracking ---

/// A tracked player strategy pattern.

///|
pub(all) struct StrategyRecord {
  /// Strategy fingerprint (e.g., "bribe_innkeeper").
  fingerprint : String
  /// Number of times this strategy was used.
  use_count : Int
  /// Number of times this strategy led to a win.
  win_count : Int
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn StrategyRecord::new(fingerprint~ : String) -> StrategyRecord {
  { fingerprint, use_count: 0, win_count: 0 }
}

///|
pub fn StrategyRecord::record_use(
  self : StrategyRecord,
  won : Bool,
) -> StrategyRecord {
  {
    fingerprint: self.fingerprint,
    use_count: self.use_count + 1,
    win_count: if won {
      self.win_count + 1
    } else {
      self.win_count
    },
  }
}

///|
pub fn StrategyRecord::win_rate(self : StrategyRecord) -> Int {
  if self.use_count == 0 {
    return 0
  }
  self.win_count * 100 / self.use_count
}

///|
/// Dominant strategy detection threshold (win rate %).
pub let dominant_threshold : Int = 65

///|
/// Minimum uses before a strategy can be flagged as dominant.
pub let min_uses_for_dominant : Int = 5

///|
pub fn StrategyRecord::is_dominant(self : StrategyRecord) -> Bool {
  self.use_count >= min_uses_for_dominant &&
  self.win_rate() >= dominant_threshold
}

/// Global strategy tracker for balance monitoring.

///|
pub(all) struct StrategyTracker {
  records : Array[StrategyRecord]
  total_games : Int
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn StrategyTracker::new() -> StrategyTracker {
  { records: [], total_games: 0 }
}

///|
pub fn StrategyTracker::record(
  self : StrategyTracker,
  fingerprint : String,
  won : Bool,
) -> StrategyTracker {
  let records = self.records.copy()
  let mut found = false
  let mut i = 0
  while i < records.length() {
    if records[i].fingerprint == fingerprint {
      records[i] = records[i].record_use(won)
      found = true
    }
    i = i + 1
  }
  if !found {
    records.push(StrategyRecord::new(fingerprint~).record_use(won))
  }
  { records, total_games: self.total_games + 1 }
}

/// Find all currently dominant strategies.

///|
pub fn StrategyTracker::dominant_strategies(
  self : StrategyTracker,
) -> Array[StrategyRecord] {
  let result : Array[StrategyRecord] = []
  for r in self.records {
    if r.is_dominant() {
      result.push(r)
    }
  }
  result
}

// --- NPC Dynamic Resistance ---

/// Base resistance values for NPC behavior adjustments.

///|
pub(all) struct NPCResistance {
  /// NPC name.
  npc_name : String
  /// Base resistance (0-10).
  base : Int
  /// Dynamic adjustment from balance system.
  adjustment : Int
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn NPCResistance::new(npc_name~ : String, base~ : Int) -> NPCResistance {
  { npc_name, base, adjustment: 0 }
}

///|
pub fn NPCResistance::effective(self : NPCResistance) -> Int {
  self.base + self.adjustment
}

/// Adjust resistance based on dominant strategy detection.
/// If a strategy targeting this NPC type is dominant, increase resistance.

///|
pub fn NPCResistance::adjust_for_dominance(
  self : NPCResistance,
  dominant_count : Int,
) -> NPCResistance {
  // Each dominant strategy adds 1 to adjustment (max 5)
  let adj = if dominant_count > 5 { 5 } else { dominant_count }
  { ..self, adjustment: adj }
}

// --- Scene Variant Pool ---

/// A scene variant with specific rule modifiers.

///|
pub(all) struct SceneVariant {
  /// Variant name.
  name : String
  /// Description for display.
  description : String
  /// Tags describing what's modified.
  tags : Array[String]
  /// Weight for random selection (higher = more likely).
  weight : Int
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn SceneVariant::new(
  name~ : String,
  description~ : String,
  tags~ : Array[String],
  weight~ : Int,
) -> SceneVariant {
  { name, description, tags, weight }
}

/// Predefined scene variants.

///|
pub fn scene_variant_pool() -> Array[SceneVariant] {
  [
    SceneVariant::new(
      name="standard",
      description="标准规则，无特殊改动",
      tags=["base"],
      weight=10,
    ),
    SceneVariant::new(
      name="shadow",
      description="谍影重重：玩家初始信息更多",
      tags=["intel_boost"],
      weight=5,
    ),
    SceneVariant::new(
      name="chaos",
      description="乱世风云：NPC 情绪波动更大",
      tags=["emotion_volatile"],
      weight=5,
    ),
    SceneVariant::new(
      name="siege",
      description="围城困局：可活动区域逐渐缩小",
      tags=["area_shrink"],
      weight=3,
    ),
    SceneVariant::new(
      name="trade",
      description="商道风云：经济因素更加重要",
      tags=["economy_focus"],
      weight=5,
    ),
  ]
}

/// Select a scene variant by weighted random (using seed).

///|
pub fn select_scene_variant(seed : Int) -> SceneVariant {
  let pool = scene_variant_pool()
  let mut total_weight = 0
  for v in pool {
    total_weight = total_weight + v.weight
  }
  if total_weight == 0 {
    return pool[0]
  }
  // Ensure non-negative target regardless of seed sign
  let target = if seed >= 0 {
    seed % total_weight
  } else {
    (seed % total_weight + total_weight) % total_weight
  }
  let mut accumulated = 0
  for v in pool {
    accumulated = accumulated + v.weight
    if accumulated > target {
      return v
    }
  }
  pool[pool.length() - 1]
}
