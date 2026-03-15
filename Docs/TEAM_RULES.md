# TEAM_RULES

## Ownership and Conflict Policy

Default zones:
- Dev A: `server`
- Dev B: `client/ui`
- Dev C: `world/content`

Rules:
1. Do not edit another zone without issue + explicit agreement in Linear comments.
2. Emergency hotfixes are allowed only for `P0` and must be documented after merge.

## One-Issue Rule

1. One issue = one concrete deliverable.
2. Target size: up to one workday.
3. If task exceeds one day, split into child issues before implementation.

## Scene Change Windows

Large world edits (terrain, major map layout, spawn topology) must be done in agreed windows only.

Recommended process:
1. Reserve time window in team chat.
2. Reference the active issue key.
3. Finish with entry in `Docs/WORLD_CHANGELOG.md`.

## Daily Cycle

1. Pick top `Todo` issue in Linear.
2. Move issue to `In Progress`.
3. Implement changes in code/world.
4. Verify in Studio play test.
5. Update `TODO.md` + `GPT_JOURNAL.md` + `WORLD_CHANGELOG.md` (if world changed).
6. Move issue to `In Review`/`Done` in same day.
