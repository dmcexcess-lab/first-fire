from pathlib import Path
import re


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected 1 match, found {count}: {old[:120]!r}")
    p.write_text(text.replace(old, new, 1))


def regex_once(path: str, pattern: str, replacement: str) -> None:
    p = Path(path)
    text = p.read_text()
    new_text, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f"{path}: expected 1 regex match, found {count}: {pattern[:120]!r}")
    p.write_text(new_text)

# New pure virus owner.
Path("game/scripts/FFVirusRules.gd").write_text('''extends RefCounted
class_name FFVirusRules

const STAGE_CLEAR := "Clear"
const STAGE_EXPOSED := "Exposed"
const STAGE_INFECTED := "Infected"
const STAGE_FEVERISH := "Feverish"
const STAGES := [STAGE_CLEAR, STAGE_EXPOSED, STAGE_INFECTED, STAGE_FEVERISH]
const EXPOSED_NATURAL_CLEAR_CHANCE := 0.30

static func default_state() -> Dictionary:
    return {"stage": STAGE_CLEAR, "days": 0, "quarantined": false}

static func normalize(value) -> Dictionary:
    var state := default_state()
    var incoming: Dictionary = value.duplicate(true) if value is Dictionary else {}
    var stage := str(incoming.get("stage", STAGE_CLEAR))
    if not STAGES.has(stage):
        stage = STAGE_CLEAR
    state["stage"] = stage
    state["days"] = maxi(0, int(incoming.get("days", 0)))
    state["quarantined"] = bool(incoming.get("quarantined", false)) if stage != STAGE_CLEAR else false
    return state

static func stage(value) -> String:
    return str(normalize(value)["stage"])

static func is_active(value) -> bool:
    return stage(value) != STAGE_CLEAR

static func is_severe(value) -> bool:
    return stage(value) == STAGE_FEVERISH

static func exposure_chance(infected_hits: int) -> float:
    if infected_hits <= 0:
        return 0.0
    return clampf(0.18 + float(infected_hits - 1) * 0.12, 0.18, 0.54)

static func expose(value) -> Dictionary:
    var state := normalize(value)
    if str(state["stage"]) == STAGE_CLEAR:
        state["stage"] = STAGE_EXPOSED
        state["days"] = 0
        state["quarantined"] = false
    return state

static func progress_day(value, rng: RandomNumberGenerator) -> Dictionary:
    var state := normalize(value)
    var event := ""
    match str(state["stage"]):
        STAGE_EXPOSED:
            state["days"] = int(state["days"]) + 1
            if rng.randf() < EXPOSED_NATURAL_CLEAR_CHANCE:
                state = default_state()
                event = "cleared"
            else:
                state["stage"] = STAGE_INFECTED
                state["days"] = 0
                event = "infected"
        STAGE_INFECTED:
            state["days"] = int(state["days"]) + 1
            if int(state["days"]) >= 1:
                state["stage"] = STAGE_FEVERISH
                state["days"] = 0
                event = "feverish"
        STAGE_FEVERISH:
            state["days"] = int(state["days"]) + 1
            if int(state["days"]) >= 1:
                event = "terminal"
    return {"state": state, "event": event}

static func spread_chance(value) -> float:
    var state := normalize(value)
    if bool(state["quarantined"]):
        return 0.0
    match str(state["stage"]):
        STAGE_INFECTED: return 0.06
        STAGE_FEVERISH: return 0.18
        _: return 0.0

static func treatment_plan(stage_name: String, has_infirmary: bool) -> Dictionary:
    match stage_name:
        STAGE_EXPOSED:
            return {
                "available": true,
                "id": "decontaminate",
                "label": "Exposure decontamination",
                "duration": 20.0,
                "resources": {"Clean Water": 1},
                "components": {"Sterile Dressing": 1},
                "summary": "1 Clean Water + 1 Sterile Dressing",
            }
        STAGE_INFECTED:
            return {
                "available": true,
                "id": "medicine_course",
                "label": "Zombie-virus medicine course",
                "duration": 60.0,
                "resources": {"Medicine": 1},
                "components": {},
                "summary": "1 Medicine",
            }
        STAGE_FEVERISH:
            if not has_infirmary:
                return {
                    "available": false,
                    "reason": "Feverish zombie-virus cases need an Infirmary and 2 Medicine.",
                    "summary": "Infirmary + 2 Medicine",
                }
            return {
                "available": true,
                "id": "emergency_course",
                "label": "Emergency zombie-virus treatment",
                "duration": 90.0,
                "resources": {"Medicine": 2},
                "components": {},
                "summary": "2 Medicine in the Infirmary",
            }
        _:
            return {"available": false, "reason": "No zombie-virus treatment is needed.", "summary": "None"}
''')

# Core orchestration: time scale, authoritative sleep, assignment gate, virus state.
path = "game/scripts/Game.gd"
replace_once(path,
'''const CampLifeRules = preload("res://scripts/FFCampLifeRules.gd")
const CampSocial = preload("res://scripts/FFCampSocial.gd")''',
'''const CampLifeRules = preload("res://scripts/FFCampLifeRules.gd")
const VirusRules = preload("res://scripts/FFVirusRules.gd")
const CampSocial = preload("res://scripts/FFCampSocial.gd")''')
replace_once(path,
'''const SAVE_SCHEMA_VERSION := 7
const DAY_SECONDS := 120.0
const MAX_POPULATION := 18''',
'''const SAVE_SCHEMA_VERSION := 7
const DAY_SECONDS := 120.0
const SIM_TIME_SCALE := 0.5
const MAX_POPULATION := 18''')
regex_once(path, r'''func _process\(delta\):\n.*?\nfunc _notification\(what\):''', '''func _process(delta):
    if not initialized or sim_paused or game_over:
        return
    var sim_delta: float = float(delta) * SIM_TIME_SCALE
    day_elapsed += sim_delta
    ui_emit_accum += delta
    autosave_accum += delta
    camp_event_accum += sim_delta
    if camp_event_cooldown > 0.0:
        camp_event_cooldown = max(0.0, camp_event_cooldown - sim_delta)

    fire_level = maxf(0.0, fire_level - CampLifeRules.FIRE_DECAY_PER_SECOND * sim_delta)
    camp_maintenance = maxf(0.0, camp_maintenance - CampLifeRules.CAMP_MAINTENANCE_DECAY_PER_SECOND * sim_delta)
    _process_pets(sim_delta)
    _process_survivors(sim_delta)
    _process_camp_chatter(sim_delta)
    _process_expeditions(sim_delta)

    if day_elapsed >= DAY_SECONDS:
        while day_elapsed >= DAY_SECONDS:
            day_elapsed -= DAY_SECONDS
            _daily_tick()

    if camp_event_accum >= CampLifeRules.CAMP_EVENT_INTERVAL:
        camp_event_accum -= CampLifeRules.CAMP_EVENT_INTERVAL
        _consider_camp_event()

    _consider_politics()
    _check_settlement_mature()

    if autosave_accum >= 10.0:
        autosave_accum = 0.0
        save_game()

    if ui_emit_accum >= 0.25:
        ui_emit_accum = 0.0
        tick.emit()

func _notification(what):''')
replace_once(path,
'''func available_survivors():
    var result = []
    for s in survivors:
        if s["condition"] != "Dead" and s["status"] == "Available":
            result.append(s)
    return result

func get_survivor(id) -> Variant:
    for s in survivors:
        if int(s["id"]) == int(id):
            return s
    return null
''',
'''func available_survivors():
    var result = []
    for s in survivors:
        if survivor_can_assign(s):
            result.append(s)
    return result

func get_survivor(id) -> Variant:
    for s in survivors:
        if int(s["id"]) == int(id):
            return s
    return null

func virus_state(survivor) -> Dictionary:
    if survivor == null:
        return VirusRules.default_state()
    return VirusRules.normalize(survivor.get("virus", {}))

func virus_stage(survivor) -> String:
    return str(virus_state(survivor)["stage"])

func _home_idle_status(survivor) -> String:
    var virus := virus_state(survivor)
    if bool(virus.get("quarantined", false)):
        return "Quarantined"
    if VirusRules.is_severe(virus):
        return "Sick"
    return "Available"

func survivor_can_assign(survivor) -> bool:
    if survivor == null or str(survivor.get("condition", "Dead")) == "Dead":
        return false
    if str(survivor.get("status", "Available")) != "Available":
        return false
    if not survivor.get("task", {}).is_empty():
        return false
    var virus := virus_state(survivor)
    return not bool(virus.get("quarantined", false)) and not VirusRules.is_severe(virus)

func _normalize_survivor_health_state(survivor) -> void:
    if survivor == null:
        return
    survivor["virus"] = VirusRules.normalize(survivor.get("virus", {}))
    if not survivor.has("task"):
        survivor["task"] = {}
    if not survivor.has("camp_activity"):
        survivor["camp_activity"] = {}
    var activity: Dictionary = survivor.get("camp_activity", {})
    if str(survivor.get("status", "Available")) == "Available" and str(activity.get("kind", "")) == "rest":
        survivor["camp_activity"] = {}
        survivor["status"] = "Sleeping"
        survivor["task"] = {
            "kind": "sleep",
            "label": "Sleeping",
            "remaining": maxf(0.1, float(activity.get("remaining", 7.0))),
            "duration": maxf(0.1, float(activity.get("duration", 7.0))),
        }
        return
    if str(survivor.get("status", "Available")) in ["Available", "Quarantined", "Sick"] and survivor.get("task", {}).is_empty():
        survivor["status"] = _home_idle_status(survivor)
''')
replace_once(path,
'''        "condition": "Healthy",
        "injury_remaining": 0.0,
        "status": "Available",''',
'''        "condition": "Healthy",
        "injury_remaining": 0.0,
        "virus": VirusRules.default_state(),
        "status": "Available",''')
