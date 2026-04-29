///|
pub let protocol_version : Int = 4

///|
pub(all) enum Side {
  A
  B
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn Side::label(self : Side) -> String {
  match self {
    A => "A"
    B => "B"
  }
}

///|
pub(all) struct PlayerIdentity {
  player_id : String
  display_name : String
  side : Side
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn PlayerIdentity::new(
  player_id : String,
  display_name : String,
  side : Side,
) -> PlayerIdentity {
  { player_id, display_name, side }
}

///|
pub(all) struct WindowId(Int) derive(Eq, Debug, ToJson, FromJson)

///|
pub fn WindowId::new(value : Int) -> WindowId {
  WindowId(value)
}

///|
pub fn WindowId::value(self : WindowId) -> Int {
  match self {
    WindowId(value) => value
  }
}

///|
pub fn WindowId::accepts(self : WindowId, input_window : WindowId) -> Bool {
  self == input_window
}
