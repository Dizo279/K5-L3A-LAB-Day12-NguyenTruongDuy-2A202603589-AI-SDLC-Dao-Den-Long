# AGENTS.md

## Project

- Game engine: Godot 4.x.
- Project root: `game/`.
- Main scene: `game/main.tscn`.
- Headless contract: `game.contract.json`, version 1.1.
- Phase 2 supports `--night 1`, `--night 2` and `--night 3`; preserve the fixed 60 tick simulation.
- Do not commit API keys, `.env` files or generated editor caches.

## Verification

Run the headless project check from the repository root:

```powershell
& "D:\Godot_v4.7.2-stable_win64.exe" --headless --path .\game --editor --quit
```

The command must exit with code `0`. Preserve the real output as evidence;
never edit test output to make it look successful.

## Workflow

1. Read the current phase requirements before changing code.
2. Write or update acceptance checks before implementing behavior.
3. Keep phase evidence under `docs/phase-N/`.
4. Record assumptions, AI usage and unresolved items honestly.
5. Run headless verification after each meaningful change.
6. Run the Phase 1 regression scenario after changing shared simulation rules.
7. Treat `game.contract.json` and the active phase ticket as numeric/behavioral source of truth; do not infer tuning from older proof files.
8. A new acceptance behavior needs a scenario and raw evidence before its checklist row is marked complete.
9. Preserve input edge state and tick/event/snapshot ordering when editing the headless runner; verify pause and replay scenarios explicitly.

