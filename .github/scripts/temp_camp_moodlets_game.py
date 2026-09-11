from pathlib import Path
p=Path('game/scripts/Game.gd')
t=p.read_text()
def r(a,b):
    global t
    assert a in t,a[:100]
    t=t.replace(a,b,1)
r('var recent_expedition_ids := []\n','var recent_expedition_ids := []\nvar fire_level := CampLifeRules.FIRE_START_LEVEL\n')
r('    recent_expedition_ids = []\n    camp_event_accum = 0.0\n','    recent_expedition_ids = []\n    fire_level = CampLifeRules.FIRE_START_LEVEL\n    camp_event_accum = 0.0\n')
r('        "stress": 10.0 if not founder else 5.0,\n        "condition": "Healthy",\n','        "stress": 10.0 if not founder else 5.0,\n        "needs": CampLifeRules.default_needs(),\n        "camp_activity": {},\n        "condition": "Healthy",\n')
r('    _process_survivors(delta)\n    _process_camp_chatter(delta)\n','    fire_level = maxf(0.0, fire_level - CampLifeRules.FIRE_DECAY_PER_SECOND * float(delta))\n    _process_survivors(delta)\n    _process_camp_chatter(delta)\n')
a=t.index('func _process_survivors(delta):')
b=t.index('\nfunc treat_survivor',a)
block='''func _process_survivors(delta):
    var pop:=population(); var capacity:=shelter_capacity()
    var hygiene_support:=bool(buildings.get("Rain Catcher",false)) or bool(buildings.get("Water Tank",false))
    for s in survivors:
        if s["condition"]=="Dead": continue
        if not s.has("needs"): s["needs"]=CampLifeRules.default_needs()
        if not s.has("camp_activity"): s["camp_activity"]={}
        var away:=["Expedition","Pending Expedition Event","Tactical Encounter"].has(str(s.get("status","Available")))
        var safety:=CampLifeRules.safety_target(buildings,pop,capacity,fire_level,away)
        s["needs"]=CampLifeRules.update_needs(s.get("needs",{}),float(s.get("fatigue",0.0)),float(delta),safety,hygiene_support,away)
        s["stress"]=clampf(float(s.get("stress",0.0))+CampLifeRules.need_stress_rate(s["needs"])*float(delta),0.0,100.0)
        if s["status"]=="Available":
            var caretaker:=false
            if leader_id!=-1:
                var leader:Variant=get_survivor(leader_id)
                caretaker=leader!=null and leader["leader_ability"]=="Caretaker"
            var recovery:=CampLifeRules.idle_recovery_rates(bool(buildings.get("Cabin",false)),caretaker,bool(buildings.get("Communal Table",false)))
            s["fatigue"]=max(0.0,float(s["fatigue"])-recovery.x*delta)
            s["stress"]=max(0.0,float(s["stress"])-recovery.y*delta)
            s["needs"]=CampLifeRules.update_needs(s["needs"],float(s["fatigue"]),0.0,safety,hygiene_support,false)
            _process_camp_activity(s,float(delta),pop,hygiene_support)
            if s["condition"]=="Hurt" or s["condition"]=="Wounded":
                s["injury_remaining"]=max(0.0,float(s["injury_remaining"])-delta*CampLifeRules.injury_recovery_multiplier(bool(buildings.get("Infirmary",false))))
                if s["injury_remaining"]<=0.0:
                    if s["condition"]=="Wounded":
                        s["condition"]="Hurt"; s["injury_remaining"]=60.0
                        s["history"].append("Day %d — Recovered from a serious wound." % day)
                    else:
                        s["condition"]="Healthy"
                        s["history"].append("Day %d — Recovered from minor injuries." % day)
        elif ["Crafting","Building","Recovering","Tending"].has(s["status"]):
            s["camp_activity"]={}
            if s["task"].is_empty(): s["status"]="Available"; continue
            s["task"]["remaining"]=max(0.0,float(s["task"]["remaining"])-delta)
            if float(s["task"]["remaining"])<=0.0: _complete_task(s)

func _process_camp_activity(s:Dictionary,delta:float,pop:int,hygiene_support:bool)->void:
    var activity:Dictionary=s.get("camp_activity",{})
    if activity.is_empty():
        activity=CampLifeRules.choose_available_activity(s.get("needs",{}),fire_level,int(resources.get("Wood",0)),pop,bool(buildings.get("Communal Table",false)),hygiene_support,rng)
        s["camp_activity"]=activity
        if activity.is_empty(): return
    activity["remaining"]=maxf(0.0,float(activity.get("remaining",0.0))-delta); s["camp_activity"]=activity
    if float(activity.get("remaining",0.0))>0.0: return
    var kind:=str(activity.get("kind",""))
    if kind=="maintain_fire":
        if int(resources.get("Wood",0))>0:
            resources["Wood"]=int(resources.get("Wood",0))-1
            fire_level=clampf(fire_level+CampLifeRules.FIRE_MAINTAIN_GAIN,0.0,100.0)
            s["stress"]=maxf(0.0,float(s.get("stress",0.0))-1.0)
    else:
        var result:=CampLifeRules.complete_activity(s.get("needs",{}),float(s.get("fatigue",0.0)),kind)
        s["needs"]=result.get("needs",s.get("needs",{})); s["fatigue"]=float(result.get("fatigue",s.get("fatigue",0.0)))
        if kind in ["watch_fire","cards","guitar"]: s["stress"]=maxf(0.0,float(s.get("stress",0.0))-2.0)
    s["camp_activity"]={}

func _clear_camp_activity(s)->void:
    if s!=null: s["camp_activity"]={}

func survivor_moodlets(survivor:Dictionary)->Array:
    return CampLifeRules.moodlets(survivor.get("needs",{}))
'''
t=t[:a]+block+t[b:]
r('    if s["condition"] == "Hurt":\n','    _clear_camp_activity(s)\n    if s["condition"] == "Hurt":\n')
r('    _pay(recipe.get("cost", {}), cc)\n    var duration = _work_duration','    _pay(recipe.get("cost", {}), cc)\n    _clear_camp_activity(s)\n    var duration = _work_duration')
r('    _pay(data.get("cost", {}), data.get("component_cost", {}))\n    var duration = _work_duration','    _pay(data.get("cost", {}), data.get("component_cost", {}))\n    _clear_camp_activity(s)\n    var duration = _work_duration')
r('    s["status"] = "Tending"\n','    _clear_camp_activity(s)\n    s["status"] = "Tending"\n')
r('        if s == null or s["status"] != "Available" or s["condition"] == "Dead":\n            return false\n','        if s == null or s["status"] != "Available" or s["condition"] == "Dead":\n            return false\n        _clear_camp_activity(s)\n')
r('    if buildings.get("Rain Catcher", false):\n','    var everyone_fed:=food_missing==0; var everyone_watered:=water_missing==0\n    for s in survivors:\n        if s["condition"]!="Dead": s["needs"]=CampLifeRules.apply_daily_rations(s.get("needs",{}),everyone_fed,everyone_watered)\n\n    if buildings.get("Rain Catcher", false):\n')
r('        "recent_expedition_ids": recent_expedition_ids,\n','        "recent_expedition_ids": recent_expedition_ids,\n        "fire_level": fire_level,\n')
r('    recent_expedition_ids = parsed.get("recent_expedition_ids", [])\n    # Returning to a saved game','    recent_expedition_ids = parsed.get("recent_expedition_ids", [])\n    fire_level=clampf(float(parsed.get("fire_level",CampLifeRules.FIRE_START_LEVEL)),0.0,100.0)\n    for s in survivors:\n        s["needs"]=CampLifeRules.normalize_needs(s.get("needs",{}))\n        if not s.has("camp_activity"): s["camp_activity"]={}\n    # Returning to a saved game')
r('    s["status"] = "Available"\n    s["task"] = {}\n    s["relationships"] = {}\n','    s["status"] = "Available"\n    s["task"] = {}\n    s["needs"] = CampLifeRules.normalize_needs(s.get("needs", {}))\n    s["camp_activity"] = {}\n    s["relationships"] = {}\n')
p.write_text(t)
