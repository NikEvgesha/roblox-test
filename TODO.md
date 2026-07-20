# TODO - Heroic Survival

Last updated: `2026-07-20`

## Snapshot

- Health: `prototype-running`
- Current phase: `cube vertical slice verification`
- Active Experience GameId: `9947791898`
- Lobby Start Place: `81561302455824`
- Combat Place: `135533599453315`
- Rojo: `7.7.0`; Lobby `34872`; Combat `34873`

## Current Blockers

1. Developer Product receipts exist but need a controlled live purchase test.

## Next Queue

| Priority | Task | Owner | Exit Criteria |
|---|---|---|---|
| Done | Publish the ghost-enemy fix to Combat | You | Published owner load-test build includes the wave fix |
| Done | Verify published Wave 10 victory return | You + Assistant | Owner confirmed the published victory flow returns players to Lobby |
| P0 | Confirm Combat access | You | Maximum visitors `8`; `Secure within Universe only` |
| Done | Add pure logic test modules | Assistant | Combat Studio passes 400 assertions across fifteen server/client suites |
| Done | Centralize Developer Product receipts | Assistant | `ReceiptRouter` is the only owner of `MarketplaceService.ProcessReceipt` |
| Done | Extract wave director services | Assistant | `WaveDirector` owns wave selection, budgets, caps, cadence, and variant weights; Play Mode baseline verified |
| Done | Extract enemy runtime service | Assistant | Registry, lifecycle, targeting, spawn-point selection, and ghost cleanup are isolated and Play Mode verified |
| Done | Extract enemy factory | Assistant | Template/fallback creation, animation loading, health UI, and death callbacks are isolated and Play Mode verified |
| Done | Extract revive runtime service | Assistant | Death, markers, free timers, wipe window, teammate/solo/team grants, and character wiring are isolated |
| Done | Extract combat client controllers | Assistant | 173-line entrypoint wires dedicated input, aim, weapon, animation, HUD, feedback, and spectator controllers |
| Done | Evaluate enemy animation examples | Shared | Owner accepted the client-side procedural direction for continued work |
| Done | Review expanded enemy roster | You | Owner accepted the 20 new mobs and four bosses for continued use |
| Done | Configure 50-wave density curve | Assistant | Medium solo scales 100 -> 500 mobs, cap stays at 500, and all four bosses spawn on Wave 50 |
| Done | Remove legacy enemy assets | Assistant | Old Toolbox/examples removed; retained templates live under server-only storage and only the new roster enters waves |
| P1 | Publish Combat balance and enemy cleanup | You | Publish Combat after reviewing the radius-150 spawn points and hidden 24-template server library |
| Done | Establish mob performance baseline | Shared | Owner reports stable play at `500` active mobs; higher counts are optional stress territory |
| P2 | Select retained weapon assets | You | Explicit keep/remove list for the remaining Combat weapon hierarchy |
| P2 | Clean and profile remaining Combat assets | Assistant | Unused non-enemy pack content removed; scene metrics recorded |

## Ownership

| Area | Owner |
|---|---|
| Gameplay and infrastructure code | Assistant |
| Draft UI | Assistant |
| Final visual direction and asset selection | You |
| Final map object placement | You |
| Final UI art pass | You |
| Balance and feel | Shared |

## Quality Gate

- [ ] Both Rojo builds pass.
- [ ] Lobby and Combat boot without runtime errors.
- [ ] Changed behavior has a manual or automated verification note.
- [ ] Active docs match code and current Place IDs.
- [ ] Git worktree contains no accidental Studio-generated files.

## Release Gate

- [ ] Save a Version History snapshot before publishing.
- [ ] Publish Lobby and Combat from the group-owned Experience.
- [x] Launch from the Roblox client through the Lobby Start Place.
- [x] Verify the Lobby to Combat to Lobby route.
- [x] Verify selected profession/difficulty, Wave 10 rewards, and clean run completion.
