///|
pub let replay_format_version : Int = 1

///|
pub(all) struct ReplayHeader {
  match_id : String
  created_at : String
  seed : Int
  protocol_version : Int
  format_version : Int
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn ReplayHeader::new(
  match_id : String,
  created_at : String,
  seed : Int,
  protocol_version : Int,
  format_version : Int,
) -> ReplayHeader {
  { match_id, created_at, seed, protocol_version, format_version }
}

///|
pub fn ReplayHeader::is_compatible(self : ReplayHeader) -> Bool {
  self.protocol_version == @protocol.protocol_version &&
  self.format_version == replay_format_version
}
