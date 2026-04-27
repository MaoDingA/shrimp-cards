# MoonBit Project Agent Notes

This project keeps the official MoonBit agent skills in `.codex/skills/`.

All MoonBit code produced for this repository must comply with those official
MoonBit skill instructions. Do not write, refactor, or generate MoonBit code
that knowingly violates the local skills.

Before changing MoonBit code in this repository, read and follow:

- `.codex/skills/moonbit-agent-guide/SKILL.md` for MoonBit project layout, coding style, and validation workflow.
- `.codex/skills/moonbit-refactoring/SKILL.md` when refactoring MoonBit APIs, files, or packages.
- `.codex/skills/moonbit-c-binding/SKILL.md` when adding native C FFI or C stubs.
- `.codex/skills/moonbit-proof/SKILL.md` when working on proof-carrying or Why3-backed MoonBit code.

When a task is not directly MoonBit source code but affects MoonBit project
structure, package layout, build configuration, tests, generated interfaces, or
developer workflow, still apply `.codex/skills/moonbit-agent-guide/SKILL.md`.

Prefer MoonBit tooling for semantic checks and navigation:

- Run `moon check` after MoonBit edits.
- Run `moon test` for relevant tests.
- Run `moon fmt` before handoff.
- Run `moon info` when public APIs may have changed.
