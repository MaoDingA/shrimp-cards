///|
pub(all) struct JoinRequest {
  player_id : String
  display_name : String
  protocol_version : Int
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn JoinRequest::new(
  player_id : String,
  display_name : String,
) -> JoinRequest {
  { player_id, display_name, protocol_version }
}

///|
pub fn JoinRequest::is_compatible(self : JoinRequest) -> Bool {
  self.protocol_version == protocol_version
}

///|
fn split_wire_text(frame : String) -> Array[String] {
  let parts : Array[String] = []
  for part in frame.split("\t") {
    parts.push(part.to_string())
  }
  parts
}

///|
fn parse_version(raw : String) -> Int? {
  Some(@string.parse_int(raw)) catch {
    _ => None
  }
}

///|
pub fn JoinRequest::to_wire_text(self : JoinRequest) -> String {
  "join\t\{self.protocol_version}\t\{self.player_id}\t\{self.display_name}"
}

///|
pub fn JoinRequest::from_wire_text(frame : String) -> JoinRequest? {
  match split_wire_text(frame) {
    ["join", version, player_id, display_name] =>
      match parse_version(version) {
        Some(protocol_version) =>
          Some({ player_id, display_name, protocol_version })
        None => None
      }
    _ => None
  }
}

///|
pub(all) enum JoinResponse {
  JoinAccepted(PlayerIdentity)
  JoinRejected(String)
} derive(Eq, Debug)

///|
pub fn JoinResponse::to_wire_text(self : JoinResponse) -> String {
  match self {
    JoinAccepted(player) =>
      "accepted\t\{player.player_id}\t\{player.display_name}\t\{player.side.label()}"
    JoinRejected(reason) => "rejected\t\{reason}"
  }
}

///|
fn side_from_label(label : String) -> Side? {
  match label {
    "A" => Some(A)
    "B" => Some(B)
    _ => None
  }
}

///|
pub fn JoinResponse::from_wire_text(frame : String) -> JoinResponse? {
  match split_wire_text(frame) {
    ["accepted", player_id, display_name, side_label] =>
      match side_from_label(side_label) {
        Some(side) =>
          Some(JoinAccepted(PlayerIdentity::new(player_id, display_name, side)))
        None => None
      }
    ["rejected", reason] => Some(JoinRejected(reason))
    _ => None
  }
}

///|
pub fn JoinResponse::summary(self : JoinResponse) -> String {
  match self {
    JoinAccepted(player) => "accepted as \{player.side.label()}"
    JoinRejected(reason) => "rejected: \{reason}"
  }
}