replace_once(path,
'''    s["status"] = "Available"
    s["task"] = {}
    s["needs"] = CampLifeRules.normalize_needs(s.get("needs", {}))
    s["camp_activity"] = {}''',
'''    s["status"] = "Available"
    s["task"] = {}
    s["needs"] = CampLifeRules.normalize_needs(s.get("needs", {}))
    s["virus"] = VirusRules.normalize(s.get("virus", {}))
    s["camp_activity"] = {}''')
regex_once(path, r'''func _process_survivors\(delta\):\n.*?\nfunc _clear_camp_activity\(s\)->void:''', '''func _process_survivors(delta):
    var pop: int = int(population())
    var capacity: int = int(shelter_capacity())
    var hygiene_support:=bool(buildings.get("Rain Catcher",false)) or bool(buildings.get("Water Tank",false))
    for s in survivors:
        if s["condition"]=="Dead": continue
        if not s.has("needs"): s["needs"]=CampLifeRules.default_needs()
        _normalize_survivor_health_state(s)
        var status := str(s.get("status","Available"))
        var away:=["Expedition","Pending Expedition Event","Tactical Encounter"].has(status)
        var safety:=CampLifeRules.safety_target(buildings,pop,capacity,fire_level,away,camp_maintenance)
        s["needs"]=CampLifeRules.update_needs(s.get("needs",{}),float(s.get("fatigue",0.0)),float(delta),safety,hygiene_support,away)
        s["stress"]=clampf(float(s.get("stress",0.0))+CampLifeRules.need_stress_rate(s["needs"])*float(delta),0.0,100.0)
        var caretaker:=false
        if leader_id!=-1:
            var leader:Variant=get_survivor(leader_id)
            caretaker=leader!=null and leader["leader_ability"]=="Caretaker"
        var recovery:=CampLifeRules.idle_recovery_rates(bool(buildings.get("Cabin",false)),caretaker,bool(buildings.get("Communal Table",false)))
        if status=="Available":
            s["fatigue"]=max(0.0,float(s["fatigue"])-recovery.x*delta)
            s["stress"]=max(0.0,float(s["stress"])-recovery.y*delta)
            s["needs"]=CampLifeRules.update_needs(s["needs"],float(s["fatigue"]),0.0,safety,hygiene_support,false)
            _process_camp_activity(s,float(delta),pop,hygiene_support)
        elif ["Sick","Quarantined"].has(status):
            s["camp_activity"]={}
            s["fatigue"]=max(0.0,float(s["fatigue"])-recovery.x*delta*0.6)
            s["stress"]=max(0.0,float(s["stress"])-recovery.y*delta*0.6)
        elif ["Chore","Pet Care"].has(status):
            s["camp_activity"]={}
            if s["task"].is_empty(): s["status"]=_home_idle_status(s)
        elif ["Crafting","Building","Recovering","Tending","Sleeping"].has(status):
            s["camp_activity"]={}
            if s["task"].is_empty(): s["status"]=_home_idle_status(s); continue
            s["task"]["remaining"]=max(0.0,float(s["task"]["remaining"])-delta)
            if float(s["task"]["remaining"])<=0.0: _complete_task(s)
        if str(s.get("status","")) in ["Available","Sleeping"] and (s["condition"]=="Hurt" or s["condition"]=="Wounded"):
            s["injury_remaining"]=max(0.0,float(s["injury_remaining"])-delta*CampLifeRules.injury_recovery_multiplier(bool(buildings.get("Infirmary",false))))
            if s["injury_remaining"]<=0.0:
                if s["condition"]=="Wounded":
                    s["condition"]="Hurt"; s["injury_remaining"]=60.0
                    s["history"].append("Day %d — Recovered from a serious wound." % day)
                else:
                    s["condition"]="Healthy"
                    s["history"].append("Day %d — Recovered from minor injuries." % day)

func _process_camp_activity(s:Dictionary,delta:float,pop:int,hygiene_support:bool)->void:
    var activity:Dictionary=s.get("camp_activity",{})
    if activity.is_empty():
        activity=CampLifeRules.choose_available_activity(s.get("needs",{}),fire_level,int(resources.get("Wood",0)),pop,bool(buildings.get("Communal Table",false)),hygiene_support,rng)
        if activity.is_empty(): return
        if str(activity.get("kind",""))=="rest":
            s["camp_activity"]={}
            s["status"]="Sleeping"
            s["task"]={
                "kind":"sleep",
                "label":"Sleeping",
                "remaining":maxf(0.1,float(activity.get("remaining",7.0))),
                "duration":maxf(0.1,float(activity.get("duration",7.0))),
            }
            return
        s["camp_activity"]=activity
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

func _clear_camp_activity(s)->void:''')
replace_once(path,
'''func pet_mood_label(pet:Dictionary)->String:
    return CampLifeRules.pet_mood(pet.get("needs",{}))

func _generate_pet_candidate()->Dictionary:''',
'''func pet_mood_label(pet:Dictionary)->String:
    return CampLifeRules.pet_mood(pet.get("needs",{}))

func _expose_survivor(survivor, source_note: String) -> bool:
    if survivor == null or str(survivor.get("condition", "Dead")) == "Dead" or virus_stage(survivor) != VirusRules.STAGE_CLEAR:
        return false
    survivor["virus"] = VirusRules.expose(survivor.get("virus", {}))
    survivor["history"].append("Day %d — Zombie-virus exposure: %s." % [day, source_note])
    _add_history("Day %d — %s was exposed to the zombie virus." % [day, survivor["name"]])
    return true

func quarantine_survivor(sid: int) -> bool:
    var survivor: Variant = get_survivor(sid)
    if survivor == null or survivor["condition"] == "Dead" or virus_stage(survivor) == VirusRules.STAGE_CLEAR:
        return false
    if str(survivor.get("status", "Available")) not in ["Available", "Sick"] or not survivor.get("task", {}).is_empty():
        toast_requested.emit("%s is busy and cannot enter quarantine yet." % survivor["name"])
        return false
    var virus := virus_state(survivor)
    virus["quarantined"] = true
    survivor["virus"] = virus
    _clear_camp_activity(survivor)
    survivor["status"] = "Quarantined"
    survivor["history"].append("Day %d — Entered quarantine for zombie-virus exposure." % day)
    toast_requested.emit("%s is quarantined and unavailable for assignments." % survivor["name"])
    save_game(); state_changed.emit(); return true

func start_virus_treatment(sid: int) -> bool:
    var survivor: Variant = get_survivor(sid)
    if survivor == null or survivor["condition"] == "Dead":
        return false
    var stage_name := virus_stage(survivor)
    if stage_name == VirusRules.STAGE_CLEAR:
        return false
    if str(survivor.get("status", "Available")) not in ["Available", "Quarantined", "Sick"] or not survivor.get("task", {}).is_empty():
        toast_requested.emit("%s is already occupied." % survivor["name"])
        return false
    var plan: Dictionary = VirusRules.treatment_plan(stage_name, bool(buildings.get("Infirmary", false)))
    if not bool(plan.get("available", false)):
        toast_requested.emit(str(plan.get("reason", "Virus treatment is not available.")))
        return false
    var resource_cost: Dictionary = plan.get("resources", {})
    var component_cost: Dictionary = plan.get("components", {})
    if not _can_pay(resource_cost, component_cost):
        toast_requested.emit("Virus treatment needs %s." % str(plan.get("summary", "medical supplies")))
        return false
    _pay(resource_cost, component_cost)
    _clear_camp_activity(survivor)
    var virus := virus_state(survivor)
    virus["quarantined"] = true
    survivor["virus"] = virus
    survivor["status"] = "Recovering"
    survivor["task"] = {
        "kind": "virus_treatment",
        "label": str(plan.get("label", "Virus treatment")),
        "remaining": float(plan.get("duration", 60.0)),
        "duration": float(plan.get("duration", 60.0)),
        "target": sid,
    }
    survivor["history"].append("Day %d — Began %s." % [day, str(plan.get("label", "zombie-virus treatment")).to_lower()])
    toast_requested.emit("%s started %s." % [survivor["name"], str(plan.get("label", "virus treatment")).to_lower()])
    save_game(); state_changed.emit(); return true

func _process_daily_virus() -> void:
    for survivor in survivors:
        if survivor["condition"] == "Dead":
            continue
        survivor["virus"] = VirusRules.normalize(survivor.get("virus", {}))
        if virus_stage(survivor) == VirusRules.STAGE_CLEAR:
            continue
        if str(survivor.get("task", {}).get("kind", "")) == "virus_treatment":
            continue
        var progressed: Dictionary = VirusRules.progress_day(survivor["virus"], rng)
        survivor["virus"] = progressed.get("state", survivor["virus"])
        var event := str(progressed.get("event", ""))
        match event:
            "cleared":
                if str(survivor.get("status", "")) in ["Quarantined", "Sick"] and survivor.get("task", {}).is_empty():
                    survivor["status"] = "Available"
                survivor["history"].append("Day %d — Cleared a zombie-virus exposure without progressing." % day)
                toast_requested.emit("%s cleared the zombie-virus exposure." % survivor["name"])
            "infected":
                survivor["fatigue"] = minf(100.0, float(survivor.get("fatigue", 0.0)) + 12.0)
                survivor["stress"] = minf(100.0, float(survivor.get("stress", 0.0)) + 8.0)
                survivor["history"].append("Day %d — Zombie-virus infection established." % day)
                toast_requested.emit("%s is now infected. Medicine can still stop it." % survivor["name"])
            "feverish":
                survivor["fatigue"] = minf(100.0, float(survivor.get("fatigue", 0.0)) + 25.0)
                survivor["stress"] = minf(100.0, float(survivor.get("stress", 0.0)) + 15.0)
                if str(survivor.get("status", "")) == "Available":
                    _clear_camp_activity(survivor)
                    survivor["status"] = "Quarantined" if bool(virus_state(survivor).get("quarantined", false)) else "Sick"
                survivor["history"].append("Day %d — Zombie-virus fever became severe." % day)
                toast_requested.emit("%s is feverish. Without Infirmary treatment, the next day can be fatal." % survivor["name"])
            "terminal":
                _kill_survivor(survivor, "turned after an untreated zombie-virus infection")
    _spread_camp_virus()

func _spread_camp_virus() -> void:
    var candidates: Array = []
    for survivor in survivors:
        if survivor["condition"] == "Dead" or virus_stage(survivor) != VirusRules.STAGE_CLEAR:
            continue
        if str(survivor.get("status", "Available")) in ["Expedition", "Pending Expedition Event", "Tactical Encounter"]:
            continue
        candidates.append(survivor)
    if candidates.is_empty():
        return
    for source in survivors:
        if source["condition"] == "Dead":
            continue
        var chance := VirusRules.spread_chance(source.get("virus", {}))
        if chance <= 0.0 or rng.randf() >= chance or candidates.is_empty():
            continue
        var target: Variant = candidates[rng.randi_range(0, candidates.size() - 1)]
        if _expose_survivor(target, "close contact with an unquarantined infected campmate"):
            target["stress"] = minf(100.0, float(target.get("stress", 0.0)) + 8.0)
            toast_requested.emit("%s was exposed in camp. Quarantine infected survivors to prevent close-contact spread." % target["name"])
            candidates.erase(target)

func _generate_pet_candidate()->Dictionary:''')
replace_once(path, '    if s==null or s["status"]!="Available": return false\n', '    if not survivor_can_assign(s): return false\n')
replace_once(path, '    if s==null or s["status"]!="Available" or pet==null: return false\n', '    if not survivor_can_assign(s) or pet==null: return false\n')
replace_once(path,
'''    if s["status"] != "Available":
        return false''',
'''    if not survivor_can_assign(s):
        return false''')
