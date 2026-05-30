///|
test "initial game state has correct defaults" {
  let state = GameState::initial(seed=429)
  let observation = state.observe(@protocol.A, @protocol.WindowId::new(1))
  assert_true(observation.side == @protocol.A)
  assert_true(observation.window_id == @protocol.WindowId::new(1))
  assert_true(state.side_a_alive)
  assert_true(state.side_b_alive)
  assert_eq(observation.state_summary, "seed 429 step 0 A=alive(0) B=alive(0)")
}

///|
test "resolve window increments step without ending" {
  let state = GameState::initial(seed=7)
  let window_id = @protocol.WindowId::new(1)
  let action_a = state.fake_action(@protocol.A, window_id, [])
  let action_b = state.fake_action(@protocol.B, window_id, [])
  let result = state.resolve_window(window_id, [action_a, action_b])
  assert_eq(result.public_log, "window 1 resolved by minimal ruleset")
  assert_eq(result.state.executed_windows, 1)
  assert_true(result.ending is None)
}

///|
test "fake action includes intervention count" {
  let state = GameState::initial(seed=0)
  let window_id = @protocol.WindowId::new(1)
  let intervention = @protocol.Intervention::new(
    side=@protocol.A,
    window_id~,
    sequence_id=@protocol.SequenceId::new(1),
    kind=@protocol.SoftPreference,
    text="/prefer test the slot",
  )
  let action_a = state.fake_action(@protocol.A, window_id, [intervention])
  let action_b = state.fake_action(@protocol.B, window_id, [])
  assert_eq(action_a.label, "fake-action-A")
  assert_eq(action_a.detail, "minimal action with 1 intervention")
  assert_eq(action_b.label, "fake-action-B")
  assert_eq(action_b.detail, "minimal action with 0 interventions")
}

// --- C3: Victory route and potential tests ---

///|
test "route potential starts at zero" {
  let p = RoutePotential::zero()
  for route in VictoryRoute::all() {
    assert_true(p.get(route) == 0)
  }
  assert_eq(p.total(), 0)
}

///|
test "route potential add and set work correctly" {
  let p = RoutePotential::zero()
  let p2 = p.add(Law, 3)
  assert_eq(p2.get(Law), 3)
  assert_eq(p2.total(), 3)
  let p3 = p2.add(Assassination, 2)
  assert_eq(p3.get(Assassination), 2)
  assert_eq(p3.total(), 5)
  let p4 = p3.set(Law, 10)
  assert_eq(p4.get(Law), 10)
  assert_eq(p4.total(), 12)
}

///|
test "highest route returns the route with max potential" {
  let p = RoutePotential::zero()
    .add(Law, 5)
    .add(Assassination, 8)
    .add(PublicOpinion, 3)
  let (route, value) = p.highest_route()
  assert_true(route == Assassination)
  assert_eq(value, 8)
}

///|
test "highest route defaults to law when all zero" {
  let p = RoutePotential::zero()
  let (route, value) = p.highest_route()
  assert_true(route == Law)
  assert_eq(value, 0)
}

// --- C3: Game ending condition tests ---

///|
test "no ending when both sides alive and below max windows" {
  let state = GameState::initial(seed=1)
  let ending = state.check_ending()
  assert_true(ending is None)
}

///|
test "side b eliminated triggers a victory" {
  let state : GameState = {
    seed: 1,
    executed_windows: 5,
    side_a_alive: true,
    side_b_alive: false,
    side_a_potential: RoutePotential::zero().add(Law, 3),
    side_b_potential: RoutePotential::zero(),
  }
  let ending = state.check_ending()
  match ending {
    Some(SideVictory(side, route, _narrative)) => {
      assert_true(side == @protocol.A)
      assert_true(route == Law)
    }
    _ => fail("expected SideVictory A Law")
  }
}

///|
test "side a eliminated triggers b victory" {
  let state : GameState = {
    seed: 1,
    executed_windows: 5,
    side_a_alive: false,
    side_b_alive: true,
    side_a_potential: RoutePotential::zero(),
    side_b_potential: RoutePotential::zero().add(Assassination, 7),
  }
  let ending = state.check_ending()
  match ending {
    Some(SideVictory(side, route, _narrative)) => {
      assert_true(side == @protocol.B)
      assert_true(route == Assassination)
    }
    _ => fail("expected SideVictory B Assassination")
  }
}

///|
test "both eliminated returns BothEliminated" {
  let state : GameState = {
    seed: 1,
    executed_windows: 3,
    side_a_alive: false,
    side_b_alive: false,
    side_a_potential: RoutePotential::zero(),
    side_b_potential: RoutePotential::zero(),
  }
  let ending = state.check_ending()
  match ending {
    Some(BothEliminated(_narrative)) => assert_true(true)
    _ => fail("expected BothEliminated")
  }
}

///|
test "forced end when max windows reached" {
  let state : GameState = {
    seed: 1,
    executed_windows: max_windows,
    side_a_alive: true,
    side_b_alive: true,
    side_a_potential: RoutePotential::zero(),
    side_b_potential: RoutePotential::zero(),
  }
  let ending = state.check_ending()
  match ending {
    Some(ForcedEnd(reason)) => assert_true(reason.contains("max windows"))
    _ => fail("expected ForcedEnd")
  }
}

///|
test "resolve window returns ending when max windows reached" {
  let state : GameState = {
    seed: 1,
    executed_windows: max_windows - 1,
    side_a_alive: true,
    side_b_alive: true,
    side_a_potential: RoutePotential::zero(),
    side_b_potential: RoutePotential::zero(),
  }
  let window_id = @protocol.WindowId::new(max_windows)
  let result = state.resolve_window(window_id, [])
  assert_eq(result.state.executed_windows, max_windows)
  match result.ending {
    Some(ForcedEnd(_)) => assert_true(true)
    _ => fail("expected ForcedEnd from resolve_window")
  }
}

///|
test "game ending summary formats correctly" {
  let ending = SideVictory(@protocol.A, Law, "test narrative")
  let s = ending.summary()
  assert_true(s.contains("A wins by"))
  assert_true(s.contains("test narrative"))
}

///|
test "victory route labels and display names" {
  assert_eq(Law.label(), "law")
  assert_eq(Law.display_name(), "法律")
  assert_eq(Assassination.label(), "assassination")
  assert_eq(Assassination.display_name(), "暗杀")
  assert_eq(PublicOpinion.label(), "public_opinion")
  assert_eq(PublicOpinion.display_name(), "舆论")
  assert_eq(Intrigue.label(), "intrigue")
  assert_eq(Intrigue.display_name(), "权谋")
  assert_eq(Masses.label(), "masses")
  assert_eq(Masses.display_name(), "群众")
}

///|
test "is alive returns correct side status" {
  let state : GameState = {
    seed: 1,
    executed_windows: 0,
    side_a_alive: true,
    side_b_alive: false,
    side_a_potential: RoutePotential::zero(),
    side_b_potential: RoutePotential::zero(),
  }
  assert_true(state.is_alive(@protocol.A))
  assert_true(!state.is_alive(@protocol.B))
}

///|
test "potential returns correct side potential" {
  let state : GameState = {
    seed: 1,
    executed_windows: 0,
    side_a_alive: true,
    side_b_alive: true,
    side_a_potential: RoutePotential::zero().add(Law, 5),
    side_b_potential: RoutePotential::zero().add(Intrigue, 3),
  }
  assert_eq(state.potential(@protocol.A).get(Law), 5)
  assert_eq(state.potential(@protocol.B).get(Intrigue), 3)
}
