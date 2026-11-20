# Tests

Phase 1 smoke scenario:

```powershell
python game\headless.py --seed 7 --night 1 --scenario tests\phase1_scenario.json --inputs tests\phase1_inputs.json --ticks 3 --out docs\phase-1\proof\smoke.jsonl
```

The output must be valid JSONL and end with an `end` object. The fixture is
intentionally small and is evidence for the contract plumbing, not a claim
that all gameplay requirements are complete.