replace_once(path, '        if s["status"] == "Available":\n            best = max(best, int(s["skills"].get(skill, 0)))\n', '        if survivor_can_assign(s):\n            best = max(best, int(s["skills"].get(skill, 0)))\n')
replace_once(path,
'''    var task = s["task"].duplicate(true)
    s["task"] = {}
    s["status"] = "Available"
    var kind = task.get("kind", "")''',
'''    var task = s["task"].duplicate(true)
    s["task"] = {}
    var kind = task.get("kind", "")''')
replace_once(path,
'''    elif kind == "treatment":
        if s["condition"] == "Critical":''',
'''    elif kind == "sleep":
        var sleep_result:=CampLifeRules.complete_activity(s.get("needs",{}),float(s.get("fatigue",0.0)),"rest")
        s["needs"]=sleep_result.get("needs",s.get("needs",{}))
        s["fatigue"]=float(sleep_result.get("fatigue",s.get("fatigue",0.0)))
    elif kind == "virus_treatment":
        s["virus"] = VirusRules.default_state()
        s["history"].append("Day %d — Completed zombie-virus treatment and tested clear." % day)
        toast_requested.emit("%s completed zombie-virus treatment and is clear." % s["name"])
    elif kind == "treatment":
        if s["condition"] == "Critical":''')
