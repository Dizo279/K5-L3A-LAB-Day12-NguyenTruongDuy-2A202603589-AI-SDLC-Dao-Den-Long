# Phase 2 acceptance criteria by feature

Each criterion is written so that it can be checked from an input scenario,
JSONL trace, or graphical run.

## Gió Lạc (Nights 2 and 3)

- Spawn on simulation ticks 1200, 2400, … with deterministic IDs `D1`, `D2`, …; never have more than two active.
- Spawned entities begin `idle` and move at 2 m/s. They enter `chase` within 15 m only while Mây carries at least five motes; otherwise they return to `idle`.
- A chasing drifter that touches Mây at XZ distance ≤1.2 m steals up to three motes once, records the new carried count, then flees at 7 m/s for 240 ticks and disappears.
- A pulse hit on a chasing drifter sends it fleeing without theft. A pulse hit on a fleeing drifter carrying stolen motes creates the same number of dropped motes and removes the drifter after the specified delay.
- Drifters do not cause flame loss and ignore lantern safe zones and player invulnerability.

## Bùa Gió

- Nights 2 and 3 place charms at the ticket coordinates and use IDs `C1`, `C2`.
- Pickup follows the mote XZ and height tolerances, refreshes a 600 tick timer, sets running speed to 7.2 m/s, and permits repeated dash activation without dash cooldown.
- Charm dashes last 12 ticks at 14 m/s; pressing dash during a current dash does not queue another dash.
- An unavailable charm returns after 2700 simulation ticks. Snapshots show availability and remaining respawn time.

## Three-night flow and pause

- Main menu offers all three named nights. Choosing one opens its island introduction and Elder Dang's message before gameplay starts.
- A night win opens a result panel; Nights 1 and 2 can advance, a loss can replay the same night, and a Night 3 win shows the accumulated score.
- Esc and P pause. While paused, the graphical simulation stops; the headless trace increments outer tick only, keeps `sim_tick`, time, cooldown and spawn timers fixed, and emits `paused`/`resumed` on rising edges.
- The pause panel exposes resume, replay, settings and main-menu actions. Returning to menu resets the scene and displays the night selector.

## Settings and audio

- Master volume and mouse sensitivity can be saved and loaded from a local user settings file across application launches.
- A looping night soundtrack plays during gameplay. Pickup, lantern lighting, pulse, hit, jump, dash, win, loss, shade spawn and the final ten-second countdown each trigger an audible cue. Night 3 wind warning precedes the gust by two seconds and includes a cue.

## HUD, maps and presentation

- HUD shows remaining flames, centered `mm:ss`, lanterns lit/total, score, ten mote slots, dash/pulse cooldowns, nearby lantern interaction text and an offscreen marker for the nearest unlit lantern.
- At 30 seconds or less the clock is red and blinks. Night 3 displays a wind warning before each gust.
- Night 1 uses the 40 m circular island and the specified lantern, mote and shade points. Night 2 uses two 28 m islands, the 18 m bridge and two launch pads. Night 3 uses the 45 m base, elevated terrace/center, ramps, tower and launch pad.
- Listed palette colors stay within 10% per RGB channel. Environment intensity follows `0.15 + 0.55 × lit_lanterns / total_lanterns`.
- The graphical build averages at least 30 FPS at 1280×720; performance evidence records resolution, sample count, average and minimum.
