# Phase 2 Completion Plan

> **For agentic workers:** Inline execution is already authorized by the user. Work task by task and preserve the phase-2 contract.

**Goal:** Close every Phase 2 acceptance gap, collect fresh evidence, then move the published `phase-2` tag to the verified completion commit.

**Architecture:** `game/headless.py` remains the deterministic 60 Hz contract reference. The Godot scene must implement the same player, mote, shade, drifter, charm, lantern, pause, and night-flow behavior for normal play. Scenario assertions cover headless rules; GUI evidence covers visible and persistent behavior.

**Tech Stack:** Python 3 standard library, Godot 4.7/GDScript, PowerShell on the development machine.

**Spec:** `docs/phase-2/SPEC.md`, `docs/phase-2/VERIFICATION-PLAN.md`, Ticket-02 in conversation, and `game.contract.json` v1.1.

## Global Constraints

- Run gameplay at fixed 60 ticks per second; keep deterministic headless output and contract version 1.1.
- Preserve Phase 1 regression behavior under normalized tuning.
- Do not edit generated JSONL or performance output by hand.
- Keep `.godot/`, Python caches, credentials, and local settings out of Git.
- Keep the known incomplete acceptance items visible until their tests or GUI evidence pass.

## Review Focus

- Spawn timers must begin at the ticket's night-specific ticks, with deterministic IDs and no same-tick interaction.
- Mote, charm, hit, fall, and pause timers must count the event tick consistently.
- Shade and drifter contact must not double-hit or bypass safe-zone, invulnerability, or height rules.
- GUI result flow must award the normalized win bonus exactly once and preserve total score across nights.
- Settings must survive relaunch; gameplay controls and SFX must work in the actual project, not only be declared.

---

### Task 1: Headless contract regression suite

**Files:** Modify `tests/test_phase2_contract.py`, `game/headless.py`, and `tests/README.md`.

- [x] Add failing checks for full 60-tick fall respawn, 2700-tick charm respawn, and Night 2/3 shade spawn times.
- [x] Run the new checks and confirm they fail on early timer and spawn boundaries.
- [x] Correct counter timing and night-specific shade schedules; rerun until green.
- [x] Add assertions for pause freeze, Night 1 shade IDs/count, hit/drop/recoil, score and end-order, map/pad heights, invalid input exit code, and exact deterministic output.
- [x] Run all focused scenarios and Phase 1 regression.

### Task 2: Graphical gameplay parity

**Files:** Modify `game/main.gd` and `game/phase2_ui.gd`; add focused Godot verification scripts under `tests/` where useful.

- [x] Implement scheduled shade groups and Night 2/3 drifters with their contract states, hit/steal/drop behavior, safe zones, and spawn cues.
- [x] Implement dropped mote TTL, charm pickup/expiry/respawn, fall penalty/respawn, single-hit-per-tick, and invulnerability.
- [x] Match interaction selection, scoring, winning time/flame bonus, all-lit victory, dawn/no-flame loss, and environment brightness.
- [x] Make dash use facing when idle, keep altitude while airborne, and apply charm dash rules.
- [x] Render the Night 3 upper terrace only in z>0, fit ramps to the specified radius span, and make the tower a non-walkable radius-2 cylinder.
- [x] Verify each gameplay feature in a real Godot run and inspect debug output.

### Task 3: GUI flow, HUD, settings, and audio evidence

**Files:** Modify `game/phase2_ui.gd`, `game/main.gd`, `tests/README.md`, and `docs/phase-2/ACCEPTANCE.md`.

- [x] Exercise menu → intro → play → win/loss → next night/retry → Night 3 dawn, including pause → main menu.
- [x] Save non-default volume and sensitivity, restart the project, and prove both values reload.
- [x] Verify each required sound cue and Night 3's 2-second wind warning against the gust.
- [x] Verify HUD fields, warning blink, nearby interaction prompt, offscreen lantern marker, and timer.
- [x] Measure actual 1280×720 average and minimum FPS after the final graphical build.

### Task 4: Final evidence and phase tag

**Files:** Update `docs/phase-2/ACCEPTANCE.md`, `docs/phase-2/proof/`, and submission documentation.

- [x] Run the complete automated headless suite, Godot editor/import check, Phase 1 regression, and deterministic 21,600-tick benchmark.
- [x] Update each acceptance row only with fresh evidence; record remaining gaps rather than inferring success.
- [x] Review the full diff and ensure the worktree is clean after commit.
- [x] Move `phase-2` to the verified completion commit and push the commit/tag.
