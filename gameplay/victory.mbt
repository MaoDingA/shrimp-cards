///|
pub(all) enum VictoryRoute {
  Law // 法律 - collect evidence, bribe officials
  Assassination // 暗杀 - physical elimination
  PublicOpinion // 舆论 - destroy reputation
  Intrigue // 权谋 - power plays
  Masses // 群众 - win popular support
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn VictoryRoute::label(self : VictoryRoute) -> String {
  match self {
    Law => "law"
    Assassination => "assassination"
    PublicOpinion => "public_opinion"
    Intrigue => "intrigue"
    Masses => "masses"
  }
}

///|
pub fn VictoryRoute::display_name(self : VictoryRoute) -> String {
  match self {
    Law => "法律"
    Assassination => "暗杀"
    PublicOpinion => "舆论"
    Intrigue => "权谋"
    Masses => "群众"
  }
}

///|
pub fn VictoryRoute::all() -> Array[VictoryRoute] {
  [Law, Assassination, PublicOpinion, Intrigue, Masses]
}

///|
pub(all) enum GameEnding {
  SideVictory(@protocol.Side, VictoryRoute, String) // winner, route, narrative
  BothEliminated(String) // narrative
  ForcedEnd(String) // reason
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn GameEnding::summary(self : GameEnding) -> String {
  match self {
    SideVictory(side, route, narrative) =>
      "\{side.label()} wins by \{route.display_name()}: \{narrative}"
    BothEliminated(narrative) => "both eliminated: \{narrative}"
    ForcedEnd(reason) => "forced end: \{reason}"
  }
}

///|
/// Victory potential threshold: at or above this value, a kill attempt has
/// reasonable chance of success.
pub let victory_potential_threshold : Int = 10

///|
/// Maximum number of resolved windows before forced end.
pub let max_windows : Int = 20

///|
pub(all) struct RoutePotential {
  law : Int
  assassination : Int
  public_opinion : Int
  intrigue : Int
  masses : Int
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn RoutePotential::zero() -> RoutePotential {
  { law: 0, assassination: 0, public_opinion: 0, intrigue: 0, masses: 0 }
}

///|
pub fn RoutePotential::get(self : RoutePotential, route : VictoryRoute) -> Int {
  match route {
    Law => self.law
    Assassination => self.assassination
    PublicOpinion => self.public_opinion
    Intrigue => self.intrigue
    Masses => self.masses
  }
}

///|
pub fn RoutePotential::set(
  self : RoutePotential,
  route : VictoryRoute,
  value : Int,
) -> RoutePotential {
  match route {
    Law =>
      {
        law: value,
        assassination: self.assassination,
        public_opinion: self.public_opinion,
        intrigue: self.intrigue,
        masses: self.masses,
      }
    Assassination =>
      {
        law: self.law,
        assassination: value,
        public_opinion: self.public_opinion,
        intrigue: self.intrigue,
        masses: self.masses,
      }
    PublicOpinion =>
      {
        law: self.law,
        assassination: self.assassination,
        public_opinion: value,
        intrigue: self.intrigue,
        masses: self.masses,
      }
    Intrigue =>
      {
        law: self.law,
        assassination: self.assassination,
        public_opinion: self.public_opinion,
        intrigue: value,
        masses: self.masses,
      }
    Masses =>
      {
        law: self.law,
        assassination: self.assassination,
        public_opinion: self.public_opinion,
        intrigue: self.intrigue,
        masses: value,
      }
  }
}

///|
pub fn RoutePotential::add(
  self : RoutePotential,
  route : VictoryRoute,
  delta : Int,
) -> RoutePotential {
  self.set(route, self.get(route) + delta)
}

///|
pub fn RoutePotential::total(self : RoutePotential) -> Int {
  self.law +
  self.assassination +
  self.public_opinion +
  self.intrigue +
  self.masses
}

///|
pub fn RoutePotential::highest_route(
  self : RoutePotential,
) -> (VictoryRoute, Int) {
  let routes = VictoryRoute::all()
  let mut best_route = Law
  let mut best_value = self.law
  for route in routes {
    let v = self.get(route)
    if v > best_value {
      best_route = route
      best_value = v
    }
  }
  (best_route, best_value)
}
