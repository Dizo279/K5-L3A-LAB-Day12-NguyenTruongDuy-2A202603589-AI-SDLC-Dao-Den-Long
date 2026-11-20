# Headless scenario checks

Run from repository root. Each output is raw JSONL from the contract runner;
do not hand-edit generated traces.

```powershell
python game\headless.py --seed 41 --night 1 --scenario tests\phase1_scenario.json --inputs tests\phase1_inputs.json --ticks 6 --out docs\phase-2\proof\phase1-regression-final.jsonl
python game\headless.py --seed 42 --night 2 --scenario tests\phase2_features_scenario.json --inputs tests\phase2_features_inputs.json --ticks 150 --snapshot-every 30 --out docs\phase-2\proof\features-final.jsonl
python game\headless.py --seed 45 --night 1 --scenario tests\phase2_pause.json --inputs tests\phase2_pause_inputs.json --ticks 15 --snapshot-every 1 --out docs\phase-2\proof\pause-final.jsonl
python game\headless.py --seed 46 --night 2 --scenario tests\phase2_drifter_drop.json --inputs tests\phase2_drifter_drop_inputs.json --ticks 3 --snapshot-every 1 --out docs\phase-2\proof\drifter-drop-final.jsonl
python game\headless.py --seed 46 --night 2 --scenario tests\phase2_drifter_scenario.json --ticks 2500 --snapshot-every 120 --out docs\phase-2\proof\drifter-final.jsonl
python game\headless.py --seed 47 --night 2 --scenario tests\phase2_charm.json --ticks 3000 --snapshot-every 300 --out docs\phase-2\proof\charm-final.jsonl
python game\headless.py --seed 47 --night 3 --scenario tests\phase2_night3_wind.json --ticks 2100 --snapshot-every 300 --out docs\phase-2\proof\night3-wind-final.jsonl
python game\headless.py --seed 48 --night 2 --scenario tests\phase2_night2_spawn.json --ticks 2500 --snapshot-every 300 --out docs\phase-2\proof\night2-spawn-final.jsonl
python game\headless.py --seed 50 --night 1 --scenario tests\phase2_shade_hit.json --ticks 4 --snapshot-every 1 --out docs\phase-2\proof\shade-hit-final.jsonl
python game\headless.py --seed 51 --night 1 --scenario tests\phase2_fall.json --ticks 65 --snapshot-every 10 --out docs\phase-2\proof\fall-final.jsonl
python game\headless.py --seed 54 --night 1 --scenario tests\phase2_jump.json --inputs tests\phase2_jump_inputs.json --ticks 60 --snapshot-every 10 --out docs\phase-2\proof\jump-final.jsonl
python game\headless.py --seed 55 --night 1 --scenario tests\phase2_interact.json --inputs tests\phase2_interact_inputs.json --ticks 3 --snapshot-every 1 --out docs\phase-2\proof\interact-final.jsonl
python game\headless.py --seed 56 --night 1 --scenario tests\phase2_pulse.json --inputs tests\phase2_features_inputs.json --ticks 2 --snapshot-every 1 --out docs\phase-2\proof\pulse-final.jsonl
python game\headless.py --seed 57 --night 1 --scenario tests\phase2_mote_spawn.json --ticks 240 --snapshot-every 60 --out docs\phase-2\proof\mote-spawn-final.jsonl
python game\headless.py --seed 61 --night 2 --scenario tests\phase2_jump_pad_night2.json --ticks 100 --snapshot-every 10 --out docs\phase-2\proof\jump-pad-night2.jsonl
python game\headless.py --seed 62 --night 3 --scenario tests\phase2_jump_pad_night3.json --ticks 100 --snapshot-every 10 --out docs\phase-2\proof\jump-pad-night3.jsonl
python game\headless.py --seed 63 --night 1 --scenario tests\phase2_walkoff.json --inputs tests\phase2_walkoff_inputs.json --ticks 600 --snapshot-every 60 --out docs\phase-2\proof\walkoff-final.jsonl
python game\headless.py --seed 50 --night 2 --inputs tests\phase2_dash_inputs.json --ticks 30 --snapshot-every 5 --out docs\phase-2\proof\dash-final.jsonl
python game\headless.py --seed 52 --night 3 --scenario tests\fullnight_benchmark.json --ticks 21600 --snapshot-every 600 --out docs\phase-2\proof\full-night-21600.jsonl
```

Phase 1 smoke check:

```powershell
python game\headless.py --seed 7 --night 1 --scenario tests\phase1_scenario.json --inputs tests\phase1_inputs.json --ticks 3 --out docs\phase-1\proof\smoke.jsonl
```

The scenarios target individual contract events. They do not replace hidden
grader tests or a full graphical play-through.

## Automated Phase 2 checks

Run from the repository root. The Godot runtime check temporarily points the
project at its test scene and restores `game/project.godot` even on failure.

```powershell
python -m unittest tests/test_phase2_contract.py -v
python tests/run_godot_runtime_checks.py --godot "D:\Godot_v4.7.2-stable_win64.exe"
```

The checks cover timer boundaries, night-specific shade schedules, pause
freezing, drifter theft during invulnerability, score at dawn, lantern
selection, terrain height, winning bonus, and the Night 3 upper terrace mesh.
