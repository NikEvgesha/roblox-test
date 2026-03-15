# Linear Workflow

## Required Fields

- Issue key (for example `IGR-101`) must be referenced in:
  - branch name,
  - commit messages,
  - world changelog entry (if world changed).

## Status Flow

1. `Backlog`
2. `Todo`
3. `In Progress`
4. `In Review`
5. `Done`

## Recommended Labels

- `server`
- `client`
- `shared`
- `world`
- `ui`
- `bug`
- `tech-debt`

## Definition of Done

1. Linked code changes merged.
2. Studio behavior verified.
3. `WORLD_CHANGELOG.md` updated for world-only changes.
4. `TODO.md` and `GPT_JOURNAL.md` updated in same day.
5. Issue comment includes commit hash and short verification result.
6. Issue moved to `Done`.

## Scope Rule

1. One issue = one concrete deliverable.
2. Target duration: up to one workday.
3. Split larger work into multiple issues before moving to `In Progress`.
