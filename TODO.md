# TODO (RobloxProject)

Last updated: `2026-03-15`

## Snapshot

- Health: `green`
- Current phase: `foundation + vertical slice backlog ready`
- Top blocker: `complete onboarding on all 3 machines (IGR-5)`

## Linear Sync (Roblox Test MVP)

Project URL:
- `https://linear.app/igrodelnya/project/roblox-test-mvp-bb15e8b25790`

Current top queue:

| Issue | Status | Priority | Milestone | Deliverable |
|---|---|---|---|---|
| `IGR-5` | `Todo` | `High` | `Foundation Setup` | Rojo onboarding for all 3 devs |
| `IGR-6` | `Todo` | `Medium` | `Foundation Setup` | Branch/merge convention adopted |
| `IGR-7` | `Todo` | `High` | `Core Loop Vertical Slice` | Gameplay loop spec v1 |
| `IGR-8` | `Todo` | `High` | `Core Loop Vertical Slice` | Server round state machine skeleton |
| `IGR-9` | `Todo` | `High` | `Core Loop Vertical Slice` | Client HUD for round state |

## Daily Cycle (Required)

1. Pick top `Todo` issue in Linear.
2. Move issue to `In Progress`.
3. Implement one concrete deliverable (up to one day).
4. Verify in Studio Play Test.
5. Update `TODO.md` + `GPT_JOURNAL.md` + `WORLD_CHANGELOG.md` (if world changed).
6. Add commit hash and verification note to issue comment.
7. Move issue to `In Review` or `Done` the same day.

## Quality Gate (Per Task)

- [ ] Verifiable Studio result exists.
- [ ] Code is in Git and linked by commit hash.
- [ ] Docs were updated when behavior/process changed.
- [ ] Linear issue closed with verification note.

## Release Gate

- [ ] Version History snapshot created before publish.
- [ ] Publish performed from group-owned experience.
- [ ] Post-release smoke test passed.

## Team Conflict Rules

- [ ] No cross-zone changes without issue + agreement.
- [ ] Large scene edits are done in scheduled time windows.
