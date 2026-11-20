---
name: phase2-godot-contract
description: Verify and update the Godot Phase 2 three-night game and its v1.1 deterministic headless contract. Use when changing simulation rules, maps, pause/settings/audio/HUD, contract scenarios, or submission evidence in this repository.
---

# Phase 2 Godot workflow

## Before editing

1. Read `docs/phase-2/SPEC.md`, `game.contract.json`, and the relevant code in `game/headless.py`, `game/main.gd`, or `game/phase2_ui.gd`.
2. Add or update a focused fixture in `tests/` and record its expected observable result before changing behavior.
3. Keep the simulation fixed at 60 ticks per second. Preserve the ticket's tick order, edge-triggered inputs, deterministic IDs, and output schema.

## Verify changes

1. From the repository root, run `python -m py_compile game/headless.py` and Godot's headless editor check from `AGENTS.md`.
2. Run the focused scenario command and the Phase 1 regression command from `tests/README.md`.
3. For a submission check, run the full-night fixture at 21,600 ticks twice and compare the raw output hashes; record elapsed time and preserve unedited JSONL.
4. For graphical changes, launch the project, inspect the relevant UI state, check debug output, and record the actual 1280×720 FPS measurement when performance claims are affected.

## Evidence and reporting

- Store raw outputs and screenshots under `docs/phase-2/proof/`.
- Do not edit generated output to make it appear successful. A passing import check does not prove gameplay behavior.
- Update `docs/phase-2/ACCEPTANCE.md` with evidence and mark uncovered requirements as partial.
- Never claim the phase is complete while a required criterion is partial or lacks evidence.
- Keep generated `.godot/`, Python caches, credentials, and user settings out of Git.
