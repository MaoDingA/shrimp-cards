///|
test "parse host command uses localhost defaults" {
  let command = parse_command(["shrimp-cards", "host"])
  match command {
    Host(options) => {
      assert_eq(options.bind_host, "127.0.0.1")
      assert_eq(options.port, 7777)
      assert_eq(options.match_id, "match-7777")
      assert_eq(options.seed, 0)
      assert_eq(options.replay_dir, "replays")
      assert_false(options.debug)
    }
    _ => fail("expected host command")
  }
}

///|
test "parse host command captures port debug and replay metadata" {
  let command = parse_command([
    "shrimp-cards", "host", "--port", "8888", "--debug", "--match-id", "local-match",
    "--seed", "42", "--replay-dir", "_build/replays",
  ])
  match command {
    Host(options) => {
      assert_eq(options.bind_host, "127.0.0.1")
      assert_eq(options.port, 8888)
      assert_eq(options.match_id, "local-match")
      assert_eq(options.seed, 42)
      assert_eq(options.replay_dir, "_build/replays")
      assert_true(options.debug)
    }
    _ => fail("expected host command")
  }
}

///|
test "parse join command captures display name" {
  let command = parse_command(["shrimp-cards", "join", "--name", "Alice"])
  match command {
    Join(options) => {
      assert_eq(options.display_name, "Alice")
      assert_eq(options.host_url, "ws://127.0.0.1:7777/match")
    }
    _ => fail("expected join command")
  }
}

///|
test "parse replay command captures file and view" {
  let command = parse_command([
    "shrimp-cards", "replay", "--file", "replays/match-1.json", "--view", "A", "--mode",
    "windows",
  ])
  match command {
    Replay(options) => {
      assert_eq(options.file, "replays/match-1.json")
      assert_eq(options.view, "A")
      assert_eq(options.mode, "windows")
    }
    _ => fail("expected replay command")
  }
}
