// --- C9: Multiplayer Sync Tests ---

// --- Event Queue ---

///|
test "event queue ordering by priority" {
  let q = EventQueue::new()
    .push(
      QueuedEvent::new(
        side=@protocol.A,
        sequence=1,
        priority=Low,
        target_npc="",
        action="chat",
      ),
    )
    .push(
      QueuedEvent::new(
        side=@protocol.B,
        sequence=2,
        priority=High,
        target_npc="",
        action="kill",
      ),
    )
    .push(
      QueuedEvent::new(
        side=@protocol.A,
        sequence=3,
        priority=Normal,
        target_npc="",
        action="bribe",
      ),
    )
  let (q2, first) = q.pop()
  match first {
    Some(e) => {
      assert_true(e.priority == High)
      assert_eq(e.sequence, 2)
    }
    None => fail("expected event")
  }
  let (_, second) = q2.pop()
  match second {
    Some(e) => assert_true(e.priority == Normal)
    None => fail("expected event")
  }
}

///|
test "event queue same priority uses sequence" {
  let q = EventQueue::new()
    .push(
      QueuedEvent::new(
        side=@protocol.B,
        sequence=2,
        priority=Normal,
        target_npc="",
        action="b",
      ),
    )
    .push(
      QueuedEvent::new(
        side=@protocol.A,
        sequence=1,
        priority=Normal,
        target_npc="",
        action="a",
      ),
    )
  let (_, first) = q.pop()
  match first {
    Some(e) => assert_eq(e.sequence, 1)
    None => fail("expected event")
  }
}

///|
test "empty queue returns None" {
  let q = EventQueue::new()
  let (_, result) = q.pop()
  assert_true(result is None)
}

///|
test "event queue length" {
  let q = EventQueue::new()
    .push(
      QueuedEvent::new(
        side=@protocol.A,
        sequence=1,
        priority=Low,
        target_npc="",
        action="a",
      ),
    )
    .push(
      QueuedEvent::new(
        side=@protocol.B,
        sequence=2,
        priority=Low,
        target_npc="",
        action="b",
      ),
    )
  assert_eq(q.length(), 2)
}

// --- NPC Lock Manager ---

///|
test "npc lock acquire and release" {
  let mgr = NPCLockManager::new()
  let (mgr2, ok1) = mgr.try_lock("innkeeper", @protocol.A)
  assert_true(ok1)
  let (mgr3, ok2) = mgr2.try_lock("innkeeper", @protocol.B)
  assert_true(!ok2)
  let mgr4 = mgr3.release("innkeeper")
  let (_, ok3) = mgr4.try_lock("innkeeper", @protocol.B)
  assert_true(ok3)
}

///|
test "npc is available when not locked" {
  let mgr = NPCLockManager::new()
  assert_true(mgr.is_available("innkeeper"))
  let (mgr2, _) = mgr.try_lock("innkeeper", @protocol.A)
  assert_true(!mgr2.is_available("innkeeper"))
}

///|
test "different npcs can be locked simultaneously" {
  let mgr = NPCLockManager::new()
  let (mgr2, ok1) = mgr.try_lock("innkeeper", @protocol.A)
  assert_true(ok1)
  let (_, ok2) = mgr2.try_lock("blacksmith", @protocol.B)
  assert_true(ok2)
}

// --- Visibility ---

///|
test "location is always visible" {
  assert_true(
    check_npc_visibility("innkeeper", "location", @protocol.A, 0) == Visible,
  )
}

///|
test "mood visible with positive relationship" {
  assert_true(
    check_npc_visibility("innkeeper", "mood", @protocol.A, 1) == Visible,
  )
  assert_true(
    check_npc_visibility("innkeeper", "mood", @protocol.A, -1) == Partial,
  )
}

///|
test "secrets hidden unless high relationship" {
  assert_true(
    check_npc_visibility("innkeeper", "secrets", @protocol.A, 3) == Hidden,
  )
  assert_true(
    check_npc_visibility("innkeeper", "secrets", @protocol.A, 5) == Partial,
  )
}

///|
test "inventory always hidden" {
  assert_true(
    check_npc_visibility("innkeeper", "inventory", @protocol.A, 5) == Hidden,
  )
}
