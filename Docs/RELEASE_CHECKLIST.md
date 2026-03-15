# RELEASE_CHECKLIST

## Pre-Release Gate

1. Target issues are `Done` in Linear and linked to commits.
2. Smoke tests from `GAMEPLAY_LOOP_TEST_PLAN.md` passed.
3. `TODO.md` and `GPT_JOURNAL.md` are updated.
4. `WORLD_CHANGELOG.md` includes all world-only changes.

## Publish Procedure

1. Open group-owned experience in Studio.
2. Create snapshot in Version History before publish.
3. Publish update from the group-owned experience only.
4. Record published version note and issue keys.

## Post-Release Verification

1. Launch play test after publish.
2. Validate core round flow and spawn/reset behavior.
3. Check logs for runtime errors.
4. Create immediate fix issue for any blocker.

## Rollback Procedure

1. Open Version History.
2. Select the snapshot created before release.
3. Roll back and publish rollback version.
4. Log rollback reason in Linear and `GPT_JOURNAL.md`.
