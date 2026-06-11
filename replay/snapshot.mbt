/// Replay integrity: state snapshots and hash verification.
///
/// After each window execution, the host records a state snapshot hash.
/// When loading a replay, the viewer can optionally verify that re-executing
/// the recorded inputs produces the same state hashes, confirming the replay
/// is consistent with the original game.
///
/// The hash is a deterministic rolling hash of the state summary string,
/// not a cryptographic hash. Its purpose is tamper detection and
/// regression testing, not security.

/// A snapshot of the game state at a specific window boundary.

///|
pub(all) struct StateSnapshot {
  window_id : @protocol.WindowId
  state_summary : String
  state_hash : Int
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn StateSnapshot::new(
  window_id~ : @protocol.WindowId,
  state_summary~ : String,
  state_hash~ : Int,
) -> StateSnapshot {
  { window_id, state_summary, state_hash }
}

// --- Rolling Hash ---

///|
pub let hash_seed : Int = 5381

/// Compute a djb2-style rolling hash of a string.

///|
pub fn djb2_hash(text : String) -> Int {
  let mut hash = hash_seed
  for i = 0; i < text.length(); i = i + 1 {
    hash = hash * 33 + text[i].to_int()
  }
  hash
}

/// Compute the state hash from a game state.
/// Uses the deterministic summary string.

///|
pub fn compute_state_hash(state : @gameplay.GameState) -> Int {
  djb2_hash(state.summary())
}

/// Create a state snapshot from the current game state after a window.

///|
pub fn make_snapshot(
  window_id : @protocol.WindowId,
  state : @gameplay.GameState,
) -> StateSnapshot {
  StateSnapshot::new(
    window_id~,
    state_summary=state.summary(),
    state_hash=compute_state_hash(state),
  )
}

/// Verify that a snapshot matches the given game state.

///|
pub fn verify_snapshot(
  snapshot : StateSnapshot,
  state : @gameplay.GameState,
) -> Bool {
  compute_state_hash(state) == snapshot.state_hash
}
