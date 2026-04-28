///|
pub(all) struct WindowSecrets {
  side_a_plan : String
  side_b_plan : String
  public_interventions : Array[String]
} derive(Eq, Debug)

///|
pub fn WindowSecrets::new(
  side_a_plan~ : String,
  side_b_plan~ : String,
  public_interventions~ : Array[String],
) -> WindowSecrets {
  { side_a_plan, side_b_plan, public_interventions }
}

///|
pub(all) struct PlayerWindowView {
  viewer : @protocol.Side
  own_agent_plan : String
  opponent_agent_plan : String?
  public_interventions : Array[String]
} derive(Eq, Debug)

///|
pub fn WindowSecrets::view_for(
  self : WindowSecrets,
  viewer : @protocol.Side,
) -> PlayerWindowView {
  let own_agent_plan = match viewer {
    @protocol.A => self.side_a_plan
    @protocol.B => self.side_b_plan
  }
  {
    viewer,
    own_agent_plan,
    opponent_agent_plan: None,
    public_interventions: self.public_interventions.copy(),
  }
}

///|
fn public_intervention_texts(
  record : @replay.ReplayWindowRecord,
) -> Array[String] {
  let result : Array[String] = Array::new()
  for intervention in record.public_interventions {
    result.push("\{intervention.side.label()}:\{intervention.text}")
  }
  result
}

///|
pub fn view_replay_window(
  record : @replay.ReplayWindowRecord,
  viewer : @protocol.Side,
) -> PlayerWindowView {
  let own_agent_plan = match viewer {
    @protocol.A => record.final_agent_plan_a
    @protocol.B => record.final_agent_plan_b
  }
  {
    viewer,
    own_agent_plan,
    opponent_agent_plan: None,
    public_interventions: public_intervention_texts(record),
  }
}
