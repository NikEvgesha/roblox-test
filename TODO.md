# TODO (RobloxProject)

Last updated: `2026-03-27`

## Snapshot

- Health: `planning-locked`
- Current phase: `MVP documentation locked + sprint 1 shaping`
- Top blocker: `class kit details still open`

## Documentation Baseline (Current)

- `Docs/GDD_MVP.md`
- `Docs/CLASS_ABILITY_SHEET_V1.md`
- `Docs/GAMEPLAY_LOOP_SYSTEM_SPEC.md`
- `Docs/GAMEPLAY_LOOP_SYSTEM_SETUP.md`
- `Docs/GAMEPLAY_LOOP_TEST_PLAN.md`
- `Docs/MVP_TASK_BOARD.md`
- `Docs/OPEN_QUESTIONS.md`

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

## Local MVP Queue (Pre-Linear sync)

| Task ID | Status | Owner | Deliverable |
|---|---|---|---|
| `A-2` | `Done` | `Assistant` | Match start policy locked (solo allowed, fixed-wave mode, wave target baseline 100) |
| `B-4` | `Done` | `Shared` | Wave target baseline locked to 100 (tunable upward) |
| `C-2` | `Done` | `Assistant` | Ability sheet v1 with level points + ULT gating + rank cap policy |
| `R-1` | `Done` | `Shared` | Death flow locked (no penalty, free timer 10s +10s/death, paid solo/team revive) |
| `B-2` | `Backlog` | `Assistant` | First stable wave loop in server runtime |
| `A-5` | `Backlog` | `Assistant` | Queue-pad host flow (join limits + start logic) |
| `B-5` | `Backlog` | `Assistant` | Player-count scaling + difficulty modifiers |
| `D-2` | `Backlog` | `Assistant` | Shop flow between waves (with draft UI) |
| `D-5` | `Backlog` | `Assistant` | Persistent boss crystals + lobby upgrade spend |
| `D-6` | `Backlog` | `Assistant` | Paid revive flow (Solo 10R$ / Team 50R$ on wipe) |
| `D-7` | `Backlog` | `Assistant` | Shared kill rewards with group bonus split |
| `D-8` | `Backlog` | `Assistant` | Character unlocks via crystal shop + achievements |
| `C-5` | `Backlog` | `Assistant` | Universal infinite stat node (`Endless Mastery`) |
| `E-5` | `Backlog` | `Assistant` | Spectate/free-fly flow while dead |
| `E-3` | `Backlog` | `You` | Final UI visual pass |

## Sprint 1 Draft (5 Tasks)

| Sprint Task | Owner | Status | Exit Criteria |
|---|---|---|---|
| `S1-1` Implement teleport Lobby -> Combat (`A-3`) | Assistant | Backlog | Party reliably reaches combat place |
| `S1-2` Implement wave loop core (`B-2`) | Assistant | Backlog | 3+ wave cycle stable in Play Test |
| `S1-3` Implement boss interval logic (`B-3`) | Assistant | Backlog | Boss spawns every 10th wave |
| `S1-4` Place lobby/combat visual pass v0 (`A-4` + map prep) | You | Backlog | Functional visual landmarks and play space |
| `S1-5` Build draft HUD for waves/shop (`E-2`) | Assistant | Backlog | Playable temporary HUD for loop validation |

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
