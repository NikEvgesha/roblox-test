# GAMEPLAY_LOOP_SYSTEM_SPEC

## Goal

Define the first playable gameplay loop contract for MVP.

Loop:
1. Spawn players.
2. Start objective round.
3. Resolve success/fail.
4. Grant reward.
5. Reset and repeat.

## Scope (v1)

- Single round type.
- Shared objective for all active players.
- Server-authoritative state transitions.
- Basic reward payout at round end.
- Hard reset after round resolution.

## State Machine

| State | Owner | Entry Condition | Exit Condition | Timeout |
|---|---|---|---|---|
| `Lobby` | Server | Server start or reset complete | Min players reached and start requested | none |
| `RoundStarting` | Server | Round initialization begins | Countdown finished | 10s |
| `RoundActive` | Server | Countdown complete | Objective success or fail condition | 300s |
| `RoundResult` | Server | Success/fail resolved | Rewards distributed and summary sent | 8s |
| `RoundReset` | Server | Result finished | World/player reset complete | 5s |

Invalid transitions are rejected and logged on server.

## Data Contract

- Shared module: `src/shared/Shared.lua`
- Required event channel groups:
  - `RoundStateChanged`
  - `RoundTimerUpdated`
  - `RoundResultPublished`
- Payloads must be schema-validated on server before broadcast/processing.

## Reward Rules (v1)

- Success: base reward to all active participants.
- Fail: no reward.
- Disconnect mid-round: no reward.
- Reward grant happens only in `RoundResult`.

## Failure Modes

| Failure | Handling |
|---|---|
| Invalid state transition | Reject transition, log warning, keep previous state |
| Round timeout | Mark fail and go to `RoundResult` |
| Reward grant error | Retry once, then log and continue reset |
| Missing player character at spawn | Retry spawn up to 3 attempts |

## Out of Scope (v1)

- Multi-objective rounds.
- Ranked/competitive modes.
- Matchmaking.
- Long-term economy balancing.
