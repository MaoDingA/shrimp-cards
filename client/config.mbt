///|
pub(all) struct ClientConfig {
  player_id : String
  display_name : String
  host_url : String
} derive(Eq, Debug)

///|
pub fn ClientConfig::new(
  player_id~ : String,
  display_name~ : String,
  host_url~ : String,
) -> ClientConfig {
  { player_id, display_name, host_url }
}

///|
pub fn ClientConfig::join_request(self : ClientConfig) -> @protocol.JoinRequest {
  @protocol.JoinRequest::new(self.player_id, self.display_name)
}
