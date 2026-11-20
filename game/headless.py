#!/usr/bin/env python3
import argparse, json, math, random, sys

T = json.load(open("game.contract.json", encoding="utf-8"))["tuning"]

MAP_LANTERNS = {
    1: [[0,0,25],[23.8,0,7.7],[14.7,0,-20.2],[-14.7,0,-20.2],[-23.8,0,7.7]],
    2: [[0,0,20],[17,0,-10],[-17,0,-10],[70,0,20],[87,0,-10],[53,0,-10]],
    3: [[0,6,6],[18,3,10],[-18,3,10],[35,0,-10],[-35,0,-10],[20,0,-35],[-20,0,-35]],
}
MAP_SHADE_POINTS={
    1:[[37*math.cos(math.radians(a)),0,37*math.sin(math.radians(a))] for a in range(15,360,30)],
    2:[[cx+26*math.cos(math.radians(a)),0,26*math.sin(math.radians(a))] for cx in (0,70) for a in (22.5,67.5,112.5,157.5,202.5,247.5,292.5,337.5)],
    3:[[43*math.cos(math.radians(i*22.5)),0,43*math.sin(math.radians(i*22.5))] for i in range(16)],
}
MAP_STARTS={1:[0,0,0],2:[0,0,0],3:[0,0,-15]}
def map_mote_points(night):
    points=[]
    if night==1:
        points += [[12*math.cos(math.radians(a)),0,12*math.sin(math.radians(a))] for a in range(0,360,45)]
        points += [[33*math.cos(math.radians(i*22.5)),0,33*math.sin(math.radians(i*22.5))] for i in range(16)]
    elif night==2:
        for cx in (0,70):
            points += [[cx+10*math.cos(math.radians(a)),0,10*math.sin(math.radians(a))] for a in (0,90,180,270)]
            points += [[cx+22*math.cos(math.radians(a)),0,22*math.sin(math.radians(a))] for a in range(0,360,45)]
    else:
        points += [[34*math.cos(math.radians(a)),0,34*math.sin(math.radians(a))] for a in range(0,360,20)]
        points += [[18*math.cos(math.radians(a)),3,18*math.sin(math.radians(a))] for a in range(20,180,20)]
        points += [[5*math.cos(math.radians(a)),6,5*math.sin(math.radians(a))] for a in (45,135,225,315)]
    return points
def terrain_height(night,x,z):
    r=math.hypot(x,z)
    if night==1: return 0.0 if r<=40 else -math.inf
    if night==2:
        return 0.0 if math.hypot(x,z)<=28 or math.hypot(x-70,z)<=28 or (26<=x<=44 and abs(z)<=2) else -math.inf
    if r<=8: return 6.0
    if 12<=r<=24 and z>0: return 3.0
    if on_ramp(x,z): return (30-r)*0.5
    return 0.0 if r<=45 else -math.inf
def on_ramp(x,z):
    r=math.hypot(x,z)
    if not 24<=r<=30: return False
    angle=math.degrees(math.atan2(z,x))%360
    return any(abs((angle-a+180)%360-180)<=math.degrees(1.5/max(r,1)) for a in (30.0,150.0))

def dist(a, b): return math.hypot(a[0]-b[0], a[2]-b[2])
def dist3(a,b): return math.sqrt((a[0]-b[0])**2+(a[1]-b[1])**2+(a[2]-b[2])**2)
def clamp(v, lo, hi): return max(lo, min(hi, v))
def pos(p): return [round(float(p[0]), 3), round(float(p[1]), 3), round(float(p[2]), 3)]

