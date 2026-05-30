/// Cost control and token budget management.
///
/// Tracks token consumption per game session, enforces budgets,
/// and triggers conservation mode when thresholds are exceeded.

///|
/// Default token budget per game session (~500k tokens = ~$0.5-1.5).
pub let default_session_budget : Int = 500000

///|
/// Conservation mode triggers at this fraction of budget (80%).
pub let conservation_threshold_fraction : Int = 80

///|
/// Hard limit: game must end when this fraction is reached (95%).
pub let hard_limit_fraction : Int = 95

///|
/// Token cost estimates per interaction type.
pub let tokens_idle_chat : Int = 500

///|
pub let tokens_standard_interaction : Int = 2000

///|
pub let tokens_key_narrative : Int = 5000

///|
pub let tokens_summary : Int = 1000

///|
pub let tokens_intent_classify : Int = 300

/// Session token budget tracker. Immutable — each operation returns a new tracker.

///|
pub(all) struct TokenBudget {
  /// Total budget for this session.
  total_budget : Int
  /// Tokens consumed so far.
  consumed : Int
  /// Tokens reserved for endgame (guaranteed minimum).
  endgame_reserve : Int
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn TokenBudget::new(total_budget~ : Int) -> TokenBudget {
  let endgame_reserve = total_budget / 10
  { total_budget, consumed: 0, endgame_reserve }
}

///|
pub fn TokenBudget::default() -> TokenBudget {
  TokenBudget::new(total_budget=default_session_budget)
}

///|
pub fn TokenBudget::remaining(self : TokenBudget) -> Int {
  self.total_budget - self.consumed
}

///|
pub fn TokenBudget::available(self : TokenBudget) -> Int {
  // Don't count endgame reserve as available during normal play
  let raw = self.remaining() - self.endgame_reserve
  if raw < 0 {
    0
  } else {
    raw
  }
}

///|
pub fn TokenBudget::consumed_fraction(self : TokenBudget) -> Int {
  if self.total_budget == 0 {
    return 100
  }
  self.consumed * 100 / self.total_budget
}

///|
pub fn TokenBudget::is_conservation_mode(self : TokenBudget) -> Bool {
  self.consumed_fraction() >= conservation_threshold_fraction
}

///|
pub fn TokenBudget::is_hard_limit(self : TokenBudget) -> Bool {
  self.consumed_fraction() >= hard_limit_fraction
}

/// Spend tokens. Returns None if insufficient budget.

///|
pub fn TokenBudget::spend(self : TokenBudget, amount : Int) -> TokenBudget? {
  let new_consumed = self.consumed + amount
  if new_consumed > self.total_budget {
    None
  } else {
    Some({ ..self, consumed: new_consumed })
  }
}

/// Force spend (for mandatory operations like endgame). Can dip into reserve.

///|
pub fn TokenBudget::force_spend(
  self : TokenBudget,
  amount : Int,
) -> TokenBudget {
  let new_consumed = self.consumed + amount
  if new_consumed > self.total_budget {
    { ..self, consumed: self.total_budget }
  } else {
    { ..self, consumed: new_consumed }
  }
}

/// Check if a request can be afforded given its estimated cost.

///|
pub fn TokenBudget::can_afford(
  self : TokenBudget,
  estimated_cost : Int,
) -> Bool {
  self.available() >= estimated_cost
}

/// Estimate token cost for a given model tier and interaction type.

///|
pub fn estimate_interaction_cost(tier : ModelTier, tokens_needed : Int) -> Int {
  tokens_needed * tier.cost_multiplier()
}

///|
pub(all) struct CostReport {
  /// Total tokens consumed.
  total_consumed : Int
  /// Budget percentage used.
  percent_used : Int
  /// Whether in conservation mode.
  conservation_mode : Bool
  /// Whether hard limit reached.
  hard_limit_reached : Bool
  /// Recommendation text.
  recommendation : String
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn CostReport::from_budget(budget : TokenBudget) -> CostReport {
  let percent = budget.consumed_fraction()
  let conservation = budget.is_conservation_mode()
  let hard = budget.is_hard_limit()
  let recommendation = if hard {
    "Token budget nearly exhausted. Force game ending soon."
  } else if conservation {
    "Conservation mode active. Using fast model for all interactions."
  } else if percent > 60 {
    "Approaching budget limit. Consider accelerating game pace."
  } else {
    "Budget healthy. Normal operation."
  }
  {
    total_consumed: budget.consumed,
    percent_used: percent,
    conservation_mode: conservation,
    hard_limit_reached: hard,
    recommendation,
  }
}
