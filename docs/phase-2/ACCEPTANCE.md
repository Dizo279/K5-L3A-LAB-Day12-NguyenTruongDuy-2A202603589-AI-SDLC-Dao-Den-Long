# Phase 2 acceptance status

Detailed feature criteria are in `SPEC.md`. The table tracks Ticket-02 requirements against current code and checked-in
evidence. “Partial” means the available implementation or proof does not yet
cover the complete acceptance condition.

| Area | Acceptance criterion | Status / evidence |
|---|---|---|
| Contract v1.1 | Standardized tuning, CLI validation, deterministic output schema | Partial; `game.contract.json` and JSONL runner are present, full contract audit remains |
| Standard simulation | Exact tick order, movement, hits, drops, safe zones, scoring and all night schedules | Partial; scenario traces exist, several physics/map details remain approximate |
| Dash and jump | Standard speed, duration, cooldown, edge activation and jump physics | Headless scenarios exist; graphical controls wired, exact in-game parity pending |
| Three night maps | Specified geometry, layers, bridge, jump pads, wind and spawn locations | Partial; headless launch traces: `proof/jump-pad-night2.jsonl`, `proof/jump-pad-night3.jsonl`; graphical Night 3 terrace is full ring and some collision edges remain simplified |
| Drifters | Spawn, chase, steal once, flee, pulse escape/drop and removal | Theft/drop traces: `proof/drifter-final.jsonl`, `proof/drifter-drop-final.jsonl`; complete lifecycle still needs auditing |
| Charms | Pickup, speed/dash effect, duration and respawn | Pickup/respawn trace: `proof/charm-final.jsonl`; speed and dash edge cases remain |
| Pause simulation | Pause toggles on rising edge, sim time freezes, resume event occurs | Checked in `proof/pause-final.jsonl` |
| Pause UI | Resume, restart, settings, and main-menu actions are present | Implemented in `game/phase2_ui.gd`; each button still needs interactive GUI exercise |
| Night flow | Menu → island intro → play → result; win advances, loss retries, Night 3 shows total | Flow is implemented and reloads the selected night; full play-through/manual button proof pending |
| Settings | Volume and sensitivity persist between launches | Config save/load implemented; persistence has not been independently exercised through GUI |
| Audio | Music plus pickup, light, pulse, hit, jump, dash, result, shade and wind cues | Procedural music and gameplay/result/wind cues are wired; shade-spawn cue and cue-by-cue GUI proof pending |
| HUD | Flames, timer warning, lantern count, score, 10 mote slots, prompt and offscreen marker | Implemented in code; menu and HUD controls still need interactive capture |
| Regression | Phase 1 behavior remains valid with normalized tuning | Smoke trace: `proof/phase1-regression-final.jsonl`; hidden tests unavailable |
| Distinct scenarios | One scenario per new behavior | Dash, pause, charm, drifter theft/drop, shade hit, fall, Night 2 spawn and Night 3 wind fixtures are in `tests/`; traces under `proof/` |
| Performance | At least 30 average FPS at 1280?720 | Measured 179.96 average, 167.00 minimum over 1,800 samples on RTX 3050; `proof/fps-1280x720.txt` |
| Full-night runtime | 21,600 ticks complete in at most 30 seconds, deterministic for matching inputs | 0.27 s; matching SHA-256 on repeat; `proof/full-night-21600.jsonl` |

Phase 2 is not complete while any required row remains partial or lacks its
interactive evidence.