class Sim:
    def __init__(self, seed, scenario, night=1):
        self.rng = random.Random(seed); self.tick = 0; self.sim_tick = 0; self.state = "playing"; self.score = 0
        self.night = night
        duration = T["night1_duration_s"] if night == 1 else T["night2_duration_s"] if night == 2 else T["night3_duration_s"]
        self.time_left = float(scenario.get("time_left_s", duration))
        p = scenario.get("player", {})
        default_start = MAP_STARTS[night]
        self.player = {"pos": list(p.get("pos", default_start)), "flames": int(p.get("flames", T["flames"])), "carried": int(p.get("carried", 0))}
        self.random_motes = bool(scenario.get("random_motes", True))
        self.random_shades = bool(scenario.get("random_shades", True))
        if "motes" in scenario:
            initial_motes = scenario["motes"]
        elif self.random_motes:
            initial_motes = self.rng.sample(map_mote_points(night), 20)
        else:
            initial_motes = []
        self.motes = [[*x, f"M{i+1}", "random", None] for i,x in enumerate(initial_motes)]
        if len(self.motes)>30: self.motes=self.motes[:30]
        self.shades = [{"id": x.get("id", f"S{i+1}"), "pos": list(x["pos"]), "state":x.get("state","wander"), "stun":int(x.get("state_ticks_left",0)) if x.get("state")=="stunned" else 0,"spawn":int(x.get("state_ticks_left",0)) if x.get("state")=="spawning" else 0,"state_ticks":int(x.get("state_ticks_left",0)),"push_ticks":0,"push_dir":[1.0,0.0]} for i,x in enumerate(scenario.get("shades", []))]
        self.drifters = [{"id": x.get("id", f"D{i+1}"), "pos": list(x["pos"]), "state":x.get("state","idle"), "stolen":int(x.get("stolen",0)),"flee_ticks":int(x.get("state_ticks_left",0)),"robbed":bool(x.get("robbed",False))} for i,x in enumerate(scenario.get("drifters", []))]
        defaults = ({2:[[35,0,0]],3:[[30,0,25],[-30,0,25]]}.get(night, []))
        charm_data = scenario.get("charms", [{"id":f"C{i+1}","pos":p} for i,p in enumerate(defaults)])
        self.charms = [{"id": x.get("id", f"C{i+1}"), "pos": list(x.get("pos",[0,0,0])), "available":bool(x.get("available",True)), "respawn":int(x.get("respawn_ticks",0))} for i,x in enumerate(charm_data)]
        default_lanterns = MAP_LANTERNS.get(night, MAP_LANTERNS[1])
        self.lanterns = [{"id":f"L{i+1}","pos":list(p),"deposited":0,"lit":False} for i,p in enumerate(default_lanterns)]
        for override in scenario.get("lanterns",[]):
            lamp=next((x for x in self.lanterns if x["id"]==override.get("id")),None)
            if lamp is not None:
                if "pos" in override: lamp["pos"]=list(override["pos"])
                if "deposited" in override: lamp["deposited"]=int(override["deposited"])
                if "lit" in override: lamp["lit"]=bool(override["lit"])
        self.events=[]; self.last_pulse=-999999; self.last_dash=-999999; self.dash_ticks=0; self.dash_dir=[0,0]; self.invuln=0; self.paused=False; self.charm_ticks=0; self.jump_vel=0.0; self.grounded=True
        self.wind_dir=0.0; self.wind_active=False
        self.random_drifters = bool(scenario.get("random_drifters", True))
        self.wind_enabled = bool(scenario.get("wind_enabled", night==3))
        if scenario.get("random_shades") is False and "shades" not in scenario: self.shades=[]
        self.shades.sort(key=lambda shade: (shade["id"][0], int(shade["id"][1:]) if shade["id"][1:].isdigit() else 0))
        self.drifters.sort(key=lambda drifter: (drifter["id"][0], int(drifter["id"][1:]) if drifter["id"][1:].isdigit() else 0))
        self.next_shade_id = len(self.shades) + 1
        self.next_mote_id = len(self.motes) + 1
        self.next_drifter_id = len(self.drifters) + 1
        self.respawn_ticks = 0
        self.pad_active=False; self.pad_horizontal=[0.0,0.0]
        self.fall_triggered = False
        self.invuln = int(p.get("invuln_ticks",0))
        self.dash_cd = int(p.get("dash_cd_ticks",0))
        self.pulse_cd = int(p.get("pulse_cd_ticks",0))
        self.charm_ticks = int(p.get("charm_ticks",0))
        self.horizontal_vel=[0.0,0.0]
        self.facing_dir=[0.0,1.0]
        self.recoil_ticks=0
        self.recoil_dir=[0.0,0.0]
        for c in self.charms:
            if not c["available"] and c["respawn"]<=0: c["respawn"]=2700
    def event(self, name, data): self.events.append({"type":"event","tick":self.tick,"name":name,"data":data})
    def snapshot(self):
        return {"type":"snapshot","tick":self.tick,"sim_tick":self.sim_tick,"night":self.night,"state":self.state,"time_left_s":round(self.time_left,3),"score":self.score,"wind":{"active":self.wind_active,"dir_deg":round(self.wind_dir,3)},
          "player":{"pos":pos(self.player["pos"]),"vel":[round(self.horizontal_vel[0],3),round(self.jump_vel,3),round(self.horizontal_vel[1],3)],"grounded":self.grounded,"flames":self.player["flames"],"carried":self.player["carried"],"invuln":self.invuln>0,"dash_cd_s":round(self.dash_cd/60,3),"pulse_cd_s":round(self.pulse_cd/60,3),"charm_s":self.charm_ticks/60},
          "lanterns":[{"id":x["id"],"pos":pos(x["pos"]),"lit":x["lit"],"deposited":x["deposited"]} for x in self.lanterns],
          "shades":[{"id":x["id"],"pos":pos(x["pos"]),"state":"stunned" if x["stun"]>0 else x["state"]} for x in self.shades],
          "drifters":[{"id":x["id"],"pos":pos(x["pos"]),"state":x["state"],"stolen":x["stolen"]} for x in self.drifters],
          "charms":[{"id":x["id"],"available":x["available"],"respawn_s":round(x["respawn"]/60,3)} for x in self.charms],
          "motes":[{"id":m[3],"pos":pos(m[:3]),"kind":m[4],"ttl_s":None if m[5] is None else round(m[5]/60,3)} for i,m in enumerate(self.motes)],"motes_active":len(self.motes)}
    def emit_shade_spawn(self, point):
        shade_id = f"S{self.next_shade_id}"
        self.next_shade_id += 1
        self.shades.append({"id":shade_id,"pos":list(point),"state":"spawning","stun":0,"spawn":60,"state_ticks":60,"push_ticks":0,"push_dir":[1.0,0.0]})
        self.event("shade_spawned", {"id":shade_id})
    def step(self, inp):
        self.tick += 1
        old = getattr(self, "buttons", {}); self.buttons = {**old, **inp}
        if self.buttons.get("pause") and not old.get("pause"):
            self.paused = not self.paused
            self.state = "paused" if self.paused else "playing"
            self.event("paused" if self.paused else "resumed", {})
        if self.paused:
            return
        self.sim_tick += 1
        if self.sim_tick == 1:
            self.event("night_start", {"night":self.night})
        self.time_left=max(0.0,self.time_left-1/60)
        self.invuln=max(0,self.invuln-1)
        self.dash_cd=max(0,self.dash_cd-1)
        self.pulse_cd=max(0,self.pulse_cd-1)
        self.charm_ticks=max(0,self.charm_ticks-1)
        for c in self.charms:
            if not c["available"]:
                c["respawn"]-=1
                if c["respawn"]<=0: c["available"]=True
        if self.respawn_ticks>0:
            self.respawn_ticks-=1
            if self.respawn_ticks==0:
                self.player["pos"]=list(MAP_STARTS[self.night])
                self.jump_vel=0; self.grounded=True; self.fall_triggered=False
        if self.recoil_ticks>0: self.recoil_ticks-=1
        for m in self.motes:
            if m[5] is not None: m[5]-=1
        for s in self.shades:
            if s["stun"]>0: s["stun"]-=1
        old_x,old_z=self.player["pos"][0],self.player["pos"][2]
        was_grounded=self.grounded
        old_floor=terrain_height(self.night,old_x,old_z)
        move=self.buttons.get("move",[0,0]); yaw=math.radians(self.buttons.get("cam_yaw_deg",0)); n=math.hypot(move[0],move[1]) or 1
        x,z=move[0]/max(1,n),move[1]/max(1,n); wx=x*math.cos(yaw)+z*math.sin(yaw); wz=-x*math.sin(yaw)+z*math.cos(yaw)
        if wx or wz: self.facing_dir=[wx,wz]
        if self.respawn_ticks<=0 and self.buttons.get("jump") and not old.get("jump") and self.grounded:
            self.jump_vel=7.0; self.grounded=False
        if self.respawn_ticks<=0 and self.buttons.get("dash") and not old.get("dash") and (self.charm_ticks>0 or self.dash_cd<=0) and self.dash_ticks<=0:
            self.last_dash=self.tick; self.dash_ticks=12 if self.charm_ticks>0 else int(T["dash_duration_s"]*60); self.dash_dir=[wx,wz] if (wx or wz) else list(self.facing_dir); self.event("dash",{})
            self.dash_cd=0 if self.charm_ticks>0 else int(T["dash_cooldown_s"]*60)
        if not self.grounded and self.dash_ticks<=0:
            self.player["pos"][1]+=self.jump_vel/60; self.jump_vel-=20.0/60
            floor=terrain_height(self.night,self.player["pos"][0],self.player["pos"][2])
            if math.isfinite(floor) and self.player["pos"][1]<=floor and self.jump_vel<=0:
                self.player["pos"][1]=floor; self.jump_vel=0; self.grounded=True; self.pad_active=False
        if self.respawn_ticks>0:
            self.horizontal_vel=[0.0,0.0]
        elif self.recoil_ticks>0:
            self.horizontal_vel=[self.recoil_dir[0]*2.0,self.recoil_dir[1]*2.0]
            self.player["pos"][0]+=self.horizontal_vel[0]/60; self.player["pos"][2]+=self.horizontal_vel[1]/60
        elif self.pad_active:
            self.horizontal_vel=[self.pad_horizontal[0],self.pad_horizontal[1]]
            self.player["pos"][0]+=self.pad_horizontal[0]/60; self.player["pos"][2]+=self.pad_horizontal[1]/60
        elif self.dash_ticks>0:
            self.player["pos"][0]+=self.dash_dir[0]*T["dash_speed"]/60; self.player["pos"][2]+=self.dash_dir[1]*T["dash_speed"]/60; self.dash_ticks-=1
            self.horizontal_vel=[self.dash_dir[0]*T["dash_speed"],self.dash_dir[1]*T["dash_speed"]]
        else:
            speed=T["player_speed"]*(1.2 if self.charm_ticks>0 else 1.0)
            max_delta=speed/6
            self.horizontal_vel[0]+=clamp(wx*speed-self.horizontal_vel[0],-max_delta,max_delta)
            self.horizontal_vel[1]+=clamp(wz*speed-self.horizontal_vel[1],-max_delta,max_delta)
            self.player["pos"][0]+=self.horizontal_vel[0]/60; self.player["pos"][2]+=self.horizontal_vel[1]/60
        if not self.pad_active and self.grounded:
            px,pz=self.player["pos"][0],self.player["pos"][2]
            pad2=(self.night==2 and (math.hypot(px-20,pz-18)<=1 or math.hypot(px-50,pz+18)<=1))
            pad3=(self.night==3 and dist3(self.player["pos"],[0,3,13])<=1)
            if pad2:
                self.pad_active=True; self.grounded=False; self.jump_vel=14.0
                self.pad_horizontal=[24.0,0.0] if px<35 else [-24.0,0.0]
            elif pad3:
                self.pad_active=True; self.grounded=False; self.jump_vel=12.0; self.pad_horizontal=[0.0,-8.0]
        self.wind_active=False
        if self.night==3 and self.wind_enabled:
            self.wind_active=self.sim_tick>=1800 and self.sim_tick%1800<300
            if self.wind_active:
                if self.sim_tick%1800==0: self.wind_dir=self.rng.random()*360.0
                self.player["pos"][0]+=math.cos(math.radians(self.wind_dir))*2/60
                self.player["pos"][2]+=math.sin(math.radians(self.wind_dir))*2/60
        new_floor=terrain_height(self.night,self.player["pos"][0],self.player["pos"][2])
        if was_grounded and self.night==3 and on_ramp(old_x,old_z) and on_ramp(self.player["pos"][0],self.player["pos"][2]):
            self.player["pos"][1]=new_floor
        elif was_grounded and new_floor>old_floor and self.night==3:
            if not on_ramp(self.player["pos"][0],self.player["pos"][2]):
                self.player["pos"][0]=old_x; self.player["pos"][2]=old_z
                new_floor=old_floor
            else:
                self.player["pos"][1]=new_floor
        if was_grounded and (not math.isfinite(new_floor) or new_floor<old_floor): self.grounded=False
        if self.player["pos"][1] < -10 and not self.fall_triggered:
            self.fall_triggered=True
            self.player["flames"]-=1
            lost=self.player["carried"]
            self.player["carried"]=0
            self.event("player_hit",{"by":"fall","flames":self.player["flames"],"dropped":0,"lost":lost})
            if self.player["flames"]>0:
                self.respawn_ticks=60
                self.invuln=90
        for m in self.motes[:]:
            if m[5] is not None and m[5]<=0: self.motes.remove(m); continue
            if self.respawn_ticks<=0 and self.player["carried"] < T["carry_capacity"] and dist(self.player["pos"],m[:3])<=T["pickup_radius"] and abs(self.player["pos"][1]-m[1])<=1.5:
                self.motes.remove(m); self.player["carried"]+=1; self.event("mote_picked",{"carried":self.player["carried"]})
        for c in self.charms:
            if self.respawn_ticks<=0 and c["available"] and dist(self.player["pos"],c["pos"])<=T["pickup_radius"] and abs(self.player["pos"][1]-c["pos"][1])<=1.5:
                c["available"]=False; c["respawn"]=2700; self.charm_ticks=600; self.event("charm_picked",{"charm_id":c["id"],"charm_ticks":self.charm_ticks})
        if self.respawn_ticks<=0 and self.buttons.get("interact") and not old.get("interact") and self.player["carried"]:
            candidates=[l for l in self.lanterns if not l["lit"] and dist(self.player["pos"],l["pos"])<=T["interact_radius"]]
            candidates.sort(key=lambda l:(dist(self.player["pos"],l["pos"]),l["id"]))
            if candidates:
                l=candidates[0]; amount=min(self.player["carried"],T["lantern_cost"]-l["deposited"]); l["deposited"]+=amount; self.player["carried"]-=amount; self.score+=amount*T["score"]["per_mote"]; self.event("deposit",{"lantern_id":l["id"],"amount":amount,"deposited":l["deposited"]})
                if l["deposited"]>=T["lantern_cost"]: l["lit"]=True; self.score+=T["score"]["per_lantern"]; self.event("lantern_lit",{"lantern_id":l["id"]})
        if self.respawn_ticks<=0 and self.buttons.get("pulse") and not old.get("pulse") and self.player["carried"]>=T["pulse_cost"] and self.tick-self.last_pulse>=T["pulse_cooldown_s"]*60:
            self.player["carried"]-=T["pulse_cost"]; self.last_pulse=self.tick; self.pulse_cd=int(T["pulse_cooldown_s"]*60); stunned=[]
            for s in self.shades:
                if dist3([self.player["pos"][0],self.player["pos"][1]+0.8,self.player["pos"][2]],s["pos"])<=T["pulse_radius"]:
                    s["stun"]=int(T["pulse_stun_s"]*60); s["state"]="stunned"; stunned.append(s["id"]); self.score+=T["score"]["per_stun"]
                    dx=s["pos"][0]-self.player["pos"][0]; dz=s["pos"][2]-self.player["pos"][2]; length=math.hypot(dx,dz)
                    s["push_dir"]=[dx/length,dz/length] if length else [1.0,0.0]
                    s["push_ticks"]=15
            for d in self.drifters:
                if dist3([self.player["pos"][0],self.player["pos"][1]+0.8,self.player["pos"][2]],d["pos"])<=T["pulse_radius"]:
                    if d["state"]=="chase":
                        d["state"]="flee"; d["flee_ticks"]=241
                    elif d["state"]=="flee" and d["stolen"]>0:
                        for _ in range(d["stolen"]):
                            self.motes.append([*d["pos"],f"M{self.next_mote_id}","dropped",480]); self.next_mote_id+=1
                        self.event("drifter_drop",{"drifter_id":d["id"],"amount":d["stolen"]})
                        d["stolen"]=0; d["state"]="flee"; d["flee_ticks"]=121
            self.event("pulse",{"stunned_ids":stunned})
        for d in self.drifters:
            if d["state"]=="removed": continue
            if d["state"]=="idle" and self.player["carried"]>=5 and dist(self.player["pos"],d["pos"])<=15: d["state"]="chase"
            elif d["state"]=="chase" and (self.player["carried"]<5 or dist(self.player["pos"],d["pos"])>15): d["state"]="idle"
            if d["state"]=="flee":
                dx=d["pos"][0]-self.player["pos"][0]; dz=d["pos"][2]-self.player["pos"][2]; ln=math.hypot(dx,dz) or 1
                d["pos"][0]+=dx/ln*7/60; d["pos"][2]+=dz/ln*7/60; d["flee_ticks"]-=1
                if d["flee_ticks"]<=0: d["state"]="removed"
            elif d["state"] in ("chase","idle"):
                dx=self.player["pos"][0]-d["pos"][0]; dz=self.player["pos"][2]-d["pos"][2]; ln=math.hypot(dx,dz) or 1; sp=7 if d["state"]=="chase" else 2
                d["pos"][0]+=dx/ln*sp/60; d["pos"][2]+=dz/ln*sp/60
            if d["state"]=="chase" and not d["robbed"] and dist(self.player["pos"],d["pos"])<=1.2:
                amount=min(3,self.player["carried"]); self.player["carried"]-=amount; d["stolen"]+=amount; d["robbed"]=True; d["state"]="flee"; d["flee_ticks"]=240; self.event("drifter_steal",{"drifter_id":d["id"],"amount":amount,"carried":self.player["carried"]})
        for s in self.shades:
            if s["spawn"]>0 or s["state"]=="spawning":
                if s["spawn"]<=0: s["spawn"]=60
                s["spawn"]-=1
                if s["spawn"]==0: s["state"]="wander"
                continue
            if s["stun"]>0:
                if s["push_ticks"]>0:
                    s["pos"][0]+=s["push_dir"][0]*T["pulse_push_m"]/15
                    s["pos"][2]+=s["push_dir"][1]*T["pulse_push_m"]/15
                    s["push_ticks"]-=1
                s["stun"]-=1; s["state"]="stunned"; continue
            if s["state"]=="stunned": s["state"]="wander"
            d=dist(self.player["pos"],s["pos"])
            if d<=12: s["state"]="chase"
            elif d>=18: s["state"]="wander"
            shade_speed=4.5 if self.night==3 else T["shade_speed"]
            if s["state"]=="chase" and d>0: s["pos"][0]+=(self.player["pos"][0]-s["pos"][0])/d*shade_speed/60; s["pos"][2]+=(self.player["pos"][2]-s["pos"][2])/d*shade_speed/60
            for lit in self.lanterns:
                safe_dist=dist(s["pos"],lit["pos"])
                if lit["lit"] and safe_dist<T["safe_radius"]:
                    dx=s["pos"][0]-lit["pos"][0]; dz=s["pos"][2]-lit["pos"][2]; ln=math.hypot(dx,dz) or 1
                    s["pos"][0]=lit["pos"][0]+dx/ln*T["safe_radius"]; s["pos"][2]=lit["pos"][2]+dz/ln*T["safe_radius"]
            d=dist(self.player["pos"],s["pos"])
            if d<=T["shade_hit_radius"] and abs(self.player["pos"][1]-s["pos"][1])<=1.5 and self.invuln<=0 and self.respawn_ticks<=0 and s["spawn"]==0:
                self.player["flames"]-=1; dropped=math.floor(self.player["carried"]/2); self.player["carried"]-=dropped
                dx=self.player["pos"][0]-s["pos"][0]; dz=self.player["pos"][2]-s["pos"][2]; length=math.hypot(dx,dz)
                self.recoil_dir=[dx/length,dz/length] if length else [1.0,0.0]
                self.recoil_ticks=61
                if dropped:
                    for _ in range(dropped):
                        angle=self.rng.random()*math.tau; radius=1.5+self.rng.random(); self.motes.append([self.player["pos"][0]+math.cos(angle)*radius,0,self.player["pos"][2]+math.sin(angle)*radius,f"M{self.next_mote_id}","dropped",480]); self.next_mote_id+=1
                self.invuln=90; self.event("player_hit",{"by":"shade","flames":self.player["flames"],"dropped":dropped})
        if self.random_motes and self.sim_tick>0 and self.sim_tick%240==0 and len(self.motes)<30:
            points=map_mote_points(self.night); occupied=[tuple(round(v,2) for v in m[:3]) for m in self.motes]
            free=[p for p in points if tuple(round(v,2) for v in p) not in occupied]
            if free:
                point=self.rng.choice(free); self.motes.append([*point,f"M{self.next_mote_id}","random",None]); self.next_mote_id+=1
        if self.night in (2,3) and self.random_drifters and self.sim_tick>0 and self.sim_tick%1200==0 and len([d for d in self.drifters if d['state']!='removed'])<2:
            did=f"D{self.next_drifter_id}"; self.next_drifter_id+=1
            point=map_mote_points(self.night)[self.rng.randrange(len(map_mote_points(self.night)))]
            self.drifters.append({"id":did,"pos":list(point),"state":"idle","stolen":0,"flee_ticks":0}); self.event("drifter_spawned",{"id":did})
        if self.random_shades:
            if self.night==1:
                slots=2 if self.sim_tick==300 else (1 if self.sim_tick>300 and (self.sim_tick-300)%480==0 else 0)
            else:
                interval=420 if self.night==2 else 360
                slots=1 if self.sim_tick>0 and self.sim_tick%interval==0 else 0
            for _ in range(slots):
                if len(self.shades)>=(6,8,10)[self.night-1]: break
                valid=[p for p in MAP_SHADE_POINTS[self.night] if dist(p,self.player["pos"])>=15]
                if valid: self.emit_shade_spawn(self.rng.choice(valid))
        if self.player["flames"]<=0: self.state="lost"; self.event("game_over",{"result":"lost","reason":"no_flames"})
        elif all(x["lit"] for x in self.lanterns): self.state="won"; self.score+=math.floor(self.time_left)*T["score"]["per_second_left"]+self.player["flames"]*T["score"]["per_flame_left"]; self.event("game_over",{"result":"won","reason":"all_lit"})
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
    except (OSError,ValueError,KeyError,TypeError) as e: print(f"invalid input: {e}",file=sys.stderr); return 2
    if a.night not in (1,2,3): print("night must be 1, 2 or 3",file=sys.stderr); return 2
    if a.ticks < 0 or a.snapshot_every < 1: print("ticks must be nonnegative and snapshot interval positive",file=sys.stderr); return 2
    try:
        if not isinstance(scenario,dict): raise ValueError("scenario root must be an object")
        if not isinstance(inputs,list): raise ValueError("inputs.frames must be an array")
        def valid_pos(value):
            return isinstance(value,list) and len(value)==3 and all(isinstance(v,(int,float)) and not isinstance(v,bool) and math.isfinite(v) for v in value)
        player=scenario.get("player",{})
        if not isinstance(player,dict): raise ValueError("scenario player must be an object")
        if "pos" in player and not valid_pos(player["pos"]): raise ValueError("player.pos must contain three finite numbers")
        for key in ("carried","flames","invuln_ticks","dash_cd_ticks","pulse_cd_ticks","charm_ticks"):
            if key in player and (not isinstance(player[key],int) or isinstance(player[key],bool) or player[key]<0): raise ValueError(f"player.{key} must be a nonnegative integer")
        if player.get("carried",0)>T["carry_capacity"]: raise ValueError("player.carried exceeds carry_capacity")
        if "time_left_s" in scenario and (not isinstance(scenario["time_left_s"],(int,float)) or not math.isfinite(scenario["time_left_s"]) or scenario["time_left_s"]<0): raise ValueError("time_left_s must be a nonnegative finite number")
        for flag in ("random_motes","random_shades","random_drifters","wind_enabled"):
            if flag in scenario and not isinstance(scenario[flag],bool): raise ValueError(f"{flag} must be boolean")
        for key in ("motes","shades","drifters","charms","lanterns"):
            if key in scenario and not isinstance(scenario[key],list): raise ValueError(f"scenario {key} must be an array")
        for mote in scenario.get("motes",[]):
            if not valid_pos(mote): raise ValueError("each mote must be a three-number position")
        for key in ("shades","drifters","charms","lanterns"):
            for item in scenario.get(key,[]):
                if not isinstance(item,dict): raise ValueError(f"each {key} item must be an object")
                if "pos" in item and not valid_pos(item["pos"]): raise ValueError(f"each {key}.pos must contain three finite numbers")
        if any(x.get("state","wander") not in {"spawning","wander","chase","recoil","stunned"} for x in scenario.get("shades",[])): raise ValueError("invalid shade state")
        if any(x.get("state","idle") not in {"idle","chase","flee","removed"} for x in scenario.get("drifters",[])): raise ValueError("invalid drifter state")
        previous=-1
        for frame in inputs:
            if not isinstance(frame,dict) or not isinstance(frame.get("tick"),int) or isinstance(frame.get("tick"),bool) or frame["tick"]<0 or frame["tick"]<=previous: raise ValueError("input frame ticks must be strictly increasing nonnegative integers")
            previous=frame["tick"]
            if "move" in frame and (not isinstance(frame["move"],list) or len(frame["move"])!=2 or any(not isinstance(v,(int,float)) or isinstance(v,bool) or not math.isfinite(v) or not -1<=v<=1 for v in frame["move"])): raise ValueError("move must be [x,z] with finite components in [-1,1]")
            if "cam_yaw_deg" in frame and (not isinstance(frame["cam_yaw_deg"],(int,float)) or not math.isfinite(frame["cam_yaw_deg"])): raise ValueError("cam_yaw_deg must be finite")
            for key in ("jump","interact","pulse","dash","pause"):
                if key in frame and not isinstance(frame[key],bool): raise ValueError(f"{key} must be boolean")
    except (ValueError,TypeError) as e: print(f"invalid input: {e}",file=sys.stderr); return 2
    frames={x["tick"]:x for x in inputs}
    sim=Sim(a.seed,scenario,a.night); rows=[sim.snapshot()]
    for _ in range(a.ticks):
        if sim.state in ("won", "lost"): break
        sim.step(frames.get(sim.tick,{}))
        rows.extend(sim.events); sim.events=[]
        if sim.tick % a.snapshot_every == 0: rows.append(sim.snapshot())
    rows.append({"type":"end","ticks":sim.tick,"state":sim.state,"score":sim.score})
    with open(a.out,"w",encoding="utf-8") as f:
        for row in rows: f.write(json.dumps(row,separators=(",",":"))+"\n")
    return 0
if __name__=="__main__": sys.exit(main())
