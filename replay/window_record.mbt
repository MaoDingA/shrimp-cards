///|
pub(all) struct ReplayWindowRecord {
  window_id : @protocol.WindowId
  sequence_id : @protocol.SequenceId
  initial_agent_plan_a : String
  initial_agent_plan_b : String
  final_agent_plan_a : String
  final_agent_plan_b : String
  public_interventions : Array[@protocol.Intervention]
  public_events : Array[@protocol.PublicEvent]
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn ReplayWindowRecord::new(
  window_id~ : @protocol.WindowId,
  sequence_id~ : @protocol.SequenceId,
  initial_agent_plan_a~ : String,
  initial_agent_plan_b~ : String,
  final_agent_plan_a~ : String,
  final_agent_plan_b~ : String,
  public_interventions~ : Array[@protocol.Intervention],
  public_events~ : Array[@protocol.PublicEvent],
) -> ReplayWindowRecord {
  {
    window_id,
    sequence_id,
    initial_agent_plan_a,
    initial_agent_plan_b,
    final_agent_plan_a,
    final_agent_plan_b,
    public_interventions,
    public_events,
  }
}

///|
pub fn ReplayWindowRecord::has_complete_agent_plans(
  self : ReplayWindowRecord,
) -> Bool {
  !self.initial_agent_plan_a.is_empty() &&
  !self.initial_agent_plan_b.is_empty() &&
  !self.final_agent_plan_a.is_empty() &&
  !self.final_agent_plan_b.is_empty()
}

///|
pub fn ReplayWindowRecord::public_event_count(self : ReplayWindowRecord) -> Int {
  self.public_events.length()
}
