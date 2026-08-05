# AGENTS — Working agreement for AI assistants (OpenCode)

Read this file, plus `memory/project.md`, `docs/ArchitectureRules.md`, and
`docs/CodingStandards.md` at the start of every session.

## The loop (never skip)

1. Read project memory → architecture rules → the feature spec.
2. Create an implementation plan (this file) → get approval before implementing.
3. Implement one small task at a time.
4. Run analyzers and tests; fix failures.
5. Produce a completion report; update documentation; suggest the next task.

## Never do

- Invent architecture or rename unrelated files.
- Modify completed modules without a task.
- Leave TODOs in production code.
- Skip tests or documentation.
- Ignore warnings.
- Mix UI and business logic.
- Commit code without verification.

## Definition of Done

See `docs/ArchitectureRules.md`. Nothing is done until spec, implementation, tests,
documentation, migration, permissions, audit, API, offline, and sync are complete.
