# Phase 2 acceptance status

Detailed feature criteria are in `SPEC.md`. The table tracks Ticket-02 requirements against current code and checked-in
evidence.

| Area | Acceptance criterion | Status / evidence |
|---|---|---|
| Contract v1.1 | Standardized tuning, CLI validation, deterministic output schema | Complete; `game.contract.json` v1.1, input validation, deterministic output schema verified by `tests/test_phase2_contract.py` (12/12 passing) |
| Standard simulation | Exact tick order, movement, hits, drops, safe zones, scoring and all night schedules | Complete; verified in unit suite and `tests/run_godot_runtime_checks.py` (26/26 runtime assertions passing) |
| Dash and jump | Standard speed, duration, cooldown, edge activation and jump physics | Complete; headless traces `proof/dash-final.jsonl`, `proof/jump-final.jsonl`; graphical controls wired and verified in runtime suite |
| Three night maps | Specified geometry, layers, bridge, jump pads, wind and spawn locations | Complete; headless launch traces `proof/jump-pad-night2.jsonl`, `proof/jump-pad-night3.jsonl`; Night 3 upper terrace verified half-ring (`z > 0`) in runtime checks |
| Drifters | Spawn, chase, steal once, flee, pulse escape/drop and removal | Complete; theft/drop traces `proof/drifter-final.jsonl`, `proof/drifter-drop-final.jsonl`; pulse drop and 120-tick removal verified in `tests/run_godot_runtime_checks.py` |
| Charms | Pickup, speed/dash effect, duration and respawn | Complete; pickup/respawn trace `proof/charm-final.jsonl`; 600-tick buff and 2700-tick respawn verified in headless and runtime checks |
| Pause simulation | Pause toggles on rising edge, sim time freezes, resume event occurs | Complete; checked in `proof/pause-final.jsonl` and contract unit tests |
| Pause UI | Resume, restart, settings, and main-menu actions are present | Complete; implemented in `game/phase2_ui.gd` and exercised in `tests/run_godot_runtime_checks.py` |
| Night flow | Menu → island intro → play → result; win advances, loss retries, Night 3 shows total | Complete; all transitions, Elder Dang intro, replay, and dawn total-score verified in `tests/run_godot_runtime_checks.py` |
| Settings | Volume and sensitivity persist between launches | Complete; verified ConfigFile persistence, AudioServer volume reload, and mouse sensitivity camera yaw in `tests/run_godot_runtime_checks.py` |
| Audio | Music plus pickup, light, pulse, hit, jump, dash, result, shade and wind cues | Complete; procedural audio stream generator `_tone` and gameplay/result SFX verified in `tests/run_godot_runtime_checks.py` |
| HUD | Flames, timer warning, lantern count, score, 10 mote slots, prompt and offscreen marker | Complete; verified in `game/phase2_ui.gd` and runtime assertion suite |
| Regression | Phase 1 behavior remains valid with normalized tuning | Complete; verified in `proof/phase1-regression-final.jsonl` and `docs/phase-1/proof/smoke.jsonl` |
| Distinct scenarios | One scenario per new behavior | Complete; 18 focused scenarios and input fixtures in `tests/`; matching raw traces under `docs/phase-2/proof/` |
| Performance | At least 30 average FPS at 1280×720 | Complete; measured 180.00 average, 180.00 minimum over 1,800 frames; `proof/fps-1280x720.txt` |
| Full-night runtime | 21,600 ticks complete in at most 30 seconds, deterministic for matching inputs | Complete; ~0.26 s runtime; matching SHA-256 (`AF2E66ED8794E159993793765631CCD06EE6CC16FA1EF09B42EE6755145F8C4C`) on repeat; `proof/full-night-21600.jsonl` |

All acceptance criteria are satisfied with verified raw traces and automated test proofs.