replace_once(path, '        s["status"] = "Available"\n        toast_requested.emit("%s\'s treatment is complete." % s["name"])\n    save_game()\n', '        toast_requested.emit("%s\'s treatment is complete." % s["name"])\n    if s["condition"] != "Dead":\n        s["status"] = _home_idle_status(s)\n    save_game()\n')
replace_once(path,
'''func start_craft(sid, station, recipe_id):
    var s: Variant = get_survivor(sid)
    if s == null or s["status"] != "Available":
        return false''',
'''func start_craft(sid, station, recipe_id):
    var s: Variant = get_survivor(sid)
    if not survivor_can_assign(s):
        return false''')
replace_once(path,
'''func start_build(sid, building):
    var s: Variant = get_survivor(sid)
    if s == null or s["status"] != "Available":
        return false''',
'''func start_build(sid, building):
    var s: Variant = get_survivor(sid)
    if not survivor_can_assign(s):
        return false''')
replace_once(path,
'''    var s: Variant = get_survivor(sid)
    if s == null or s["status"] != "Available":
        return false
    _clear_camp_activity(s)
    s["status"] = "Tending"''',
'''    var s: Variant = get_survivor(sid)
    if not survivor_can_assign(s):
        return false
    _clear_camp_activity(s)
    s["status"] = "Tending"''')
replace_once(path,
'''func equip_gear(sid, gear_name):
    var s: Variant = get_survivor(sid)
    if s == null or not inventory_gear.has(gear_name) or not D.GEAR.has(gear_name):
        return false''',
'''func equip_gear(sid, gear_name):
    var s: Variant = get_survivor(sid)
    if not survivor_can_assign(s) or not inventory_gear.has(gear_name) or not D.GEAR.has(gear_name):
        return false''')
replace_once(path,
'''        var s: Variant = get_survivor(sid)
        if s == null or s["status"] != "Available" or s["condition"] == "Dead":
            return false''',
'''        var s: Variant = get_survivor(sid)
        if not survivor_can_assign(s):
            return false''')
replace_once(path,
'''        var s: Variant = get_survivor(sid)
        if s == null or s["status"] != "Available":
            return false
    var duration = float(D.SPECIAL_SITES[site]["duration"])''',
'''        var s: Variant = get_survivor(sid)
        if not survivor_can_assign(s):
            return false
    var duration = float(D.SPECIAL_SITES[site]["duration"])''')
replace_once(path,
'''        lead["stress"] = min(100.0, float(lead["stress"]) + min(18.0, float(result.get("damage", 0)) * 1.5))
        var combat_xp := mini(20, int(result.get("kills", 0)) * 2 + int(result.get("melee", 0)) + int(result.get("shots", 0)))''',
'''        lead["stress"] = min(100.0, float(lead["stress"]) + min(18.0, float(result.get("damage", 0)) * 1.5))
        var infected_hits := int(result.get("infected_hits", 0))
        if infected_hits > 0 and lead["condition"] != "Dead" and virus_stage(lead) == VirusRules.STAGE_CLEAR:
            var exposure_chance := VirusRules.exposure_chance(infected_hits)
            if rng.randf() < exposure_chance:
                _expose_survivor(lead, "%d direct infected hit%s in the field" % [infected_hits, "" if infected_hits == 1 else "s"])
                lead["stress"] = minf(100.0, float(lead.get("stress", 0.0)) + 10.0)
                toast_requested.emit("%s was exposed to the zombie virus. Early decontamination can stop it." % lead["name"])
        var combat_xp := mini(20, int(result.get("kills", 0)) * 2 + int(result.get("melee", 0)) + int(result.get("shots", 0)))''')
text = Path(path).read_text()
for old, new in [
('            s["status"] = "Available"\n            s["task"] = {}\n    expeditions.erase(exp)', '            s["status"] = _home_idle_status(s)\n            s["task"] = {}\n    expeditions.erase(exp)'),
('        s["status"] = "Available"\n        s["task"] = {}\n        s["fatigue"] = min(100.0, float(s["fatigue"]) + CampLifeRules.fatigue_gain(float(D.ZONES[zone]["fatigue"])))', '        s["status"] = _home_idle_status(s)\n        s["task"] = {}\n        s["fatigue"] = min(100.0, float(s["fatigue"]) + CampLifeRules.fatigue_gain(float(D.ZONES[zone]["fatigue"])))'),
('                s["status"] = "Available"\n                s["task"] = {}\n                s["fatigue"] = min(100.0, float(s["fatigue"]) + float(D.ZONES[exp["zone"]]["fatigue"]))', '                s["status"] = _home_idle_status(s)\n                s["task"] = {}\n                s["fatigue"] = min(100.0, float(s["fatigue"]) + float(D.ZONES[exp["zone"]]["fatigue"]))'),
('                s["status"] = "Available"\n                s["task"] = {}\n        expeditions.erase(exp)', '                s["status"] = _home_idle_status(s)\n                s["task"] = {}\n        expeditions.erase(exp)'),
]:
    if old not in text:
        raise SystemExit(f"{path}: missing return-status block {old[:80]!r}")
    text = text.replace(old, new, 1)
Path(path).write_text(text)
replace_once(path,
'''    for s in survivors:
        if s["condition"] == "Critical" and s["status"] != "Recovering" and rng.randf() < CampLifeRules.critical_decline_chance(bool(buildings.get("Infirmary", false))):''',
'''    _process_daily_virus()

    for s in survivors:
        if s["condition"] == "Critical" and s["status"] != "Recovering" and rng.randf() < CampLifeRules.critical_decline_chance(bool(buildings.get("Infirmary", false))):''')
replace_once(path,
'''    for s in survivors:
        s["needs"]=CampLifeRules.normalize_needs(s.get("needs",{}))
        if not s.has("camp_activity"): s["camp_activity"]={}
    # Returning to a saved game is always paused until the player explicitly resumes.''',
'''    for s in survivors:
        s["needs"]=CampLifeRules.normalize_needs(s.get("needs",{}))
        _normalize_survivor_health_state(s)
    # Returning to a saved game is always paused until the player explicitly resumes.''')

path = "game/scripts/GameThreeStat.gd"
replace_once(path, '        "condition": "Healthy", "injury_remaining": 0.0, "status": "Available", "task": {},', '        "condition": "Healthy", "injury_remaining": 0.0, "virus": VirusRules.default_state(), "status": "Available", "task": {},')
replace_once(path, '    if s == null or s["condition"] in ["Healthy", "Dead"] or s["status"] != "Available": return false', '    if s == null or s["condition"] in ["Healthy", "Dead"] or not survivor_can_assign(s): return false')
replace_once(path, '    if s == null or s["status"] != "Available" or s["condition"] == "Dead": return false', '    if not survivor_can_assign(s): return false')

