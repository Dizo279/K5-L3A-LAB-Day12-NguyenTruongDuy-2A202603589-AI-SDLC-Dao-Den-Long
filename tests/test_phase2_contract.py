import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from game.headless import terrain_height


ROOT = Path(__file__).resolve().parents[1]
RUNNER = ROOT / "game" / "headless.py"


def run_simulation(night: int, scenario: dict, ticks: int, snapshot_every: int = 1, inputs=None):
    with tempfile.TemporaryDirectory() as tmp:
        scenario_file = Path(tmp) / "scenario.json"
        inputs_file = Path(tmp) / "inputs.json"
        output_file = Path(tmp) / "output.jsonl"
        scenario_file.write_text(json.dumps(scenario), encoding="utf-8")
        if inputs is not None:
            inputs_file.write_text(json.dumps({"frames": inputs}), encoding="utf-8")
        command = [
                sys.executable,
                str(RUNNER),
                "--seed",
                "91",
                "--night",
                str(night),
                "--scenario",
                str(scenario_file),
                "--ticks",
                str(ticks),
                "--snapshot-every",
                str(snapshot_every),
                "--out",
                str(output_file),
            ]
        if inputs is not None:
            command.extend(["--inputs", str(inputs_file)])
        result = subprocess.run(
            command,
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode:
            raise AssertionError(f"headless failed: {result.stderr}")
        return [json.loads(line) for line in output_file.read_text(encoding="utf-8").splitlines()]


def snapshot_at(rows, tick):
    return next(row for row in rows if row["type"] == "snapshot" and row["tick"] == tick)


class Phase2TimerContractTests(unittest.TestCase):
    def test_fall_respawn_waits_full_sixty_ticks_after_fall_event(self):
        rows = run_simulation(
            1,
            {"player": {"pos": [0, -10.1, 0]}, "random_motes": False, "random_shades": False},
            61,
        )
        self.assertEqual(snapshot_at(rows, 1)["player"]["flames"], 2)
        self.assertEqual(snapshot_at(rows, 60)["player"]["pos"], [0.0, -10.1, 0.0])
        self.assertEqual(snapshot_at(rows, 61)["player"]["pos"], [0.0, 0.0, 0.0])

    def test_charm_respawn_timer_does_not_lose_the_pickup_tick(self):
        rows = run_simulation(
            2,
            {
                "player": {"pos": [0, 0, 0]},
                "random_motes": False,
                "random_shades": False,
                "random_drifters": False,
                "charms": [{"id": "C1", "pos": [0, 0, 0]}],
            },
            2701,
            inputs=[{"tick": 1, "move": [0, 1]}, {"tick": 60, "move": [0, 0]}],
        )
        self.assertFalse(snapshot_at(rows, 2700)["charms"][0]["available"])
        self.assertTrue(snapshot_at(rows, 2701)["charms"][0]["available"])

    def test_night_two_shade_schedule_starts_after_seven_seconds(self):
        rows = run_simulation(
            2,
            {"random_motes": False, "random_drifters": False},
            420,
            snapshot_every=60,
        )
        spawns = [row["tick"] for row in rows if row.get("name") == "shade_spawned"]
        self.assertEqual(spawns, [420])

    def test_night_three_shade_schedule_starts_after_six_seconds(self):
        rows = run_simulation(
            3,
            {"random_motes": False, "random_drifters": False, "wind_enabled": False},
            360,
            snapshot_every=60,
        )
        spawns = [row["tick"] for row in rows if row.get("name") == "shade_spawned"]
        self.assertEqual(spawns, [360])

    def test_night_one_has_two_initial_shades_then_one_per_eight_seconds(self):
        rows = run_simulation(1, {"random_motes": False}, 780, snapshot_every=1)
        spawns = [row for row in rows if row.get("name") == "shade_spawned"]
        self.assertEqual([(row["tick"], row["data"]["id"]) for row in spawns], [(300, "S1"), (300, "S2"), (780, "S3")])
        self.assertEqual([shade["state"] for shade in snapshot_at(rows, 300)["shades"]], ["spawning", "spawning"])
        self.assertEqual([shade["state"] for shade in snapshot_at(rows, 360)["shades"]], ["wander", "wander"])

    def test_pause_freezes_simulation_time_and_cooldowns(self):
        rows = run_simulation(
            1,
            {"player": {"pulse_cd_ticks": 20}, "random_motes": False, "random_shades": False},
            4,
            inputs=[{"tick": 0, "pause": True}, {"tick": 1, "pause": False}, {"tick": 2, "pause": True}, {"tick": 3, "pause": False}],
        )
        paused = snapshot_at(rows, 1)
        paused_again = snapshot_at(rows, 2)
        resumed = snapshot_at(rows, 3)
        self.assertEqual(paused["state"], "paused")
        self.assertEqual(paused["sim_tick"], 0)
        # Ticket-03 (Contract v1.2): night1_duration_s thay đổi từ 300s thành 240s
        self.assertEqual(paused["time_left_s"], 240.0)
        self.assertEqual(paused["player"]["pulse_cd_s"], round(20 / 60, 3))
        self.assertEqual(paused_again["sim_tick"], 0)
        self.assertEqual(paused_again["time_left_s"], 240.0)
        self.assertEqual(resumed["state"], "playing")
        self.assertEqual(resumed["sim_tick"], 1)
        self.assertEqual([row["name"] for row in rows if row["type"] == "event"], ["paused", "resumed", "night_start"])

    def test_drifter_can_steal_during_player_invulnerability_without_flame_damage(self):
        rows = run_simulation(
            2,
            {
                "player": {"pos": [0, 0, 0], "carried": 5, "invuln_ticks": 90},
                "random_motes": False,
                "random_shades": False,
                "random_drifters": False,
                "drifters": [{"id": "D1", "pos": [0, 0, 1]}],
            },
            1,
        )
        steal = next(row for row in rows if row.get("name") == "drifter_steal")
        self.assertEqual(steal["data"], {"drifter_id": "D1", "amount": 3, "carried": 2})
        state = snapshot_at(rows, 1)
        self.assertEqual(state["player"]["flames"], 3)
        self.assertEqual(state["player"]["carried"], 2)

    def test_pulsed_fleeing_drifter_drops_motes_and_remains_for_120_ticks(self):
        rows = run_simulation(
            2,
            {
                "player": {"pos": [0, 0, 0], "carried": 3},
                "random_motes": False,
                "random_shades": False,
                "random_drifters": False,
                "drifters": [{"id": "D1", "pos": [0, 0, 2], "state": "flee", "stolen": 2, "state_ticks_left": 240}],
            },
            122,
            snapshot_every=1,
            inputs=[{"tick": 0, "pulse": True}, {"tick": 1, "pulse": False}],
        )
        self.assertEqual(next(row for row in rows if row.get("name") == "drifter_drop")["data"]["amount"], 2)
        self.assertEqual(snapshot_at(rows, 120)["drifters"][0]["state"], "flee")
        self.assertEqual(snapshot_at(rows, 121)["drifters"][0]["state"], "removed")
        self.assertEqual(snapshot_at(rows, 1)["motes_active"], 2)

    def test_pulse_sends_chasing_drifter_fleeing_for_full_240_ticks_without_theft(self):
        rows = run_simulation(
            2,
            {
                "player": {"pos": [0, 0, 0], "carried": 5},
                "random_motes": False,
                "random_shades": False,
                "random_drifters": False,
                "drifters": [{"id": "D1", "pos": [0, 0, 2], "state": "chase"}],
            },
            241,
            snapshot_every=1,
            inputs=[{"tick": 0, "pulse": True}, {"tick": 1, "pulse": False}],
        )
        self.assertEqual(snapshot_at(rows, 1)["drifters"][0]["state"], "flee")
        self.assertEqual(snapshot_at(rows, 240)["drifters"][0]["state"], "flee")
        self.assertEqual(snapshot_at(rows, 241)["drifters"][0]["state"], "removed")
        self.assertFalse(any(row.get("name") == "drifter_steal" for row in rows))

    def test_nearest_lantern_wins_interaction_with_id_tie_break(self):
        rows = run_simulation(
            1,
            {
                "player": {"pos": [0, 0, 0], "carried": 10},
                "random_motes": False,
                "random_shades": False,
                "lanterns": [
                    {"id": "L1", "pos": [0, 0, 1]},
                    {"id": "L2", "pos": [0, 0, -1]},
                ],
            },
            1,
            inputs=[{"tick": 0, "interact": True}],
        )
        deposit = next(row for row in rows if row.get("name") == "deposit")
        self.assertEqual(deposit["data"]["lantern_id"], "L1")
        self.assertEqual(deposit["data"]["amount"], 10)

    def test_lighting_last_lantern_on_dawn_tick_wins_and_scores_bonus(self):
        lantern_overrides = [
            {"id": f"L{i}", "lit": True} for i in range(2, 6)
        ] + [{"id": "L1", "pos": [0, 0, 1], "deposited": 9}]
        rows = run_simulation(
            1,
            {
                "player": {"pos": [0, 0, 0], "carried": 1, "flames": 2},
                "random_motes": False,
                "random_shades": False,
                "lanterns": lantern_overrides,
                "time_left_s": 1 / 60,
            },
            2,
            inputs=[{"tick": 0, "interact": True}],
        )
        end = rows[-1]
        # Ticket-03 (Contract v1.2): Thay thế all_lit bằng dawn_survived, công thức tính điểm mới:
        # +5 (mote) + 100 (thắp lần đầu) + 746 (5 đèn x (50 + floor(fuel))) + 100 (2 flames x 50) = 951
        self.assertEqual((end["state"], end["score"]), ("won", 951))
        self.assertEqual(next(row for row in rows if row.get("name") == "game_over")["data"]["reason"], "dawn_survived")

    def test_night_three_terrain_has_half_ring_and_two_ramps(self):
        self.assertEqual(terrain_height(3, 0, 0), 6.0)
        self.assertEqual(terrain_height(3, 0, 18), 3.0)
        self.assertEqual(terrain_height(3, 0, -18), 0.0)
        self.assertAlmostEqual(terrain_height(3, 27 * 0.8660254, 13.5), 1.5, places=5)


if __name__ == "__main__":
    unittest.main()
