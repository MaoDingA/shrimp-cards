///|
pub(all) struct MatchId(String) derive(Eq, Debug, ToJson, FromJson)

///|
pub fn MatchId::new(value : String) -> MatchId {
  MatchId(value)
}

///|
pub fn MatchId::value(self : MatchId) -> String {
  match self {
    MatchId(value) => value
  }
}

///|
pub(all) struct SequenceId(Int) derive(Eq, Debug, ToJson, FromJson)

///|
pub fn SequenceId::new(value : Int) -> SequenceId {
  SequenceId(value)
}

///|
pub fn SequenceId::value(self : SequenceId) -> Int {
  match self {
    SequenceId(value) => value
  }
}

///|
pub fn SequenceId::is_newer_than(
  self : SequenceId,
  last_seen : SequenceId,
) -> Bool {
  self.value() > last_seen.value()
}
