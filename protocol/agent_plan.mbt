///|
pub(all) enum AgentPlanPhase {
  InitialPlan
  FinalPlan
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn AgentPlanPhase::wire_label(self : AgentPlanPhase) -> String {
  match self {
    InitialPlan => "initial"
    FinalPlan => "final"
  }
}

///|
pub fn AgentPlanPhase::from_wire_label(label : String) -> AgentPlanPhase? {
  match label {
    "initial" => Some(InitialPlan)
    "final" => Some(FinalPlan)
    _ => None
  }
}

///|
pub(all) struct AgentPlan {
  side : Side
  window_id : WindowId
  phase : AgentPlanPhase
  plan : String
  reason : String
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn AgentPlan::new(
  side~ : Side,
  window_id~ : WindowId,
  phase~ : AgentPlanPhase,
  plan~ : String,
  reason~ : String,
) -> AgentPlan {
  { side, window_id, phase, plan, reason }
}
