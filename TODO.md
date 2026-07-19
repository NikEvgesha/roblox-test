# TODO - Heroic Survival

Last updated: `2026-07-19`

## Snapshot

- Health: `prototype-running`
- Current phase: `cube vertical slice verification`
- Active Experience GameId: `9947791898`
- Lobby Start Place: `81561302455824`
- Combat Place: `135533599453315`
- Rojo: `7.7.0`; Lobby `34872`; Combat `34873`

## Current Blockers

1. The ghost-enemy wave stall fix is published but still needs one full Wave 10 retest.
2. Developer Product receipts exist but need a controlled live purchase test.
3. Core runtime scripts are oversized; core reward/scaling/progression/ability calculations now have automated coverage.

## Next Queue

| Priority | Task | Owner | Exit Criteria |
|---|---|---|---|
| Done | Publish the ghost-enemy fix to Combat | You | Published owner load-test build includes the wave fix |
| P0 | Retest Wave 10 completion | You + Assistant | Boss and all mobs die, run resolves, players return to Lobby |
| P0 | Confirm Combat access | You | Maximum visitors `8`; `Secure within Universe only` |
| Done | Add pure logic test modules | Assistant | `GameRulesTests` passes 26 assertions in Combat Studio |
| Done | Centralize Developer Product receipts | Assistant | `ReceiptRouter` is the only owner of `MarketplaceService.ProcessReceipt` |
| P1 | Extract wave director services | Assistant | `zombies.server.lua` is split without behavior regression |
| P1 | Extract combat client controllers | Assistant | Input, weapons, spectator, and UI concerns are separated |
| P2 | Select retained enemy/weapon assets | You | Explicit keep/remove list for Combat hierarchy |
| P2 | Clean and profile Combat assets | Assistant | Unused pack content removed; scene metrics recorded |

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
- [ ] Verify selected profession/difficulty, Wave 10 rewards, and clean run completion.