path = "game/scripts/FFCombat.gd"
replace_once(path, 'var stats := {"kills": 0, "shots": 0, "melee": 0, "shoves": 0, "searches": 0, "containers": 0, "noise": 0, "damage": 0}', 'var stats := {"kills": 0, "shots": 0, "melee": 0, "shoves": 0, "searches": 0, "containers": 0, "noise": 0, "damage": 0, "infected_hits": 0}')
replace_once(path, '    stats = {"kills": 0, "shots": 0, "melee": 0, "shoves": 0, "searches": 0, "containers": 0, "noise": 0, "damage": 0}', '    stats = {"kills": 0, "shots": 0, "melee": 0, "shoves": 0, "searches": 0, "containers": 0, "noise": 0, "damage": 0, "infected_hits": 0}')
replace_once(path, '    tick = int(runtime.get("tick", tick))\n\n    var open_doors: Array = runtime.get("open_doors", [])', '    tick = int(runtime.get("tick", tick))\n    stats["infected_hits"] = int(runtime.get("infected_hits", stats.get("infected_hits", 0)))\n\n    var open_doors: Array = runtime.get("open_doors", [])')
replace_once(path, '        "container_state": saved_containers,\n        "tick": tick,\n        "zombies": zsave,', '        "container_state": saved_containers,\n        "infected_hits": int(stats.get("infected_hits", 0)),\n        "tick": tick,\n        "zombies": zsave,')
replace_once(path, '        if target_actor.controlled:\n            stats.damage += dmg\n            msg = "The infected breaks through your guard for %d." % dmg if guarded else "The infected hits you for %d." % dmg', '        if target_actor.controlled:\n            stats.damage += dmg\n            stats["infected_hits"] = int(stats.get("infected_hits", 0)) + 1\n            msg = "The infected breaks through your guard for %d." % dmg if guarded else "The infected hits you for %d." % dmg')
replace_once(path, '        "kills": int(stats.kills), "shots": int(stats.shots), "melee": int(stats.get("melee", 0)), "shoves": int(stats.get("shoves", 0)), "damage": int(stats.damage),', '        "kills": int(stats.kills), "shots": int(stats.shots), "melee": int(stats.get("melee", 0)), "shoves": int(stats.get("shoves", 0)), "damage": int(stats.damage), "infected_hits": int(stats.get("infected_hits", 0)),')

path = "game/scripts/FFCombatThreeStat.gd"
replace_once(path, '        if target_actor.controlled:\n            stats.damage += dmg\n            msg = "The infected hits you for %d." % dmg', '        if target_actor.controlled:\n            stats.damage += dmg\n            stats["infected_hits"] = int(stats.get("infected_hits", 0)) + 1\n            msg = "The infected hits you for %d." % dmg')

path = "game/scripts/FFCampSocial.gd"
replace_once(path,
'''        var status := str(survivor.get("status", "Available"))
        if status in ["Expedition", "Pending Expedition Event", "Tactical Encounter"]: continue
        var task: Dictionary = survivor.get("task", {})
        if task.has("expedition_id"): continue
        result.append(survivor)''',
'''        var status := str(survivor.get("status", "Available"))
        if status != "Available": continue
        var task: Dictionary = survivor.get("task", {})
        if not task.is_empty(): continue
        result.append(survivor)''')

path = "game/scripts/FFCampView.gd"
replace_once(path, 'func _spawn_cell(sid: int) -> Vector2i:\n    return IDLE_CELLS[posmod(sid, IDLE_CELLS.size())]\n\nfunc _target_cell(survivor: Dictionary) -> Vector2i:', '''func _spawn_cell(sid: int) -> Vector2i:
    return IDLE_CELLS[posmod(sid, IDLE_CELLS.size())]

func _sleep_slots() -> Array:
    var slots: Array = [SLEEP_CELL]
    if bool(Game.buildings.get("Makeshift Shelter", false)):
        slots.append_array([Vector2i(3,6), Vector2i(4,6)])
    if bool(Game.buildings.get("Cabin", false)):
        slots.append_array([Vector2i(11,5), Vector2i(12,5), Vector2i(13,5), Vector2i(12,6)])
    if bool(Game.buildings.get("Bunkhouse", false)):
        slots.append_array([Vector2i(2,7), Vector2i(3,7), Vector2i(4,7), Vector2i(2,8), Vector2i(3,8), Vector2i(4,8)])
    if bool(Game.buildings.get("Dormitory", false)):
        slots.append_array([Vector2i(9,7), Vector2i(10,7), Vector2i(11,7), Vector2i(9,8), Vector2i(11,8)])
    return slots

func _sleep_cell_for_survivor(survivor: Dictionary) -> Vector2i:
    var slots := _sleep_slots()
    var living_ids: Array = []
    for value in Game.survivors:
        if str(value.get("condition", "Dead")) != "Dead":
            living_ids.append(int(value.get("id", -1)))
    living_ids.sort()
    var index := living_ids.find(int(survivor.get("id", -1)))
    if index < 0:
        index = 0
    return slots[posmod(index, slots.size())]

func _target_cell(survivor: Dictionary) -> Vector2i:''')
replace_once(path, '    if status == "Tending":\n        return building_cell("Garden Plot") + Vector2i(1, 0)\n    if status == "Recovering":\n        return Vector2i(12, 6) if bool(Game.buildings.get("Cabin", false)) else SLEEP_CELL\n    var camp_activity: Dictionary = survivor.get("camp_activity", {})', '    if status == "Tending":\n        return building_cell("Garden Plot") + Vector2i(1, 0)\n    if status == "Sleeping":\n        return _sleep_cell_for_survivor(survivor)\n    if status == "Recovering":\n        return building_cell("Infirmary") + Vector2i(-1, 0) if bool(Game.buildings.get("Infirmary", false)) else _sleep_cell_for_survivor(survivor)\n    if status in ["Quarantined", "Sick"]:\n        return building_cell("Infirmary") + Vector2i(1, 0) if bool(Game.buildings.get("Infirmary", false)) else Vector2i(16, 7)\n    var camp_activity: Dictionary = survivor.get("camp_activity", {})')
replace_once(path, '        "maintain_fire", "watch_fire": return FIRE_CELL + Vector2i(0, 1)\n        "rest": return Vector2i(12, 6) if bool(Game.buildings.get("Cabin", false)) else SLEEP_CELL\n        "wash": return building_cell("Water Tank") + Vector2i(1, 0) if bool(Game.buildings.get("Water Tank", false)) else building_cell("Rain Catcher") + Vector2i(1, 0)\n    if float(survivor.get("fatigue", 0.0)) >= 78.0:\n        return Vector2i(12, 6) if bool(Game.buildings.get("Cabin", false)) else SLEEP_CELL', '        "maintain_fire", "watch_fire": return FIRE_CELL + Vector2i(0, 1)\n        "rest": return _sleep_cell_for_survivor(survivor)\n        "wash": return building_cell("Water Tank") + Vector2i(1, 0) if bool(Game.buildings.get("Water Tank", false)) else building_cell("Rain Catcher") + Vector2i(1, 0)')
replace_once(path, '        var scale: float = clampf(tile / 32.0, 0.70, 1.18)\n        draw_set_transform(center, 0.0, Vector2(scale, scale))\n        Visuals.draw_survivor(self, Vector2.ZERO, actor, false)', '        var scale: float = clampf(tile / 32.0, 0.70, 1.18)\n        var sleeping := status == "Sleeping"\n        draw_set_transform(center, PI * 0.5 if sleeping else 0.0, Vector2(scale, scale))\n        Visuals.draw_survivor(self, Vector2.ZERO, actor, false)')
replace_once(path, 'func _draw_activity_graphic(survivor: Dictionary, center: Vector2, tile: float) -> void:\n    var activity: Dictionary = survivor.get("camp_activity", {})\n    var kind := str(activity.get("kind", ""))', '''func _draw_activity_graphic(survivor: Dictionary, center: Vector2, tile: float) -> void:
    var status := str(survivor.get("status", "Available"))
    var task: Dictionary = survivor.get("task", {})
    if status == "Sleeping":
        var font := get_theme_default_font()
        var z_size: int = maxi(8, int(tile * 0.34))
        draw_string(font, center + Vector2(tile * 0.16, -tile * 0.25), "Z", HORIZONTAL_ALIGNMENT_LEFT, -1.0, z_size, Color(0.72, 0.82, 0.92, 0.90))
        draw_string(font, center + Vector2(tile * 0.30, -tile * 0.42), "z", HORIZONTAL_ALIGNMENT_LEFT, -1.0, maxi(7, z_size - 2), Color(0.72, 0.82, 0.92, 0.72))
        return
    if str(task.get("kind", "")) == "virus_treatment":
        draw_line(center + Vector2(-tile*0.18, 0), center + Vector2(tile*0.18, 0), Color(0.72,0.94,0.88,0.90), maxf(2.0,tile*0.07))
        draw_line(center + Vector2(0, -tile*0.18), center + Vector2(0, tile*0.18), Color(0.72,0.94,0.88,0.90), maxf(2.0,tile*0.07))
        return
    if status in ["Quarantined", "Sick"]:
        draw_arc(center, tile*0.34, 0.0, TAU, 20, Color(0.90,0.58,0.30,0.88), maxf(1.0,tile*0.05))
        return
    var activity: Dictionary = survivor.get("camp_activity", {})
    var kind := str(activity.get("kind", ""))''')
