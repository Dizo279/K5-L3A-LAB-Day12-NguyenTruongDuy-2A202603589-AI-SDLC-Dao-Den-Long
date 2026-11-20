import unittest
import json
import math
from game.headless import Sim, T

class Phase3ContractTests(unittest.TestCase):
    def test_fuel_decay_and_lantern_out(self):
        # Lantern L1 starts lit with fuel = 1.0 (60 ticks)
        scenario = {
            "time_left_s": 240,
            "random_motes": False,
            "random_shades": False,
            "random_drifters": False,
            "lanterns": [{"id": "L1", "lit": True, "fuel": 1.0}]
        }
        sim = Sim(seed=1, scenario=scenario, night=1)
        # Advance 59 ticks
        for _ in range(59):
            sim.step({})
        self.assertTrue(sim.lanterns[0]["lit"])
        self.assertAlmostEqual(sim.lanterns[0]["fuel_ticks"] / 60.0, 1.0 / 60.0, places=3)

        # On 60th tick, fuel decays to 0 and lantern turns off
        sim.step({})
        self.assertFalse(sim.lanterns[0]["lit"])
        self.assertTrue(sim.lanterns[0]["ever_lit"])
        self.assertEqual(sim.lanterns[0]["deposited"], 0)
        self.assertEqual(sim.lanterns[0]["fuel_ticks"], 0)
        # Check lantern_out event emitted
        out_events = [e for e in sim.events if e["name"] == "lantern_out"]
        self.assertEqual(len(out_events), 1)
        self.assertEqual(out_events[0]["data"]["lantern_id"], "L1")

    def test_refuel_lit_lantern(self):
        # L1 is lit with fuel = 75.0 (needs ceil((100-75)/10) = 3 motes)
        # Player has 5 motes, carries 5.
        scenario = {
            "player": {"pos": [0, 0, 24], "carried": 5},
            "random_motes": False,
            "random_shades": False,
            "random_drifters": False,
            "lanterns": [{"id": "L1", "pos": [0, 0, 25], "lit": True, "fuel": 75.0}]
        }
        sim = Sim(seed=1, scenario=scenario, night=1)
        initial_score = sim.score
        # Interact: 1 tick
        sim.step({"interact": True})
        # After 1 tick, decay was 1 tick (1/60 fuel), then refuel:
        # 3 motes used => +30 fuel, capped at 100
        refuel_events = [e for e in sim.events if e["name"] == "refuel"]
        self.assertEqual(len(refuel_events), 1)
        self.assertEqual(refuel_events[0]["data"]["lantern_id"], "L1")
        self.assertEqual(refuel_events[0]["data"]["amount"], 3)
        self.assertEqual(sim.player["carried"], 2)
        self.assertEqual(sim.score, initial_score + 3 * 5) # +5 per mote
        self.assertEqual(sim.lanterns[0]["fuel_ticks"], 6000) # capped at 100 fuel

    def test_relight_cost_is_five_and_awards_forty_points(self):
        # L1 was ever_lit = True, currently unlit.
        scenario = {
            "player": {"pos": [0, 0, 24], "carried": 7},
            "random_motes": False,
            "random_shades": False,
            "random_drifters": False,
            "lanterns": [{"id": "L1", "pos": [0, 0, 25], "lit": False, "ever_lit": True, "deposited": 0}]
        }
        sim = Sim(seed=1, scenario=scenario, night=1)
        sim.step({"interact": True})
        # Relight needs 5 motes
        self.assertEqual(sim.player["carried"], 2) # 7 - 5 = 2
        self.assertTrue(sim.lanterns[0]["lit"])
        self.assertEqual(sim.lanterns[0]["relit_count"], 1)
        # Score: 5 motes * 5 = 25, + 40 relight bonus = 65
        self.assertEqual(sim.score, 65)
        # Capacity increases by 2
        self.assertEqual(sim.capacity, 12)
        lit_events = [e for e in sim.events if e["name"] == "lantern_lit"]
        self.assertEqual(len(lit_events), 1)
        self.assertTrue(lit_events[0]["data"]["relight"])

    def test_capacity_progression_max_twenty(self):
        scenario = {
            "player": {"pos": [0, 0, 0], "carried": 0, "successful_lights": 6},
            "random_motes": False,
            "random_shades": False,
            "random_drifters": False
        }
        sim = Sim(seed=1, scenario=scenario, night=1)
        # 10 + 2 * 6 = 22, capped at 20
        self.assertEqual(sim.capacity, 20)

    def test_shade_targets_low_fuel_lantern_and_drains(self):
        # L1 lit with fuel = 25.0 (< 30). Shade at (0, 0, 21), 4m away from L1 at (0, 0, 25).
        scenario = {
            "player": {"pos": [0, 0, 0], "carried": 0},
            "random_motes": False,
            "random_shades": False,
            "random_drifters": False,
            "lanterns": [{"id": "L1", "pos": [0, 0, 25], "lit": True, "fuel": 25.0}],
            "shades": [{"id": "S1", "pos": [0, 0, 21], "state": "wander"}]
        }
        sim = Sim(seed=1, scenario=scenario, night=1)
        # At shade_speed = 4.0 m/s, moving 2m takes 30 ticks to reach dist <= 2.0m
        for _ in range(35):
            sim.step({})
        self.assertEqual(sim.shades[0]["state"], "drain")
        self.assertEqual(sim.shades[0]["target_lantern_id"], "L1")

    def test_pulse_on_draining_shade_awards_fifteen_points(self):
        # Shade S1 is currently in drain state at (0, 0, 2)
        scenario = {
            "player": {"pos": [0, 0, 0], "carried": 3},
            "random_motes": False,
            "random_shades": False,
            "random_drifters": False,
            "lanterns": [{"id": "L1", "pos": [0, 0, 2], "lit": True, "fuel": 20.0}],
            "shades": [{"id": "S1", "pos": [0, 0, 2], "state": "drain", "target_lantern_id": "L1"}]
        }
        sim = Sim(seed=1, scenario=scenario, night=1)
        sim.step({"pulse": True})
        self.assertEqual(sim.shades[0]["state"], "stunned")
        # Pulse on drain gives 15 points
        self.assertEqual(sim.score, 15)

    def test_safe_zone_lost_when_fuel_under_thirty_and_restored_when_refueled(self):
        # L1 lit with fuel = 29.0: safe zone does not repel shade
        scenario = {
            "player": {"pos": [0, 0, 24], "carried": 2},
            "random_motes": False,
            "random_shades": False,
            "random_drifters": False,
            "lanterns": [{"id": "L1", "pos": [0, 0, 25], "lit": True, "fuel": 29.0}],
            "shades": [{"id": "S1", "pos": [0, 0, 23], "state": "wander"}] # dist to L1 = 2m < 6m
        }
        sim = Sim(seed=1, scenario=scenario, night=1)
        # Refuel L1 with 2 motes (+20 fuel) -> fuel = 48.9 >= 30
        sim.step({"interact": True})
        # Shade S1 should now be pushed to safe radius (6m) from L1 (0, 0, 25)
        dist_to_l1 = math.hypot(sim.shades[0]["pos"][0] - 0, sim.shades[0]["pos"][2] - 25)
        self.assertAlmostEqual(dist_to_l1, 6.0, places=1)

    def test_no_early_win_when_all_lit(self):
        # All 5 lanterns lit, but time_left = 100s. Game must keep playing!
        scenario = {
            "time_left_s": 100,
            "player": {"pos": [0, 0, 0], "carried": 0},
            "random_motes": False,
            "random_shades": False,
            "random_drifters": False,
            "lanterns": [{"id": f"L{i+1}", "lit": True, "fuel": 80.0} for i in range(5)]
        }
        sim = Sim(seed=1, scenario=scenario, night=1)
        sim.step({})
        self.assertEqual(sim.state, "playing")

    def test_dawn_survival_win_and_score(self):
        # Night 1: 3 out of 5 lanterns lit (>= 60%), time_left = 1/60s (1 tick to dawn)
        # L1 fuel = 50.0, L2 fuel = 60.5, L3 fuel = 40.0, L4 & L5 unlit.
        # Flames = 2
        scenario = {
            "time_left_s": 1.0 / 60.0,
            "player": {"pos": [0, 0, 0], "carried": 0, "flames": 2},
            "random_motes": False,
            "random_shades": False,
            "random_drifters": False,
            "lanterns": [
                {"id": "L1", "lit": True, "fuel": 50.0},
                {"id": "L2", "lit": True, "fuel": 60.5},
                {"id": "L3", "lit": True, "fuel": 40.0},
                {"id": "L4", "lit": False, "fuel": 0.0},
                {"id": "L5", "lit": False, "fuel": 0.0}
            ]
        }
        sim = Sim(seed=1, scenario=scenario, night=1)
        sim.step({})
        self.assertEqual(sim.state, "won")
        # Bonus calculation:
        # L1: 50 + floor(49.98) = 50 + 49 = 99
        # L2: 50 + floor(60.48) = 50 + 60 = 110
        # L3: 50 + floor(39.98) = 50 + 39 = 89
        # Total lantern dawn bonus = 99 + 110 + 89 = 298
        # Flames bonus: 2 * 50 = 100
        # Total expected score = 398
        self.assertEqual(sim.score, 398)
        game_over = [e for e in sim.events if e["name"] == "game_over"]
        self.assertEqual(len(game_over), 1)
        self.assertEqual(game_over[0]["data"]["result"], "won")
        self.assertEqual(game_over[0]["data"]["reason"], "dawn_survived")

    def test_dawn_loss_when_under_sixty_percent(self):
        # Night 1: only 2 out of 5 lit at dawn (< 3)
        scenario = {
            "time_left_s": 1.0 / 60.0,
            "player": {"pos": [0, 0, 0], "carried": 0, "flames": 2},
            "random_motes": False,
            "random_shades": False,
            "random_drifters": False,
            "lanterns": [
                {"id": "L1", "lit": True, "fuel": 50.0},
                {"id": "L2", "lit": True, "fuel": 60.0},
                {"id": "L3", "lit": False, "fuel": 0.0},
                {"id": "L4", "lit": False, "fuel": 0.0},
                {"id": "L5", "lit": False, "fuel": 0.0}
            ]
        }
        sim = Sim(seed=1, scenario=scenario, night=1)
        sim.step({})
        self.assertEqual(sim.state, "lost")
        game_over = [e for e in sim.events if e["name"] == "game_over"]
        self.assertEqual(len(game_over), 1)
        self.assertEqual(game_over[0]["data"]["result"], "lost")
        self.assertEqual(game_over[0]["data"]["reason"], "dawn")

if __name__ == "__main__":
    unittest.main()
