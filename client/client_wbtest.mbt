///|
test "client config builds compatible join request" {
  let config = ClientConfig::new(
    player_id="player-1",
    display_name="Alice",
    host_url="ws://127.0.0.1:7777/match",
  )
  let request = config.join_request()
  assert_eq(request.player_id, "player-1")
  assert_eq(request.display_name, "Alice")
  assert_true(request.is_compatible())
}
