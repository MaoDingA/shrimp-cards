///|
pub(all) enum JoinDecision {
  Accepted(@protocol.PlayerIdentity)
  Rejected(String)
} derive(Eq, Debug)

///|
pub(all) struct Lobby {
  players : Array[@protocol.PlayerIdentity]
} derive(Eq, Debug)

///|
pub fn Lobby::new() -> Lobby {
  { players: [] }
}

///|
fn next_side(count : Int) -> @protocol.Side? {
  match count {
    0 => Some(@protocol.A)
    1 => Some(@protocol.B)
    _ => None
  }
}

///|
pub fn Lobby::accept_join(
  self : Lobby,
  request : @protocol.JoinRequest,
) -> JoinDecision {
  if !request.is_compatible() {
    Rejected("protocol version mismatch")
  } else {
    match next_side(self.players.length()) {
      Some(side) => {
        let player = @protocol.PlayerIdentity::new(
          request.player_id,
          request.display_name,
          side,
        )
        self.players.push(player)
        Accepted(player)
      }
      None => Rejected("match is full")
    }
  }
}

///|
pub fn Lobby::accept_join_response(
  self : Lobby,
  request : @protocol.JoinRequest,
) -> @protocol.JoinResponse {
  match self.accept_join(request) {
    Accepted(player) => @protocol.JoinAccepted(player)
    Rejected(reason) => @protocol.JoinRejected(reason)
  }
}

///|
pub fn Lobby::handle_join_frame(self : Lobby, frame : String) -> String {
  match @protocol.JoinRequest::from_wire_text(frame) {
    Some(request) => self.accept_join_response(request).to_wire_text()
    None => @protocol.JoinRejected("invalid join request").to_wire_text()
  }
}

///|
pub fn Lobby::is_ready_to_start(self : Lobby) -> Bool {
  self.players.length() == 2
}
