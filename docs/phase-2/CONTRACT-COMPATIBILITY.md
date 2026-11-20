# Contract version and portability

Ticket-02 explicitly upgrades the root contract to version `1.1`. The root
file retains every v1.0 tuning key and adds the five required v1.1 tuning
keys. Do not downgrade the version: automated Phase 2 checks expect `1.1`.

Commands use `python3` and the `godot` executable on PATH, so the same values
work on macOS/Linux after Python 3 and Godot 4 are installed. On Windows, use
the equivalent `python` command or the local Godot executable path.

- Build: `python3 -m py_compile game/headless.py`
- Run: `godot --path game`
- Headless: `python3 game/headless.py`

The caller appends the documented flags to the headless command. Required
flags are `--night`, `--ticks`, and `--out`; optional flags include seed,
scenario, inputs, and snapshot interval.
