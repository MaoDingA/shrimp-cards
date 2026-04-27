# MoonBit Project Agent Notes

This project keeps the official MoonBit agent skills in `.codex/skills/`.

Before changing MoonBit code in this repository, read and follow:

- `.codex/skills/moonbit-agent-guide/SKILL.md` for MoonBit project layout, coding style, and validation workflow.
- `.codex/skills/moonbit-refactoring/SKILL.md` when refactoring MoonBit APIs, files, or packages.
- `.codex/skills/moonbit-c-binding/SKILL.md` when adding native C FFI or C stubs.
- `.codex/skills/moonbit-proof/SKILL.md` when working on proof-carrying or Why3-backed MoonBit code.

Prefer MoonBit tooling for semantic checks and navigation:

- Run `moon check` after MoonBit edits.
- Run `moon test` for relevant tests.
- Run `moon fmt` before handoff.
- Run `moon info` when public APIs may have changed.
