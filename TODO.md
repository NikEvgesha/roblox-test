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

1. Published `Lobby -> Combat` teleport has not been verified in the Roblox client.
2. A full 10-wave run through boss, crystals, victory, and return to Lobby has not been recorded.
3. Developer Product receipts exist but need a controlled live purchase test.
4. Core runtime scripts are oversized and have no automated test coverage.

## Next Queue

| Priority | Task | Owner | Exit Criteria |
|---|---|---|---|
| P0 | Publish Lobby and Combat | You | Both cloud places contain the latest Rojo-synced code |
| P0 | Configure Combat access | You | Maximum visitors `8`; `Secure within Universe only` |
| P0 | Test Lobby to Combat teleport | You + Assistant | Solo party reaches reserved Combat server with selected profession/difficulty |
| P0 | Run 10-wave vertical slice | Assistant | Wave 10 boss dies, crystals persist, players return to Lobby |
| P1 | Add pure logic test modules | Assistant | Reward, scaling, progression, and ability rules run without a full match |
| P1 | Centralize Developer Product receipts | Assistant | One receipt router owns `MarketplaceService.ProcessReceipt` |
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
- [ ] Launch from the Roblox client through the Lobby Start Place.
- [ ] Verify teleport, selected profession/difficulty, rewards, and return flow.
