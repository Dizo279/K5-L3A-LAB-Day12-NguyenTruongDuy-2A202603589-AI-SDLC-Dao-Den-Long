# CP1 decisions — PRD-0 assumptions

These decisions resolve details that PRD-0 leaves open. Ticket-02 may override
the corresponding tuning and behaviors for later nights.

| Topic | Decision | Contract value / behavior |
|---|---|---|
| Firefly pickup | Automatic, measured horizontally in XZ; at capacity, leave mote in place | `pickup_radius = 1.2`, `carry_capacity = 10`; pickup emits `mote_picked` with resulting carried count |
| Lantern deposit | Interact within range; transfer only what fits, retain remainder | `interact_radius = 2.0`; amount is `min(carried, lantern_cost - deposited)` |
| Pulse | Cost comes from carried motes; insufficient motes means no activation/event | `pulse_cost = 3`; successful activation emits `pulse` with `stunned_ids` |
| Hit drops | Drop `floor(carried × hit_drop_ratio)`; carried decreases by exactly that amount; dropped motes return to ground | `hit_drop_ratio = 0.5`; `motes_active` includes dropped motes |
| Tick/output order | Events in step k use tick k+1, precede that tick's snapshot; game_over is an event; end is always final | Win bonuses are applied before final score output |
| Win score | Award remaining-time and remaining-flame bonuses on win only | `score.per_second_left = 2`; `score.per_flame_left = 50` |
| Safe zones | Lit lanterns only; shades inside when lit are moved to the boundary, and cannot enter afterward | `safe_radius = 6.0` |

These assumptions are also summarized in the README's gameplay notes. The
contract file is the source of truth for numeric tuning.

## Ticket-02 clarifications

- A naturally spawned Shade remains `spawning` for 60 ticks, cannot hit during
  that period, then changes to `wander`. Scenario-provided Shades start as
  `wander` immediately.
- Night 2 starts at `(0, 0, 0)`; Night 3 starts at `(0, 0, -15)`. Both face +Z.
- Snapshot `player.invuln` is boolean. Scenario `player.invuln_ticks` carries
  the remaining duration.
- `night_start` is emitted on tick 1; tick 0 remains the pre-input scenario
  snapshot.