replace_once(path, '    match status:\n        "Crafting": return "CRAFT"\n        "Building": return "BUILD"\n        "Recovering": return "RECOVER"\n        "Tending": return "GARDEN"', '    match status:\n        "Crafting": return "CRAFT"\n        "Building": return "BUILD"\n        "Sleeping": return "SLEEP"\n        "Recovering": return "VIRUS CARE" if str(survivor.get("task", {}).get("kind", "")) == "virus_treatment" else "RECOVER"\n        "Quarantined": return "QUARANTINE"\n        "Sick": return "FEVER"\n        "Tending": return "GARDEN"')
replace_once(path, '    match str(a.get("kind", "")):\n        "maintain_fire": return "FIRE"\n        "watch_fire": return "WATCH FIRE"\n        "rest": return "REST"\n        "wash": return "WASH"\n    return ""', '    match str(a.get("kind", "")):\n        "maintain_fire": return "FIRE"\n        "watch_fire": return "WATCH FIRE"\n        "rest": return "REST"\n        "wash": return "WASH"\n    var virus_stage := Game.virus_stage(survivor)\n    return virus_stage.to_upper() if virus_stage != "Clear" else ""')

path = "game/scripts/FFSurvivorPanel.gd"
replace_once(path, '    var condition_label = _make_label(condition.to_upper(), 11)\n', '    var condition_label = _make_label(_condition_text(survivor), 11)\n')
replace_once(path, '    var vitals_label = _make_label("Fatigue %.0f  •  Stress %.0f" % [float(survivor.get("fatigue", 0.0)), float(survivor.get("stress", 0.0))], 12)', '    var vitals_label = _make_label(_vitals_text(survivor), 12)')
replace_once(path, '        send.disabled = status != "Available"\n', '        send.disabled = not Game.survivor_can_assign(survivor)\n')
replace_once(path, '            condition_labels[sid].text = condition.to_upper()\n', '            condition_labels[sid].text = _condition_text(survivor)\n')
replace_once(path, '            vitals_labels[sid].text = "Fatigue %.0f  •  Stress %.0f" % [float(survivor.get("fatigue", 0.0)), float(survivor.get("stress", 0.0))]', '            vitals_labels[sid].text = _vitals_text(survivor)')
replace_once(path, '            send_buttons[sid].disabled = condition == "Dead" or status != "Available"\n', '            send_buttons[sid].disabled = not Game.survivor_can_assign(survivor)\n')
replace_once(path, 'func _recent_returns(limit: int) -> Array:', '''func _condition_text(survivor: Dictionary) -> String:
    var physical := str(survivor.get("condition", "Healthy")).to_upper()
    var stage := Game.virus_stage(survivor)
    return physical if stage == "Clear" else "%s • %s" % [physical, stage.to_upper()]

func _vitals_text(survivor: Dictionary) -> String:
    var needs: Dictionary = survivor.get("needs", {})
    return "Fatigue %.0f  •  Stress %.0f  •  Sleep %.0f" % [float(survivor.get("fatigue",0.0)), float(survivor.get("stress",0.0)), float(needs.get("sleep",100.0))]

func _recent_returns(limit: int) -> Array:''')
replace_once(path, '    if ["Crafting", "Building", "Recovering", "Tending"].has(status):\n        var active_task: Dictionary = survivor.get("task", {})\n        if not active_task.is_empty():\n            return "%s — %.0fs remaining" % [status, float(active_task.get("remaining", 0.0))]\n    if status == "Available":', '    if ["Crafting", "Building", "Recovering", "Tending", "Sleeping"].has(status):\n        var active_task: Dictionary = survivor.get("task", {})\n        if not active_task.is_empty():\n            var label := "Virus treatment" if str(active_task.get("kind", "")) == "virus_treatment" else status\n            return "%s — %.0fs remaining" % [label, float(active_task.get("remaining", 0.0))]\n    if status == "Quarantined": return "Quarantined — %s" % Game.virus_stage(survivor)\n    if status == "Sick": return "Feverish — needs zombie-virus care"\n    if status == "Available":')

