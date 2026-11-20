# Phase 2 verification plan

Run each scenario with the documented command and retain raw JSONL output.

| Area | Scenario and assertion |
|---|---|
| Phase 1 regression | CP1 pickup/deposit/pulse/hit/win scenarios retain behavior allowed by v1.1 |
| Movement | Move direction/yaw, jump, dash duration/cooldown and airborne dash altitude |
| Interactions | Capacity, pickup height, nearest lantern tie-break, partial deposits, pulse cost/radius/retrigger |
| Shades | Spawn state 60 ticks, chase range, safe-zone displacement, hit/invulnerability, dropped mote TTL, fall/respawn |
| Maps/spawns | Exact starts, lantern and mote locations; scheduled mote/shade counts and IDs for all three nights |
| Drifters | Scheduled spawn, idle/chase thresholds, steal amount, flee expiry, pulse release/drop |
| Charms/wind | Pickup/refresh/expiry/respawn, speed and dash cooldown effect; Night 3 warning/wind intervals |
| Pause | Tick advances while sim_tick/time/cooldowns/spawns/TTL freeze; resume event and input edge behavior |
| Output | Schema, event-before-snapshot order, exact end record, deterministic hash on repeated runs |
| Performance | Full 21,600-tick run under 30 seconds; graphical build averages at least 30 FPS at 1280x720 |

Do not mark an acceptance row complete without a matching scenario output or
runtime measurement. Phase 1 regression is rerun after shared simulation edits.
