# Start Prompt - Heroic Survival

Read before implementation:

1. `AGENTS.md`
2. `Docs/GPT_PROJECT_CONTEXT.md`
3. `Docs/GDD_V2.md`
4. `Docs/CUBE_PROTOTYPE_PLAN.md`
5. `Docs/ABILITY_SYSTEM_SPEC.md`
6. `Docs/MVP_TASK_BOARD.md`
7. `TODO.md`

Session start:

1. Run `powershell -ExecutionPolicy Bypass -File scripts/start-dev.ps1`.
2. List Roblox Studio instances through MCP and identify them by PlaceId/GameId.
3. Pick the highest-priority open item from `TODO.md`.
4. Implement Rojo-managed code in `src`.
5. Build both mappings when shared code or config changes.
6. Smoke-test the affected Place and inspect Output.
7. Update the task board and relevant docs.
8. Commit and push only verified changes.
