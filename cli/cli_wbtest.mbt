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
      assert_eq(options.heartbeat_timeout_ms, 30000)
      assert_eq(options.heartbeat_scan_ms, 1000)
      assert_false(options.debug)
    }
    _ => fail("expected host command")
  }
}

///|
test "parse host command captures port debug and replay metadata" {
  let command = parse_command([
    "shrimp-cards", "host", "--port", "8888", "--debug", "--match-id", "local-match",
    "--seed", "42", "--replay-dir", "_build/replays", "--heartbeat-timeout-ms", "12000",
    "--heartbeat-scan-ms", "250",
  ])
  match command {
    Host(options) => {
      assert_eq(options.bind_host, "127.0.0.1")
      assert_eq(options.port, 8888)
      assert_eq(options.match_id, "local-match")
      assert_eq(options.seed, 42)
      assert_eq(options.replay_dir, "_build/replays")
      assert_eq(options.heartbeat_timeout_ms, 12000)
      assert_eq(options.heartbeat_scan_ms, 250)
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
      assert_eq(options.lang, "zh")
      assert_eq(options.heartbeat_interval_ms, 5000)
    }
    _ => fail("expected join command")
  }
}

///|
test "parse join command captures language option" {
  let command = parse_command([
    "shrimp-cards", "join", "--name", "Alice", "--lang", "en", "--heartbeat-interval-ms",
    "2500",
  ])
  match command {
    Join(options) => {
      assert_eq(options.lang, "en")
      assert_eq(options.heartbeat_interval_ms, 2500)
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

///|
fn assert_help_command(command : Command, expected : HelpTopic) -> Unit raise {
  match command {
    Help(topic) => assert_true(topic == expected)
    _ => fail("expected help command")
  }
}

///|
test "parse root help flags without starting a command" {
  assert_help_command(parse_command(["shrimp-cards"]), RootHelp)
  assert_help_command(parse_command(["shrimp-cards", "--help"]), RootHelp)
  assert_help_command(parse_command(["shrimp-cards", "-h"]), RootHelp)
}

///|
test "parse subcommand help flags without starting a command" {
  assert_help_command(
    parse_command(["shrimp-cards", "host", "--help"]),
    HostHelp,
  )
  assert_help_command(parse_command(["shrimp-cards", "join", "-h"]), JoinHelp)
  assert_help_command(
    parse_command(["shrimp-cards", "replay", "--help"]),
    ReplayHelp,
  )
}

///|
test "help lines list stable commands and options" {
  let root = help_lines(RootHelp)
  assert_true(
    root.contains("  host     Start the authoritative local match host"),
  )
  assert_true(root.contains("  join     Join the host as one player terminal"))
  assert_true(root.contains("  replay   Print a saved replay"))
  let host = help_lines(HostHelp)
  assert_true(
    host.contains(
      "  --replay-dir <dir>               Replay directory (default: replays)",
    ),
  )
  let join = help_lines(JoinHelp)
  assert_true(
    join.contains(
      "  --lang <zh|en>                   Display language (default: zh)",
    ),
  )
  assert_true(
    join.contains("  /prefer <text>                   Guide the agent plan"),
  )
  let replay = help_lines(ReplayHelp)
  assert_true(
    replay.contains(
      "  --mode <events|windows|metadata> Output mode (default: events)",
    ),
  )
}
