///|
pub(all) struct HostOptions {
  bind_host : String
  port : Int
  match_id : String
  seed : Int
  replay_dir : String
  heartbeat_timeout_ms : Int
  heartbeat_scan_ms : Int
  debug : Bool
} derive(Eq, Debug)

///|
pub(all) struct JoinOptions {
  display_name : String
  host_url : String
  lang : String
  heartbeat_interval_ms : Int
} derive(Eq, Debug)

///|
pub(all) struct ReplayOptions {
  file : String
  view : String
  mode : String
} derive(Eq, Debug)

///|
pub(all) enum HelpTopic {
  RootHelp
  HostHelp
  JoinHelp
  ReplayHelp
} derive(Eq, Debug)

///|
pub(all) enum Command {
  Host(HostOptions)
  Join(JoinOptions)
  Replay(ReplayOptions)
  Help(HelpTopic)
} derive(Eq, Debug)

///|
fn option_value(
  args : Array[String],
  flag : String,
  default : String,
) -> String {
  let mut value = default
  for index in 0..<args.length() {
    if args[index] == flag {
      match args.get(index + 1) {
        Some(next) => value = next
        None => ()
      }
    }
  }
  value
}

///|
fn has_flag(args : Array[String], flag : String) -> Bool {
  args.contains(flag)
}

///|
fn has_help_flag(args : Array[String]) -> Bool {
  has_flag(args, "--help") || has_flag(args, "-h")
}

///|
fn option_int(args : Array[String], flag : String, default : Int) -> Int {
  let raw = option_value(args, flag, "")
  if raw.is_empty() {
    default
  } else {
    @string.parse_int(raw) catch {
      _ => default
    }
  }
}

///|
pub fn parse_command(args : Array[String]) -> Command {
  match args.get(1) {
    Some("--help") | Some("-h") => Help(RootHelp)
    Some("host") =>
      if has_help_flag(args) {
        Help(HostHelp)
      } else {
        let port = option_int(args, "--port", 7777)
        Host({
          bind_host: option_value(args, "--bind", "127.0.0.1"),
          port,
          match_id: option_value(args, "--match-id", "match-\{port}"),
          seed: option_int(args, "--seed", 0),
          replay_dir: option_value(args, "--replay-dir", "replays"),
          heartbeat_timeout_ms: option_int(
            args, "--heartbeat-timeout-ms", 30000,
          ),
          heartbeat_scan_ms: option_int(args, "--heartbeat-scan-ms", 1000),
          debug: has_flag(args, "--debug"),
        })
      }
    Some("join") =>
      if has_help_flag(args) {
        Help(JoinHelp)
      } else {
        Join({
          display_name: option_value(args, "--name", "Player"),
          host_url: option_value(args, "--host", "ws://127.0.0.1:7777/match"),
          lang: option_value(args, "--lang", "zh"),
          heartbeat_interval_ms: option_int(
            args, "--heartbeat-interval-ms", 5000,
          ),
        })
      }
    Some("replay") =>
      if has_help_flag(args) {
        Help(ReplayHelp)
      } else {
        Replay({
          file: option_value(args, "--file", ""),
          view: option_value(args, "--view", "A"),
          mode: option_value(args, "--mode", "events"),
        })
      }
    _ => Help(RootHelp)
  }
}

///|
pub fn Command::summary(self : Command) -> String {
  match self {
    Host(options) =>
      "host \{options.bind_host}:\{options.port} match \{options.match_id}"
    Join(options) =>
      "join \{options.display_name} -> \{options.host_url} lang \{options.lang}"
    Replay(options) =>
      "replay \{options.file} as \{options.view} mode \{options.mode}"
    Help(topic) => topic.usage_line()
  }
}

///|
fn HelpTopic::usage_line(self : HelpTopic) -> String {
  match self {
    RootHelp => "usage: shrimp-cards <host|join|replay> [options]"
    HostHelp => "usage: shrimp-cards host [options]"
    JoinHelp => "usage: shrimp-cards join [options]"
    ReplayHelp => "usage: shrimp-cards replay --file <path> [options]"
  }
}

///|
pub fn help_lines(topic : HelpTopic) -> Array[String] {
  match topic {
    RootHelp =>
      [
        "Shrimp Cards - local MoonBit card-game foundation", "", "Usage:", "  shrimp-cards <command> [options]",
        "", "Commands:", "  host     Start the authoritative local match host", "  join     Join the host as one player terminal",
        "  replay   Print a saved replay", "", "Run 'shrimp-cards <command> --help' for command options.",
      ]
    HostHelp =>
      [
        "Start the authoritative local match host.", "", "Usage:", "  shrimp-cards host [options]",
        "", "Options:", "  --bind <addr>                    Bind address (default: 127.0.0.1)",
        "  --port <port>                    Port (default: 7777)", "  --match-id <id>                  Match id (default: match-<port>)",
        "  --seed <int>                     Match seed (default: 0)", "  --replay-dir <dir>               Replay directory (default: replays)",
        "  --heartbeat-timeout-ms <ms>      Disconnect timeout (default: 30000)",
        "  --heartbeat-scan-ms <ms>         Disconnect scan interval (default: 1000)",
        "  --debug                          Enable debug output", "  -h, --help                       Show this help",
        "", "Example:", "  shrimp-cards host --port 7777 --match-id local-match --seed 42",
      ]
    JoinHelp =>
      [
        "Join a local host as a player supervisor terminal.", "", "Usage:", "  shrimp-cards join [options]",
        "", "Options:", "  --name <name>                    Display name (default: Player)",
        "  --host <url>                     Host URL (default: ws://127.0.0.1:7777/match)",
        "  --lang <zh|en>                   Display language (default: zh)", "  --heartbeat-interval-ms <ms>     Client heartbeat interval (default: 5000)",
        "  -h, --help                       Show this help", "", "Terminal commands:",
        "  /ready                           Mark this side ready", "  /prefer <text>                   Guide the agent plan",
        "  /ban <text>                      Forbid one thing", "  /lock                            Accept the current plan",
        "  /leave                           Leave and end the match", "  /lang <zh|en>                    Change local display language",
      ]
    ReplayHelp =>
      [
        "Print a saved replay through the same visibility filter as players.", "",
        "Usage:", "  shrimp-cards replay --file <path> [options]", "", "Options:",
        "  --file <path>                    Replay JSON file", "  --view <A|B>                     Viewer side (default: A)",
        "  --mode <events|windows|metadata> Output mode (default: events)", "  -h, --help                       Show this help",
        "", "Example:", "  shrimp-cards replay --file replays/local-match.json --view A --mode events",
      ]
  }
}
