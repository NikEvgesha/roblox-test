# GAMEPLAY_LOOP_TEST_PLAN

## Test Goal

Validate first gameplay loop behavior and guard against regressions after each merged task.

## Smoke Tests (run for every task)

| ID | Check | Steps | Expected |
|---|---|---|---|
| SMK-1 | Server start | Press Play | Server log appears, no runtime errors |
| SMK-2 | Client start | Press Play | Client log appears, no runtime errors |
| SMK-3 | Round flow | Trigger one full round cycle | States progress in correct order |
| SMK-4 | Result phase | Complete or fail objective | Correct round result is shown |
| SMK-5 | Reset | Wait for reset phase | Players/world return to start state |

## Regression Matrix

| Area | Risk | Check |
|---|---|---|
| State machine | Invalid transitions | Confirm rejection/logging path works |
| Networking | Bad payloads | Send malformed payload and verify rejection |
| Rewards | Duplicate grants | Ensure reward is issued once per round |
| Reset | Stuck state | Ensure timeout fallback returns to `Lobby` |

## Execution Policy

- Run smoke tests before moving issue to `In Review`.
- Attach test result summary in issue comment.
- Link commit hash used for test.

## Pass/Fail Criteria

- Pass: all smoke tests pass and no critical errors in Output.
- Fail: any smoke test fails or runtime error blocks round completion.

## Reporting

When failed:
1. Create/attach bug issue in Linear.
2. Include reproduction steps and expected vs actual.
3. Include screenshot/log excerpt and tested commit hash.
