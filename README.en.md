# Shrimp Cards

[简体中文](./README.md) | English

Shrimp Cards is a terminal-first MoonBit card-game foundation for PvE and PvP
experiments. The current code focuses on non-gameplay infrastructure: local
host/client communication, live intervention windows, replay recording, and
agent plan placeholders.

Gameplay rules are intentionally not defined yet.

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

## Run A Local Match

Start a host:

```sh
moon run cmd/main --target native -- host \
  --port 7777 \
  --match-id local-match \
  --seed 42 \
  --replay-dir replays
```

Join as player A in a second terminal:

```sh
moon run cmd/main --target native -- join \
  --name Alice \
  --lang zh \
  --host ws://127.0.0.1:7777/match
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
current window, emits final placeholder plans, executes a placeholder step, and
opens the next window. `/leave` ends the match and saves the replay. `/lang`
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
