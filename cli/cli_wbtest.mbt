///|
test "parse host command uses localhost defaults" {
  let command = parse_command(["shrimp-cards", "host"])
  match command {
    Host(options) => {
      assert_eq(options.bind_host, "127.0.0.1")
      assert_eq(options.port, 7777)
      assert_false(options.debug)
    }
    _ => fail("expected host command")
  }
}

///|
test "parse host command captures port and debug flag" {
  let command = parse_command([
    "shrimp-cards", "host", "--port", "8888", "--debug",
  ])
  match command {
    Host(options) => {
      assert_eq(options.bind_host, "127.0.0.1")
      assert_eq(options.port, 8888)
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
    "shrimp-cards", "replay", "--file", "replays/match-1.json", "--view", "A",
  ])
  match command {
    Replay(options) => {
      assert_eq(options.file, "replays/match-1.json")
      assert_eq(options.view, "A")
    }
    _ => fail("expected replay command")
  }
}
