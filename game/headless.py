#!/usr/bin/env python3
import argparse, json, math, random, sys

T = json.load(open("game.contract.json", encoding="utf-8"))["tuning"]

def dist(a, b): return math.hypot(a[0]-b[0], a[2]-b[2])
def clamp(v, lo, hi): return max(lo, min(hi, v))
def pos(p): return [round(float(p[0]), 3), round(float(p[1]), 3), round(float(p[2]), 3)]

class Sim:
    def __init__(self, seed, scenario):
        self.rng = random.Random(seed); self.tick = 0; self.state = "playing"; self.score = 0
        self.time_left = float(scenario.get("time_left_s", T["night1_duration_s"]))
        p = scenario.get("player", {})
        self.player = {"pos": list(p.get("pos", [0,0,0])), "flames": int(p.get("flames", T["flames"])), "carried": int(p.get("carried", 0))}
        self.motes = [list(x) for x in scenario.get("motes", [])]
        self.shades = [{"id": x.get("id", f"S{i+1}"), "pos": list(x["pos"]), "state":"chase", "stun":0} for i,x in enumerate(scenario.get("shades", []))]
        self.lanterns = [{"id": x.get("id", f"L{i+1}"), "pos": list(x.get("pos", [0,0,0])), "deposited": int(x.get("deposited",0)), "lit": bool(x.get("lit",False))} for i,x in enumerate(scenario.get("lanterns", []))]
        if not self.lanterns: self.lanterns = [{"id":f"L{i+1}","pos":[0,0,0],"deposited":0,"lit":False} for i in range(5)]
        self.events=[]; self.last_pulse=-999999; self.invuln=0
    def event(self, name, data): self.events.append({"type":"event","tick":self.tick,"name":name,"data":data})
    def snapshot(self):
        return {"type":"snapshot","tick":self.tick,"sim_tick":self.tick,"state":self.state,"time_left_s":round(self.time_left,3),"score":self.score,
          "player":{"pos":pos(self.player["pos"]),"flames":self.player["flames"],"carried":self.player["carried"]},
          "lanterns":[{"id":x["id"],"pos":pos(x["pos"]),"lit":x["lit"],"deposited":x["deposited"]} for x in self.lanterns],
          "shades":[{"id":x["id"],"pos":pos(x["pos"]),"state":"stunned" if x["stun"]>0 else x["state"]} for x in self.shades],"motes_active":len(self.motes)}
    def step(self, inp):
        self.tick += 1
        old = getattr(self, "buttons", {}); self.buttons = {**old, **inp}
        move=self.buttons.get("move",[0,0]); yaw=math.radians(self.buttons.get("cam_yaw_deg",0)); n=math.hypot(move[0],move[1]) or 1
        x,z=move[0]/max(1,n),move[1]/max(1,n); wx=x*math.cos(yaw)+z*math.sin(yaw); wz=-x*math.sin(yaw)+z*math.cos(yaw)
        self.player["pos"][0]+=wx*T["player_speed"]/60; self.player["pos"][2]+=wz*T["player_speed"]/60
        for m in self.motes[:]:
            if self.player["carried"] < T["carry_capacity"] and dist(self.player["pos"],m)<=T["pickup_radius"]:
                self.motes.remove(m); self.player["carried"]+=1; self.score+=T["score"]["per_mote"]; self.event("mote_picked",{"carried":self.player["carried"]})
        if self.buttons.get("interact") and not old.get("interact"):
            for l in self.lanterns:
                if not l["lit"] and dist(self.player["pos"],l["pos"])<=T["interact_radius"] and self.player["carried"]:
                    amount=min(self.player["carried"],T["lantern_cost"]-l["deposited"]); l["deposited"]+=amount; self.player["carried"]-=amount; self.event("deposit",{"lantern_id":l["id"],"amount":amount,"deposited":l["deposited"]})
                    if l["deposited"]>=T["lantern_cost"]: l["lit"]=True; self.score+=T["score"]["per_lantern"]; self.event("lantern_lit",{"lantern_id":l["id"]})
                    break
        if self.buttons.get("pulse") and not old.get("pulse") and self.player["flames"]>=T["pulse_cost"] and self.tick-self.last_pulse>=T["pulse_cooldown_s"]*60:
            self.player["flames"]-=T["pulse_cost"]; self.last_pulse=self.tick; stunned=[]
            for s in self.shades:
                if dist(self.player["pos"],s["pos"])<=T["pulse_radius"]: s["stun"]=int(T["pulse_stun_s"]*60); stunned.append(s["id"]); self.score+=T["score"]["per_stun"]
            self.event("pulse",{"stunned_ids":stunned})
        for s in self.shades:
            if s["stun"]>0: s["stun"]-=1; continue
            d=dist(self.player["pos"],s["pos"])
            if d>0: s["pos"][0]+=(self.player["pos"][0]-s["pos"][0])/d*T["shade_speed"]/60; s["pos"][2]+=(self.player["pos"][2]-s["pos"][2])/d*T["shade_speed"]/60
            if d<=T["shade_hit_radius"] and self.invuln<=0: self.player["flames"]-=1; dropped=math.floor(self.player["carried"]*T["hit_drop_ratio"]); self.player["carried"]-=dropped; self.invuln=int(T["invuln_s"]*60); self.event("player_hit",{"by":"shade","flames":self.player["flames"],"dropped":dropped})
        self.invuln=max(0,self.invuln-1); self.time_left-=1/60
        if all(x["lit"] for x in self.lanterns): self.state="won"; self.score+=math.floor(self.time_left)*T["score"]["per_second_left"]+self.player["flames"]*T["score"]["per_flame_left"]; self.event("game_over",{"result":"won","reason":"all_lit"})
        elif self.player["flames"]<=0: self.state="lost"; self.event("game_over",{"result":"lost","reason":"no_flames"})
        elif self.time_left<=0: self.state="lost"; self.event("game_over",{"result":"lost","reason":"dawn"})
    def run(self, ticks, inputs, every):
        frames={x["tick"]:x for x in inputs}; out=[self.snapshot()]
        while self.tick<ticks and self.state=="playing": self.step(frames.get(self.tick,{})); out.extend(self.events); self.events=[]; 
        # snapshots and events are emitted in simulation order; snapshots are deterministic checkpoints.
        return out

