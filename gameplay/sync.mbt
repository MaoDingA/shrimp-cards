/// Multiplayer synchronization and NPC state conflict resolution.
///
/// Implements:
///   - Event queue with FIFO ordering and priority
///   - NPC state lock (one interaction at a time)
///   - Information isolation (visibility matrix)

/// Priority levels for events in the queue.

///|
pub(all) enum EventPriority {
  /// Low priority: idle chat, exploration results.
  Low
  /// Normal priority: standard NPC interactions.
  Normal
  /// High priority: kill attempts, game-ending events.
  High
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn EventPriority::value(self : EventPriority) -> Int {
  match self {
    Low => 0
    Normal => 1
    High => 2
  }
}

/// A queued player action event.

///|
pub(all) struct QueuedEvent {
  /// Which side submitted this event.
  side : @protocol.Side
  /// Timestamp (monotonic counter).
  sequence : Int
  /// Priority level.
  priority : EventPriority
  /// Target NPC name (empty if no NPC target).
  target_npc : String
  /// The action description.
  action : String
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn QueuedEvent::new(
  side~ : @protocol.Side,
  sequence~ : Int,
  priority~ : EventPriority,
  target_npc~ : String,
  action~ : String,
) -> QueuedEvent {
  { side, sequence, priority, target_npc, action }
}

/// Compare events: higher priority first, then earlier sequence.

///|
pub fn compare_events(a : QueuedEvent, b : QueuedEvent) -> Int {
  let pa = a.priority.value()
  let pb = b.priority.value()
  if pa != pb {
    pb - pa
  } else {
    a.sequence - b.sequence
  }
}

/// Global event queue that orders player actions.

///|
pub(all) struct EventQueue {
  events : Array[QueuedEvent]
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn EventQueue::new() -> EventQueue {
  { events: [] }
}

///|
pub fn EventQueue::length(self : EventQueue) -> Int {
  self.events.length()
}

///|
pub fn EventQueue::push(self : EventQueue, event : QueuedEvent) -> EventQueue {
  let events = self.events.copy()
  events.push(event)
  // Simple insertion sort to maintain order
  sort_events(events)
  { events, }
}

/// Pop the next event from the queue.

///|
pub fn EventQueue::pop(self : EventQueue) -> (EventQueue, QueuedEvent?) {
  if self.events.length() == 0 {
    (self, None)
  } else {
    let event = self.events[0]
    let remaining : Array[QueuedEvent] = []
    let n = self.events.length()
    let mut i = 1
    while i < n {
      remaining.push(self.events[i])
      i = i + 1
    }
    ({ events: remaining }, Some(event))
  }
}

///|
fn sort_events(events : Array[QueuedEvent]) -> Unit {
  let n = events.length()
  let mut i = 1
  while i < n {
    let mut j = i
    while j > 0 {
      if compare_events(events[j], events[j - 1]) < 0 {
        let temp = events[j]
        events[j] = events[j - 1]
        events[j - 1] = temp
      }
      j = j - 1
    }
    i = i + 1
  }
}

// --- NPC State Lock ---

/// Status of an NPC (busy or available).

///|
pub(all) enum NPCAvailability {
  /// NPC is free to interact.
  Available
  /// NPC is busy interacting with a side.
  Busy(@protocol.Side)
} derive(Eq, Debug, ToJson, FromJson)

/// Tracks which NPCs are currently being interacted with.

///|
pub(all) struct NPCLockManager {
  /// NPC name -> current availability.
  locks : Array[(String, NPCAvailability)]
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn NPCLockManager::new() -> NPCLockManager {
  { locks: [] }
}

/// Try to acquire an NPC lock. Returns updated manager if successful.

///|
pub fn NPCLockManager::try_lock(
  self : NPCLockManager,
  npc_name : String,
  side : @protocol.Side,
) -> (NPCLockManager, Bool) {
  // Check if already locked
  for pair in self.locks {
    let (name, status) = pair
    if name == npc_name {
      match status {
        Busy(_) => return (self, false)
        Available => ignore(0)
      }
    }
  }
  // Acquire lock
  let locks = self.locks.copy()
  let mut found = false
  for pair in locks {
    let (name, _status) = pair
    if name == npc_name {
      found = true
    }
  }
  if !found {
    locks.push((npc_name, Busy(side)))
  }
  ({ locks, }, true)
}

/// Release an NPC lock.

///|
pub fn NPCLockManager::release(
  self : NPCLockManager,
  npc_name : String,
) -> NPCLockManager {
  let locks : Array[(String, NPCAvailability)] = []
  for pair in self.locks {
    let (name, status) = pair
    if name == npc_name {
      locks.push((name, Available))
    } else {
      locks.push((name, status))
    }
  }
  { locks, }
}

/// Check if an NPC is available.

///|
pub fn NPCLockManager::is_available(
  self : NPCLockManager,
  npc_name : String,
) -> Bool {
  for pair in self.locks {
    let (name, status) = pair
    if name == npc_name {
      match status {
        Available => return true
        Busy(_) => return false
      }
    }
  }
  true
}

// --- Information Visibility Matrix ---

/// What information a player can see about a game element.

///|
pub(all) enum Visibility {
  /// Fully visible.
  Visible
  /// Partially visible (some details hidden).
  Partial
  /// Completely hidden.
  Hidden
} derive(Eq, Debug, ToJson, FromJson)

/// Check visibility of NPC information for a given side.

///|
pub fn check_npc_visibility(
  npc_name : String,
  info_type : String,
  requesting_side : @protocol.Side,
  relationship : Int,
) -> Visibility {
  // Relationship-based visibility
  match info_type {
    "location" => Visible
    "mood" => if relationship >= 0 { Visible } else { Partial }
    "dialogue_content" =>
      // Only see dialogue content if relationship is positive
      if relationship > 2 {
        Visible
      } else {
        Partial
      }
    "inventory" => Hidden
    "secrets" => if relationship > 4 { Partial } else { Hidden }
    _ => Partial
  }
}
