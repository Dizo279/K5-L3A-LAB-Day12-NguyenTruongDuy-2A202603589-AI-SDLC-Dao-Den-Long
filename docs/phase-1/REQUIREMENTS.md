# Phase 1 — PRD-0 summary

The first playable night is **Đêm 1 — Đảo Bến**. The player controls Mây in
a small 3D island scene, collects motes, deposits them into five lanterns,
avoids or repels shades, and reaches a win or loss state with a score.

The automatic interface is `game.contract.json` plus `game/headless.py`:

- fixed 60 ticks per second;
- deterministic output for the same seed, scenario and inputs;
- JSONL snapshots, events and a final `end` record;
- invalid input returns a non-zero error, with malformed input reserved for code 2.

Open assumptions are recorded in `ASSUMPTIONS.md`. This document is a short
traceability note, not a replacement for the original PRD-0 supplied by the
instructor.