path = "game/scripts/FFInspectorThreeStat.gd"
replace_once(path, '    body.add_child(_make_label("Fatigue %.0f / 100  •  Stress %.0f / 100" % [float(survivor.get("fatigue", 0.0)), float(survivor.get("stress", 0.0))], 14))\n    var treatment_status := _treatment_status_line(survivor)', '    body.add_child(_make_label("Fatigue %.0f / 100  •  Stress %.0f / 100" % [float(survivor.get("fatigue", 0.0)), float(survivor.get("stress", 0.0))], 14))\n    var virus := Game.virus_state(survivor)\n    var virus_stage := str(virus.get("stage", "Clear"))\n    body.add_child(_make_label("Zombie virus: %s%s" % [virus_stage.to_upper(), "  •  QUARANTINED" if bool(virus.get("quarantined", false)) else ""], 13))\n    if virus_stage != "Clear":\n        body.add_child(_make_label("Exposure may clear naturally once. Established infection progresses to fever; untreated fever can turn fatal on the next day. Quarantine prevents close-contact camp spread.", 11))\n        if str(survivor.get("task", {}).get("kind", "")) == "virus_treatment":\n            body.add_child(_make_label("Virus treatment underway — %.0fs of camp time remaining." % float(survivor.get("task", {}).get("remaining", 0.0)), 11))\n    var treatment_status := _treatment_status_line(survivor)')
replace_once(path, '            equip.disabled = status != "Available"\n', '            equip.disabled = not Game.survivor_can_assign(survivor)\n')
replace_once(path, '        treat.disabled = condition == "Healthy" or status != "Available"\n', '        treat.disabled = condition == "Healthy" or not Game.survivor_can_assign(survivor)\n')
replace_once(path, '        send.disabled = status != "Available"; send.pressed.connect(_handoff_send); actions.add_child(send)\n', '        send.disabled = not Game.survivor_can_assign(survivor); send.pressed.connect(_handoff_send); actions.add_child(send)\n')
replace_once(path, '        body.add_child(actions)\n\n    body.add_child(_separator())\n    body.add_child(_heading("RELATIONSHIPS", 18))', '''        body.add_child(actions)
        if virus_stage != "Clear":
            body.add_child(_separator())
            body.add_child(_heading("ZOMBIE VIRUS", 18))
            var plan: Dictionary = Game.VirusRules.treatment_plan(virus_stage, bool(Game.buildings.get("Infirmary", false)))
            body.add_child(_make_label("Treatment: %s. You can also wait and risk progression; Exposed has one natural-clear chance." % str(plan.get("summary", "medical care")), 11))
            if not bool(plan.get("available", false)) and str(plan.get("reason", "")) != "":
                body.add_child(_make_label(str(plan.get("reason", "")), 11))
            var virus_actions = HBoxContainer.new()
            var virus_treat = Button.new()
            virus_treat.text = "DECONTAMINATE" if virus_stage == "Exposed" else ("EMERGENCY CARE" if virus_stage == "Feverish" else "TREAT VIRUS")
            virus_treat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            virus_treat.custom_minimum_size = Vector2(0, 46)
            virus_treat.disabled = str(survivor.get("status", "")) not in ["Available", "Quarantined", "Sick"] or not survivor.get("task", {}).is_empty() or not bool(plan.get("available", false))
            virus_treat.pressed.connect(_treat_virus)
            virus_actions.add_child(virus_treat)
            var quarantine = Button.new()
            quarantine.text = "QUARANTINE"
            quarantine.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            quarantine.custom_minimum_size = Vector2(0, 46)
            quarantine.disabled = bool(virus.get("quarantined", false)) or str(survivor.get("status", "")) not in ["Available", "Sick"] or not survivor.get("task", {}).is_empty()
            quarantine.pressed.connect(_quarantine_virus)
            virus_actions.add_child(quarantine)
            body.add_child(virus_actions)

    body.add_child(_separator())
    body.add_child(_heading("RELATIONSHIPS", 18))''')
replace_once(path, 'func _render_item() -> void:', 'func _treat_virus() -> void:\n    if Game.start_virus_treatment(current_survivor_id):\n        _render_survivor()\n\nfunc _quarantine_virus() -> void:\n    if Game.quarantine_survivor(current_survivor_id):\n        _render_survivor()\n\nfunc _render_item() -> void:')
replace_once(path, '    var description := str(ITEM_DESCRIPTIONS.get(current_item, "No field notes have been written for this item yet."))\n    if current_item in ["Work Gloves", "Heavy Boots", "Leather Jacket", "Work Jacket", "Padded Jacket"]:', '    var description := str(ITEM_DESCRIPTIONS.get(current_item, "No field notes have been written for this item yet."))\n    if current_item == "Medicine":\n        description = "High-grade medical supplies used for Critical trauma stabilization and established zombie-virus treatment. Feverish cases need two doses in an Infirmary."\n    elif current_item == "Sterile Dressing":\n        description = "Clean wound-care material used for Hurt/Wounded physical injuries and, with Clean Water, early zombie-virus exposure decontamination."\n    if current_item in ["Work Gloves", "Heavy Boots", "Leather Jacket", "Work Jacket", "Padded Jacket"]:')

path = "game/scripts/Main.gd"
replace_once(path, '    content_box.add_child(_make_label("Sleep, meals and downtime happen on their own. Productive camp work is yours to assign. Chores are hands-on: assign someone, then tap WORK to finish the job.",12))', '    content_box.add_child(_make_label("Sleep, meals and downtime happen on their own. Sleeping survivors go to their beds and are unavailable until they wake. Productive camp work is yours to assign.",12))')
replace_once(path, '["Crafting", "Building", "Recovering", "Tending"].has(s["status"])', '["Crafting", "Building", "Recovering", "Tending", "Sleeping"].has(s["status"])')
replace_once(path, '    if ["Crafting", "Building", "Recovering", "Tending"].has(s["status"]) and not s["task"].is_empty():\n        return "%s — %.0fs remaining" % [s["status"], float(s["task"].get("remaining", 0.0))]\n    return s["status"]', '    if ["Crafting", "Building", "Recovering", "Tending", "Sleeping"].has(s["status"]) and not s["task"].is_empty():\n        var label := "Virus treatment" if str(s["task"].get("kind", "")) == "virus_treatment" else str(s["status"])\n        return "%s — %.0fs remaining" % [label, float(s["task"].get("remaining", 0.0))]\n    if str(s["status"]) == "Quarantined": return "Quarantined — %s" % Game.virus_stage(s)\n    if str(s["status"]) == "Sick": return "Feverish — needs zombie-virus care"\n    var stage := Game.virus_stage(s)\n    return "%s — virus %s" % [s["status"], stage] if stage != "Clear" else s["status"]')

path = "game/scripts/ci/FFArchitectureSmoke.gd"
replace_once(path, 'const CampLifeRules = preload("res://scripts/FFCampLifeRules.gd")\nconst CampSocial = preload("res://scripts/FFCampSocial.gd")', 'const CampLifeRules = preload("res://scripts/FFCampLifeRules.gd")\nconst VirusRules = preload("res://scripts/FFVirusRules.gd")\nconst CampSocial = preload("res://scripts/FFCampSocial.gd")')
replace_once(path, '    var base_needs := CampLifeRules.default_needs()', '''    if not _check(VirusRules.stage(VirusRules.default_state()) == "Clear", "virus default clear"): return
    if not _check(is_equal_approx(VirusRules.exposure_chance(1), 0.18) and VirusRules.exposure_chance(3) > VirusRules.exposure_chance(1), "infected contact exposure risk"): return
    var exposed_plan := VirusRules.treatment_plan("Exposed", false)
    var infected_plan := VirusRules.treatment_plan("Infected", false)
    var fever_plan := VirusRules.treatment_plan("Feverish", true)
    if not _check(int(exposed_plan.get("resources", {}).get("Clean Water", 0)) == 1 and int(exposed_plan.get("components", {}).get("Sterile Dressing", 0)) == 1, "early exposure decontamination"): return
    if not _check(int(infected_plan.get("resources", {}).get("Medicine", 0)) == 1 and int(fever_plan.get("resources", {}).get("Medicine", 0)) == 2, "virus medicine escalation"): return
    if not _check(not bool(VirusRules.treatment_plan("Feverish", false).get("available", true)), "fever requires infirmary"): return
    if not _check(base_game_source.contains("const SIM_TIME_SCALE := 0.5") and base_game_source.contains("s[\\\"status\\\"]=\\\"Sleeping\\\"") and base_game_source.contains("func survivor_can_assign"), "half-speed authoritative sleeping"): return
    var camp_view_source := FileAccess.get_file_as_string("res://scripts/FFCampView.gd")
    if not _check(camp_view_source.contains("func _sleep_cell_for_survivor") and camp_view_source.contains("\\\"Sleeping\\\": return \\\"SLEEP\\\""), "sleep routes to visible beds"): return
    if not _check(combat_source.contains("infected_hits") and base_combat_source.contains("\\\"infected_hits\\\""), "infected tactical contact tracking"): return

    var base_needs := CampLifeRules.default_needs()''')

