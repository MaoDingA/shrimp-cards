///|
pub(all) struct HostOptions {
  bind_host : String
  port : Int
  match_id : String
  seed : Int
  replay_dir : String
  debug : Bool
} derive(Eq, Debug)

///|
pub(all) struct JoinOptions {
  display_name : String
  host_url : String
  lang : String
} derive(Eq, Debug)

///|
pub(all) struct ReplayOptions {
  file : String
  view : String
  mode : String
} derive(Eq, Debug)

///|
pub(all) enum Command {
  Host(HostOptions)
  Join(JoinOptions)
  Replay(ReplayOptions)
  Help
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
    Some("host") => {
      let port = option_int(args, "--port", 7777)
      Host({
        bind_host: option_value(args, "--bind", "127.0.0.1"),
        port,
        match_id: option_value(args, "--match-id", "match-\{port}"),
        seed: option_int(args, "--seed", 0),
        replay_dir: option_value(args, "--replay-dir", "replays"),
        debug: has_flag(args, "--debug"),
      })
    }
    Some("join") =>
      Join({
        display_name: option_value(args, "--name", "Player"),
        host_url: option_value(args, "--host", "ws://127.0.0.1:7777/match"),
        lang: option_value(args, "--lang", "zh"),
      })
    Some("replay") =>
      Replay({
        file: option_value(args, "--file", ""),
        view: option_value(args, "--view", "A"),
        mode: option_value(args, "--mode", "events"),
      })
    _ => Help
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
    Help => "usage: shrimp-cards <host|join|replay>"
  }
}