def main():
    ap=argparse.ArgumentParser(); ap.add_argument("--seed",type=int,default=0); ap.add_argument("--night",type=int,required=True); ap.add_argument("--scenario"); ap.add_argument("--inputs"); ap.add_argument("--ticks",type=int,required=True); ap.add_argument("--out",required=True); ap.add_argument("--snapshot-every",type=int,default=10); a=ap.parse_args()
    try:
        scenario=json.load(open(a.scenario,encoding="utf-8")) if a.scenario else {}; inputs=json.load(open(a.inputs,encoding="utf-8"))["frames"] if a.inputs else []
    except (OSError,ValueError,KeyError) as e: print(f"invalid input: {e}",file=sys.stderr); return 2
    sim=Sim(a.seed,scenario); rows=[]
    for _ in range(a.ticks):
        if sim.tick%a.snapshot_every==0: rows.append(sim.snapshot())
        if sim.state!="playing": break
        sim.step({x["tick"]:x for x in inputs}.get(sim.tick,{})); rows.extend(sim.events); sim.events=[]
    if sim.tick%a.snapshot_every==0 and not rows[-1].get("type")=="snapshot": rows.append(sim.snapshot())
    rows.append({"type":"end","ticks":sim.tick,"state":sim.state,"score":sim.score})
    with open(a.out,"w",encoding="utf-8") as f:
        for row in rows: f.write(json.dumps(row,separators=(",",":"))+"\n")
    return 0
if __name__=="__main__": sys.exit(main())
