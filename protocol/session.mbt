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
fn encode_wire_field(value : String) -> String {
  value.to_json().stringify()
}

///|
fn decode_wire_field(value : String) -> String? {
  try {
    let decoded : String = @json.from_json(@json.parse(value))
    Some(decoded)
  } catch {
    _ => None
  }
}

///|
fn parse_version(raw : String) -> Int? {
  Some(@string.parse_int(raw)) catch {
    _ => None
  }
}

///|
pub fn JoinRequest::to_wire_text(self : JoinRequest) -> String {
  "join\t\{self.protocol_version}\t\{encode_wire_field(self.player_id)}\t\{encode_wire_field(self.display_name)}"
}

///|
pub fn JoinRequest::from_wire_text(frame : String) -> JoinRequest? {
  match split_wire_text(frame) {
    ["join", version, player_id, display_name] =>
      match
        (
          parse_version(version),
          decode_wire_field(player_id),
          decode_wire_field(display_name),
        ) {
        (Some(protocol_version), Some(player_id), Some(display_name)) =>
          Some({ player_id, display_name, protocol_version })
        _ => None
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
      "accepted\t\{encode_wire_field(player.player_id)}\t\{encode_wire_field(player.display_name)}\t\{player.side.label()}"
    JoinRejected(reason) => "rejected\t\{encode_wire_field(reason)}"
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
      match
        (
          decode_wire_field(player_id),
          decode_wire_field(display_name),
          side_from_label(side_label),
        ) {
        (Some(player_id), Some(display_name), Some(side)) =>
          Some(JoinAccepted(PlayerIdentity::new(player_id, display_name, side)))
        _ => None
      }
    ["rejected", reason] =>
      match decode_wire_field(reason) {
        Some(reason) => Some(JoinRejected(reason))
        None => None
      }
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
