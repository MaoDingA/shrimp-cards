// --- C5: Cost Control Tests ---

///|
test "default budget has correct total" {
  let budget = TokenBudget::default()
  assert_eq(budget.total_budget, default_session_budget)
  assert_eq(budget.consumed, 0)
  assert_true(budget.remaining() == default_session_budget)
}

///|
test "budget spend reduces remaining" {
  let budget = TokenBudget::new(total_budget=10000)
  let budget2 = budget.spend(3000)
  assert_true(budget2 is Some(_))
  match budget2 {
    Some(b) => {
      assert_eq(b.consumed, 3000)
      assert_eq(b.remaining(), 7000)
    }
    None => fail("expected Some")
  }
}

///|
test "budget spend fails when insufficient" {
  let budget = TokenBudget::new(total_budget=1000)
  let result = budget.spend(2000)
  assert_true(result is None)
}

///|
test "force spend caps at total" {
  let budget = TokenBudget::new(total_budget=1000)
  let forced = budget.force_spend(5000)
  assert_eq(forced.consumed, 1000)
}

///|
test "consumed fraction calculation" {
  let budget = TokenBudget::new(total_budget=10000).force_spend(2500)
  assert_eq(budget.consumed_fraction(), 25)
}

///|
test "conservation mode triggers at threshold" {
  let budget = TokenBudget::new(total_budget=10000).force_spend(7999)
  assert_true(!budget.is_conservation_mode())
  let budget2 = TokenBudget::new(total_budget=10000).force_spend(8000)
  assert_true(budget2.is_conservation_mode())
}

///|
test "hard limit at 95 percent" {
  let budget = TokenBudget::new(total_budget=10000).force_spend(9499)
  assert_true(!budget.is_hard_limit())
  let budget2 = TokenBudget::new(total_budget=10000).force_spend(9500)
  assert_true(budget2.is_hard_limit())
}

///|
test "endgame reserve reduces available tokens" {
  let budget = TokenBudget::new(total_budget=10000)
  // Reserve is 10% = 1000
  assert_eq(budget.endgame_reserve, 1000)
  assert_eq(budget.available(), 9000)
}

///|
test "can afford check" {
  let budget = TokenBudget::new(total_budget=10000)
  assert_true(budget.can_afford(5000))
  assert_true(!budget.can_afford(9001))
}

///|
test "estimate interaction cost scales with tier" {
  let base = 1000
  assert_eq(estimate_interaction_cost(Fast, base), 1000)
  assert_eq(estimate_interaction_cost(Standard, base), 5000)
  assert_eq(estimate_interaction_cost(Premium, base), 25000)
}

///|
test "cost report recommendations" {
  let healthy = CostReport::from_budget(
    TokenBudget::new(total_budget=10000).force_spend(1000),
  )
  assert_true(!healthy.conservation_mode)
  assert_true(healthy.recommendation.contains("healthy"))

  let conserving = CostReport::from_budget(
    TokenBudget::new(total_budget=10000).force_spend(8500),
  )
  assert_true(conserving.conservation_mode)
  assert_true(conserving.recommendation.contains("Conservation"))

  let hard = CostReport::from_budget(
    TokenBudget::new(total_budget=10000).force_spend(9600),
  )
  assert_true(hard.hard_limit_reached)
  assert_true(hard.recommendation.contains("exhausted"))
}
