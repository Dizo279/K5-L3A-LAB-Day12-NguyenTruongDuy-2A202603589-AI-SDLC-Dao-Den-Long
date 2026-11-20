# Phase 1 assumptions compared with Ticket-02

Ticket-02's Part 1 tuning and Test Contract v1.1 supersede the corresponding
Phase 1 choices. The following CP1 assumptions remain useful only where the
ticket does not replace them.

| CP1 assumption | Ticket-02 decision | Phase 2 treatment |
|---|---|---|
| Auto pickup, capacity 10 | Explicitly standardized: auto pickup at XZ <= 1.0 m, capacity 10, height delta <= 1.5 m | Replace CP1 pickup radius 1.2 with 1.0 and check vertical delta |
| Deposit what fits and retain remainder | Explicit: 10 motes per lantern, multiple deposits, nearest eligible lantern, id tie-break | Keep transfer rule; implement nearest/id selection |
| Pulse costs carried motes | Explicit: cost 3, radius 5 m, 3 s cooldown, stun/push details | Keep resource source; replace CP1 timing/score assumptions with ticket values |
| Hit drops floor(carried/2) | Explicit same rule, dropped motes live 480 ticks and can be picked from next tick | Keep rounding; add TTL and delayed pickup |
| Lit lanterns make safe zones | Explicit radius 6 m and displacement over at most 30 ticks | Keep lit-only rule; implement transition and movement constraint |
| CP1 score bonus | Ticket standardizes per-mote deposit, lantern, stun, win-time and flame values | Replace all prior tuning with v1.1 values |
| Fixed 5-lantern circular island | Replaced by three standardized maps and night-specific starts | Keep CP1 as Night 1 regression only |

Additional clarified details: spawn animation lasts 60 ticks; scenario shades
start wandering; Night 2 starts at origin; Night 3 starts at (0,0,-15);
`player.invuln` is boolean; `night_start` occurs at tick 1.
