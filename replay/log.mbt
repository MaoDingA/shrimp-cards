///|
pub(all) struct ReplayLog {
  header : ReplayHeader
  players : Array[@protocol.PlayerIdentity]
  windows : Array[ReplayWindowRecord]
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn ReplayLog::new(
  header : ReplayHeader,
  players : Array[@protocol.PlayerIdentity],
  windows : Array[ReplayWindowRecord],
) -> ReplayLog {
  { header, players, windows }
}

///|
fn has_player_side(
  players : Array[@protocol.PlayerIdentity],
  side : @protocol.Side,
) -> Bool {
  let mut found = false
  for player in players {
    if player.side == side {
      found = true
    }
  }
  found
}

///|
pub fn ReplayLog::can_play(self : ReplayLog) -> Bool {
  self.header.is_compatible() &&
  has_player_side(self.players, @protocol.A) &&
  has_player_side(self.players, @protocol.B)
}