path = ".github/workflows/pages.yml"
replace_once(path, '          test -f game/scripts/FFCampLifeRules.gd\n          test -f game/scripts/FFCampSocial.gd', '          test -f game/scripts/FFCampLifeRules.gd\n          test -f game/scripts/FFVirusRules.gd\n          test -f game/scripts/FFCampSocial.gd')

path = "README_CONTEXT.md"
replace_once(path, '`FFCampLifeRules.gd` owns six survivor needs plus pet affection/retention/reward rules, fire/maintenance tuning, autonomous idle recovery/downtime, and camp cadence.', '`FFCampLifeRules.gd` owns six survivor needs plus pet affection/retention/reward rules, fire/maintenance tuning, autonomous idle recovery/downtime, and camp cadence. Sleep is autonomous but authoritative: when a survivor sleeps they enter a timed `Sleeping` status, move to a deterministic built bed/sleeping spot in the living camp, and cannot be assigned until they wake.')
replace_once(path, 'Disease/illness is not currently part of the survivor condition model and should remain a separate future axis if added.', 'Zombie-virus infection is a separate persistent axis from physical `condition`, owned by `FFVirusRules.gd`. Direct infected hits can create **Exposed** state; exposure can clear naturally once or be decontaminated with 1 Clean Water + 1 Sterile Dressing. Established **Infected** state needs 1 Medicine; **Feverish** infection needs an Infirmary + 2 Medicine and becomes fatal on the following untreated day. Unquarantined infected survivors can create low-probability close-contact camp exposure; quarantine prevents that spread but makes the survivor unavailable. Physical wounds continue to use the Hurt/Wounded/Critical ladder independently.')
replace_once(path, 'For testing, one full in-game day is **2 real active minutes**.', 'For testing, settlement simulation now runs at **half the previous real-time speed**: one full in-game day is **4 real active minutes**. Camp recovery, work, expeditions, needs, events, pets, fire/maintenance decay, and the settlement clock share that half-speed simulation scale; UI refresh/autosave remain real-time.')

path = "ARCHITECTURE.md"
replace_once(path, '### `FFCampView.gd`\nLiving 2D camp presentation. It reads authoritative state and maps it to visual stations/cosmetic survivor motion only.', '### `FFCampView.gd`\nLiving 2D camp presentation. It reads authoritative state and maps it to visual stations/cosmetic survivor motion only. Authoritative `Sleeping` survivors route to deterministic bed slots and are rendered asleep; treatment/quarantine state routes toward medical/isolation space.')
replace_once(path, 'Eating/drinking, sleeping, and fun remain systemic idle behavior; productive chores, maintenance, crafting/building, pet care, and expeditions are assigned by the player through `Game.gd`.', 'Eating/drinking and fun remain systemic idle behavior. Sleep is also autonomous, but once chosen it becomes authoritative `Sleeping` task/status so the survivor is unavailable until waking. Productive chores, maintenance, crafting/building, pet care, and expeditions are assigned by the player through `Game.gd`.')
replace_once(path, '### `FFCampSocial.gd`\nRelationships, chatter, political standing, and leadership support.', '### `FFVirusRules.gd`\nPure zombie-virus rules: persistent stage normalization, direct-contact exposure probability, daily progression, close-contact camp spread, quarantine effect, and stage-specific treatment requirements. `Game.gd` owns survivor virus state/orchestration; physical injury `condition` remains separate.\n\n### `FFCampSocial.gd`\nRelationships, chatter, political standing, and leadership support.')

path = "ROADMAP.md"
replace_once(path, 'The current two-real-minute game day is test tuning, not automatically the shipping answer.', 'The current four-real-minute game day is test tuning, not automatically the shipping answer.')
replace_once(path, '- survivor moodlets driven by hunger, thirst, sleep, fun, safety, and hygiene; eating/drinking/sleep/fun remain autonomous idle behavior while productive labor is player-assigned;', '- survivor moodlets driven by hunger, thirst, sleep, fun, safety, and hygiene; eating/drinking/fun remain autonomous idle behavior, while sleep becomes an authoritative unavailable state at a real bed and productive labor is player-assigned;')

p = Path("CHANGELOG.md")
entry = '''## Beta Candidate — Camp Sleep, Zombie Virus & Half-Speed Time — 2026-09-11

- Sleep is now an authoritative timed survivor state instead of cosmetic passive rest. Sleeping survivors are unavailable for dispatch/work, walk to deterministic bed slots provided by current shelter buildings, and are shown lying down with sleep cues in the living camp.
- Centralized survivor assignment availability so sleeping, wound/virus treatment, crafting/building/gardening, chores, pet care, quarantine, and other active camp work cannot be bypassed by stale UI state.
- Added a separate persistent zombie-virus axis: direct infected tactical hits can cause Exposed state; early decontamination uses Clean Water + Sterile Dressing, established infection uses Medicine, and Feverish cases require the Infirmary + 2 Medicine before the next untreated day becomes fatal.
- Added quarantine and natural-wait choices. Quarantine makes the survivor unavailable and prevents low-probability close-contact camp spread; Exposed survivors get one natural-clear chance before infection establishes.
- Slowed settlement simulation to half its previous real-time pace. One in-game day now takes four real active minutes, and camp work/recovery/needs/expedition/event/fire timers share the same half-speed simulation scale.
- Save schema remains 7; virus state is additive with backward-compatible clear defaults, and old passive sleep state is normalized into the new Sleeping task on load.

'''
p.write_text(entry + p.read_text())

checks = {
    "game/scripts/FFVirusRules.gd": ["STAGE_FEVERISH", "func treatment_plan", "func exposure_chance"],
    "game/scripts/Game.gd": ["const SIM_TIME_SCALE := 0.5", "func survivor_can_assign", 's["status"]="Sleeping"', "func start_virus_treatment", "func _process_daily_virus"],
    "game/scripts/FFCampView.gd": ["func _sleep_cell_for_survivor", '"Sleeping": return "SLEEP"', "PI * 0.5 if sleeping else 0.0"],
    "game/scripts/FFCombat.gd": ["infected_hits"],
    "game/scripts/FFCombatThreeStat.gd": ["infected_hits"],
    "game/scripts/FFInspectorThreeStat.gd": ["ZOMBIE VIRUS", "_treat_virus", "_quarantine_virus"],
    "game/scripts/FFSurvivorPanel.gd": ["Sleep %.0f", "Game.survivor_can_assign"],
}
for filename, needles in checks.items():
    text = Path(filename).read_text()
    for needle in needles:
        if needle not in text:
            raise SystemExit(f"{filename}: missing sanity marker {needle!r}")
