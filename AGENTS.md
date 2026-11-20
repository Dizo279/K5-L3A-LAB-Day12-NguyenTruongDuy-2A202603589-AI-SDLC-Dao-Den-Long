# AGENTS.md

## Project

- Game engine: Godot 4.x.
- Project root: `game/`.
- Main scene: `game/main.tscn`.
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

