///|
pub(all) enum InterventionKind {
  HardConstraint
  SoftPreference
} derive(Eq, Debug, ToJson, FromJson)

///|
pub(all) struct Intervention {
  side : Side
  window_id : WindowId
  sequence_id : SequenceId
  kind : InterventionKind
  text : String
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn Intervention::new(
  side~ : Side,
  window_id~ : WindowId,
  sequence_id~ : SequenceId,
  kind~ : InterventionKind,
  text~ : String,
) -> Intervention {
  { side, window_id, sequence_id, kind, text }
}

///|
pub fn Intervention::is_for_window(
  self : Intervention,
  current : WindowId,
) -> Bool {
  self.window_id == current
}
