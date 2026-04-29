# Shrimp Cards

<p align="left">
  <a href="./README.md"><img alt="简体中文" src="https://img.shields.io/static/v1?label=%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87&message=README&color=64748b"></a>
  <a href="./README.en.md"><img alt="English" src="https://img.shields.io/static/v1?label=English&message=current&color=0f766e"></a>
  <a href="https://www.moonbitlang.com/"><img alt="MoonBit" src="https://img.shields.io/static/v1?label=MoonBit&message=native&color=7c3aed"></a>
  <a href="./LICENSE"><img alt="License: MIT" src="https://img.shields.io/static/v1?label=license&message=MIT&color=22c55e"></a>
  <img alt="terminal-first" src="https://img.shields.io/static/v1?label=terminal&message=first&color=334155">
  <img alt="PvE and PvP" src="https://img.shields.io/static/v1?label=mode&message=PvE%20%2B%20PvP&color=2563eb">
</p>

Shrimp Cards is a terminal-first MoonBit card-game foundation for PvE and PvP
experiments. The current code focuses on non-gameplay infrastructure: local
host/client communication, live intervention windows, replay recording, and
agent planning flow.

Gameplay rules are intentionally not defined yet. The code only includes a tiny
fake/minimal ruleset to prove that the gameplay slot, agent plans, and replay
pipeline are connected.

## Current Architecture

```mermaid
flowchart TD
  PlayerA["Player A terminal"] --> JoinA["join + light TUI"]
  PlayerB["Player B terminal"] --> JoinB["join + light TUI"]
  Viewer["Post-match replay terminal"] --> ReplayCmd["replay command"]

  JoinA --> ClientWS["client/ws LiveSession"]
  JoinB --> ClientWS
  ReplayCmd --> ReplayLoader["ReplayEventLog loader"]

  ClientWS <--> HostWS["host/ws WebSocket server"]
  HostWS --> Session["host MatchSession"]
  Session --> Gameplay["gameplay: minimal fake ruleset"]
  Gameplay --> Protocol["protocol: ClientInput / ServerEvent / AgentPlan"]
  Session --> Protocol

  HostWS --> Journal["ReplayEventJournal"]
  Journal --> ReplayFile["replays/*.json"]

  HostWS --> Visibility["visibility filter"]
  ReplayLoader --> Visibility
  Visibility --> JoinA
  Visibility --> JoinB
  Visibility --> ReplayCmd
```

The `host` is the only authoritative state owner. Player clients only send input
messages. Player terminals and the replay viewer both pass through the same
`visibility` filter so hidden information is not decided in UI code. The current
replay is an event stream; real gameplay, cards, and combat resolution are not
wired in yet.

## Requirements

- MoonBit toolchain
- A terminal that can run three shell sessions

## Check The Project

```sh
moon fmt --check
moon check --target native
moon test --target native
moon test
moon info --target native
```

## Local Smoke Test

Run a host, two player clients, the ready/leave flow, and replay validation:

```sh
scripts/smoke-local.sh
```

## Run A Local Match

Print command help:

```sh
moon run cmd/main --target native -- --help
moon run cmd/main --target native -- host --help
moon run cmd/main --target native -- join --help
moon run cmd/main --target native -- replay --help
```

Start a host:

```sh
moon run cmd/main --target native -- host \
  --port 7777 \
  --match-id local-match \
  --seed 42 \
  --replay-dir replays
```

Optional heartbeat parameters:

```sh
--heartbeat-timeout-ms 30000
--heartbeat-scan-ms 1000
```

Join as player A in a second terminal:

```sh
moon run cmd/main --target native -- join \
  --name Alice \
  --lang zh \
  --host ws://127.0.0.1:7777/match
```

Optional heartbeat parameter:

```sh
--heartbeat-interval-ms 5000
```

Join as player B in a third terminal:

```sh
moon run cmd/main --target native -- join \
  --name Bob \
  --lang zh \
  --host ws://127.0.0.1:7777/match
```

Useful supervisor commands in each player terminal:

```text
/ready
/prefer <text>
/ban <text>
/lock
/leave
/lang zh
/lang en
```

The match opens the first intervention window after both players send
`/ready`. `/prefer` and `/ban` add supervisor interventions. `/lock` closes the
current window, emits fake/minimal final plans, executes one minimal ruleset
step, and opens the next window. `/leave` ends the match and saves the replay. `/lang`
changes only the current client display language; it is not sent to the host and
does not alter replay data.

## Replay

Print the full event stream:

```sh
moon run cmd/main --target native -- replay \
  --file replays/local-match.json \
  --view A \
  --mode events
```

Print events grouped by input window:

```sh
moon run cmd/main --target native -- replay \
  --file replays/local-match.json \
  --view A \
  --mode windows
```

Print replay metadata:

```sh
moon run cmd/main --target native -- replay \
  --file replays/local-match.json \
  --mode metadata
```

## CI

GitHub Actions runs formatting, native checks, native tests, default tests, and
generated interface verification on pushes to `main` and on pull requests.

## License

This project is licensed under the [MIT License](./LICENSE).
