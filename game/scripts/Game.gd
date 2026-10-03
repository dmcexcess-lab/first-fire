extends Node

signal state_changed
signal tick
signal event_changed
signal combat_changed
signal toast_requested(message)
signal camp_chatter_requested(data)

const D = preload("res://scripts/FFData.gd")
const ExpeditionRules = preload("res://scripts/FFExpeditionRules.gd")
const TacticalScenarios = preload("res://scripts/FFTacticalScenarios.gd")
const LegacyFieldEvents = preload("res://scripts/FFFieldEventsLegacy.gd")
const SaveCodec = preload("res://scripts/FFSaveCodec.gd")
const CampLifeRules = preload("res://scripts/FFCampLifeRules.gd")
const CampSocial = preload("res://scripts/FFCampSocial.gd")
const TacticalVisuals = preload("res://scripts/FFTacticalVisuals.gd")
const TacticalBalance = preload("res://scripts/FFTacticalBalance.gd")
# Alpha saves are disposable; the filename remains stable while schema changes invalidate old state cleanly.
const SAVE_PATH := "user://first_fire_alpha01.json"
const SAVE_SCHEMA_VERSION := 8
const DAY_SECONDS := 300.0
const MAX_POPULATION := 18

var rng := RandomNumberGenerator.new()
var sim_paused := false
var initialized := false
var save_existed_on_boot := false
var ui_emit_accum := 0.0
var autosave_accum := 0.0
var camp_event_accum := 0.0
var camp_event_cooldown := 0.0
var camp_chatter_accum := 0.0
var next_camp_chatter_at := 10.0

var day := 1
var day_elapsed := 0.0
var resources := {}
var components := {}
var inventory_gear := []
var inventory_gear_states := {}
var buildings := {}
var survivors := []
var next_survivor_id := 1
var next_expedition_id := 1
var expeditions := []
var zone_successes := {}
var zone_pressure := {}
var unlocked_zones := []
var special_sites := {}
var history := []
var flags := {}
var policies := {}
var current_event := {}
var event_queue := []
var current_combat := {}
var coordinator_id := -1
var leader_id := -1
var leadership_form := "None"
var eligible_expeditions_since_recruit := 0
var food_shortage_days := 0
var water_shortage_days := 0
var garden_tended_day := -1
var game_over := false
var settlement_mature := false
var settlement_mature_shown := false
var recent_expedition_ids := []
var fire_level := CampLifeRules.FIRE_START_LEVEL
var camp_maintenance := CampLifeRules.CAMP_MAINTENANCE_START
var pets := []
var next_pet_id := 1

func _ready():
    rng.randomize()
    save_existed_on_boot = SaveCodec.exists(SAVE_PATH)
    if save_existed_on_boot:
        load_game()
    else:
        new_game()
    initialized = true
    set_process(true)

func has_save_game():
    return SaveCodec.exists(SAVE_PATH)

func tutorial_needed() -> bool:
    # Only saves created after onboarding was added carry this flag. Existing
    # schema-7 Beta saves are not interrupted by a retroactive tutorial.
    return flags.has("tutorial_complete") and not bool(flags.get("tutorial_complete", true))

func complete_tutorial() -> void:
    flags["tutorial_complete"] = true
    save_game()

func new_game():
    day = 1
    day_elapsed = 0.0
    resources = D.STARTING_RESOURCES.duplicate(true)
    components = D.STARTING_COMPONENTS.duplicate(true)
    inventory_gear = []
    inventory_gear_states = {}
    buildings = {"Fire Pit": true, "Sleeping Bag": true, "Storage Crate": true}
    for b in D.BUILD_ORDER:
        buildings[b] = false
    # Sparse wilderness start: the fire, one bedroll and communal storage are the
    # only permanent camp fixtures. Workbench and expansion structures are built.
    survivors = []
    next_survivor_id = 1
    next_expedition_id = 1
    expeditions = []
    zone_successes = {}
    zone_pressure = {}
    for z in D.ZONE_ORDER:
        zone_successes[z] = 0
        zone_pressure[z] = 0
    unlocked_zones = ExpeditionRules.starting_routes()
    special_sites = {}
    for site in D.SPECIAL_SITES.keys():
        special_sites[site] = {"discovered": false, "cleared": false}
    history = []
    flags = {"tutorial_complete": false}
    flags[ExpeditionRules.VEHICLE_UNLOCK_FLAG] = false
    policies = {}
    current_event = {}
    event_queue = []
    current_combat = {}
    coordinator_id = -1
    leader_id = -1
    leadership_form = "None"
    eligible_expeditions_since_recruit = 0
    food_shortage_days = 0
    water_shortage_days = 0
    garden_tended_day = -1
    game_over = false
    settlement_mature = false
    settlement_mature_shown = false
    recent_expedition_ids = []
    fire_level = CampLifeRules.FIRE_START_LEVEL
    camp_maintenance = CampLifeRules.CAMP_MAINTENANCE_START
    pets = []
    next_pet_id = 1
    camp_event_accum = 0.0
    camp_event_cooldown = CampLifeRules.NEW_GAME_EVENT_COOLDOWN
    camp_chatter_accum = 0.0
    next_camp_chatter_at = rng.randf_range(CampLifeRules.CAMP_CHATTER_MIN_SECONDS, CampLifeRules.CAMP_CHATTER_MAX_SECONDS)
    sim_paused = false
    var founder = _generate_survivor(true)
    founder["equipment"] = {"Weapon": "Utility Knife", "Secondary": "", "Clothing": "", "Pack": "", "Tool": ""}
    founder["history"].append("Day 1 — Established First Fire.")
    survivors.append(founder)
    _add_history("Day 1 — %s established First Fire." % founder["name"])
    save_game()
    state_changed.emit()

func _process(delta):
    if not initialized or sim_paused or game_over:
        return
    day_elapsed += delta
    ui_emit_accum += delta
    autosave_accum += delta
    camp_event_accum += delta
    if camp_event_cooldown > 0.0:
        camp_event_cooldown = max(0.0, camp_event_cooldown - delta)

    fire_level = maxf(0.0, fire_level - CampLifeRules.FIRE_DECAY_PER_SECOND * float(delta))
    camp_maintenance = CampLifeRules.degrade_camp_condition(camp_maintenance, float(delta))
    _process_pets(float(delta))
    _process_survivors(delta)
    _process_camp_chatter(delta)
    _process_expeditions(delta)

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

func _notification(what):
    if not initialized:
        return
    if what == MainLoop.NOTIFICATION_APPLICATION_PAUSED or what == MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT:
        sim_paused = true
        save_game()
        state_changed.emit()
    elif what == MainLoop.NOTIFICATION_APPLICATION_RESUMED or what == MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN:
        # Deliberately remain paused after returning. The player resumes explicitly.
        state_changed.emit()

func toggle_pause():
    sim_paused = not sim_paused
    save_game()
    state_changed.emit()

func set_paused(value):
    sim_paused = value
    save_game()
    state_changed.emit()

func formatted_time():
    var minutes_into_day = int((day_elapsed / DAY_SECONDS) * 1440.0)
    var total_minutes = (8 * 60 + minutes_into_day) % 1440
    var hour = total_minutes / 60
    var minute = total_minutes % 60
    var suffix = "AM"
    var display_hour = hour
    if hour >= 12:
        suffix = "PM"
    if display_hour == 0:
        display_hour = 12
    elif display_hour > 12:
        display_hour -= 12
    return "%d:%02d %s" % [display_hour, minute, suffix]

func shelter_capacity():
    if buildings.get("Dormitory", false):
        return MAX_POPULATION
    if buildings.get("Barracks", false):
        return 12
    if buildings.get("Large Tarp", false):
        return 7
    return 3

func building_under_construction(building: String) -> bool:
    for survivor in survivors:
        var task: Dictionary = survivor.get("task", {})
        if str(survivor.get("status", "")) == "Building" and str(task.get("kind", "")) == "build" and str(task.get("building", "")) == building:
            return true
        if str(task.get("kind", "")) == "forced_rest":
            var resume_value = task.get("resume_task", {})
            var resume_task: Dictionary = resume_value if resume_value is Dictionary else {}
            if str(resume_task.get("kind", "")) == "build" and str(resume_task.get("building", "")) == building:
                return true
    return false

func building_requirements_met(building: String) -> bool:
    if not D.BUILDINGS.has(building):
        return false
    var data: Dictionary = D.BUILDINGS[building]
    for requirement in data.get("requires", []):
        if not bool(buildings.get(requirement, false)):
            return false
    return true

func population():
    var count = 0
    for s in survivors:
        if s["condition"] != "Dead":
            count += 1
    return count

func available_survivors():
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

func _generate_survivor(founder = false, preferred_background = ""):
    var s = {
        "id": next_survivor_id,
        "name": "",
        "background": "",
        "skills": {"Combat": 0, "Scavenging": 0, "Survival": 0, "Medical": 0, "Technical": 0, "Social": 0},
        "skill_xp": {"Combat": 0, "Scavenging": 0, "Survival": 0, "Medical": 0, "Technical": 0, "Social": 0},
        "traits": [],
        "fatigue": 0.0,
        "stress": 10.0 if not founder else 5.0,
        "needs": CampLifeRules.default_needs(),
        "camp_activity": {},
        "condition": "Healthy",
        "injury_remaining": 0.0,
        "status": "Available",
        "task": {},
        "equipment": {"Weapon": "", "Secondary": "", "Clothing": "", "Pack": "", "Tool": ""},
        "appearance": {},
        "relationships": {},
        "reputation": 0,
        "leader_support": 0,
        "leader_ability": "",
        "history": [],
        "expeditions_done": 0,
    }
    next_survivor_id += 1
    s["name"] = "%s %s" % [D.FIRST_NAMES[rng.randi_range(0, D.FIRST_NAMES.size() - 1)], D.LAST_NAMES[rng.randi_range(0, D.LAST_NAMES.size() - 1)]]
    s["appearance"] = TacticalVisuals.survivor_appearance(rng)
    var background_names = D.BACKGROUNDS.keys()
    if preferred_background != "" and D.BACKGROUNDS.has(preferred_background):
        s["background"] = preferred_background
    else:
        s["background"] = background_names[rng.randi_range(0, background_names.size() - 1)]

    for skill in s["skills"].keys():
        s["skills"][skill] = rng.randi_range(1, 3) if founder else rng.randi_range(0, 3)
    for skill in D.BACKGROUNDS[s["background"]].keys():
        s["skills"][skill] = min(5, int(s["skills"][skill]) + int(D.BACKGROUNDS[s["background"]][skill]))

    if s["background"] == "College Student":
        var random_skills = s["skills"].keys()
        var chosen = random_skills[rng.randi_range(0, random_skills.size() - 1)]
        s["skills"][chosen] = min(5, int(s["skills"][chosen]) + 2)
    elif s["background"] == "Retiree":
        var random_skills2 = s["skills"].keys()
        var chosen2 = random_skills2[rng.randi_range(0, random_skills2.size() - 1)]
        s["skills"][chosen2] = min(5, int(s["skills"][chosen2]) + 2)

    if founder:
        for skill in s["skills"].keys():
            s["skills"][skill] = clamp(int(s["skills"][skill]), 1, 4)

    var t1 = D.TRAITS[rng.randi_range(0, D.TRAITS.size() - 1)]
    var t2 = D.TRAITS[rng.randi_range(0, D.TRAITS.size() - 1)]
    var attempts = 0
    while (t2 == t1 or D.INCOMPATIBLE_TRAITS.get(t1, []).has(t2)) and attempts < 30:
        t2 = D.TRAITS[rng.randi_range(0, D.TRAITS.size() - 1)]
        attempts += 1
    s["traits"] = [t1, t2]
    s["leader_ability"] = _derive_leader_ability(s)
    return s

func _derive_leader_ability(s):
    var skills = s["skills"]
    if int(skills["Technical"]) >= 4:
        return "Organizer"
    if int(skills["Scavenging"]) >= 4 or int(skills["Survival"]) >= 4:
        return "Provider"
    if int(skills["Medical"]) >= 4:
        return "Caretaker"
    if int(skills["Social"]) >= 4 or s["traits"].has("Diplomatic"):
        return "Mediator"
    if s["traits"].has("Suspicious") or s["traits"].has("Cautious"):
        return "Watchful"
    return "Pragmatist"

func _initialize_relationships(new_survivor):
    for other in survivors:
        if other["condition"] == "Dead" or int(other["id"]) == int(new_survivor["id"]):
            continue
        var a = rng.randi_range(0, 10)
        var b = rng.randi_range(0, 10)
        new_survivor["relationships"][str(other["id"])] = a
        other["relationships"][str(new_survivor["id"])] = b

func _add_recruit(preferred_background = "", rescuer_ids = []) -> Variant:
    if population() >= MAX_POPULATION:
        toast_requested.emit("First Fire is at its %d-person limit." % MAX_POPULATION)
        return null
    if population() >= shelter_capacity():
        toast_requested.emit("Shelter is full. First Fire has to turn this survivor away.")
        return null
    var s = _generate_survivor(false, preferred_background)
    _initialize_relationships(s)
    for rid in rescuer_ids:
        s["relationships"][str(rid)] = rng.randi_range(15, 25)
        var rescuer: Variant = get_survivor(rid)
        if rescuer != null:
            rescuer["relationships"][str(s["id"])] = rng.randi_range(5, 15)
            _change_reputation(rescuer, 5)
    survivors.append(s)
    s["history"].append("Day %d — Joined First Fire." % day)
    _add_history("Day %d — %s joined First Fire." % [day, s["name"]])
    eligible_expeditions_since_recruit = 0
    save_game()
    state_changed.emit()
    return s

func _add_recruit_candidate(candidate: Dictionary, rescuer_ids = []) -> Variant:
    if candidate.is_empty():
        return _add_recruit("", rescuer_ids)
    if population() >= MAX_POPULATION:
        toast_requested.emit("First Fire is at its %d-person limit." % MAX_POPULATION)
        return null
    if population() >= shelter_capacity():
        toast_requested.emit("Shelter is full. First Fire has to turn this survivor away.")
        return null
    var s: Dictionary = candidate.duplicate(true)
    if int(s.get("id", -1)) < 0:
        s["id"] = next_survivor_id
        next_survivor_id += 1
    else:
        next_survivor_id = maxi(next_survivor_id, int(s["id"]) + 1)
    s["status"] = "Available"
    s["task"] = {}
    s["needs"] = CampLifeRules.normalize_needs(s.get("needs", {}))
    s["camp_activity"] = {}
    s["relationships"] = {}
    if not s.has("history"):
        s["history"] = []
    _initialize_relationships(s)
    for rid in rescuer_ids:
        s["relationships"][str(rid)] = rng.randi_range(15, 25)
        var rescuer: Variant = get_survivor(rid)
        if rescuer != null:
            rescuer["relationships"][str(s["id"])] = rng.randi_range(5, 15)
            _change_reputation(rescuer, 5)
    survivors.append(s)
    s["history"].append("Day %d — Rescued in the field and joined First Fire." % day)
    _add_history("Day %d — %s joined First Fire after a field rescue." % [day, s["name"]])
    eligible_expeditions_since_recruit = 0
    save_game()
    state_changed.emit()
    return s

func relationship_label(value):
    return CampSocial.relationship_label(int(value))

func _change_relationship(a, b, amount):
    if a == null or b == null:
        return
    CampSocial.change_relationship(a, b, int(amount), leader_id)

func _change_reputation(s, amount):
    s["reputation"] = int(s.get("reputation", 0)) + int(amount)

func add_skill_xp(s, skill, amount):
    if s == null or not s["skills"].has(skill):
        return
    s["skill_xp"][skill] = int(s["skill_xp"].get(skill, 0)) + int(amount)
    var rank = int(s["skills"][skill])
    var threshold = 20 + rank * 15
    while rank < 10 and int(s["skill_xp"][skill]) >= threshold:
        s["skill_xp"][skill] = int(s["skill_xp"].get(skill, 0)) - threshold
        rank += 1
        s["skills"][skill] = rank
        s["history"].append("Day %d — Reached %s %d." % [day, skill, rank])
        _add_history("Day %d — %s reached %s %d." % [day, s["name"], skill, rank])
        threshold = 20 + rank * 15

func skill_check(s, skill, dc, extra = 0):
    var effective = int(s["skills"].get(skill, 0)) + int(extra)
    if s["fatigue"] >= 80 and ["Combat", "Scavenging", "Survival", "Technical"].has(skill):
        effective -= 2
    elif s["fatigue"] >= 60 and ["Combat", "Scavenging", "Survival", "Technical"].has(skill):
        effective -= 1
    if s["traits"].has("Nervous") and s["stress"] >= 50 and ["Combat", "Survival"].has(skill):
        effective -= 1
    if s["traits"].has("Calm") and skill == "Survival":
        effective += 1
    if s["traits"].has("Diplomatic") and skill == "Social":
        effective += 1
    var roll = rng.randi_range(1, 10) + effective
    if roll >= dc + 4: return 2
    if roll >= dc: return 1
    if roll >= dc - 2: return 0
    return -1

func _process_camp_chatter(delta):
    if population() < 2 or not current_event.is_empty() or not current_combat.is_empty():
        camp_chatter_accum = 0.0
        return
    camp_chatter_accum += float(delta)
    if camp_chatter_accum < next_camp_chatter_at:
        return
    camp_chatter_accum = 0.0
    next_camp_chatter_at = rng.randf_range(CampLifeRules.CAMP_CHATTER_MIN_SECONDS, CampLifeRules.CAMP_CHATTER_MAX_SECONDS)
    var chatter: Dictionary = CampSocial.roll_chatter(survivors, leader_id, coordinator_id, food_shortage_days, water_shortage_days, policies, rng)
    if chatter.is_empty():
        return
    var speaker: Variant = get_survivor(int(chatter.get("speaker_id", -1)))
    var listener: Variant = get_survivor(int(chatter.get("listener_id", -1)))
    if speaker == null or listener == null:
        return
    var delta_ab := int(chatter.get("relationship_delta", 0))
    var delta_ba := int(chatter.get("reverse_delta", 0))
    if delta_ab != 0: _change_relationship(speaker, listener, delta_ab)
    if delta_ba != 0: _change_relationship(listener, speaker, delta_ba)
    speaker["stress"] = clampf(float(speaker.get("stress", 0.0)) + float(chatter.get("speaker_stress_delta", 0.0)), 0.0, 100.0)
    listener["stress"] = clampf(float(listener.get("stress", 0.0)) + float(chatter.get("listener_stress_delta", 0.0)), 0.0, 100.0)
    camp_chatter_requested.emit(chatter)

func _process_survivors(delta):
    var pop: int = int(population())
    var capacity: int = int(shelter_capacity())
    var hygiene_support:=bool(buildings.get("Rain Catcher",false)) or bool(buildings.get("Water Tank",false))
    for s in survivors:
        if s["condition"]=="Dead": continue
        if not s.has("needs"): s["needs"]=CampLifeRules.default_needs()
        if not s.has("camp_activity"): s["camp_activity"]={}
        var away:=["Expedition","Pending Expedition Event","Tactical Encounter"].has(str(s.get("status","Available")))
        var safety:=CampLifeRules.safety_target(buildings,pop,capacity,fire_level,away,camp_maintenance)
        s["needs"]=CampLifeRules.update_needs(s.get("needs",{}),float(s.get("fatigue",0.0)),float(delta),safety,hygiene_support,away)
        s["stress"]=clampf(float(s.get("stress",0.0))+CampLifeRules.need_stress_rate(s["needs"])*float(delta),0.0,100.0)
        if s["status"]=="Available":
            var caretaker:=false
            if leader_id!=-1:
                var leader:Variant=get_survivor(leader_id)
                caretaker=leader!=null and leader["leader_ability"]=="Caretaker"
            var recovery:=CampLifeRules.idle_recovery_rates(CampLifeRules.shelter_tier(buildings),caretaker,CampLifeRules.tavern_tier(buildings))
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
        elif ["Chore","Pet Care"].has(s["status"]):
            s["camp_activity"]={}
            if s["task"].is_empty(): s["status"]="Available"
        elif ["Crafting","Building","Recovering","Tending"].has(s["status"]):
            s["camp_activity"]={}
            if s["task"].is_empty(): s["status"]="Available"; continue
            s["task"]["remaining"]=max(0.0,float(s["task"]["remaining"])-delta)
            if float(s["task"]["remaining"])<=0.0: _complete_task(s)

func _process_camp_activity(s:Dictionary,delta:float,pop:int,hygiene_support:bool)->void:
    var activity:Dictionary=s.get("camp_activity",{})
    if activity.is_empty():
        activity=CampLifeRules.choose_available_activity(
            s.get("needs",{}),
            fire_level,
            int(resources.get("Wood",0)),
            pop,
            CampLifeRules.tavern_tier(buildings),
            hygiene_support,
            rng,
            CampLifeRules.settlement_hour(day_elapsed,DAY_SECONDS),
            s.get("daily_activity",{}),
            int(resources.get("Cooked Food",0)),
            int(resources.get("Clean Water",0)),
            int(resources.get("Beer",0))
        )
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
        var tavern_quality:=CampLifeRules.tavern_tier(buildings)
        if kind=="tavern_drink":
            if int(resources.get("Beer",0))>0:
                resources["Beer"]=int(resources.get("Beer",0))-1
            else:
                kind="tavern_social"
        var result:=CampLifeRules.complete_activity(s.get("needs",{}),float(s.get("fatigue",0.0)),kind,tavern_quality)
        s["needs"]=result.get("needs",s.get("needs",{})); s["fatigue"]=float(result.get("fatigue",s.get("fatigue",0.0)))
        if kind in ["tavern_social","tavern_drink"]:
            s["stress"]=maxf(0.0,float(s.get("stress",0.0))-CampLifeRules.tavern_social_stress_relief(tavern_quality,kind=="tavern_drink"))
        elif kind in ["watch_fire","cards","guitar"]:
            s["stress"]=maxf(0.0,float(s.get("stress",0.0))-2.0)
    s["camp_activity"]={}

func _clear_camp_activity(s)->void:
    if s!=null: s["camp_activity"]={}

func survivor_moodlets(survivor:Dictionary)->Array:
    return CampLifeRules.moodlets(survivor.get("needs",{}))

func _process_pets(delta:float)->void:
    for pet in pets:
        pet["needs"]=CampLifeRules.update_pet_needs(pet.get("needs",{}),delta)

func get_pet(pet_id:int) -> Variant:
    for pet in pets:
        if int(pet.get("id",-1))==pet_id: return pet
    return null

func pet_mood_label(pet:Dictionary)->String:
    return CampLifeRules.pet_mood(pet.get("needs",{}))

func _generate_pet_candidate()->Dictionary:
    var species := "Dog" if rng.randf()<0.58 else "Cat"
    var name := str(CampLifeRules.PET_NAMES[rng.randi_range(0,CampLifeRules.PET_NAMES.size()-1)])
    return {
        "id": -10000-next_pet_id, "name": name, "species": species, "is_pet": true,
        "skills": {"Combat":0,"Agility":3,"Leadership":0}, "traits": [], "fatigue":0.0,"stress":35.0,
        "condition":"Healthy", "equipment":{"Weapon":"","Secondary":"","Clothing":"","Pack":"","Tool":""},
        "appearance":{}, "needs":CampLifeRules.default_pet_needs()
    }

func _add_pet(candidate_value)->Variant:
    if pets.size()>=CampLifeRules.MAX_PETS:
        toast_requested.emit("First Fire can only support %d pets right now." % CampLifeRules.MAX_PETS); return null
    var candidate:Dictionary=candidate_value.duplicate(true) if candidate_value is Dictionary else {}
    if candidate.is_empty(): candidate=_generate_pet_candidate()
    candidate["id"]=next_pet_id; next_pet_id+=1
    candidate["is_pet"]=true
    candidate["needs"]=CampLifeRules.normalize_pet_needs(candidate.get("needs",{}))
    candidate.erase("skills"); candidate.erase("traits"); candidate.erase("fatigue"); candidate.erase("stress"); candidate.erase("condition"); candidate.erase("equipment"); candidate.erase("appearance")
    pets.append(candidate)
    _add_history("Day %d — %s the %s was rescued and brought to First Fire." % [day,candidate["name"],candidate["species"]])
    toast_requested.emit("%s the %s joined camp." % [candidate["name"],candidate["species"]])
    save_game(); state_changed.emit(); return candidate

func start_camp_chore(sid:int,chore:String)->bool:
    var s:Variant=get_survivor(sid)
    if s==null or s["status"]!="Available": return false
    var label:=""; var goal:=4
    match chore:
        "stoke_fire":
            if int(resources.get("Wood",0))<=0: toast_requested.emit("Stoking the fire needs 1 Wood."); return false
            resources["Wood"]=int(resources.get("Wood",0))-1; label="Stoke First Fire"; goal=4
        "clean_camp": label="Clean Camp"; goal=5
        "repair_perimeter":
            if int(resources.get("Scrap Metal",0))>0: resources["Scrap Metal"]=int(resources.get("Scrap Metal",0))-1
            elif int(resources.get("Wood",0))>0: resources["Wood"]=int(resources.get("Wood",0))-1
            else: toast_requested.emit("Perimeter maintenance needs 1 Scrap Metal or Wood."); return false
            label="Repair Perimeter"; goal=6
        _: return false
    _clear_camp_activity(s); s["status"]="Chore"; s["task"]={"kind":"chore","chore":chore,"label":label,"progress":0,"goal":goal}
    save_game(); state_changed.emit(); return true

func start_pet_care(sid:int,pet_id:int,action:String)->bool:
    var s:Variant=get_survivor(sid); var pet:Variant=get_pet(pet_id)
    if s==null or s["status"]!="Available" or pet==null: return false
    if action not in ["play","love"]: return false
    _clear_camp_activity(s); s["status"]="Pet Care"
    s["task"]={"kind":"pet_care","pet_id":pet_id,"action":action,"label":"%s %s" % [action.capitalize(),pet["name"]],"progress":0,"goal":4 if action=="play" else 3}
    save_game(); state_changed.emit(); return true

func perform_camp_task_tap(sid:int)->bool:
    var s:Variant=get_survivor(sid)
    if s==null or not ["Chore","Pet Care"].has(str(s.get("status",""))) or s.get("task",{}).is_empty(): return false
    s["task"]["progress"]=int(s["task"].get("progress",0))+1
    s["fatigue"]=minf(100.0,float(s.get("fatigue",0.0))+0.7)
    if int(s["task"]["progress"])>=int(s["task"].get("goal",1)): _complete_task(s)
    else: save_game(); state_changed.emit()
    return true

func treat_survivor(sid):
    var s: Variant = get_survivor(sid)
    if s == null or s["condition"] in ["Healthy", "Dead"] or s["status"] != "Available":
        return false
    _clear_camp_activity(s)
    var condition := str(s["condition"])
    if condition == "Hurt":
        if int(components.get("Bandage", 0)) <= 0:
            toast_requested.emit("You need a Bandage.")
            return false
        components["Bandage"] -= 1
        s["injury_remaining"] = min(float(s["injury_remaining"]), 30.0)
        s["status"] = "Available"
        s["history"].append("Day %d — Treated a minor injury with a Bandage." % day)
        toast_requested.emit("%s treated — Bandage applied; about %.0fs recovery remains." % [s["name"], float(s["injury_remaining"])])
    else:
        var supply_name := "Bandage" if condition == "Wounded" else "First Aid Kit"
        if int(components.get(supply_name, 0)) <= 0:
            toast_requested.emit("You need %s." % ("a Bandage" if condition == "Wounded" else "a First Aid Kit"))
            return false
        components[supply_name] -= 1
        s["status"] = "Recovering"
        var base: float = 45.0 if condition == "Wounded" else 120.0
        var medical_skill: int = int(_best_available_skill("Medical", sid))
        var reduction: float = minf(0.35, float(medical_skill) * 0.04)
        var treatment_time: float = base * (1.0 - reduction) * CampLifeRules.treatment_time_multiplier(bool(buildings.get("Infirmary", false)))
        s["task"] = {"kind": "treatment", "remaining": treatment_time, "duration": base, "target": sid}
        s["history"].append("Day %d — Began %s treatment using %s." % [day, condition.to_lower(), supply_name])
        toast_requested.emit("%s treatment started with %s." % [s["name"], supply_name])
    save_game()
    state_changed.emit()
    return true

func _best_available_skill(skill, exclude_id = -1):
    var best = 0
    for s in survivors:
        if int(s["id"]) == int(exclude_id) or s["condition"] == "Dead":
            continue
        if s["status"] == "Available":
            best = max(best, int(s["skills"].get(skill, 0)))
    return best

func _complete_task(s):
    var task = s["task"].duplicate(true)
    s["task"] = {}
    s["status"] = "Available"
    var kind = task.get("kind", "")
    if kind == "craft":
        var recipe = task["recipe"]
        if recipe.has("gives_resource"):
            for key in recipe["gives_resource"].keys():
                resources[key] = int(resources.get(key, 0)) + int(recipe["gives_resource"][key])
        if recipe.has("gives_component"):
            for key in recipe["gives_component"].keys():
                components[key] = int(components.get(key, 0)) + int(recipe["gives_component"][key])
        if recipe.has("gives_gear"):
            inventory_gear.append(recipe["gives_gear"])
        add_skill_xp(s, "Technical", clamp(int(float(task["duration"]) / 3.0), 2, 12))
        _add_history("Day %d — %s crafted %s." % [day, s["name"], recipe["id"]])
        toast_requested.emit("%s finished %s." % [s["name"], recipe["id"]])
    elif kind == "build":
        var building = task["building"]
        buildings[building] = true
        add_skill_xp(s, "Technical", clamp(int(float(task["duration"]) / 3.0), 2, 12))
        _change_reputation(s, 2)
        s["history"].append("Day %d — Helped complete %s." % [day, building])
        _add_history("Day %d — %s completed %s." % [day, s["name"], building])
        toast_requested.emit("%s completed." % building)
    elif kind == "garden":
        garden_tended_day = day
        add_skill_xp(s, "Technical", 2)
        toast_requested.emit("Garden tended for Day %d." % day)
    elif kind == "chore":
        var chore:=str(task.get("chore",""))
        if chore=="stoke_fire": fire_level=clampf(fire_level+CampLifeRules.FIRE_MAINTAIN_GAIN,0.0,100.0)
        elif chore=="clean_camp":
            camp_maintenance=CampLifeRules.recover_camp_condition(camp_maintenance,chore)
            for survivor in survivors:
                if survivor["condition"]!="Dead" and survivor["status"] not in ["Expedition","Tactical Encounter"]:
                    var needs:=CampLifeRules.normalize_needs(survivor.get("needs",{})); needs["hygiene"]=clampf(float(needs["hygiene"])+18.0,0.0,100.0); survivor["needs"]=needs
        elif chore=="repair_perimeter": camp_maintenance=CampLifeRules.recover_camp_condition(camp_maintenance,chore)
        _add_history("Day %d — %s completed camp duty: %s." % [day,s["name"],task.get("label","Chore")])
        toast_requested.emit("%s complete." % task.get("label","Chore"))
    elif kind == "pet_care":
        var pet:Variant=get_pet(int(task.get("pet_id",-1)))
        if pet!=null:
            pet["needs"]=CampLifeRules.apply_pet_care(pet.get("needs",{}),str(task.get("action","")))
            toast_requested.emit("%s is %s." % [pet["name"],pet_mood_label(pet).to_lower()])
    elif kind == "treatment":
        if s["condition"] == "Critical":
            s["condition"] = "Wounded"
            s["injury_remaining"] = 180.0
        elif s["condition"] == "Wounded":
            s["condition"] = "Hurt"
            s["injury_remaining"] = 60.0
        s["status"] = "Available"
        toast_requested.emit("%s's treatment is complete." % s["name"])
    save_game()
    state_changed.emit()

func _can_pay(cost, component_cost = {}):
    for key in cost.keys():
        if int(resources.get(key, 0)) < int(cost[key]):
            return false
    for key in component_cost.keys():
        if int(components.get(key, 0)) < int(component_cost[key]):
            return false
    return true

func _pay(cost, component_cost = {}):
    for key in cost.keys():
        resources[key] = int(resources.get(key, 0)) - int(cost[key])
    for key in component_cost.keys():
        components[key] = int(components.get(key, 0)) - int(component_cost[key])

func start_craft(sid, station, recipe_id):
    var s: Variant = get_survivor(sid)
    if s == null or s["status"] != "Available":
        return false
    if station != "Fire Pit" and not buildings.get(station, false):
        return false
    var recipe: Variant = null
    for r in D.RECIPES.get(station, []):
        if r["id"] == recipe_id:
            recipe = r
            break
    if recipe == null:
        return false
    for req in recipe.get("requires", []):
        if not buildings.get(req, false):
            toast_requested.emit("Requires %s." % req)
            return false
    var cc = recipe.get("component_cost", {})
    if not _can_pay(recipe.get("cost", {}), cc):
        toast_requested.emit("Not enough materials.")
        return false
    _pay(recipe.get("cost", {}), cc)
    _clear_camp_activity(s)
    var duration = _work_duration(s, float(recipe["time"]))
    s["status"] = "Crafting"
    s["fatigue"] = min(100.0, float(s["fatigue"]) + CampLifeRules.crafting_fatigue(float(recipe["time"])))
    s["task"] = {"kind": "craft", "station": station, "recipe": recipe.duplicate(true), "remaining": duration, "duration": float(recipe["time"])}
    save_game()
    state_changed.emit()
    return true

func start_build(sid, building):
    var s: Variant = get_survivor(sid)
    if s == null or s["status"] != "Available":
        return false
    if buildings.get(building, false) or building_under_construction(str(building)) or not D.BUILDINGS.has(building):
        return false
    var data = D.BUILDINGS[building]
    for req in data.get("requires", []):
        if not buildings.get(req, false):
            toast_requested.emit("Requires %s." % req)
            return false
    if not _can_pay(data.get("cost", {}), data.get("component_cost", {})):
        toast_requested.emit("Not enough materials/components.")
        return false
    _pay(data.get("cost", {}), data.get("component_cost", {}))
    _clear_camp_activity(s)
    var duration = _work_duration(s, float(data["time"]))
    s["status"] = "Building"
    s["fatigue"] = min(100.0, float(s["fatigue"]) + CampLifeRules.fatigue_gain(float(data["time"]) / 5.0))
    s["task"] = {"kind": "build", "building": building, "remaining": duration, "duration": float(data["time"])}
    save_game()
    state_changed.emit()
    return true

func tend_garden(sid):
    if not buildings.get("Garden Plot", false):
        return false
    if garden_tended_day == day:
        toast_requested.emit("The garden has already been tended today.")
        return false
    var s: Variant = get_survivor(sid)
    if s == null or s["status"] != "Available":
        return false
    _clear_camp_activity(s)
    s["status"] = "Tending"
    s["fatigue"] = min(100.0, float(s["fatigue"]) + CampLifeRules.fatigue_gain(4.0))
    s["task"] = {"kind": "garden", "remaining": _work_duration(s, 8.0), "duration": 8.0}
    save_game()
    state_changed.emit()
    return true


func _work_duration(s, base):
    var reduction = min(0.30, int(s["skills"]["Technical"]) * 0.04)
    if s["traits"].has("Hard Worker"):
        reduction += 0.10
    elif s["traits"].has("Lazy"):
        reduction -= 0.10
    var leader: Variant = get_survivor(leader_id)
    if leader != null and leader["leader_ability"] == "Organizer":
        reduction += 0.10
    return max(base * 0.45, base * (1.0 - reduction))

func _default_gear_state(gear_name: String) -> Dictionary:
    if not D.GEAR.has(gear_name):
        return {}
    var data: Dictionary = D.GEAR[gear_name]
    if gear_name == "Flashlight":
        return {"charge": float(data.get("charge_max", 100.0))}
    if gear_name == "Lock Pick":
        return {"uses_left": rng.randi_range(int(data.get("uses_min", 3)), int(data.get("uses_max", 5)))}
    if gear_name == "Firecracker":
        return {"uses_left": 1}
    return {}

func _normalize_survivor_equipment_state(survivor) -> void:
    if survivor == null:
        return
    if not survivor.has("equipment_state") or not (survivor.get("equipment_state", {}) is Dictionary):
        survivor["equipment_state"] = {}
    var states: Dictionary = survivor["equipment_state"]
    var equipment: Dictionary = survivor.get("equipment", {})
    for slot in equipment.keys():
        var gear_name := str(equipment.get(slot, ""))
        if gear_name == "":
            states.erase(str(slot))
            continue
        if not states.has(str(slot)):
            var initial := _default_gear_state(gear_name)
            if not initial.is_empty():
                states[str(slot)] = initial
        elif gear_name == "Lock Pick":
            var lock_state_value = states.get(str(slot), {})
            if lock_state_value is Dictionary:
                var lock_state: Dictionary = lock_state_value
                lock_state["uses_left"] = clampi(int(lock_state.get("uses_left", 1)), 1, 3)
                states[str(slot)] = lock_state
    survivor["equipment_state"] = states

func _take_inventory_gear_state(gear_name: String) -> Dictionary:
    var pool_value = inventory_gear_states.get(gear_name, [])
    var pool: Array = pool_value if pool_value is Array else []
    if not pool.is_empty():
        var state_value = pool.pop_back()
        inventory_gear_states[gear_name] = pool
        var state: Dictionary = state_value.duplicate(true) if state_value is Dictionary else {}
        if gear_name == "Lock Pick" and not state.is_empty():
            state["uses_left"] = clampi(int(state.get("uses_left", 1)), 1, 3)
        return state
    return _default_gear_state(gear_name)

func _store_inventory_gear_state(gear_name: String, state: Dictionary) -> void:
    if gear_name == "" or state.is_empty():
        return
    var stored := state.duplicate(true)
    if gear_name == "Lock Pick":
        stored["uses_left"] = clampi(int(stored.get("uses_left", 1)), 1, 3)
    var pool_value = inventory_gear_states.get(gear_name, [])
    var pool: Array = pool_value if pool_value is Array else []
    pool.append(stored)
    inventory_gear_states[gear_name] = pool

func equip_gear(sid, gear_name):
    var s: Variant = get_survivor(sid)
    if s == null or not inventory_gear.has(gear_name) or not D.GEAR.has(gear_name):
        return false
    _normalize_survivor_equipment_state(s)
    var slot := str(D.GEAR[gear_name]["slot"])
    var old := str(s["equipment"].get(slot, ""))
    var states: Dictionary = s.get("equipment_state", {})
    var old_state_value = states.get(slot, {})
    var old_state: Dictionary = old_state_value if old_state_value is Dictionary else {}
    inventory_gear.erase(gear_name)
    var new_state := _take_inventory_gear_state(str(gear_name))
    if old != "":
        inventory_gear.append(old)
        _store_inventory_gear_state(old, old_state)
    s["equipment"][slot] = gear_name
    if new_state.is_empty():
        states.erase(slot)
    else:
        states[slot] = new_state
    s["equipment_state"] = states
    save_game()
    state_changed.emit()
    return true

func _process_expeditions(delta):
    var finished = []
    for exp in expeditions:
        if exp.get("state", "") != "traveling":
            continue
        if bool(exp.get("tactical_resolved", false)):
            var provisioned_ids: Array = exp.get("survivor_ids", []).duplicate()
            for returning_id in exp.get("return_recruit_ids", []):
                if not provisioned_ids.has(int(returning_id)):
                    provisioned_ids.append(int(returning_id))
            _credit_expedition_provisions(provisioned_ids, str(exp.get("zone", "")))
        exp["remaining"] = max(0.0, float(exp["remaining"]) - delta)
        var tactical_due = exp.get("combat_kind", "") != "" and not exp.get("combat_triggered", false) and float(exp["remaining"]) <= float(exp.get("combat_trigger_remaining", -1.0))
        if tactical_due:
            if current_combat.is_empty() and current_event.is_empty():
                _begin_tactical_encounter(exp)
            else:
                # Hold at the encounter point until the tactical board can open.
                # Never silently finish a run that was already assigned combat.
                exp["remaining"] = maxf(0.01, float(exp.get("combat_trigger_remaining", 0.01)))
            continue
        if exp.get("event_key", "") != "" and not exp.get("event_triggered", false) and float(exp["remaining"]) <= float(exp["event_trigger_remaining"]):
            # Schema-8 compatibility: old traveling saves may still carry a
            # legacy text-event key. Do not resolve abstract field rewards.
            exp["event_triggered"] = true
            exp["event_key"] = ""
        if float(exp["remaining"]) <= 0.0:
            finished.append(exp["id"])
    for eid in finished:
        _finish_expedition(eid)

func expedition_route_unlocked(zone: String) -> bool:
    return D.ZONES.has(zone) and ExpeditionRules.route_is_unlocked(zone, flags)

func expedition_route_band(zone: String) -> String:
    return ExpeditionRules.route_band(zone)

func expedition_route_hours(zone: String) -> float:
    return ExpeditionRules.route_hours(zone)

func expedition_route_lock_text(zone: String) -> String:
    return ExpeditionRules.route_lock_text(zone)

func expedition_vehicle_unlocked() -> bool:
    return ExpeditionRules.vehicle_unlocked(flags)

func unlock_expedition_vehicle() -> bool:
    if expedition_vehicle_unlocked():
        return false
    flags[ExpeditionRules.VEHICLE_UNLOCK_FLAG] = true
    if not unlocked_zones.has("Industrial Edge"):
        unlocked_zones.append("Industrial Edge")
    _add_history("Day %d — First Fire secured an expedition vehicle. Very Far routes are now reachable." % day)
    toast_requested.emit("Expedition vehicle unlocked — Very Far routes available.")
    save_game()
    state_changed.emit()
    return true

func expedition_supply_cost(zone: String, party_size: int) -> Dictionary:
    return ExpeditionRules.route_supply_cost(zone, party_size)

func expedition_cost_text(zone: String, party_size: int) -> String:
    return ExpeditionRules.route_cost_text(zone, party_size)

func can_pay_expedition_cost(zone: String, party_size: int) -> bool:
    var cost := expedition_supply_cost(zone, party_size)
    return int(resources.get("Cooked Food", 0)) >= int(cost.get("Cooked Food", 0)) and int(resources.get("Clean Water", 0)) >= int(cost.get("Clean Water", 0))

func _pay_expedition_cost(zone: String, party_size: int) -> void:
    var cost := expedition_supply_cost(zone, party_size)
    resources["Cooked Food"] = maxi(0, int(resources.get("Cooked Food", 0)) - int(cost.get("Cooked Food", 0)))
    resources["Clean Water"] = maxi(0, int(resources.get("Clean Water", 0)) - int(cost.get("Clean Water", 0)))

func _credit_expedition_provisions(party_ids: Array, zone: String) -> void:
    var per_survivor := expedition_supply_cost(zone, 1)
    var has_food := int(per_survivor.get("Cooked Food", 0)) > 0
    var has_water := int(per_survivor.get("Clean Water", 0)) > 0
    if not has_food and not has_water:
        return
    for sid_value in party_ids:
        var member: Variant = get_survivor(int(sid_value))
        if member == null or not member.has("daily_activity"):
            continue
        var activity := CampLifeRules.normalize_daily_activity(member.get("daily_activity", {}), day)
        if has_food:
            activity["ate_normally"] = true
        if has_water:
            activity["drank_normally"] = true
        member["daily_activity"] = activity

func _expedition_member_available(survivor) -> bool:
    if survivor == null or str(survivor.get("condition", "Dead")) == "Dead":
        return false
    if str(survivor.get("status", "Available")) != "Available" or not survivor.get("task", {}).is_empty():
        return false
    if has_method("survivor_can_assign"):
        return bool(call("survivor_can_assign", survivor))
    return true

func _expedition_party_ids(primary_id: int, companion_id: int = -1) -> Array:
    var ids: Array = [primary_id]
    if companion_id >= 0 and companion_id != primary_id:
        ids.append(companion_id)
    if ids.size() > ExpeditionRules.MAX_PARTY_SIZE:
        ids.resize(ExpeditionRules.MAX_PARTY_SIZE)
    for sid_value in ids:
        if not _expedition_member_available(get_survivor(int(sid_value))):
            return []
    return ids

func start_expedition(primary_id, zone, companion_id = -1):
    zone = str(zone)
    if not expedition_route_unlocked(zone):
        toast_requested.emit("%s is locked — %s." % [zone, expedition_route_lock_text(zone)])
        return false
    if not current_combat.is_empty():
        return false
    var party_ids := _expedition_party_ids(int(primary_id), int(companion_id))
    if party_ids.is_empty():
        toast_requested.emit("The expedition party is no longer available.")
        return false
    for sid_value in party_ids:
        var traveler: Variant = get_survivor(int(sid_value))
        if zone in ["Commercial Fringe", "Industrial Edge"] and float(traveler.get("fatigue", 0.0)) >= 95.0:
            toast_requested.emit("%s is too exhausted for that trip." % traveler["name"])
            return false
        if zone in ["Commercial Fringe", "Industrial Edge"] and traveler["condition"] == "Wounded":
            toast_requested.emit("%s is too badly wounded for that trip." % traveler["name"])
            return false
    if not can_pay_expedition_cost(zone, party_ids.size()):
        toast_requested.emit("%s needs %s for %d survivor%s." % [zone, expedition_cost_text(zone, party_ids.size()), party_ids.size(), "" if party_ids.size() == 1 else "s"])
        return false

    var outing: Dictionary = TacticalScenarios.pick_outing(zone, rng)
    var duration := ExpeditionRules.route_duration_seconds(zone, DAY_SECONDS)
    var exp = {
        "id": next_expedition_id,
        "survivor_ids": party_ids.duplicate(),
        "zone": zone,
        "duration": duration,
        "remaining": duration,
        "state": "departing",
        "event_key": "",
        "event_triggered": true,
        "event_trigger_remaining": -1.0,
        "combat_kind": str(outing.get("kind", "explore")),
        "combat_triggered": false,
        "combat_trigger_remaining": 0.0,
        "tactical_resolved": false,
        "quiet_explore": bool(outing.get("quiet", false)),
        "rescue_pet": bool(outing.get("rescue_pet", false)),
        "outing": str(outing.get("outing", "infected_explore")),
        "time_cost_paid": false,
        "special_site": "",
        "recovered_loot": {},
        "recovered_gear": "",
        "return_recruit_ids": [],
        "return_pet": {},
    }
    next_expedition_id += 1
    expeditions.append(exp)
    _pay_expedition_cost(zone, party_ids.size())
    for sid_value in party_ids:
        var member: Variant = get_survivor(int(sid_value))
        if member != null:
            _clear_camp_activity(member)
            member["status"] = "Expedition"
            member["task"] = {"expedition_id": exp["id"]}
        recent_expedition_ids.append(int(sid_value))
    while recent_expedition_ids.size() > 4:
        recent_expedition_ids.pop_front()

    _begin_tactical_encounter(exp)
    save_game()
    state_changed.emit()
    return not current_combat.is_empty()

func _commit_expedition_return_payload(exp) -> String:
    if exp == null:
        return ""
    var bits: Array = []
    var recovered_value = exp.get("recovered_loot", {})
    var recovered: Dictionary = recovered_value if recovered_value is Dictionary else {}
    var keys: Array = recovered.keys()
    keys.sort()
    for key_value in keys:
        var item_name := str(key_value)
        var amount := maxi(0, int(recovered.get(key_value, 0)))
        if amount <= 0:
            continue
        if _store_loot_item(item_name, amount):
            bits.append("+%d %s" % [amount, item_name])
    var recovered_gear := str(exp.get("recovered_gear", ""))
    if recovered_gear != "" and D.GEAR.has(recovered_gear):
        inventory_gear.append(recovered_gear)
        bits.append(recovered_gear)
    var returning_pet_value = exp.get("return_pet", {})
    var returning_pet: Dictionary = returning_pet_value if returning_pet_value is Dictionary else {}
    if not returning_pet.is_empty():
        _add_pet(returning_pet)
        bits.append("%s rescued" % str(returning_pet.get("name", "Pet")))
    exp["recovered_loot"] = {}
    exp["recovered_gear"] = ""
    exp["return_pet"] = {}
    exp["time_cost_paid"] = true
    return ", ".join(bits)

func start_special_site(primary_id, site, companion_id = -1):
    if not special_sites.has(site) or not bool(special_sites[site].get("discovered", false)) or bool(special_sites[site].get("cleared", false)):
        return false
    if not current_combat.is_empty():
        return false
    var site_data: Dictionary = D.SPECIAL_SITES.get(site, {})
    var zone := str(site_data.get("zone", "Commercial Fringe"))
    if not expedition_route_unlocked(zone):
        toast_requested.emit("%s is locked — %s." % [site, expedition_route_lock_text(zone)])
        return false
    var party_ids := _expedition_party_ids(int(primary_id), int(companion_id))
    if party_ids.is_empty():
        return false
    if not can_pay_expedition_cost(zone, party_ids.size()):
        toast_requested.emit("%s needs %s for %d survivor%s." % [site, expedition_cost_text(zone, party_ids.size()), party_ids.size(), "" if party_ids.size() == 1 else "s"])
        return false
    var duration := ExpeditionRules.route_duration_seconds(zone, DAY_SECONDS)
    var exp = {
        "id": next_expedition_id,
        "survivor_ids": party_ids.duplicate(),
        "zone": zone,
        "duration": duration,
        "remaining": duration,
        "state": "departing",
        "event_key": "",
        "event_triggered": true,
        "event_trigger_remaining": -1.0,
        "combat_kind": "explore",
        "combat_triggered": false,
        "combat_trigger_remaining": 0.0,
        "tactical_resolved": false,
        "quiet_explore": false,
        "rescue_pet": false,
        "outing": "special_site",
        "time_cost_paid": false,
        "special_site": site,
        "recovered_loot": {},
        "recovered_gear": "",
        "return_recruit_ids": [],
        "return_pet": {},
    }
    next_expedition_id += 1
    expeditions.append(exp)
    _pay_expedition_cost(zone, party_ids.size())
    for sid_value in party_ids:
        var member: Variant = get_survivor(int(sid_value))
        if member != null:
            _clear_camp_activity(member)
            member["status"] = "Expedition"
            member["task"] = {"expedition_id": exp["id"]}
    _begin_tactical_encounter(exp)
    save_game()
    state_changed.emit()
    return not current_combat.is_empty()

func _pick_tactical_kind(zone):
    return TacticalScenarios.pick_kind(str(zone), rng)

func _tactical_gear_pool(zone: String) -> Array:
    var pool: Array = []
    var zone_index := D.ZONE_ORDER.find(zone)
    if zone_index < 0:
        zone_index = 0
    for i in range(zone_index + 1):
        var tier_zone := str(D.ZONE_ORDER[i])
        pool.append_array(Array(D.TACTICAL_GEAR_UNLOCKS_BY_ZONE.get(tier_zone, [])))
    return pool

func _tactical_gear_find_chance(zone: String) -> float:
    return float({
        "Camp Perimeter": 0.30,
        "Nearby Streets": 0.50,
        "Residential Blocks": 1.0,
        "Commercial Fringe": 1.0,
        "Industrial Edge": 1.0,
    }.get(zone, 1.0))

func _pick_tactical_gear(zone: String) -> String:
    var pool := _tactical_gear_pool(zone)
    if pool.is_empty() or rng.randf() > _tactical_gear_find_chance(zone):
        return ""
    return str(pool[rng.randi_range(0, pool.size() - 1)])

func _combat_condition_hp(s):
    if s == null: return 0
    match str(s.get("condition", "Healthy")):
        "Hurt": return 14
        "Wounded": return 10
        "Critical": return 6
        "Dead": return 0
        _: return 18

func _begin_tactical_encounter(exp):
    if exp == null or not current_combat.is_empty():
        return
    var ids: Array = exp.get("survivor_ids", [])
    if ids.is_empty():
        return
    var lead: Variant = get_survivor(ids[0])
    if lead == null or lead["condition"] == "Dead":
        return
    exp["combat_triggered"] = true
    exp["state"] = "combat"
    for sid in ids:
        var s: Variant = get_survivor(sid)
        if s != null and s["condition"] != "Dead":
            s["status"] = "Tactical Encounter"
    var combat_kind := str(exp.get("combat_kind", "ambush"))
    var environment_id := TacticalScenarios.pick_environment(str(exp["zone"]), combat_kind, rng)
    var environment_variant := TacticalScenarios.environment_variant(environment_id, rng)
    var scene_state: Dictionary = TacticalScenarios.pick_scene_state(environment_id, rng)
    var rescue_candidate := {}
    var rescue_is_pet := false
    if combat_kind == "rescue":
        rescue_is_pet = bool(exp.get("rescue_pet", false)) and pets.size() < CampLifeRules.MAX_PETS
        if rescue_is_pet:
            rescue_candidate = _generate_pet_candidate()
        else:
            rescue_candidate = _generate_survivor(false)
            rescue_candidate["status"] = "Awaiting Rescue"
            rescue_candidate["task"] = {}
            rescue_candidate["stress"] = rng.randf_range(35.0, 60.0)
            rescue_candidate["fatigue"] = rng.randf_range(15.0, 35.0)
    current_combat = {
        "uid": "%d-%d-%d" % [day, int(exp["id"]), rng.randi_range(1000, 999999)],
        "expedition_id": int(exp["id"]),
        "survivor_ids": ids.duplicate(true),
        "zone": str(exp["zone"]),
        "zone_pressure": int(zone_pressure.get(str(exp["zone"]), 0)),
        "kind": combat_kind,
        "outing": str(exp.get("outing", combat_kind)),
        "quiet": bool(exp.get("quiet_explore", false)),
        "rescue_candidate": rescue_candidate.duplicate(true) if combat_kind == "rescue" else {},
        "rescue_is_pet": rescue_is_pet,
        "environment_id": environment_id,
        "environment_variant": environment_variant,
        "time_of_day": str(scene_state.get("time_of_day", "day")),
        "power_on": bool(scene_state.get("power_on", false)),
        "location_name": TacticalScenarios.environment_name(environment_id),
        "field_gear": _pick_tactical_gear(str(exp["zone"])) if combat_kind == "explore" else "",
        "seed": rng.randi_range(1, 2147483000),
        "runtime": {
            "lead_hp": _combat_condition_hp(lead),
            "objective_done": str(exp.get("combat_kind", "ambush")) == "ambush",
            "tick": 0
        }
    }
    _add_history("Day %d — %s entered a tactical encounter at %s." % [day, _party_names(ids), current_combat["location_name"]])
    # Thinking at the tactical board should never burn camp time in real time.
    sim_paused = true
    save_game()
    combat_changed.emit()
    state_changed.emit()

func update_combat_runtime(data):
    if current_combat.is_empty():
        return
    current_combat["runtime"] = data.duplicate(true)
    save_game()

func consume_combat_ammo(_amount):
    # Compatibility facade for older tactical code/saves. Current ranged
    # weapons use magazine/chamber reloads with no camp Ammo resource.
    return true

func _condition_rank(name):
    return {"Healthy": 0, "Hurt": 1, "Wounded": 2, "Critical": 3, "Dead": 4}.get(str(name), 0)

func _commit_tactical_health(s, hp, max_hp, reason):
    if s == null or s["condition"] == "Dead":
        return
    hp = int(hp)
    max_hp = max(1, int(max_hp))
    if hp <= 0:
        _kill_survivor(s, reason)
        return
    var ratio = float(hp) / float(max_hp)
    var target = "Healthy"
    var injury_time = 0.0
    if ratio < 0.25:
        target = "Critical"; injury_time = 360.0
    elif ratio < 0.55:
        target = "Wounded"; injury_time = 180.0
    elif ratio < 0.80:
        target = "Hurt"; injury_time = 60.0
    if _condition_rank(target) > _condition_rank(s["condition"]):
        s["condition"] = target
        s["injury_remaining"] = injury_time
        s["history"].append("Day %d — Injured during a tactical encounter: %s." % [day, target])

func _prepare_rescue_candidate(candidate_value, hp: int, max_hp: int) -> Dictionary:
    var candidate: Dictionary = candidate_value.duplicate(true) if candidate_value is Dictionary else {}
    if candidate.is_empty():
        return candidate
    var ratio := float(maxi(0, hp)) / float(maxi(1, max_hp))
    var condition := "Healthy"
    var injury_time := 0.0
    if ratio < 0.25:
        condition = "Critical"; injury_time = 360.0
    elif ratio < 0.55:
        condition = "Wounded"; injury_time = 180.0
    elif ratio < 0.80:
        condition = "Hurt"; injury_time = 60.0
    candidate["condition"] = condition
    candidate["injury_remaining"] = injury_time
    candidate["stress"] = min(100.0, float(candidate.get("stress", 10.0)) + float(maxi(0, max_hp - hp)) * 3.0)
    candidate["status"] = "Available"
    candidate["task"] = {}
    if condition != "Healthy":
        var candidate_history: Array = candidate.get("history", [])
        candidate_history.append("Day %d — Injured during rescue: %s." % [day, condition])
        candidate["history"] = candidate_history
    return candidate

func _store_loot_item(item_name: String, amount: int = 1) -> bool:
    if amount <= 0:
        return false
    if D.RESOURCE_ORDER.has(item_name):
        resources[item_name] = int(resources.get(item_name, 0)) + amount
        return true
    if D.COMPONENT_ORDER.has(item_name):
        components[item_name] = int(components.get(item_name, 0)) + amount
        return true
    return false

func _format_tactical_container_loot(value) -> String:
    if not (value is Dictionary):
        return ""
    var found: Dictionary = value
    var bits: Array = []
    for key in found.keys():
        var item_name := str(key)
        var amount := clampi(int(found[key]), 0, 12)
        if amount > 0:
            bits.append("+%d %s" % [amount, item_name])
    bits.sort()
    return ", ".join(bits)

func _commit_tactical_secondary_state(survivor, item_name: String, state_value) -> void:
    if survivor == null:
        return
    _normalize_survivor_equipment_state(survivor)
    var equipment: Dictionary = survivor.get("equipment", {})
    var states: Dictionary = survivor.get("equipment_state", {})
    equipment["Secondary"] = item_name
    if item_name == "":
        states.erase("Secondary")
    else:
        states["Secondary"] = state_value.duplicate(true) if state_value is Dictionary else {}
    survivor["equipment"] = equipment
    survivor["equipment_state"] = states

func resolve_combat(result):
    if current_combat.is_empty():
        return
    var encounter = current_combat.duplicate(true)
    var eid = int(encounter.get("expedition_id", -1))
    var exp: Variant = _find_expedition(eid)
    var ids: Array = encounter.get("survivor_ids", [])
    var lead: Variant = get_survivor(ids[0]) if not ids.is_empty() else null

    var infected_stress := CampLifeRules.tactical_infected_stress(int(result.get("infected_encountered", 0)))
    if lead != null:
        _commit_tactical_health(lead, result.get("lead_hp", 0), result.get("lead_max_hp", 18), "was killed in a tactical field encounter")
        _commit_tactical_secondary_state(lead, str(result.get("lead_secondary_item", lead.get("equipment", {}).get("Secondary", ""))), result.get("lead_secondary_state", lead.get("equipment_state", {}).get("Secondary", {})))
        lead["stress"] = min(100.0, float(lead["stress"]) + infected_stress + min(18.0, float(result.get("damage", 0)) * 1.5))
        var combat_xp := mini(20, int(result.get("kills", 0)) * 2 + int(result.get("melee", 0)) + int(result.get("shots", 0)))
        if combat_xp > 0:
            add_skill_xp(lead, "Combat", combat_xp)
    if ids.size() > 1:
        var companion: Variant = get_survivor(int(ids[1]))
        if companion != null:
            var fallback_companion_hp: int = 0 if companion.get("condition", "Dead") == "Dead" else int(_combat_condition_hp(companion))
            _commit_tactical_health(companion, result.get("companion_hp", fallback_companion_hp), result.get("companion_max_hp", maxi(1, fallback_companion_hp)), "was killed while accompanying an expedition")
            companion["stress"] = min(100.0, float(companion.get("stress", 0.0)) + infected_stress + 2.0)
    current_combat = {}
    sim_paused = false
    combat_changed.emit()

    if exp == null:
        save_game(); state_changed.emit(); return
    exp["tactical_resolved"] = true
    if float(exp.get("remaining", 0.0)) <= 0.0:
        exp["remaining"] = maxf(0.0, float(exp.get("duration", 0.0)))
    var living = []
    for sid in exp["survivor_ids"]:
        var s: Variant = get_survivor(sid)
        if s != null and s["condition"] != "Dead": living.append(s)
    if living.is_empty() or lead == null or lead["condition"] == "Dead" or str(result.get("outcome", "dead")) != "escaped":
        _add_history("Day %d — The tactical encounter at %s ended in disaster." % [day, encounter.get("location_name", "the field")])
        _abort_expedition(eid, false)
        _check_game_over()
        save_game(); state_changed.emit(); return

    exp["state"] = "pending"
    for s in living:
        s["status"] = "Pending Expedition Event"
    var event_context = {
        "expedition_id": eid,
        "survivor_ids": exp["survivor_ids"].duplicate(true),
        "zone": exp["zone"],
        "return_after_tactical": true,
    }
    var event = _event_base("tactical_result", "Tactical Encounter", "", [], event_context)
    var kind = str(encounter.get("kind", "ambush"))
    var place = str(encounter.get("location_name", "the area"))
    var recovered_value = result.get("container_loot", {})
    var recovered_loot: Dictionary = recovered_value.duplicate(true) if recovered_value is Dictionary else {}
    exp["recovered_loot"] = recovered_loot
    var container_reward := _format_tactical_container_loot(recovered_loot)
    var loot_note := " Carrying: %s." % container_reward if container_reward != "" else ""
    if container_reward != "":
        _add_history("Day %d — Physically recovered at %s and carried on the return trip: %s." % [day, place, container_reward])
    if kind == "rescue" and bool(result.get("rescued", false)) and bool(encounter.get("rescue_is_pet",false)):
        var pet_candidate:Dictionary=encounter.get("rescue_candidate",{}).duplicate(true)
        exp["return_pet"] = pet_candidate
        _queue_field_result(event,"%s Rescued" % str(pet_candidate.get("name","Pet")),"You get the stranded %s out of %s alive. It stays with the expedition for the return to First Fire.%s" % [str(pet_candidate.get("species","animal")).to_lower(),place,loot_note],"A rescued pet joined the return trip to First Fire.")
    elif kind == "rescue" and bool(result.get("rescued", false)):
        var rescue_candidate: Dictionary = _prepare_rescue_candidate(encounter.get("rescue_candidate", {}), int(result.get("rescue_survivor_hp", 1)), int(result.get("rescue_survivor_max_hp", TacticalBalance.RESCUE_SURVIVOR_HP)))
        var rescue_name := str(rescue_candidate.get("name", "The survivor"))
        _queue_recruit_offer(event, "%s Makes It Out" % rescue_name, "You get %s out of %s alive. Away from the infected and with a little room to breathe, they finally decide whether they trust First Fire enough to come back with you.%s" % [rescue_name, place, loot_note], "tactical_rescue", "", rescue_candidate)
    elif kind == "explore":
        var searches := int(result.get("searches_completed", 0))
        var total_sites := maxi(searches, int(result.get("search_sites_total", searches)))
        var reward: String = container_reward
        var recovered_gear := str(result.get("field_gear", "")) if bool(result.get("objective_done", false)) else ""
        if recovered_gear != "" and D.GEAR.has(recovered_gear):
            exp["recovered_gear"] = recovered_gear
            reward = (reward + ", " if reward != "" else "") + recovered_gear
        if bool(result.get("objective_done", false)):
            if recovered_gear != "":
                _queue_field_result(event, "%s Searched" % place, "You searched %d/%d marked spots, recovered the target gear, and got back out. Find: %s." % [searches, total_sites, reward if reward != "" else "nothing extra"], "The party searched %s tactically and escaped with %s." % [place, recovered_gear])
            else:
                _queue_field_result(event, "%s Searched" % place, "You finished searching %d/%d marked spots and got back out. There was no special gear cache this time. Find: %s." % [searches, total_sites, reward if reward != "" else "nothing useful"], "The party fully scavenged %s and escaped." % place)
        elif searches > 0:
            var partial_reason := "before finding the target gear" if str(result.get("field_gear", "")) != "" else "before checking every marked spot"
            _queue_field_result(event, "Partial Search of %s" % place, "You searched %d/%d marked spots and escaped %s. You still keep the supplies you physically recovered: %s." % [searches, total_sites, partial_reason, reward if reward != "" else "nothing useful"], "The party partially searched %s and withdrew alive." % place)
        else:
            var opportunity_text := "the marked gear opportunity here is gone" if str(result.get("field_gear", "")) != "" else "you leave without searching the marked containers"
            _queue_field_result(event, "Withdrew from %s" % place, "You found a way out before committing to the search; %s." % opportunity_text, "The party withdrew from %s before searching the tactical objective." % place)
    elif kind == "rescue" and not bool(result.get("objective_done", false)):
        var rescue_name := str(encounter.get("rescue_candidate", {}).get("name", "the survivor"))
        if not bool(result.get("rescue_survivor_alive", true)):
            _queue_field_result(event, "Rescue Failed", "%s did not survive the encounter at %s. You still make it back out, but there is nobody left to bring home.%s" % [rescue_name, place, loot_note], "The attempted rescue at %s failed, but the expedition survivor escaped." % place)
        elif bool(result.get("rescue_contacted", false)):
            _queue_field_result(event, "Separated at %s" % place, "You reached %s, but extracted before both of you could reach the exit. The outing is over and the rescue opportunity is lost.%s" % [rescue_name, loot_note], "The party reached a stranded survivor at %s but could not extract them." % place)
        else:
            _queue_field_result(event, "Withdrew from %s" % place, "You found a way out and chose survival over the rescue. The outing is over and the opportunity here is gone.%s" % loot_note, "The party withdrew from %s before completing the tactical objective." % place)
    else:
        _queue_field_result(event, "Broke Contact", "The ambush never became a stand-up fight. You made space, found an exit, and got away from %s.%s" % [place, loot_note], "The party escaped a tactical ambush at %s." % place)
    save_game()
    state_changed.emit()

func _select_field_event(zone):
    # Compatibility facade. Delete with FFFieldEventsLegacy when Alpha 0.3 has
    # converted every outside-world text encounter to a tactical scenario.
    return LegacyFieldEvents.select(str(zone), rng)

func _find_expedition(eid) -> Variant:
    for exp in expeditions:
        if int(exp["id"]) == int(eid):
            return exp
    return null

func _resume_expedition(eid):
    var exp: Variant = _find_expedition(eid)
    if exp == null:
        return
    if float(exp.get("remaining", 0.0)) <= 0.0:
        _finish_expedition(eid)
        return
    exp["state"] = "traveling"
    for sid in exp["survivor_ids"]:
        var s: Variant = get_survivor(sid)
        if s != null and s["condition"] != "Dead":
            s["status"] = "Expedition"
    for sid_value in exp.get("return_recruit_ids", []):
        var returning_recruit: Variant = get_survivor(int(sid_value))
        if returning_recruit != null and returning_recruit["condition"] != "Dead":
            returning_recruit["status"] = "Expedition"
            returning_recruit["task"] = {"expedition_id": int(exp["id"])}

func _abort_expedition(eid, return_loot = false):
    var exp: Variant = _find_expedition(eid)
    if exp == null:
        return
    if return_loot:
        _finish_expedition(eid)
        return
    for sid in exp["survivor_ids"]:
        var s: Variant = get_survivor(sid)
        if s != null and s["condition"] != "Dead":
            s["status"] = "Available"
            s["task"] = {}
    expeditions.erase(exp)
    save_game()
    state_changed.emit()

func _finish_expedition(eid):
    var exp: Variant = _find_expedition(eid)
    if exp == null:
        return
    if exp.get("special_site", "") != "" and bool(exp.get("tactical_resolved", false)):
        var resolved_site := str(exp.get("special_site", ""))
        if special_sites.has(resolved_site):
            special_sites[resolved_site]["cleared"] = true
            _add_history("Day %d — %s was cleared tactically." % [day, resolved_site])

    var zone = exp["zone"]
    var log_bits = []
    if not exp.get("tactical_resolved", false):
        _resolve_routine_danger(exp, log_bits)

    var living_party: Array = []
    var living_returner_ids: Array = []
    for sid in exp["survivor_ids"]:
        var s: Variant = get_survivor(sid)
        if s != null and s["condition"] != "Dead":
            living_party.append(s)
            living_returner_ids.append(int(s["id"]))
    for sid_value in exp.get("return_recruit_ids", []):
        var returning_recruit: Variant = get_survivor(int(sid_value))
        if returning_recruit != null and returning_recruit["condition"] != "Dead":
            if not living_returner_ids.has(int(returning_recruit["id"])):
                living_returner_ids.append(int(returning_recruit["id"]))

    # Carried tactical loot/pets only reach First Fire with a living human
    # returner. If the whole return party dies while Away, the payload is lost.
    if living_returner_ids.is_empty():
        var lost_payload := _format_tactical_container_loot(exp.get("recovered_loot", {}))
        var lost_gear := str(exp.get("recovered_gear", ""))
        var lost_bits: Array = []
        if lost_payload != "":
            lost_bits.append(lost_payload)
        if lost_gear != "":
            lost_bits.append(lost_gear)
        var lost_pet_value = exp.get("return_pet", {})
        var lost_pet: Dictionary = lost_pet_value if lost_pet_value is Dictionary else {}
        if not lost_pet.is_empty():
            lost_bits.append("%s rescue" % str(lost_pet.get("name", "pet")))
        var lost_text := ", ".join(lost_bits) if not lost_bits.is_empty() else "no carried loot"
        _add_history("Day %d — The return party from %s was lost before reaching First Fire; %s was lost with them." % [day, zone, lost_text])
        expeditions.erase(exp)
        _check_game_over()
        save_game()
        state_changed.emit()
        return

    var carried_return := _commit_expedition_return_payload(exp) if bool(exp.get("tactical_resolved", false)) else ""

    # Expedition return never invents a haul. Resources/components/gear must
    # already have been physically recovered from tactical containers, corpses,
    # or an explicit on-map pickup before this point.
    var loot: Dictionary = {}
    var gear_found := ""

    zone_pressure[zone] = int(zone_pressure.get(zone, 0)) + int(D.ZONES[zone]["pressure"])
    zone_successes[zone] = int(zone_successes.get(zone, 0)) + 1
    _check_zone_unlock(zone)

    for s in living_party:
        s["status"] = "Available"
        s["task"] = {}
        s["fatigue"] = min(100.0, float(s["fatigue"]) + ExpeditionRules.route_fatigue_hit(zone))
        s["expeditions_done"] = int(s.get("expeditions_done", 0)) + 1
        var sxp = {"Camp Perimeter": 3, "Nearby Streets": 5, "Residential Blocks": 7, "Commercial Fringe": 9, "Industrial Edge": 11}[zone]
        var survxp = {"Camp Perimeter": 1, "Nearby Streets": 2, "Residential Blocks": 3, "Commercial Fringe": 4, "Industrial Edge": 6}[zone]
        add_skill_xp(s, "Scavenging", sxp)
        add_skill_xp(s, "Survival", survxp)
        s["history"].append("Day %d — Returned from %s." % [day, zone])
    for sid_value in exp.get("return_recruit_ids", []):
        var returning_recruit: Variant = get_survivor(int(sid_value))
        if returning_recruit != null and returning_recruit["condition"] != "Dead":
            returning_recruit["status"] = "Available"
            returning_recruit["task"] = {}
    exp["return_recruit_ids"] = []
    if living_party.size() == 2:
        _change_relationship(living_party[0], living_party[1], 2)
        _change_relationship(living_party[1], living_party[0], 2)

    var loot_text = []
    for key in loot.keys():
        if int(loot[key]) > 0:
            loot_text.append("+%d %s" % [loot[key], key])
    if gear_found != "":
        loot_text.append("Found %s" % gear_found)
    var names = _party_names(living_returner_ids)
    if bool(exp.get("tactical_resolved", false)):
        var haul_suffix := " (%s)" % carried_return if carried_return != "" else ""
        _add_history("Day %d — %s returned from the tactical outing to %s%s." % [day, names, zone, haul_suffix])
        toast_requested.emit("%s returned from %s%s." % [names, zone, haul_suffix])
    elif loot_text.is_empty():
        _add_history("Day %d — %s returned from %s empty-handed." % [day, names, zone])
        toast_requested.emit("%s returned empty-handed." % names)
    else:
        var haul_summary = ", ".join(loot_text)
        _add_history("Day %d — %s returned from %s (%s)." % [day, names, zone, haul_summary])
        toast_requested.emit("%s returned: %s" % [names, haul_summary])
    expeditions.erase(exp)
    _check_game_over()
    save_game()
    state_changed.emit()

func _resolve_routine_danger(exp, log_bits):
    var zone = exp["zone"]
    var chance = {"Camp Perimeter": 0.0, "Nearby Streets": 0.05, "Residential Blocks": 0.15, "Commercial Fringe": 0.25, "Industrial Edge": 0.35}[zone]
    if rng.randf() >= chance:
        return
    var dc = {"Nearby Streets": 8, "Residential Blocks": 10, "Commercial Fringe": 13, "Industrial Edge": 15}.get(zone, 7)
    var best_survival: Variant = null
    for sid in exp["survivor_ids"]:
        var s: Variant = get_survivor(sid)
        if s != null and s["condition"] != "Dead":
            if best_survival == null or int(s["skills"]["Survival"]) > int(best_survival["skills"]["Survival"]):
                best_survival = s
    if best_survival == null:
        return
    var result = skill_check(best_survival, "Survival", dc)
    if result >= 1:
        log_bits.append("Avoided trouble")
        return
    var target: Variant = get_survivor(exp["survivor_ids"][rng.randi_range(0, exp["survivor_ids"].size() - 1)])
    if target == null or target["condition"] == "Dead":
        return
    var combat_bonus = _equipment_combat_bonus(target)
    var combat_result = skill_check(target, "Combat", dc, combat_bonus)
    add_skill_xp(target, "Combat", rng.randi_range(5, 10))
    if combat_result >= 1:
        log_bits.append("Fought off danger")
    elif zone == "Nearby Streets":
        _apply_injury(target, "Hurt")
    elif zone == "Residential Blocks":
        _apply_injury(target, "Wounded" if combat_result < 0 else "Hurt")
    elif zone == "Commercial Fringe":
        _apply_injury(target, "Critical" if combat_result < 0 else "Wounded")
    elif zone == "Industrial Edge":
        if combat_result < 0 and (target["condition"] == "Wounded" or float(target["fatigue"]) >= 80.0) and rng.randf() < 0.18:
            _kill_survivor(target, "was killed during an expedition to the Industrial Edge")
        else:
            _apply_injury(target, "Critical" if combat_result < 1 else "Wounded")

func _equipment_combat_bonus(s):
    var weapon = s["equipment"].get("Weapon", "")
    if weapon == "" or not D.GEAR.has(weapon):
        return 0
    return int(D.GEAR[weapon].get("combat", 0))

func _apply_injury(s, severity):
    if s == null or s["condition"] == "Dead":
        return
    var protection = 0.0
    var clothing = s["equipment"].get("Clothing", "")
    if clothing != "" and D.GEAR.has(clothing):
        protection = float(D.GEAR[clothing].get("protect", 0.0))
    if rng.randf() < protection:
        if severity == "Critical": severity = "Wounded"
        elif severity == "Wounded": severity = "Hurt"
        elif severity == "Hurt": return
    if severity == "Hurt":
        if s["condition"] == "Healthy":
            s["condition"] = "Hurt"
            s["injury_remaining"] = 60.0
    elif severity == "Wounded":
        if s["condition"] == "Critical":
            return
        s["condition"] = "Wounded"
        s["injury_remaining"] = 180.0
    elif severity == "Critical":
        if s["condition"] == "Critical":
            _kill_survivor(s, "died from accumulated injuries")
            return
        s["condition"] = "Critical"
        s["injury_remaining"] = 0.0
    s["stress"] = min(100.0, float(s["stress"]) + (5.0 if severity == "Hurt" else 12.0))
    s["history"].append("Day %d — Was %s." % [day, severity.to_lower()])

func _kill_survivor(s, reason):
    if s == null or s["condition"] == "Dead":
        return
    s["condition"] = "Dead"
    s["status"] = "Dead"
    s["task"] = {}
    s["history"].append("Day %d — Died: %s." % [day, reason])
    _add_history("Day %d — %s %s." % [day, s["name"], reason])
    for other in survivors:
        if other["condition"] == "Dead" or int(other["id"]) == int(s["id"]):
            continue
        var rel = int(other["relationships"].get(str(s["id"]), 0))
        if rel >= 60:
            other["stress"] = min(100.0, float(other["stress"]) + 25.0)
        elif rel >= 25:
            other["stress"] = min(100.0, float(other["stress"]) + 15.0)
    if coordinator_id == int(s["id"]):
        coordinator_id = -1
        if leadership_form == "Coordinator": leadership_form = "None"
    if leader_id == int(s["id"]):
        leader_id = -1
        leadership_form = "None"
    _check_game_over()

func _roll_loot(exp, party):
    var zone = exp["zone"]
    var target_items = _loot_item_target(zone)
    var pressure = int(zone_pressure.get(zone, 0))
    if pressure >= 85:
        target_items = max(0, target_items - 2)
    elif pressure >= 60:
        target_items = max(0, target_items - 1)

    var best_scav = 0
    for s in party:
        best_scav = max(best_scav, int(s["skills"]["Scavenging"]))
    # Skill improves reliability without returning to giant Alpha loot piles.
    if best_scav >= 3 and rng.randf() < 0.20:
        target_items += 1
    if best_scav >= 6 and rng.randf() < 0.15:
        target_items += 1

    var zone_cap = ExpeditionRules.zone_cap(str(zone))
    target_items = min(target_items, int(zone_cap))

    var capacity = 0
    for s in party:
        capacity += _pack_capacity(s)
    target_items = min(target_items, capacity)

    var loot = {}
    for i in range(target_items):
        var key = _weighted_loot_pick(zone)
        loot[key] = int(loot.get(key, 0)) + 1

    var leader: Variant = get_survivor(leader_id)
    if leader != null and leader["leader_ability"] == "Provider" and target_items < capacity and target_items < int(zone_cap) and rng.randf() < 0.15:
        var bonus_key = _weighted_loot_pick(zone)
        loot[bonus_key] = int(loot.get(bonus_key, 0)) + 1
    return loot

func _loot_item_target(zone):
    return ExpeditionRules.loot_item_target(str(zone), rng)

func _weighted_loot_pick(zone):
    var table = D.ZONES[zone]["loot"]
    var total = 0.0
    var weighted = []
    for key in table.keys():
        var w = float(table[key])
        weighted.append([key, w])
        total += w
    var roll = rng.randf_range(0.0, total)
    var cursor = 0.0
    for entry in weighted:
        cursor += float(entry[1])
        if roll <= cursor:
            return entry[0]
    return weighted.back()[0]

func _pack_capacity(s):
    var pack = s["equipment"].get("Pack", "")
    if pack != "" and D.GEAR.has(pack):
        return int(D.GEAR[pack].get("capacity", 4))
    return 4

func survivor_carry_capacity(survivor) -> int:
    if survivor == null:
        return 4
    return _pack_capacity(survivor)

func _roll_gear(exp, party):
    var zone = exp["zone"]
    var chance = {"Camp Perimeter": 0.01, "Nearby Streets": 0.04, "Residential Blocks": 0.10, "Commercial Fringe": 0.16, "Industrial Edge": 0.18}[zone]
    var best = 0
    for s in party:
        best = max(best, int(s["skills"]["Scavenging"]))
    chance += best * 0.015
    if int(zone_pressure.get(zone, 0)) >= 60:
        chance *= 0.65
    chance = min(chance, 0.35)
    if rng.randf() > chance:
        return ""
    var pool = []
    if zone == "Camp Perimeter":
        pool = ["Work Gloves", "Flashlight", "Firecracker"]
    elif zone == "Nearby Streets":
        pool = ["Kitchen Knife", "Work Gloves", "Heavy Boots", "School Backpack", "Lock Pick", "Firecracker"]
    elif zone == "Residential Blocks":
        pool = ["Kitchen Knife", "Baseball Bat", "Crossbow", "Flashlight", "Lock Pick", "Screwdriver Set", "School Backpack", "Leather Jacket"]
    elif zone == "Commercial Fringe":
        pool = ["Crowbar", "Sledgehammer", "Hatchet", "Flashlight", "Lock Pick", "Firecracker", "Bolt Cutters", "Toolbox", "6-Shot Revolver", "Double-Barrel Shotgun", "Hiking Pack", "Leather Jacket"]
    else:
        pool = ["Crowbar", "Sledgehammer", "Hatchet", "Lock Pick", "Firecracker", "Bolt Cutters", "Toolbox", "6-Shot Revolver", "12-Shot Automatic", "Double-Barrel Shotgun", "Pump Shotgun", "Medium Rifle", "Long Rifle", "Hiking Pack", "Heavy Boots", "Work Jacket"]
    return pool[rng.randi_range(0, pool.size() - 1)]

func _check_zone_unlock(_zone):
    # Standard route progression is explicit now. Repetition never unlocks
    # farther routes; future long-range prerequisites call unlock_expedition_route().
    return

func zone_loot_state(zone):
    var p = int(zone_pressure.get(zone, 0))
    if p >= 85: return "Picked Over"
    if p >= 60: return "Sparse"
    if p >= 30: return "Good"
    return "Rich"

func _resolve_daily_rations() -> void:
    var pop = population()
    var food_have = int(resources.get("Cooked Food", 0))
    var water_have = int(resources.get("Clean Water", 0))
    var food_missing = max(0, pop - food_have)
    var water_missing = max(0, pop - water_have)
    resources["Cooked Food"] = max(0, food_have - pop)
    resources["Clean Water"] = max(0, water_have - pop)

    if food_missing > 0:
        food_shortage_days += 1
        _apply_shortage("food", food_shortage_days)
    else:
        food_shortage_days = 0
    if water_missing > 0:
        water_shortage_days += 1
        _apply_shortage("water", water_shortage_days)
    else:
        water_shortage_days = 0

    var everyone_fed: bool = int(food_missing) == 0
    var everyone_watered: bool = int(water_missing) == 0
    for s in survivors:
        if s["condition"]!="Dead": s["needs"]=CampLifeRules.apply_daily_rations(s.get("needs",{}),everyone_fed,everyone_watered)

func _daily_tick():
    _resolve_daily_rations()

    if buildings.get("Rain Catcher", false):
        resources["Dirty Water"] = int(resources.get("Dirty Water", 0)) + CampLifeRules.rain_catcher_yield(bool(buildings.get("Water Tank", false)))
    if buildings.get("Garden Plot", false) and garden_tended_day == day:
        resources["Raw Food"] = int(resources.get("Raw Food", 0)) + 2

    var pets_to_leave:Array=[]
    for pet in pets:
        if CampLifeRules.pet_should_leave(pet.get("needs",{})):
            pets_to_leave.append(pet)
            continue
        var pet_find:=CampLifeRules.pet_forage_resource(str(pet.get("species","Dog")),rng)
        resources[pet_find]=int(resources.get(pet_find,0))+1
        _add_history("Day %d — %s brought back 1 %s." % [day,pet.get("name","Pet"),pet_find])
    for pet in pets_to_leave:
        pets.erase(pet)
        _add_history("Day %d — %s left First Fire after going too long without affection." % [day,pet.get("name","Pet")])
        toast_requested.emit("%s left camp — they needed more attention." % pet.get("name","Pet"))

    for s in survivors:
        if s["condition"] == "Critical" and s["status"] != "Recovering" and rng.randf() < CampLifeRules.critical_decline_chance(bool(buildings.get("Infirmary", false))):
            _kill_survivor(s, "died from untreated critical injuries")
        if s["condition"] != "Dead" and population() > shelter_capacity():
            s["stress"] = min(100.0, float(s["stress"]) + 10.0)

    day += 1
    _add_history("Day %d began." % day)
    save_game()
    state_changed.emit()

func _apply_shortage(kind, consecutive):
    for s in survivors:
        if s["condition"] == "Dead":
            continue
        var stress_gain = 0
        var hurt_chance = 0.0
        if kind == "food":
            if consecutive == 1: stress_gain = 10
            elif consecutive == 2: stress_gain = 20; hurt_chance = 0.10
            else: stress_gain = 30; hurt_chance = 0.20
        else:
            if consecutive == 1: stress_gain = 15
            elif consecutive == 2: stress_gain = 25; hurt_chance = 0.20
            else: stress_gain = 40; hurt_chance = 0.40
        var leader: Variant = get_survivor(leader_id)
        if leader != null and leader["leader_ability"] == "Pragmatist" and consecutive == 1:
            stress_gain = int(stress_gain * 0.5)
            hurt_chance *= 0.5
        s["stress"] = min(100.0, float(s["stress"]) + stress_gain)
        if hurt_chance > 0.0 and rng.randf() < hurt_chance:
            _apply_injury(s, "Hurt")

func _party_names(ids):
    var names = []
    for sid in ids:
        var s: Variant = get_survivor(sid)
        if s != null:
            names.append(s["name"])
    return " & ".join(names)

# -----------------------------------------------------------------------------
# EVENTS
# -----------------------------------------------------------------------------

func _queue_event(event):
    if event.is_empty():
        return
    if current_event.is_empty():
        current_event = event
        event_changed.emit()
    else:
        event_queue.append(event)

func _advance_event_queue():
    if event_queue.is_empty():
        current_event = {}
    else:
        current_event = event_queue.pop_front()
    event_changed.emit()
    save_game()

func resolve_event(choice_index):
    if current_event.is_empty():
        return
    var choices = current_event.get("choices", [])
    if choice_index < 0 or choice_index >= choices.size():
        return
    var choice = choices[choice_index]
    if choice.get("disabled", false):
        return
    var event = current_event.duplicate(true)
    var action = choice.get("action", "close")
    _handle_event_action(event, action)
    if current_event == event or current_event.get("uid", "") == event.get("uid", ""):
        _advance_event_queue()
    save_game()
    state_changed.emit()

func _event_base(key, title, body, choices, context = {}):
    return {
        "uid": "%s_%d_%d" % [key, day, rng.randi()],
        "key": key,
        "title": title,
        "body": body,
        "choices": choices,
        "context": context.duplicate(true),
    }

func _choice(text, action, disabled = false, reason = ""):
    var c = {"text": text, "action": action}
    if disabled:
        c["disabled"] = true
        if reason != "":
            c["text"] = "%s  —  %s" % [text, reason]
    return c

func _has_room_for_recruit():
    return population() < MAX_POPULATION and population() < shelter_capacity()

func _party_has_gear_name(ids, gear_name):
    for sid in ids:
        var s: Variant = get_survivor(sid)
        if s == null:
            continue
        for slot in ["Weapon", "Secondary", "Clothing", "Pack", "Tool"]:
            if s["equipment"].get(slot, "") == gear_name:
                return true
    return false

func _party_best_skill(ids, skill):
    var best = 0
    for sid in ids:
        var s: Variant = get_survivor(sid)
        if s != null:
            best = max(best, int(s["skills"].get(skill, 0)))
    return best

func _discover_site_from_zone(zone):
    var candidates = []
    for site in D.SPECIAL_SITES.keys():
        if D.SPECIAL_SITES[site]["zone"] == zone and not special_sites[site]["discovered"] and not special_sites[site]["cleared"]:
            candidates.append(site)
    if candidates.is_empty():
        return ""
    var site = candidates[rng.randi_range(0, candidates.size() - 1)]
    special_sites[site]["discovered"] = true
    _add_history("Day %d — Information revealed %s." % [day, site])
    return site

func _record_event_history(event, note):
    if note == "":
        return
    var ids = event.get("context", {}).get("survivor_ids", [])
    for sid in ids:
        var s: Variant = get_survivor(sid)
        if s != null:
            s["history"].append("Day %d — %s" % [day, note])
    _add_history("Day %d — %s" % [day, note])

func _queue_field_result(event, title, body, note = ""):
    _record_event_history(event, note)
    var is_tactical_return := str(event.get("key", "")) == "tactical_result" or bool(event.get("context", {}).get("return_after_tactical", false))
    var continue_text := "Begin return to First Fire" if is_tactical_return else "Continue the expedition"
    _queue_event(_event_base("field_result", title, body, [
        _choice(continue_text, "resume")
    ], event.get("context", {})))

func _queue_closed_result(event, title, body, note = ""):
    _record_event_history(event, note)
    _queue_event(_event_base("closed_result", title, body, [
        _choice("Continue", "close")
    ], event.get("context", {})))

func _queue_recruit_offer(event, title, body, source = "stranger", preferred_background = "", recruit_candidate = {}):
    var context = event.get("context", {}).duplicate(true)
    context["recruit_source"] = source
    context["preferred_background"] = preferred_background
    if recruit_candidate is Dictionary and not recruit_candidate.is_empty():
        context["recruit_candidate"] = recruit_candidate.duplicate(true)
    _queue_event(_event_base("recruit_offer", title, body, [
        _choice("Invite them to First Fire", "recruit_offer_accept", not _has_room_for_recruit(), "NO SHELTER SPACE"),
        _choice("Ask what they know, then part ways", "recruit_offer_info"),
        _choice("Wish them luck", "recruit_offer_decline")
    ], context))

func _build_field_event(key, exp):
    var context = {"expedition_id": exp["id"], "survivor_ids": exp["survivor_ids"], "zone": exp["zone"]}
    var lead: Variant = get_survivor(exp["survivor_ids"][0])
    if lead == null:
        return {}

    if key == "backpack":
        return _event_base(key, "The Backpack", "%s spots a decent backpack lying in the road. It is almost too visible." % lead["name"], [
            _choice("Grab it before somebody else does", "backpack_grab"),
            _choice("Watch the street before touching it", "backpack_watch"),
            _choice("Leave it alone", "resume")
        ], context)

    if key == "someone_inside":
        var r = rng.randf()
        context["inside_kind"] = "survivor" if r < 0.45 else ("zombie" if r < 0.75 else ("empty" if r < 0.90 else "hostile"))
        return _event_base(key, "Someone Inside", "A curtain moves in a house that looked abandoned. Then everything goes still.", [
            _choice("Call out from cover", "inside_call"),
            _choice("Enter quietly and find out", "inside_quiet"),
            _choice("Leave the house alone", "resume")
        ], context)

    if key == "injured_stranger":
        var can_treat = int(components.get("First Aid Kit", 0)) > 0
        var can_supply = int(resources.get("Cooked Food", 0)) > 0 and int(resources.get("Clean Water", 0)) > 0
        return _event_base(key, "The Injured Stranger", "A survivor sits against a wall with a badly injured leg. They are alert, frightened, and cannot travel far without help.", [
            _choice("Help them all the way back to First Fire", "stranger_help", not _has_room_for_recruit(), "NO SHELTER SPACE"),
            _choice("Treat the leg here", "stranger_treat", not can_treat, "NEEDS FIRST AID KIT"),
            _choice("Leave food and clean water", "stranger_supply", not can_supply, "NEEDS 1 FOOD + 1 CLEAN WATER"),
            _choice("Tell them you cannot help", "stranger_leave")
        ], context)

    if key == "injured_stranger_return":
        return _event_base(key, "A Familiar Face", "The injured survivor you helped is on their feet again. They recognize the party immediately and wave you down.", [
            _choice("Invite them to First Fire", "return_stranger_join", not _has_room_for_recruit(), "NO SHELTER SPACE"),
            _choice("Accept repayment in supplies", "return_stranger_supplies"),
            _choice("Ask what they found out there", "return_stranger_info"),
            _choice("Part on good terms", "resume")
        ], context)

    if key == "dog":
        return _event_base(key, "The Dog", "A thin dog watches from half a block away. It looks at %s, then deliberately looks toward an alley." % lead["name"], [
            _choice("Follow it, but keep your distance", "dog_follow"),
            _choice("Give it some food", "dog_feed", int(resources.get("Cooked Food", 0)) < 1, "NEEDS 1 COOKED FOOD"),
            _choice("Ignore it", "resume")
        ], context)

    if key == "dog_return":
        return _event_base(key, "The Dog Returns", "The same dog trots out from between two wrecks. It waits until you notice it, then starts down a side street and looks back.", [
            _choice("Follow it this time", "dog_return_follow"),
            _choice("Send it away", "resume")
        ], context)

    if key == "locked_garage":
        var has_breach = _party_has_tool(exp["survivor_ids"], "Breach")
        return _event_base(key, "Locked Garage", "A detached garage looks almost untouched. The side door is locked and the front door is jammed.", [
            _choice("Pry the side door", "garage_pry", not has_breach, "NEEDS PRY TOOL"),
            _choice("Work the lock carefully", "garage_technical"),
            _choice("Climb through the small window", "garage_window"),
            _choice("Leave it", "resume")
        ], context)

    if key == "gunshot":
        var rg = rng.randf()
        context["gunshot_kind"] = "survivor" if rg < 0.40 else ("aftermath" if rg < 0.70 else ("hostile" if rg < 0.90 else "nothing"))
        return _event_base(key, "The Gunshot", "A single gunshot cracks somewhere nearby, followed by a silence that lasts too long.", [
            _choice("Go find out what happened", "gunshot_investigate"),
            _choice("Watch the area from a distance", "gunshot_watch"),
            _choice("Move away from it", "resume")
        ], context)

    if key == "discover_market":
        return _discovery_event("Miller Street Market", "An old market sits behind a collapsed delivery truck. Its rear stockroom entrance looks blocked rather than looted.", context)
    if key == "discover_clinic":
        return _discovery_event("Neighborhood Clinic", "A small neighborhood clinic still has intact shutters and an unbroken rear door.", context)
    if key == "hardware_cage":
        return _discovery_event("Hardware Cage", "A stripped hardware store still has a locked contractor cage at the rear.", context)
    if key == "construction_trailer":
        return _discovery_event("Construction Trailer", "Behind a fenced worksite sits a contractor trailer that appears untouched.", context)
    if key == "locked_office":
        return _discovery_event("Locked Industrial Office", "An office inside the industrial complex has been barricaded from the inside.", context)

    if key == "patrol_car":
        var has_pry = _party_has_tool(exp["survivor_ids"], "Breach")
        return _event_base(key, "Abandoned Patrol Car", "A patrol car sits half on the curb. The doors are locked. A pistol is still visible in the rack.", [
            _choice("Pry the door quietly", "patrol_pry", not has_pry, "NEEDS PRY TOOL"),
            _choice("Smash the window and move fast", "patrol_break"),
            _choice("Inspect it for alarms or traps", "patrol_inspect"),
            _choice("Leave it", "resume")
        ], context)

    if key == "barricade":
        return _event_base(key, "The Barricade", "Shopping carts and sheet metal block the road. Two armed strangers step into view but keep their weapons lowered.", [
            _choice("Talk before this gets stupid", "barricade_talk"),
            _choice("Back away slowly", "resume"),
            _choice("Refuse to be pushed around", "barricade_stand")
        ], context)
    return {}

func _discovery_event(site, body, context):
    return _event_base("discover_site", site, body, [
        _choice("Mark it for a dedicated trip", "mark_site:%s" % site),
        _choice("Leave it alone for now", "resume")
    ], context)

func _build_special_site_event(site, exp):
    var context = {"expedition_id": exp["id"], "survivor_ids": exp["survivor_ids"], "site": site, "zone": exp["zone"]}
    if site == "Miller Street Market":
        var rm = rng.randf()
        context["market_kind"] = "survivor" if rm < 0.30 else ("zombie" if rm < 0.75 else "animal")
        return _event_base("site_market", site, "The sales floor is wrecked, but the stockroom is still sealed behind shelving. Something scratches intermittently on the other side.", [
            _choice("Clear it slowly and listen first", "site_market_careful"),
            _choice("Force the shelving aside and get it over with", "site_market_force"),
            _choice("Turn back", "site_retreat")
        ], context)
    if site == "Neighborhood Clinic":
        var rc = rng.randf()
        context["clinic_kind"] = "survivor" if rc < 0.45 else ("zombie" if rc < 0.75 else "empty")
        var cabinets_looted = bool(special_sites[site].get("cabinets_looted", false))
        return _event_base("site_clinic", site, "The clinic is dusty but surprisingly intact. %s A faint sound still comes from the storage room." % ("The medical cabinets have already been stripped." if cabinets_looted else "Several medical cabinets remain closed."), [
            _choice("Search the medical cabinets first", "site_clinic_search", cabinets_looted, "ALREADY SEARCHED"),
            _choice("Call toward the storage room", "site_clinic_call"),
            _choice("Turn back", "site_retreat")
        ], context)
    if site == "Hardware Cage":
        var ids = exp["survivor_ids"]
        return _event_base("site_hardware", site, "Boxes of contractor hardware sit behind heavy chain-link and a stubborn lock.", [
            _choice("Cut the chain", "site_hardware_cut", not _party_has_tool(ids, "Cutters"), "NEEDS BOLT CUTTERS"),
            _choice("Pry the latch", "site_hardware_pry", not _party_has_tool(ids, "Breach"), "NEEDS PRY TOOL"),
            _choice("Work the lock", "site_hardware_technical"),
            _choice("Turn back", "site_retreat")
        ], context)
    if site == "Construction Trailer":
        var has_pry = _party_has_tool(exp["survivor_ids"], "Breach")
        var shelves_looted = bool(special_sites[site].get("shelves_looted", false))
        return _event_base("site_construction", site, "The trailer holds job boxes, rolled plans and %s A locked interior door leads to the back room." % ("empty open shelves." if shelves_looted else "open shelves of supplies."), [
            _choice("Strip the open shelves for supplies", "site_construction_loot", shelves_looted, "ALREADY STRIPPED"),
            _choice("Pry open the back room", "site_construction_pry", not has_pry, "NEEDS PRY TOOL"),
            _choice("Work the back-room lock", "site_construction_room"),
            _choice("Turn back", "site_retreat")
        ], context)
    if site == "Locked Industrial Office":
        return _event_base("site_office", site, "The barricade shifts when you knock. Someone is alive inside and very deliberately keeping the door shut.", [
            _choice("Talk through the door", "site_office_talk"),
            _choice("Force the door", "site_office_force"),
            _choice("Respect the warning and leave", "site_retreat")
        ], context)
    return {}

func _party_has_tool(ids, tool_kind):
    for sid in ids:
        var s: Variant = get_survivor(sid)
        if s == null:
            continue
        for slot in ["Weapon", "Tool"]:
            var gear = s["equipment"].get(slot, "")
            if gear != "" and D.GEAR.has(gear) and D.GEAR[gear].get("tool", "") == tool_kind:
                return true
    return false

func _lead_from_event(event) -> Variant:
    var ids = event.get("context", {}).get("survivor_ids", [])
    if ids.is_empty():
        return null
    return get_survivor(ids[0])

func _finish_event_expedition(event, resume = true):
    var eid = int(event.get("context", {}).get("expedition_id", -1))
    if eid < 0:
        return
    if resume:
        _resume_expedition(eid)
    else:
        _abort_expedition(eid, false)

func _handle_event_action(event, action):
    var lead: Variant = _lead_from_event(event)
    var ids = event.get("context", {}).get("survivor_ids", [])
    var zone = event.get("context", {}).get("zone", "")

    if action == "resume":
        _finish_event_expedition(event, true)
        return
    if action == "close":
        return
    if action.begins_with("mark_site:"):
        var site = action.trim_prefix("mark_site:")
        if special_sites.has(site):
            special_sites[site]["discovered"] = true
            _record_event_history(event, "%s marked %s for a dedicated scavenging run." % [lead["name"] if lead != null else "The party", site])
            toast_requested.emit("Special site discovered: %s" % site)
        _finish_event_expedition(event, true)
        return

    match action:
        "recruit_offer_accept":
            var preferred = event.get("context", {}).get("preferred_background", "")
            var source = event.get("context", {}).get("recruit_source", "stranger")
            var recruit_candidate: Dictionary = event.get("context", {}).get("recruit_candidate", {})
            var recruit: Variant = null
            if not recruit_candidate.is_empty():
                recruit = _add_recruit_candidate(recruit_candidate, ids)
            else:
                recruit = _add_recruit(preferred, ids)
            if recruit != null:
                if source == "injured_stranger":
                    for sid in ids:
                        var helper: Variant = get_survivor(sid)
                        if helper != null:
                            helper["fatigue"] = min(100.0, float(helper["fatigue"]) + CampLifeRules.fatigue_gain(8.0))
                if bool(event.get("context", {}).get("return_after_tactical", false)):
                    var return_eid := int(event.get("context", {}).get("expedition_id", -1))
                    var return_exp: Variant = _find_expedition(return_eid)
                    if return_exp != null:
                        recruit["status"] = "Expedition"
                        recruit["task"] = {"expedition_id": return_eid}
                        var returning_ids: Array = return_exp.get("return_recruit_ids", [])
                        if not returning_ids.has(int(recruit["id"])):
                            returning_ids.append(int(recruit["id"]))
                        return_exp["return_recruit_ids"] = returning_ids
                _queue_field_result(event, "%s Joins First Fire" % recruit["name"], "%s accepts and joins the return trip to First Fire." % recruit["name"], "%s agreed to join First Fire." % recruit["name"])
            else:
                _queue_field_result(event, "No Room", "There is nowhere safe to put another person yet. You exchange directions and part ways.")
        "recruit_offer_info":
            var revealed = _discover_site_from_zone(zone)
            if revealed != "":
                _queue_field_result(event, "Useful Information", "They sketch a route and point out a place that may still be worth searching: %s." % revealed, "The party learned the location of %s from another survivor." % revealed)
            else:
                _queue_field_result(event, "Nothing New", "They cannot point to anywhere you have not already marked. You trade a little information and part ways; nothing new is added to the haul.")
        "recruit_offer_decline":
            _queue_field_result(event, "Parting Ways", "Nobody makes promises. You trade names, wish each other luck, and head in opposite directions.")

        "backpack_grab":
            var rb = rng.randf()
            if rb < 0.68:
                inventory_gear.append("School Backpack")
                resources["Cooked Food"] += 1
                _queue_field_result(event, "Worth the Risk", "The bag is real and nobody is waiting on it. Inside is a sealed snack and a few useless personal items.", "The party recovered a School Backpack and food from an exposed road.")
            elif rb < 0.88:
                inventory_gear.append("School Backpack")
                if lead != null:
                    lead["stress"] = min(100.0, float(lead["stress"]) + 6.0)
                _queue_field_result(event, "Noise in the Alley", "You get the pack, but something moves close enough to make the grab feel like a bad idea. The party leaves quickly.", "The party grabbed an exposed backpack and drew unwanted attention.")
            else:
                if lead != null:
                    _apply_injury(lead, "Hurt")
                _queue_field_result(event, "Not Unattended", "A dead hand snaps out from under a wreck as the bag is lifted. You get away, but not cleanly.", "A scavenging grab ended in an injury.")
        "backpack_watch":
            if lead != null:
                var rw = skill_check(lead, "Survival", 8)
                add_skill_xp(lead, "Survival", 4)
                if rw >= 1:
                    inventory_gear.append("School Backpack")
                    resources["Cooked Food"] += 1
                    if rw == 2:
                        resources["Hardware"] = int(resources.get("Hardware", 0)) + 1
                    _queue_field_result(event, "Clear Enough", "After several quiet minutes, the street tells you what you needed to know. The pack is safe to recover." + (" A loose round under a nearby seat is a bonus." if rw == 2 else ""), "Careful observation turned an exposed backpack into safe loot.")
                elif rw == 0:
                    inventory_gear.append("School Backpack")
                    lead["stress"] = min(100.0, float(lead["stress"]) + 2.0)
                    _queue_field_result(event, "Probably Safe", "You never get a perfect read on the street, but nothing closes in. The bag comes with you.")
                else:
                    lead["stress"] = min(100.0, float(lead["stress"]) + 4.0)
                    _queue_field_result(event, "Someone Else Was Watching", "A shape appears two blocks away and disappears when noticed. Keeping the bag is not worth showing them where you are going.")

        "inside_call":
            var kind = event.get("context", {}).get("inside_kind", "empty")
            if kind == "survivor":
                var rs = skill_check(lead, "Social", 10) if lead != null else -1
                if lead != null: add_skill_xp(lead, "Social", 6)
                if rs >= 0:
                    _queue_recruit_offer(event, "A Voice Answers", "After a long silence, a frightened survivor opens the door just enough to talk.", "house_survivor")
                else:
                    if lead != null: lead["stress"] = min(100.0, float(lead["stress"]) + 3.0)
                    _queue_field_result(event, "No Trust", "Someone is definitely inside, but they refuse to answer again. Pushing harder would turn a conversation into a fight.")
            elif kind == "zombie":
                var rz = skill_check(lead, "Combat", 8, _equipment_combat_bonus(lead)) if lead != null else -1
                if lead != null: add_skill_xp(lead, "Combat", 5)
                if rz < 0 and lead != null: _apply_injury(lead, "Hurt")
                else: resources["Raw Food"] += 1
                _queue_field_result(event, "The Answer Is Dead", "The call brings a single infected body through the doorway. At least now the house is quieter." + (" A little usable food remains in the kitchen." if rz >= 0 else ""), "The party called an infected occupant out of a house.")
            elif kind == "hostile":
                var rh = skill_check(lead, "Social", 13) if lead != null else -1
                if rh >= 1:
                    _queue_field_result(event, "A Bad Conversation Ends Well", "The voice inside is armed and angry, but not suicidal. Both sides agree to leave it there.")
                elif rh == 0 and int(resources.get("Cooked Food", 0)) > 0:
                    resources["Cooked Food"] -= 1
                    _queue_field_result(event, "A Toll", "They demand food for letting you walk away without trouble. One meal is cheaper than a gunfight.")
                else:
                    if lead != null: _apply_injury(lead, "Hurt")
                    _queue_field_result(event, "Shots Through the Door", "The conversation turns ugly fast. The party escapes, but not untouched.", "An attempted contact with armed occupants ended violently.")
            else:
                resources["Cloth"] += 1
                _queue_field_result(event, "Nothing Human", "No one answers. A trapped animal bolts from the back of the house when you finally approach. A blanket near the door is still usable.")
        "inside_quiet":
            var ri = skill_check(lead, "Survival", 10) if lead != null else -1
            if lead != null: add_skill_xp(lead, "Survival", 5)
            var ik = event.get("context", {}).get("inside_kind", "empty")
            if ik == "survivor" and ri >= 0:
                _queue_recruit_offer(event, "You Find a Survivor", "You locate them before they locate you. Once the initial panic passes, they are willing to talk.", "house_survivor")
            elif ik == "zombie":
                if ri < 0 and lead != null:
                    _apply_injury(lead, "Hurt")
                    _queue_field_result(event, "Too Close", "The thing behind the curtain is dead and much closer than expected. The quiet entry becomes a scramble back outside.")
                else:
                    resources["Cooked Food"] += 1
                    resources["Cloth"] += 1
                    _queue_field_result(event, "A Dead House", "You get the drop on the infected occupant and search without drawing the whole block. A little food and cloth remain.")
            elif ik == "hostile":
                if ri >= 1:
                    resources["Hardware"] += 1
                    _queue_field_result(event, "Seen Before Seeing", "You spot the armed occupant first and slip back out with a small box of hardware from the garage shelf.")
                else:
                    if lead != null: _apply_injury(lead, "Hurt")
                    _queue_field_result(event, "Bad House", "You walk into someone else's ambush. The party breaks contact and abandons the house.")
            elif ik == "empty":
                resources["Raw Food"] += 2
                _queue_field_result(event, "Empty Enough", "The movement was an animal trapped inside. The pantry has two usable food items left.")
            else:
                _queue_field_result(event, "They Heard You", "Whoever is inside moves deeper into the house and refuses contact. You decide not to chase them room to room.")

        "stranger_help":
            var recruit2: Variant = _add_recruit("", ids)
            if recruit2 != null:
                for sid in ids:
                    var helper2: Variant = get_survivor(sid)
                    if helper2 != null:
                        helper2["fatigue"] = min(100.0, float(helper2["fatigue"]) + 10.0)
                _finish_event_expedition(event, false)
                _queue_closed_result(event, "A Slow Return", "%s cannot move quickly. The scavenging run is over; the party turns around and escorts them directly back to First Fire." % recruit2["name"], "%s was carried back to First Fire after being found injured." % recruit2["name"])
            else:
                _queue_field_result(event, "No Safe Bed", "You cannot honestly offer shelter right now. The party helps them get more comfortable, then moves on.")
        "stranger_treat":
            if int(components.get("First Aid Kit", 0)) > 0:
                components["First Aid Kit"] -= 1
            if lead != null:
                var rt = skill_check(lead, "Medical", 10)
                add_skill_xp(lead, "Medical", 10)
                if rt >= 1:
                    flags["injured_stranger_return_after"] = 1
                    _change_reputation(lead, 3)
                    _queue_field_result(event, "Stable", "The first-aid kit gets the bleeding controlled and the leg braced well enough for them to move when they are ready. You leave directions to First Fire without demanding anything.", "%s treated an injured stranger in the field." % lead["name"])
                elif rt == 0:
                    flags["injured_stranger_return_after"] = 2
                    _queue_field_result(event, "Good Enough for Tonight", "The first-aid kit is enough to control the bleeding and support the leg. They should survive the night if nothing else finds them.")
                else:
                    lead["stress"] = min(100.0, float(lead["stress"]) + 6.0)
                    _queue_field_result(event, "Beyond What You Can Do", "The kit helps, but the injury is worse than it looked. You stabilize what you can and have to leave them where they are.")
        "stranger_supply":
            resources["Cooked Food"] -= 1
            resources["Clean Water"] -= 1
            flags["injured_stranger_return_after"] = 1
            if lead != null: _change_reputation(lead, 2)
            _queue_field_result(event, "Enough to Keep Going", "You leave a meal, clean water and directions that avoid the worst streets. They promise nothing, but they remember your camp's name.", "The party left food and water with an injured stranger.")
        "stranger_leave":
            if lead != null:
                if lead["traits"].has("Generous") or lead["traits"].has("Protective"):
                    lead["stress"] = min(100.0, float(lead["stress"]) + 5.0)
                elif lead["traits"].has("Selfish") or lead["traits"].has("Pragmatist"):
                    lead["stress"] = max(0.0, float(lead["stress"]) - 1.0)
            _queue_field_result(event, "You Keep Moving", "The stranger does not argue. They just nod once as the party leaves. The road keeps its own accounting.", "The party left an injured stranger behind.")
        "return_stranger_join":
            var recruit3: Variant = _add_recruit("", ids)
            if recruit3 != null:
                _queue_field_result(event, "Debt Repaid Differently", "%s says they have had enough of surviving alone and asks to come with you." % recruit3["name"], "%s joined First Fire after surviving with the party's earlier help." % recruit3["name"])
        "return_stranger_supplies":
            resources["Raw Food"] += 3
            resources["Clean Water"] += 1
            _queue_field_result(event, "Repayment", "They insist you take what they can spare: three food items and a sealed bottle of water. Then they continue on their own.", "A survivor repaid First Fire with supplies.")
        "return_stranger_info":
            var site2 = _discover_site_from_zone(zone)
            if site2 != "":
                _queue_field_result(event, "A Place Worth Checking", "They have been moving through this area for days and mark %s on your route." % site2, "A survivor revealed the location of %s." % site2)
            else:
                resources["Hardware"] += 2
                _queue_field_result(event, "Nothing New, But Something Useful", "You already know every place they can name. They give you two pieces of useful hardware instead.")

        "dog_follow":
            if lead != null:
                var rd = skill_check(lead, "Survival", 9)
                add_skill_xp(lead, "Survival", 4)
                if rd == 2:
                    var dog_site = _discover_site_from_zone(zone)
                    if dog_site != "":
                        _queue_field_result(event, "It Was Leading You Somewhere", "The dog stops at a route you would have passed. From there you spot %s and mark it for later." % dog_site, "A stray dog led the party to %s." % dog_site)
                    else:
                        resources["Cooked Food"] += 3
                        resources["Hardware"] += 1
                        _queue_field_result(event, "A Hidden Cache", "The dog leads you to a stash under a collapsed porch: food and a little hardware.")
                elif rd >= 0:
                    resources["Cooked Food"] += 2
                    resources["Hardware"] += 1
                    _queue_field_result(event, "A Small Cache", "The dog leads you to a place someone used recently. Whoever owned it is gone, but a little food and hardware remain.")
                else:
                    lead["stress"] = min(100.0, float(lead["stress"]) + 3.0)
                    _queue_field_result(event, "Lost It", "The dog slips through a gap you cannot follow and disappears. You spend too long looking for a way around.")
            flags["met_dog"] = true
        "dog_feed":
            resources["Cooked Food"] -= 1
            flags["fed_dog"] = true
            flags["dog_return_after"] = 1
            if lead != null: lead["stress"] = max(0.0, float(lead["stress"]) - 5.0)
            _queue_field_result(event, "It Eats From Your Hand", "The dog keeps its distance until you step away from the food. When it finishes, it follows for half a block before vanishing between houses.", "The party fed a stray dog instead of taking its food.")
        "dog_return_follow":
            resources["Cooked Food"] += 3
            resources["Raw Food"] += 1
            var dsite = _discover_site_from_zone(zone)
            var extra = " It also gives you a route past %s." % dsite if dsite != "" else ""
            _queue_field_result(event, "This Time It Waits", "The dog leads you straight to a concealed food cache and waits until you find it.%s" % extra, "The dog returned and led the party to useful supplies.")

        "garage_pry":
            resources["Scrap Metal"] += rng.randi_range(2, 4)
            resources["Hardware"] += rng.randi_range(2, 3)
            if rng.randf() < 0.30: inventory_gear.append("Toolbox")
            _queue_field_result(event, "Door Open", "The pry bar ruins the latch but keeps the noise manageable. The garage has scrap, hardware and maybe something better.", "The party breached a locked garage with proper tools.")
        "garage_technical":
            if lead != null:
                var r4 = skill_check(lead, "Technical", 10)
                add_skill_xp(lead, "Technical", 7)
                if r4 >= 1:
                    resources["Scrap Metal"] += 2
                    resources["Hardware"] += 3
                    if r4 == 2: inventory_gear.append("Screwdriver Set")
                    _queue_field_result(event, "Clean Entry", "The lock gives without breaking the door. The shelves inside are worth the patience.")
                elif r4 == 0:
                    resources["Hardware"] += 1
                    _queue_field_result(event, "Half a Win", "The lock finally opens, but only after you damage it and make more noise than intended. You grab what is nearest and leave.")
                else:
                    lead["stress"] = min(100.0, float(lead["stress"]) + 3.0)
                    _queue_field_result(event, "Wrong Lock, Wrong Tools", "After several minutes the lock is no closer to opening. Staying longer only advertises your position.")
        "garage_window":
            if lead != null:
                var r5 = skill_check(lead, "Survival", 9)
                add_skill_xp(lead, "Survival", 3)
                if r5 < 0:
                    _apply_injury(lead, "Hurt")
                    _queue_field_result(event, "Glass and Gravity", "The window is tighter and weaker than it looked. The entry works, but it costs skin and blood.")
                else:
                    resources["Hardware"] += 2
                    resources["Raw Food"] += 1
                    if r5 == 2: inventory_gear.append("Screwdriver Set")
                    _queue_field_result(event, "Inside", "The awkward entry works. A shelf of hardware and an old emergency food tin are still usable.")

        "gunshot_investigate":
            var gk = event.get("context", {}).get("gunshot_kind", "nothing")
            if gk == "survivor":
                _queue_recruit_offer(event, "After the Shot", "You find a shaken survivor behind a wrecked car. The shot was theirs. Whatever they fired at is down, and they are not eager to stay alone.", "gunshot_survivor")
            elif gk == "aftermath":
                resources["Hardware"] = int(resources.get("Hardware", 0)) + rng.randi_range(2, 4)
                if rng.randf() < 0.35: components["First Aid Kit"] = int(components.get("First Aid Kit", 0)) + 1
                _queue_field_result(event, "Too Late for the People", "The fight is already over. There is ammunition left behind, and maybe one medical item worth taking.", "The party scavenged the aftermath of a gunfight.")
            elif gk == "hostile":
                var rg2 = skill_check(lead, "Combat", 11, _equipment_combat_bonus(lead)) if lead != null else -1
                if lead != null: add_skill_xp(lead, "Combat", 7)
                if rg2 >= 1:
                    resources["Hardware"] = int(resources.get("Hardware", 0)) + 2
                    _queue_field_result(event, "Contact Broken", "The shooter tries to turn the encounter into an ambush and loses the nerve when you push back. Two rounds are left where they fled.")
                else:
                    if lead != null: _apply_injury(lead, "Hurt")
                    _queue_field_result(event, "The Second Shot Was for You", "The first shot was bait or warning. The party gets out, but somebody pays for the investigation.")
            else:
                if lead != null:
                    add_skill_xp(lead, "Survival", 3)
                    lead["stress"] = min(100.0, float(lead["stress"]) + 2.0)
                _queue_field_result(event, "Nothing Left", "You find the location, but no shooter, body or useful trail. The uncertainty is worse than an answer.")
        "gunshot_watch":
            if lead != null:
                var gw = skill_check(lead, "Survival", 9)
                add_skill_xp(lead, "Survival", 4)
                if gw >= 1:
                    zone_pressure[zone] = max(0, int(zone_pressure.get(zone, 0)) - 3)
                    _queue_field_result(event, "Information Instead of Risk", "From cover, you map the movement around the shot and identify a quieter route through the area. The zone is a little less picked-over than you thought.", "The party mapped a safer scavenging route after hearing gunfire.")
                else:
                    _queue_field_result(event, "No Clear Picture", "You wait long enough to know nobody is coming toward you. That is all the information the shot gives up.")

        "patrol_pry":
            inventory_gear.append("6-Shot Revolver")
            resources["Hardware"] = int(resources.get("Hardware", 0)) + rng.randi_range(2, 4)
            _queue_field_result(event, "Quiet Entry", "The door flexes just enough to defeat the old lock. The pistol and ammunition come out without broadcasting the theft.", "The party recovered a pistol from an abandoned patrol car.")
        "patrol_break":
            if rng.randf() < 0.62:
                inventory_gear.append("6-Shot Revolver")
                resources["Hardware"] = int(resources.get("Hardware", 0)) + rng.randi_range(1, 3)
                if lead != null: lead["stress"] = min(100.0, float(lead["stress"]) + 3.0)
                _queue_field_result(event, "Fast and Loud", "The glass goes everywhere, but the rack gives up the pistol. The party leaves before the noise draws an answer.", "The party smashed into a patrol car and recovered its weapon.")
            else:
                if lead != null: _apply_injury(lead, "Hurt")
                _queue_field_result(event, "The Car Was Not Empty", "The alarm is dead. The infected body folded into the back seat is not. The grab becomes a close fight and the weapon stays behind.")
        "patrol_inspect":
            if lead != null:
                var r7 = skill_check(lead, "Survival", 11)
                add_skill_xp(lead, "Survival", 4)
                if r7 >= 1:
                    inventory_gear.append("6-Shot Revolver")
                    resources["Hardware"] = int(resources.get("Hardware", 0)) + 2
                    _queue_field_result(event, "A Better Way In", "The rear window is already cracked and the rack release can be reached with a piece of wire. No smashing required.")
                elif r7 == 0:
                    resources["Hardware"] = int(resources.get("Hardware", 0)) + 1
                    _queue_field_result(event, "Not Worth the Gun", "You cannot find a clean route to the rack, but a loose round under the driver's seat is reachable through the broken seal.")
                else:
                    lead["stress"] = min(100.0, float(lead["stress"]) + 3.0)
                    _queue_field_result(event, "Too Many Unknowns", "You cannot tell whether the car is trapped, occupied, or simply jammed. You leave it alone.")

        # Legacy Alpha 0.1 save compatibility. Smoke is no longer in the
        # new random pool, but an already-saved pending smoke event can still resolve.
        "smoke_investigate":
            var sr = rng.randf()
            if sr < 0.40:
                _queue_recruit_offer(event, "A Small Fire", "The smoke belongs to a lone survivor cooking behind a wall. They are wary, but willing to talk.", "smoke_survivor")
            elif sr < 0.75:
                resources["Cooked Food"] += 2
                _queue_field_result(event, "Abandoned Fire", "Whoever made the smoke is gone. Two cooked meals were left behind in the rush.")
            else:
                if lead != null: _apply_injury(lead, "Hurt")
                _queue_field_result(event, "Someone Was Watching the Smoke", "The fire was bait or bad luck. The party breaks contact after a brief violent encounter.")
        "smoke_mark":
            flags["smoke_marked"] = true
            if lead != null: add_skill_xp(lead, "Survival", 2)
            zone_pressure[zone] = max(0, int(zone_pressure.get(zone, 0)) - 2)
            _queue_field_result(event, "Marked and Avoided", "You mark the smoke and use it to map where other people are moving without approaching them.")

        "barricade_talk":
            if lead != null:
                var r8 = skill_check(lead, "Social", 12)
                add_skill_xp(lead, "Social", 8)
                if r8 >= 1:
                    flags["met_barricade_group"] = true
                    _queue_event(_event_base("barricade_trade", "Terms", "They are not raiders. They are protecting a route and willing to do limited business.", [
                        _choice("Trade 1 Clean Water for 2 Cooked Food", "barricade_trade_food", int(resources.get("Clean Water", 0)) < 1, "NEEDS 1 CLEAN WATER"),
                        _choice("Ask what is still worth searching", "barricade_trade_info"),
                        _choice("Thank them and leave", "resume")
                    ], event.get("context", {})))
                elif r8 == 0:
                    lead["stress"] = min(100.0, float(lead["stress"]) + 3.0)
                    _queue_field_result(event, "No Deal", "The conversation never becomes friendly, but it never becomes a fight either. They let you back away.")
                else:
                    lead["stress"] = min(100.0, float(lead["stress"]) + 8.0)
                    _queue_field_result(event, "Wrong Tone", "One of them shoulders a weapon and the other tells you to leave. You do.")
        "barricade_trade_food":
            resources["Clean Water"] -= 1
            resources["Cooked Food"] += 2
            _queue_field_result(event, "Trade", "A sealed bottle of clean water buys two meals. Nobody gets cheated and nobody gets shot.", "First Fire made a small trade with the barricade group.")
        "barricade_trade_info":
            var bs = _discover_site_from_zone(zone)
            if bs != "":
                _queue_field_result(event, "Local Knowledge", "They mark %s and warn you which approach makes the least noise." % bs, "The barricade group revealed %s." % bs)
            else:
                zone_pressure[zone] = max(0, int(zone_pressure.get(zone, 0)) - 5)
                _queue_field_result(event, "A Better Route", "You already know their named locations, but they give you a quieter route through the zone. It opens up a little more scavenging ground.")
        "barricade_stand":
            if lead != null:
                var r9 = skill_check(lead, "Combat", 13, _equipment_combat_bonus(lead))
                add_skill_xp(lead, "Combat", 8)
                if r9 < 0:
                    _apply_injury(lead, "Wounded")
                    _queue_field_result(event, "A Point Nobody Needed Proved", "The standoff becomes a real fight. The party escapes, but the cost is far worse than simply walking away.", "A confrontation at a barricade left a survivor wounded.")
                elif r9 == 0:
                    _apply_injury(lead, "Hurt")
                    _queue_field_result(event, "Mutual Bad Decision", "Nobody wins. A short violent exchange ends with both sides breaking contact.")
                else:
                    resources["Hardware"] = int(resources.get("Hardware", 0)) + 2
                    resources["Cooked Food"] += 1
                    _queue_field_result(event, "They Back Down", "Your side looks harder to rob than they expected. They retreat behind the barricade, leaving a small pouch behind in the scramble.")

        "site_market_careful":
            var mk = event.get("context", {}).get("market_kind", "zombie")
            resources["Cooked Food"] += rng.randi_range(5, 8)
            resources["Raw Food"] += rng.randi_range(2, 3)
            if mk == "survivor":
                _clear_site(event, true)
                _queue_recruit_offer(event, "Someone Was Trapped Back There", "The scratching stops when you speak. A dehydrated survivor answers from behind the shelving. They have been trapped in the stockroom, not hiding from you.", "market_survivor", "Cook")
            elif mk == "zombie":
                var mr = skill_check(lead, "Combat", 10, _equipment_combat_bonus(lead)) if lead != null else -1
                if mr < 0 and lead != null: _apply_injury(lead, "Hurt")
                _clear_site(event, true)
                _queue_closed_result(event, "Stockroom Cleared", "The scratching was infected. Moving slowly keeps the fight controlled, and the stockroom food is still mostly usable.", "Miller Street Market was cleared for food.")
            else:
                _clear_site(event, true)
                _queue_closed_result(event, "Just an Animal", "A trapped animal bolts out when you shift the shelving. The stockroom itself is a small jackpot of shelf-stable food.", "Miller Street Market was cleared for food.")
        "site_market_force":
            resources["Cooked Food"] += rng.randi_range(6, 9)
            resources["Raw Food"] += 1
            var mk2 = event.get("context", {}).get("market_kind", "zombie")
            var force_body = "The stockroom opens fast and the food comes out faster."
            if mk2 == "zombie":
                if lead != null and rng.randf() < 0.45:
                    _apply_injury(lead, "Hurt")
                    force_body = "The shelving comes down on top of an infected occupant. The party gets the food, but the close fight leaves a mark."
                else:
                    force_body = "An infected occupant comes out with the shelving. The party is ready enough to put it down and strip the food."
            elif mk2 == "survivor":
                if lead != null: lead["stress"] = min(100.0, float(lead["stress"]) + 4.0)
                force_body = "A terrified survivor was trapped behind the shelving. The violent entry sends them fleeing through the rear exit before anyone can talk. You keep the food, but lose the chance to make contact."
            else:
                force_body = "A trapped animal explodes out through the opening and disappears. The stockroom itself is full of usable food."
            _clear_site(event, true)
            _queue_closed_result(event, "Forced Open", force_body, "Miller Street Market was forced open and stripped for food.")

        "site_clinic_search":
            var med = 2
            if lead != null:
                med = 2 + int(lead["skills"]["Medical"] >= 3) + int(lead["skills"]["Medical"] >= 5)
                add_skill_xp(lead, "Medical", 10)
            components["First Aid Kit"] = int(components.get("First Aid Kit", 0)) + med
            special_sites["Neighborhood Clinic"]["cabinets_looted"] = true
            _finish_special_site_without_clear(event)
            _queue_closed_result(event, "Cabinets Stripped", "You take the accessible first-aid kits and leave rather than open the noisy storage room today. The clinic remains marked; the storage room is still unresolved.", "The party stripped the accessible medical cabinets at Neighborhood Clinic.")
        "site_clinic_call":
            var ck = event.get("context", {}).get("clinic_kind", "empty")
            if ck == "survivor":
                _clear_site(event, true)
                _queue_recruit_offer(event, "A Caregiver Answers", "A survivor emerges with a makeshift medical bag. They have been using the clinic as a shelter and know exactly what is left in it.", "clinic_survivor", "Nursing Assistant")
            elif ck == "zombie":
                var cr = skill_check(lead, "Combat", 9, _equipment_combat_bonus(lead)) if lead != null else -1
                if cr < 0 and lead != null: _apply_injury(lead, "Hurt")
                components["First Aid Kit"] = int(components.get("First Aid Kit", 0)) + 2
                _clear_site(event, true)
                _queue_closed_result(event, "The Sound Answers", "An infected former patient lurches from storage. Once it is dealt with, two useful medical items remain.", "Neighborhood Clinic was cleared after contact with an infected occupant.")
            else:
                components["First Aid Kit"] = int(components.get("First Aid Kit", 0)) + 2
                _clear_site(event, true)
                _queue_closed_result(event, "Nobody There", "The sound was loose equipment shifting against a vent. The storage room still contains two useful medical items.")

        # Legacy special-site choice from the first playable Alpha.
        "site_hardware_open":
            resources["Hardware"] += rng.randi_range(3, 6)
            resources["Scrap Metal"] += rng.randi_range(2, 4)
            if rng.randf() < 0.30: inventory_gear.append("Toolbox")
            _clear_site(event, true)
            _queue_closed_result(event, "Cage Open", "The contractor cage gives up a useful load of hardware and scrap.", "The Hardware Cage was cleared.")

        "site_hardware_cut":
            resources["Hardware"] += rng.randi_range(5, 7)
            resources["Scrap Metal"] += rng.randi_range(2, 4)
            if rng.randf() < 0.40: inventory_gear.append("Toolbox")
            _clear_site(event, true)
            _queue_closed_result(event, "Exactly the Right Tool", "Bolt cutters make the cage almost trivial. The contractor stock inside is worth the trip.", "The Hardware Cage was opened with bolt cutters.")
        "site_hardware_pry":
            resources["Hardware"] += rng.randi_range(4, 6)
            resources["Scrap Metal"] += rng.randi_range(2, 3)
            _clear_site(event, true)
            _queue_closed_result(event, "Latch Defeated", "The pry tool bends the latch enough to get a hand through and release the cage from inside.", "The Hardware Cage was pried open.")
        "site_hardware_technical":
            var ht = skill_check(lead, "Technical", 12) if lead != null else -1
            if lead != null: add_skill_xp(lead, "Technical", 9)
            if ht >= 0:
                resources["Hardware"] += rng.randi_range(3, 6)
                resources["Scrap Metal"] += 2
                if ht == 2: inventory_gear.append("Toolbox")
                _clear_site(event, true)
                _queue_closed_result(event, "Lock Open", "Patience beats force. The cage opens and the hardware comes out cleanly.", "The Hardware Cage was opened without brute force.")
            else:
                _finish_special_site_without_clear(event)
                _queue_closed_result(event, "Lock Wins This Time", "You cannot get the lock to cooperate. The party heads home; the cage remains marked for another dedicated attempt.")

        "site_construction_loot":
            resources["Wood"] += 4
            resources["Hardware"] += 3
            resources["Scrap Metal"] += 2
            special_sites["Construction Trailer"]["shelves_looted"] = true
            _finish_special_site_without_clear(event)
            _queue_closed_result(event, "Open Shelves Stripped", "You take the obvious building materials and leave the locked back room alone. The trailer stays marked because there is still something behind that interior door.", "The party stripped the open shelves at the Construction Trailer.")
        "site_construction_pry":
            inventory_gear.append("Toolbox")
            resources["Hardware"] += 3
            resources["Wood"] += 3
            if rng.randf() < 0.45 and _has_room_for_recruit():
                _clear_site(event, true)
                _queue_recruit_offer(event, "Someone Behind the Door", "The back room was locked because someone was sleeping behind it. A construction worker lowers a hammer when they see you are not here to rob them.", "construction_survivor", "Construction Worker")
            else:
                _clear_site(event, true)
                _queue_closed_result(event, "Back Room Open", "The back room holds a toolbox, hardware and framing lumber. Nobody is inside.", "The Construction Trailer back room was breached.")
        "site_construction_room":
            var ct = skill_check(lead, "Technical", 11) if lead != null else -1
            if lead != null: add_skill_xp(lead, "Technical", 8)
            if ct >= 1:
                if rng.randf() < 0.45 and _has_room_for_recruit():
                    _clear_site(event, true)
                    _queue_recruit_offer(event, "The Lock Was Keeping Others Out", "A construction worker has been sheltering in the back room. They appreciate that you opened the door without destroying it.", "construction_survivor", "Construction Worker")
                else:
                    inventory_gear.append("Toolbox")
                    resources["Hardware"] += 3
                    _clear_site(event, true)
                    _queue_closed_result(event, "Back Room Open", "The lock clicks. Inside is a toolbox and contractor hardware.")
            elif ct == 0:
                resources["Hardware"] += 2
                _clear_site(event, true)
                _queue_closed_result(event, "Good Enough", "The lock is damaged beyond reuse, but it opens. You salvage hardware from the room and leave.")
            else:
                _finish_special_site_without_clear(event)
                _queue_closed_result(event, "Not Today", "The lock refuses every improvised technique. The party heads home and leaves the trailer marked for another attempt.")

        "site_office_talk":
            if lead != null:
                var ot = skill_check(lead, "Social", 10)
                add_skill_xp(lead, "Social", 9)
                if ot >= 0:
                    _clear_site(event, true)
                    _queue_recruit_offer(event, "The Barricade Opens", "A mechanically minded survivor finally cracks the door. They have tools, but almost no food, and are ready to discuss leaving with you.", "office_survivor", "Mechanic")
                else:
                    resources["Hardware"] += 1
                    _clear_site(event, true)
                    _queue_closed_result(event, "They Will Not Come Out", "They refuse to open the door, but slide a piece of hardware under it in exchange for you leaving quietly. You respect the boundary.")
        "site_office_force":
            if lead != null:
                var rr = skill_check(lead, "Combat", 12, _equipment_combat_bonus(lead))
                add_skill_xp(lead, "Combat", 7)
                if rr < 0: _apply_injury(lead, "Hurt")
            resources["Scrap Metal"] += 2
            resources["Hardware"] += 2
            _clear_site(event, true)
            _queue_closed_result(event, "Office Breached", "The barricade comes apart. Whoever was inside escapes through another exit while you are forcing the door. You salvage what they leave behind, but no trust survives the choice.", "The party forced entry into the Locked Industrial Office.")
        "site_retreat":
            _finish_special_site_without_clear(event)

        "camp_attack_hold":
            _resolve_camp_zombie_attack(event, "hold")
        "camp_attack_fall_back":
            _resolve_camp_zombie_attack(event, "fall_back")
        "camp_attack_draw_away":
            _resolve_camp_zombie_attack(event, "draw_away")
        "camp_spoil_discard":
            _resolve_camp_spoil(event, false)
        "camp_spoil_risk":
            _resolve_camp_spoil(event, true)
        "camp_storm_brace":
            _resolve_camp_storm(event, "brace")
        "camp_storm_clear":
            _resolve_camp_storm(event, "clear")
        "camp_storm_work":
            _resolve_camp_storm(event, "work")
        "camp_solo_fire":
            _resolve_solo_night(event, true)
        "camp_solo_dark":
            _resolve_solo_night(event, false)
        "camp_crowd_quiet":
            _resolve_crowd_night(event, "quiet")
        "camp_crowd_tavern":
            _resolve_crowd_night(event, "tavern")
        "camp_crowd_feast":
            _resolve_crowd_night(event, "feast")
        "camp_sleep_newcomer":
            _resolve_sleep_event(event, "newcomer")
        "camp_sleep_existing":
            _resolve_sleep_event(event, "existing")
        "camp_sleep_rough":
            _resolve_sleep_event(event, "rough")
        "camp_run_best":
            _resolve_run_complaint(event, "best")
        "camp_run_rotate":
            policies["Expedition Duty"] = "Rotation"
            _resolve_run_complaint(event, "rotate")
        "camp_extra_food_give":
            if int(resources["Cooked Food"]) > 0:
                resources["Cooked Food"] -= 1
                if lead != null: lead["stress"] = max(0.0, float(lead["stress"]) - 10.0)
        "camp_extra_food_refuse":
            if lead != null: lead["stress"] = min(100.0, float(lead["stress"]) + 5.0)
        "camp_missing_search":
            flags["searched_missing_food"] = true
            if rng.randf() < 0.60:
                toast_requested.emit("The missing food was hidden among personal belongings.")
            else:
                toast_requested.emit("No proof turned up.")
        "camp_missing_ignore":
            pass
        "camp_fight_separate":
            _resolve_fight(event, "separate")
        "camp_fight_mediated":
            _resolve_fight(event, "mediate")
        "camp_fight_settle":
            _resolve_fight(event, "settle")
        "camp_refuse_rest":
            if lead != null:
                lead["fatigue"] = max(0.0, float(lead["fatigue"]) - 15.0)
                lead["stress"] = max(0.0, float(lead["stress"]) - 5.0)
        "camp_refuse_force":
            if lead != null:
                lead["stress"] = min(100.0, float(lead["stress"]) + 10.0)
                lead["leader_support"] = int(lead.get("leader_support", 0)) - 5
        "camp_outside_investigate":
            var outside_risk := CampLifeRules.outside_injury_chance(bool(buildings.get("Noise Line", false)), bool(buildings.get("Watch Post", false)))
            if lead != null and rng.randf() < outside_risk:
                _apply_injury(lead, "Hurt")
            else:
                toast_requested.emit("Nothing made it into camp.")
        "camp_outside_wait":
            toast_requested.emit("The noise eventually fades.")
        "camp_request_give":
            if int(resources["Cloth"]) > 0:
                resources["Cloth"] -= 1
                if lead != null: lead["stress"] = max(0.0, float(lead["stress"]) - 8.0)
        "camp_request_refuse":
            if lead != null: lead["stress"] += 4
        "camp_meal_share":
            if int(resources.get("Cooked Food", 0)) >= 2:
                resources["Cooked Food"] -= 2
                for survivor_value in _camp_present_survivors():
                    var survivor: Dictionary = survivor_value
                    survivor["stress"] = max(0.0, float(survivor["stress"]) - 6.0)
                var meal_pair := CampSocial.pick_pair(survivors, rng)
                if meal_pair.size() == 2:
                    _change_relationship(meal_pair[0], meal_pair[1], 4)
                    _change_relationship(meal_pair[1], meal_pair[0], 4)
        "camp_meal_save":
            pass
        "camp_shortage_back_leader":
            for survivor_value in _camp_present_survivors():
                var survivor: Dictionary = survivor_value
                survivor["leader_support"] = int(survivor.get("leader_support", 0)) + 2
        "camp_shortage_open_floor":
            for survivor_value in _camp_present_survivors():
                var survivor: Dictionary = survivor_value
                survivor["stress"] = max(0.0, float(survivor["stress"]) - 2.0)
                survivor["leader_support"] = int(survivor.get("leader_support", 0)) + rng.randi_range(-2, 1)
        "politics_support_a", "politics_support_b", "politics_neutral":
            _resolve_coordinator_vote(event, action)
        "election_support_a", "election_support_b", "election_neutral":
            _resolve_formal_election(event, action)
        "confidence_support_a", "confidence_support_b", "confidence_neutral":
            _resolve_confidence_vote(event, action)
        "mature_continue":
            settlement_mature_shown = true
        _:
            pass

func _clear_site(event, resume_after):
    var site = event.get("context", {}).get("site", "")
    if site != "" and special_sites.has(site):
        special_sites[site]["cleared"] = true
        _add_history("Day %d — %s was cleared." % [day, site])
    var eid = int(event.get("context", {}).get("expedition_id", -1))
    var exp: Variant = _find_expedition(eid)
    if exp != null:
        for sid in exp["survivor_ids"]:
            var s: Variant = get_survivor(sid)
            if s != null and s["condition"] != "Dead":
                s["status"] = "Available"
                s["task"] = {}
                s["fatigue"] = min(100.0, float(s["fatigue"]) + float(D.ZONES[exp["zone"]]["fatigue"]))
        expeditions.erase(exp)

func _finish_special_site_without_clear(event):
    var eid = int(event.get("context", {}).get("expedition_id", -1))
    var exp: Variant = _find_expedition(eid)
    if exp != null:
        for sid in exp["survivor_ids"]:
            var s: Variant = get_survivor(sid)
            if s != null:
                s["status"] = "Available"
                s["task"] = {}
        expeditions.erase(exp)

# -----------------------------------------------------------------------------
# CAMP EVENTS / POLITICS
# -----------------------------------------------------------------------------

func _camp_present_survivors() -> Array:
    var result: Array = []
    for survivor_value in survivors:
        var survivor: Dictionary = survivor_value
        if str(survivor.get("condition", "Dead")) == "Dead":
            continue
        if str(survivor.get("status", "Available")) in ["Expedition", "Pending Expedition Event", "Tactical Encounter"]:
            continue
        result.append(survivor)
    return result

func _breakable_camp_buildings() -> Array:
    var result: Array = []
    for building_value in D.BUILD_ORDER:
        var building_name := str(building_value)
        if not bool(buildings.get(building_name, false)):
            continue
        var supports_built_dependency := false
        for other_value in D.BUILD_ORDER:
            var other_name := str(other_value)
            if not bool(buildings.get(other_name, false)):
                continue
            var other_data: Dictionary = D.BUILDINGS.get(other_name, {})
            if Array(other_data.get("requires", [])).has(building_name):
                supports_built_dependency = true
                break
        if not supports_built_dependency:
            result.append(building_name)
    return result

func _break_camp_building(building_name: String, reason: String) -> bool:
    if building_name == "" or not bool(buildings.get(building_name, false)):
        return false
    buildings[building_name] = false
    _add_history("Day %d — %s was destroyed: %s." % [day, building_name, reason])
    return true

func _camp_event_supply_keys() -> Array:
    var allowed := ["Raw Food", "Cooked Food", "Dirty Water", "Clean Water", "Beer", "Wood", "Scrap Metal", "Cloth", "Plastic", "Hardware", "Seeds"]
    var result: Array = []
    for key_value in allowed:
        var key := str(key_value)
        if int(resources.get(key, 0)) > 0:
            result.append(key)
    return result

func _camp_spoilable_supply_keys() -> Array:
    var result: Array = []
    for key_value in ["Cooked Food", "Raw Food", "Clean Water", "Beer"]:
        var key := str(key_value)
        if int(resources.get(key, 0)) > 0:
            result.append(key)
    return result

func _ruin_random_camp_supplies(amount: int) -> String:
    var remaining := maxi(0, amount)
    var lost: Dictionary = {}
    while remaining > 0:
        var keys := _camp_event_supply_keys()
        if keys.is_empty():
            break
        var key := str(keys[rng.randi_range(0, keys.size() - 1)])
        resources[key] = maxi(0, int(resources.get(key, 0)) - 1)
        lost[key] = int(lost.get(key, 0)) + 1
        remaining -= 1
    if lost.is_empty():
        return "nothing was left in the stores to lose"
    var parts: Array = []
    for key in lost.keys():
        parts.append("%d %s" % [int(lost[key]), str(key)])
    parts.sort()
    return ", ".join(parts)

func _apply_camp_event_injury(survivor, severity: String, note: String) -> void:
    # Deliberately bypass clothing/stat mitigation: destructive camp events use
    # their stored luck roll rather than tactical skill or equipment checks.
    if survivor == null or str(survivor.get("condition", "Dead")) == "Dead":
        return
    match severity:
        "Hurt":
            if str(survivor.get("condition", "Healthy")) == "Healthy":
                survivor["condition"] = "Hurt"
                survivor["injury_remaining"] = 60.0
        "Wounded":
            if str(survivor.get("condition", "Healthy")) != "Critical":
                survivor["condition"] = "Wounded"
                survivor["injury_remaining"] = 180.0
        "Critical":
            survivor["condition"] = "Critical"
            survivor["injury_remaining"] = 0.0
    survivor["stress"] = minf(100.0, float(survivor.get("stress", 0.0)) + (6.0 if severity == "Hurt" else 14.0))
    survivor["history"].append("Day %d — %s." % [day, note])

func _adjust_camp_mood(stress_delta: float, fun_delta: float, safety_delta: float) -> void:
    for survivor_value in _camp_present_survivors():
        var survivor: Dictionary = survivor_value
        survivor["stress"] = clampf(float(survivor.get("stress", 0.0)) + stress_delta, 0.0, 100.0)
        var needs := CampLifeRules.normalize_needs(survivor.get("needs", {}))
        needs["fun"] = clampf(float(needs.get("fun", 50.0)) + fun_delta, 0.0, 100.0)
        needs["safety"] = clampf(float(needs.get("safety", 50.0)) + safety_delta, 0.0, 100.0)
        survivor["needs"] = needs

func _build_camp_zombie_attack_event() -> Dictionary:
    var present := _camp_present_survivors()
    if present.is_empty():
        return {}
    var target: Dictionary = present[rng.randi_range(0, present.size() - 1)]
    var breakable := _breakable_camp_buildings()
    var building_target := str(breakable[rng.randi_range(0, breakable.size() - 1)]) if not breakable.is_empty() else ""
    var warning := "The Noise Line starts clattering before shapes reach the perimeter." if bool(buildings.get("Noise Line", false)) else "Scraping and wet footsteps gather just beyond the firelight."
    if bool(buildings.get("Watch Post", false)):
        warning += " The Watch Post sees the breach forming, but nobody can know where the bodies will fall."
    return _event_base("camp_zombie_attack", "Dead at the Perimeter", warning + " This is a camp crisis, not a tactical fight: preparation and a hidden luck roll decide the damage.", [
        _choice("Hold the camp together and stand your ground", "camp_attack_hold"),
        _choice("Give ground and abandon the stores", "camp_attack_fall_back"),
        _choice("Have one person draw them away", "camp_attack_draw_away"),
    ], {
        "survivor_ids":[int(target.get("id", -1))],
        "attack_roll":rng.randi_range(1, 100),
        "supply_loss":rng.randi_range(2, 4),
        "building_target":building_target,
    })

func _resolve_camp_zombie_attack(event: Dictionary, approach: String) -> void:
    var context: Dictionary = event.get("context", {})
    var target: Variant = _lead_from_event(event)
    var raw_roll := int(context.get("attack_roll", 50))
    var outcome := CampLifeRules.camp_attack_outcome(raw_roll, approach, bool(buildings.get("Noise Line", false)), bool(buildings.get("Watch Post", false)))
    var body := ""
    _adjust_camp_mood(6.0, -4.0, -10.0)

    if approach == "fall_back":
        var abandoned := _ruin_random_camp_supplies(int(context.get("supply_loss", 2)))
        body = "The camp gives ground instead of meeting the dead at the edge. The stores take the first hit: %s." % abandoned
    elif approach == "draw_away":
        body = "%s runs the noise away from the sleeping area while everyone else stays low." % (str(target.get("name", "One survivor")) if target != null else "One survivor")
    else:
        body = "Everyone stays inside the camp line and lets the breach hit whatever it hits."

    match outcome:
        "killed":
            if target != null:
                var name := str(target.get("name", "A survivor"))
                _kill_survivor(target, "was killed during a random zombie breach at First Fire")
                body += " The luck is awful. %s does not make it through the breach." % name
        "exposed":
            if target != null:
                _apply_camp_event_injury(target, "Wounded", "Was badly bitten during a zombie breach at First Fire")
                var exposed := false
                if has_method("_expose_survivor"):
                    exposed = bool(call("_expose_survivor", target, "a random zombie breach at First Fire"))
                body += " %s is dragged clear with a serious bite%s." % [str(target.get("name", "A survivor")), " and zombie-virus exposure" if exposed else ""]
        "wounded":
            if target != null:
                _apply_camp_event_injury(target, "Wounded", "Was wounded during a zombie breach at First Fire")
                body += " %s is seriously wounded in the scramble." % str(target.get("name", "A survivor"))
        "hurt":
            if target != null:
                _apply_camp_event_injury(target, "Hurt", "Was hurt drawing infected away from First Fire")
                body += " %s comes back bloodied but alive." % str(target.get("name", "A survivor"))
        "building":
            var building_name := str(context.get("building_target", ""))
            if _break_camp_building(building_name, "zombies tore through it during a perimeter breach"):
                body += " The dead tear down the %s. It will have to be rebuilt." % building_name
            else:
                body += " They hit the stores instead. Lost: %s." % _ruin_random_camp_supplies(int(context.get("supply_loss", 2)))
        "supplies":
            body += " They get into the stores before the camp drives them off. Lost: %s." % _ruin_random_camp_supplies(int(context.get("supply_loss", 2)))
        _:
            _adjust_camp_mood(-3.0, 2.0, 6.0)
            body += " Somehow the line holds. The dead peel away without taking anything permanent."

    _queue_closed_result(event, "After the Breach", body, "First Fire survived a luck-driven zombie breach (%s)." % outcome)

func _build_camp_spoil_event() -> Dictionary:
    var candidates := _camp_spoilable_supply_keys()
    if candidates.is_empty():
        return {}
    var key := str(candidates[rng.randi_range(0, candidates.size() - 1)])
    var loss := mini(int(resources.get(key, 0)), rng.randi_range(1, 3))
    var present := _camp_present_survivors()
    var target_id := int(present[rng.randi_range(0, present.size() - 1)].get("id", -1)) if not present.is_empty() else -1
    return _event_base("camp_spoil", "Something Is Wrong With the Stores", "A sour smell comes from the %s stock. It might be one bad container. It might be more." % key, [
        _choice("Throw out anything questionable", "camp_spoil_discard"),
        _choice("Keep it and hope it is fine", "camp_spoil_risk"),
    ], {"supply":key, "loss":loss, "spoil_roll":rng.randi_range(1, 100), "survivor_ids":[target_id] if target_id >= 0 else []})

func _resolve_camp_spoil(event: Dictionary, take_risk: bool) -> void:
    var context: Dictionary = event.get("context", {})
    var key := str(context.get("supply", "Raw Food"))
    var loss := mini(int(resources.get(key, 0)), int(context.get("loss", 1)))
    if not take_risk:
        resources[key] = maxi(0, int(resources.get(key, 0)) - loss)
        _adjust_camp_mood(1.0, -1.0, 3.0)
        _queue_closed_result(event, "Thrown Out", "You dump %d %s before anyone can argue themselves into eating or drinking it." % [loss, key], "Questionable stores were discarded.")
        return
    if CampLifeRules.camp_spoil_goes_bad(int(context.get("spoil_roll", 50))):
        resources[key] = maxi(0, int(resources.get(key, 0)) - loss)
        var target: Variant = _lead_from_event(event)
        if target != null:
            target["stress"] = minf(100.0, float(target.get("stress", 0.0)) + 10.0)
            var needs := CampLifeRules.normalize_needs(target.get("needs", {}))
            needs["hunger"] = maxf(0.0, float(needs.get("hunger", 50.0)) - 16.0)
            needs["safety"] = maxf(0.0, float(needs.get("safety", 50.0)) - 10.0)
            target["needs"] = needs
        _queue_closed_result(event, "Bad Call", "The smell was a warning. %d %s is ruined, and somebody spends the rest of the day regretting the gamble." % [loss, key], "The camp kept questionable stores and paid for it.")
    else:
        _adjust_camp_mood(-2.0, 2.0, 1.0)
        _queue_closed_result(event, "False Alarm", "It was ugly, but still usable. Nothing is lost this time.", "Questionable stores turned out to be usable.")

func _build_camp_storm_event() -> Dictionary:
    var breakable := _breakable_camp_buildings()
    if breakable.is_empty():
        return {}
    var building_name := str(breakable[rng.randi_range(0, breakable.size() - 1)])
    return _event_base("camp_storm", "Wind Against the Camp", "A hard burst of wind and rain starts pulling at the %s. There is time to make one decision before it gets worse." % building_name, [
        _choice("Spend 1 Hardware and brace it", "camp_storm_brace", int(resources.get("Hardware", 0)) < 1, "NEEDS 1 HARDWARE"),
        _choice("Move everyone clear and let the structure take it", "camp_storm_clear"),
        _choice("Keep the camp running through the storm", "camp_storm_work"),
    ], {"building_target":building_name, "weather_roll":rng.randi_range(1, 100)})

func _resolve_camp_storm(event: Dictionary, approach: String) -> void:
    var context: Dictionary = event.get("context", {})
    var building_name := str(context.get("building_target", ""))
    var roll := int(context.get("weather_roll", 50))
    if approach == "brace":
        if int(resources.get("Hardware", 0)) > 0:
            resources["Hardware"] = int(resources.get("Hardware", 0)) - 1
        _adjust_camp_mood(1.0, 0.0, 3.0)
        _queue_closed_result(event, "Braced in Time", "A piece of Hardware and a miserable hour in the rain keep the %s standing." % building_name, "The camp spent Hardware to brace %s." % building_name)
        return
    var adjusted_roll := roll - (20 if approach == "work" else 0)
    if CampLifeRules.camp_weather_breaks(adjusted_roll, false):
        _break_camp_building(building_name, "weather damage")
        _adjust_camp_mood(7.0, -3.0, -8.0)
        _queue_closed_result(event, "Something Gives", "The %s comes apart under the weather. Nobody is killed, but the structure is gone and must be rebuilt." % building_name, "%s was destroyed by a camp storm." % building_name)
    else:
        camp_maintenance = maxf(0.0, camp_maintenance - (4.0 if approach == "clear" else 8.0))
        _adjust_camp_mood(2.0, -1.0, -2.0)
        _queue_closed_result(event, "Still Standing", "The %s survives, though the camp is left muddy, scattered and harder to live in." % building_name, "A storm battered First Fire without destroying a building.")

func _build_solo_night_event() -> Dictionary:
    var present := _camp_present_survivors()
    if present.size() != 1:
        return {}
    var survivor: Dictionary = present[0]
    return _event_base("camp_solo_night", "Only One Set of Footsteps", "%s notices how loud an empty camp can feel once the fire settles down." % str(survivor.get("name", "The survivor")), [
        _choice("Burn 1 Wood and keep First Fire bright", "camp_solo_fire", int(resources.get("Wood", 0)) < 1, "NEEDS 1 WOOD"),
        _choice("Save the Wood and sit through the dark", "camp_solo_dark"),
    ], {"survivor_ids":[int(survivor.get("id", -1))]})

func _resolve_solo_night(event: Dictionary, feed_fire: bool) -> void:
    var target: Variant = _lead_from_event(event)
    if target == null:
        return
    if feed_fire and int(resources.get("Wood", 0)) > 0:
        resources["Wood"] = int(resources.get("Wood", 0)) - 1
        fire_level = minf(100.0, fire_level + 24.0)
        target["stress"] = maxf(0.0, float(target.get("stress", 0.0)) - 8.0)
        var needs := CampLifeRules.normalize_needs(target.get("needs", {}))
        needs["safety"] = minf(100.0, float(needs.get("safety", 50.0)) + 12.0)
        needs["fun"] = minf(100.0, float(needs.get("fun", 50.0)) + 3.0)
        target["needs"] = needs
        _queue_closed_result(event, "A Brighter Circle", "The extra Wood is expensive, but the fire makes the camp feel occupied instead of abandoned.", "The lone survivor spent Wood for comfort and safety.")
    else:
        target["stress"] = minf(100.0, float(target.get("stress", 0.0)) + 6.0)
        var needs2 := CampLifeRules.normalize_needs(target.get("needs", {}))
        needs2["safety"] = maxf(0.0, float(needs2.get("safety", 50.0)) - 9.0)
        target["needs"] = needs2
        _queue_closed_result(event, "Long Dark", "The Wood stays stacked. Every sound beyond the fire feels closer than it probably is.", "The lone survivor endured a dark night to conserve Wood.")

func _build_crowd_night_event() -> Dictionary:
    if population() < 5:
        return {}
    var tavern_ready := bool(buildings.get("Tavern", false))
    return _event_base("camp_crowd_night", "Too Many Voices", "First Fire is no longer a quiet camp. Some people want another hour together; others want everyone to shut up and sleep.", [
        _choice("Call for quiet", "camp_crowd_quiet"),
        _choice("Let the Tavern carry the night", "camp_crowd_tavern", not tavern_ready, "NEEDS TAVERN"),
        _choice("Put out 2 Cooked Food and make a night of it", "camp_crowd_feast", int(resources.get("Cooked Food", 0)) < 2, "NEEDS 2 COOKED FOOD"),
    ])

func _resolve_crowd_night(event: Dictionary, approach: String) -> void:
    match approach:
        "quiet":
            _adjust_camp_mood(2.0, -7.0, 8.0)
            _queue_closed_result(event, "Quiet Wins", "The camp settles down. Some people are annoyed, but the perimeter feels orderly again.", "The camp chose quiet over morale.")
        "tavern":
            _adjust_camp_mood(-4.0, 10.0, -3.0)
            _queue_closed_result(event, "One More Hour", "The Tavern stays loud. People laugh more than they sleep, and for tonight that feels worth it.", "The camp chose Tavern social time over quiet.")
        "feast":
            if int(resources.get("Cooked Food", 0)) >= 2:
                resources["Cooked Food"] = int(resources.get("Cooked Food", 0)) - 2
            _adjust_camp_mood(-7.0, 15.0, 3.0)
            _queue_closed_result(event, "A Real Evening", "Two meals disappear quickly, but the camp feels like a community instead of a collection of beds.", "The camp spent food on a communal morale night.")

func _consider_camp_event():
    if camp_event_cooldown > 0.0 or population() < 1 or game_over or not current_event.is_empty() or not event_queue.is_empty():
        return
    if _camp_present_survivors().is_empty():
        return
    var avg_stress := 0.0
    var living := 0
    var tense := false
    for survivor_value in _camp_present_survivors():
        var survivor: Dictionary = survivor_value
        avg_stress += float(survivor.get("stress", 0.0))
        living += 1
        for relationship_value in survivor.get("relationships", {}).values():
            if int(relationship_value) <= -25:
                tense = true
    if living > 0:
        avg_stress /= float(living)
    var chance := 0.18 + (avg_stress / 800.0)
    if population() > shelter_capacity():
        chance += 0.06
    if food_shortage_days > 0 or water_shortage_days > 0:
        chance += 0.05
    if camp_maintenance < CampLifeRules.CAMP_CONDITION_NEGLECTED:
        chance += 0.05
    if _camp_present_survivors().size() >= 5:
        chance += 0.04
    if tense:
        chance += 0.04
    chance = minf(0.52, chance)
    if rng.randf() > chance:
        return
    var event := _select_camp_event()
    if not event.is_empty():
        _queue_event(event)
        camp_event_cooldown = 60.0

func _select_camp_event() -> Dictionary:
    var pop: int = int(_camp_present_survivors().size())
    var candidates: Array = ["attack"]
    if pop == 1:
        candidates.append("solo_night")
    else:
        if pop > shelter_capacity():
            candidates.append("sleep")
        if _repeated_runner() != null:
            candidates.append("run")
        if int(resources.get("Cooked Food", 0)) > 0:
            candidates.append("extra_food")
        if pop >= 3 and int(resources.get("Cooked Food", 0)) > 0:
            candidates.append("missing")
        if _tense_pair().size() == 2:
            candidates.append("fight")
        if _high_stress_survivor() != null:
            candidates.append("refuse")
        if int(resources.get("Cloth", 0)) > 0:
            candidates.append("request")
        if bool(buildings.get("Tavern", false)) and pop >= 3 and int(resources.get("Cooked Food", 0)) >= pop + 2:
            candidates.append("meal")
        if (food_shortage_days > 0 or water_shortage_days > 0) and (leader_id != -1 or coordinator_id != -1):
            candidates.append("shortage_meeting")
    if not _breakable_camp_buildings().is_empty():
        candidates.append("storm")
    if not _camp_spoilable_supply_keys().is_empty():
        candidates.append("spoil")
    if pop >= 4:
        candidates.append("attack")
    if pop >= 5:
        candidates.append("crowd")
    if pop >= 8:
        candidates.append("attack")

    var key := str(candidates[rng.randi_range(0, candidates.size() - 1)])
    match key:
        "attack":
            return _build_camp_zombie_attack_event()
        "solo_night":
            return _build_solo_night_event()
        "spoil":
            return _build_camp_spoil_event()
        "storm":
            return _build_camp_storm_event()
        "crowd":
            return _build_crowd_night_event()
        "sleep":
            return _event_base("camp_sleep", "Where Am I Sleeping?", "There are more people than proper sleeping spaces. Someone is going to have a miserable night unless the camp changes its priorities.", [
                {"text":"Give the newcomer the best spot","action":"camp_sleep_newcomer"},
                {"text":"Ask an established survivor to give up theirs","action":"camp_sleep_existing"},
                {"text":"The newcomer sleeps rough","action":"camp_sleep_rough"},
            ])
        "run":
            var repeated: Variant = _repeated_runner()
            return _event_base("camp_run", "Another Run?", "%s asks why they are always the one being sent outside while others stay at camp." % repeated["name"], [
                {"text":"You're the best at it","action":"camp_run_best"},
                {"text":"Promise to rotate expedition duty","action":"camp_run_rotate"},
            ], {"survivor_ids":[repeated["id"]]})
        "extra_food":
            var target: Variant = _highest_stress_survivor()
            return _event_base("camp_extra_food", "Extra Food", "%s quietly asks for another ration." % target["name"], [
                {"text":"Give them one","action":"camp_extra_food_give"},
                {"text":"Refuse","action":"camp_extra_food_refuse"},
            ], {"survivor_ids":[target["id"]]})
        "missing":
            resources["Cooked Food"] = maxi(0, int(resources["Cooked Food"]) - 1)
            return _event_base("camp_missing", "The Missing Can", "A ration is missing from the camp's food stores. Nobody admits taking it.", [
                {"text":"Search for what happened","action":"camp_missing_search"},
                {"text":"Let it go","action":"camp_missing_ignore"},
            ])
        "fight":
            var pair: Array = _tense_pair()
            return _event_base("camp_fight", "Fight at the Fire", "%s and %s finally come to blows beside the fire." % [pair[0]["name"], pair[1]["name"]], [
                {"text":"Separate them","action":"camp_fight_separate"},
                {"text":"Have someone mediate","action":"camp_fight_mediated"},
                {"text":"Let them settle it","action":"camp_fight_settle"},
            ], {"pair":[pair[0]["id"], pair[1]["id"]]})
        "refuse":
            var stressed: Variant = _high_stress_survivor()
            return _event_base("camp_refuse", "Refusing Duty", "%s says they are done working for now." % stressed["name"], [
                {"text":"Give them time to rest","action":"camp_refuse_rest"},
                {"text":"Tell them everyone has to contribute","action":"camp_refuse_force"},
            ], {"survivor_ids":[stressed["id"]]})
        "request":
            var requester: Variant = _highest_stress_survivor()
            return _event_base("camp_request", "A Personal Request", "%s asks for some cloth to repair a personal keepsake. It will not help the camp." % requester["name"], [
                {"text":"Give them the cloth","action":"camp_request_give"},
                {"text":"We need it for the camp","action":"camp_request_refuse"},
            ], {"survivor_ids":[requester["id"]]})
        "meal":
            return _event_base("camp_meal", "Eat Together", "There is enough food for once. Someone suggests putting two extra rations on the communal table and eating like people instead of inventory slots.", [
                {"text":"Use two extra rations and eat together","action":"camp_meal_share"},
                {"text":"Save the food","action":"camp_meal_save"},
            ])
        "shortage_meeting":
            var active_leader: Variant = get_survivor(leader_id if leader_id != -1 else coordinator_id)
            return _event_base("camp_shortage_meeting", "Rations and Blame", "Short supplies turn into a political argument. People want to know whether %s actually has a plan." % (active_leader["name"] if active_leader != null else "anyone"), [
                {"text":"Back the current ration plan","action":"camp_shortage_back_leader"},
                {"text":"Let everyone say what they think","action":"camp_shortage_open_floor"},
            ])
    return {}

func _repeated_runner() -> Variant:
    if recent_expedition_ids.size() < 4:
        return null
    var present_ids: Array = []
    for survivor_value in _camp_present_survivors():
        present_ids.append(int(survivor_value.get("id", -1)))
    var counts = {}
    for sid in recent_expedition_ids:
        counts[str(sid)] = int(counts.get(str(sid), 0)) + 1
    for key in counts.keys():
        if int(counts[key]) >= 3:
            var s: Variant = get_survivor(int(key))
            if s != null and present_ids.has(int(s["id"])) and present_ids.size() >= 2:
                return s
    return null

func _tense_pair() -> Array:
    return CampSocial.tense_pair(_camp_present_survivors())

func _high_stress_survivor() -> Variant:
    return CampSocial.high_stress_survivor(_camp_present_survivors())

func _highest_stress_survivor() -> Variant:
    return CampSocial.highest_stress_survivor(_camp_present_survivors())

func _highest_skill_survivor(skill) -> Variant:
    return CampSocial.highest_skill_survivor(_camp_present_survivors(), str(skill))

func _resolve_sleep_event(event, mode):
    var living = []
    for s in survivors:
        if s["condition"] != "Dead": living.append(s)
    if living.is_empty(): return
    var newcomer = living.back()
    if mode == "newcomer":
        newcomer["stress"] = max(0.0, float(newcomer["stress"]) - 5.0)
        if living.size() > 1: living[0]["stress"] = min(100.0, float(living[0]["stress"]) + 5.0)
    elif mode == "existing":
        newcomer["stress"] = max(0.0, float(newcomer["stress"]) - 3.0)
        if living.size() > 1: living[0]["stress"] += 8
    else:
        newcomer["stress"] += 10

func _resolve_run_complaint(event, mode):
    var s: Variant = _lead_from_event(event)
    if s == null: return
    if mode == "best":
        s["stress"] = min(100.0, float(s["stress"]) + 6.0)
        s["leader_support"] = int(s.get("leader_support", 0)) - 2
    else:
        s["stress"] = max(0.0, float(s["stress"]) - 5.0)
        flags["promised_rotation"] = true

func _resolve_fight(event, mode):
    var pair_ids = event.get("context", {}).get("pair", [])
    if pair_ids.size() != 2: return
    var a: Variant = get_survivor(pair_ids[0])
    var b: Variant = get_survivor(pair_ids[1])
    if a == null or b == null: return
    if mode == "mediate":
        var med: Variant = _highest_skill_survivor("Social")
        if med != null and skill_check(med, "Social", 10) >= 0:
            _change_relationship(a, b, 8)
            _change_relationship(b, a, 8)
            add_skill_xp(med, "Social", 8)
        else:
            _change_relationship(a, b, -4)
            _change_relationship(b, a, -4)
    elif mode == "separate":
        _change_relationship(a, b, -2)
        _change_relationship(b, a, -2)
    else:
        _change_relationship(a, b, -8)
        _change_relationship(b, a, -8)
        if rng.randf() < 0.50: _apply_injury(a if rng.randf() < 0.5 else b, "Hurt")

func _consider_politics():
    if game_over:
        return
    if population() >= 3 and coordinator_id == -1 and leader_id == -1 and not flags.get("coordinator_event_queued", false):
        flags["coordinator_event_queued"] = true
        _queue_event(_build_coordinator_event())
        return
    if population() >= 5 and leader_id == -1 and coordinator_id != -1 and not flags.get("formal_election_queued", false):
        flags["formal_election_queued"] = true
        _queue_event(_build_formal_election())
        return
    if leader_id == -1 or population() < 6:
        return
    if not flags.has("next_confidence_check_day"):
        flags["next_confidence_check_day"] = day + 3
        return
    if day < int(flags.get("next_confidence_check_day", day + 3)) or not current_event.is_empty():
        return
    var incumbent: Variant = get_survivor(leader_id)
    var support := CampSocial.leader_support_score(incumbent, survivors)
    flags["next_confidence_check_day"] = day + (3 if support <= -12.0 else 2)
    if support > -12.0:
        return
    var challenger: Variant = CampSocial.strongest_challenger(survivors, leader_id)
    if challenger != null:
        _queue_event(_build_confidence_vote(challenger))

func _candidate_standing(s):
    return CampSocial.candidate_standing(s, survivors)

func _top_candidates():
    return CampSocial.top_candidates(survivors)

func _build_coordinator_event():
    var c = _top_candidates()
    if c.size() < 2: return {}
    return _event_base("politics_coordinator", "Who Decides?", "The camp has grown past one person making every call by habit. When people disagree, someone needs the final word.", [
        {"text": "Support %s — %s" % [c[0]["name"], c[0]["leader_ability"]], "action": "politics_support_a"},
        {"text": "Support %s — %s" % [c[1]["name"], c[1]["leader_ability"]], "action": "politics_support_b"},
        {"text": "Stay out of it", "action": "politics_neutral"},
    ], {"candidates": [c[0]["id"], c[1]["id"]]})

func _resolve_coordinator_vote(event, action):
    var ids = event.get("context", {}).get("candidates", [])
    if ids.size() < 2: return
    var endorsement = -1
    if action == "politics_support_a": endorsement = ids[0]
    elif action == "politics_support_b": endorsement = ids[1]
    var winner = _run_vote(ids, endorsement)
    coordinator_id = winner
    leadership_form = "Coordinator"
    var s: Variant = get_survivor(winner)
    if s != null:
        _add_history("Day %d — %s became First Fire's coordinator (%s)." % [day, s["name"], s["leader_ability"]])
        toast_requested.emit("%s is now Coordinator." % s["name"])

func _build_formal_election():
    var incumbent: Variant = get_survivor(coordinator_id)
    var candidates = _top_candidates()
    var challenger: Variant = null
    for c in candidates:
        if incumbent == null or int(c["id"]) != int(incumbent["id"]):
            challenger = c
            break
    if incumbent == null or challenger == null:
        return {}
    return _event_base("politics_election", "Make It Official", "Five people now depend on this camp. The informal arrangement is no longer enough. The camp calls for a formal leader.", [
        {"text": "Support %s — %s" % [incumbent["name"], incumbent["leader_ability"]], "action": "election_support_a"},
        {"text": "Support %s — %s" % [challenger["name"], challenger["leader_ability"]], "action": "election_support_b"},
        {"text": "Stay neutral", "action": "election_neutral"},
    ], {"candidates": [incumbent["id"], challenger["id"]]})

func _resolve_formal_election(event, action):
    var ids = event.get("context", {}).get("candidates", [])
    if ids.size() < 2: return
    var endorsement = -1
    if action == "election_support_a": endorsement = ids[0]
    elif action == "election_support_b": endorsement = ids[1]
    leader_id = _run_vote(ids, endorsement)
    coordinator_id = -1
    leadership_form = "Elected Leader"
    flags["next_confidence_check_day"] = day + 3
    var winner: Variant = get_survivor(leader_id)
    if winner != null:
        _add_history("Day %d — %s was elected leader of First Fire (%s)." % [day, winner["name"], winner["leader_ability"]])
        toast_requested.emit("%s was elected leader." % winner["name"])

func _build_confidence_vote(challenger: Dictionary):
    var incumbent: Variant = get_survivor(leader_id)
    if incumbent == null or challenger.is_empty():
        return {}
    return _event_base("politics_confidence", "Confidence Vote", "Support for %s has fallen far enough that %s openly asks the camp for a new vote." % [incumbent["name"], challenger["name"]], [
        {"text": "Keep %s" % incumbent["name"], "action": "confidence_support_a"},
        {"text": "Back %s" % challenger["name"], "action": "confidence_support_b"},
        {"text": "Stay neutral", "action": "confidence_neutral"},
    ], {"candidates": [incumbent["id"], challenger["id"]]})

func _resolve_confidence_vote(event, action):
    var ids = event.get("context", {}).get("candidates", [])
    if ids.size() != 2:
        return
    var old_leader := int(leader_id)
    var endorsement := -1
    if action == "confidence_support_a": endorsement = int(ids[0])
    elif action == "confidence_support_b": endorsement = int(ids[1])
    leader_id = _run_vote(ids, endorsement)
    leadership_form = "Elected Leader"
    flags["next_confidence_check_day"] = day + 4
    var winner: Variant = get_survivor(leader_id)
    if winner != null:
        var verb := "kept leadership" if leader_id == old_leader else "won leadership"
        _add_history("Day %d — %s %s after a confidence vote." % [day, winner["name"], verb])
        toast_requested.emit("%s %s." % [winner["name"], verb])

func _run_vote(candidate_ids, endorsement):
    var totals = {}
    for cid in candidate_ids: totals[str(cid)] = 0
    for voter in survivors:
        if voter["condition"] == "Dead": continue
        var best_id = candidate_ids[0]
        var best_score = -99999
        for cid in candidate_ids:
            var c: Variant = get_survivor(cid)
            if c == null: continue
            var score = int(voter["relationships"].get(str(cid), 0)) + int(c["skills"]["Social"]) * 6 + int(c["reputation"])
            if int(voter["id"]) == int(cid): score += 50
            if int(cid) == int(endorsement): score += 15
            score += rng.randi_range(-8, 8)
            if score > best_score:
                best_score = score
                best_id = cid
        totals[str(best_id)] = int(totals.get(str(best_id), 0)) + 1
    var winner = candidate_ids[0]
    for cid in candidate_ids:
        if int(totals[str(cid)]) > int(totals[str(winner)]): winner = cid
        elif int(totals[str(cid)]) == int(totals[str(winner)]) and _candidate_standing(get_survivor(cid)) > _candidate_standing(get_survivor(winner)):
            winner = cid
    return int(winner)

func leader_support_label():
    var leader: Variant = get_survivor(leader_id if leader_id != -1 else coordinator_id)
    if leader == null: return "None"
    var avg := CampSocial.leader_support_score(leader, survivors)
    if avg >= 50: return "Very Strong"
    if avg >= 20: return "Strong"
    if avg <= -40: return "Hostile"
    if avg <= -15: return "Weak"
    return "Mixed"

func _all_buildings_complete() -> bool:
    for building in D.BUILD_ORDER:
        if not buildings.get(building, false):
            return false
    return true

func _check_settlement_mature():
    if settlement_mature:
        return
    if population() >= 15 and _all_buildings_complete() and leader_id != -1:
        settlement_mature = true
        _add_history("Day %d — First Fire reached mature-settlement scale." % day)
        _queue_event(_event_base("settlement_mature", "FIRST FIRE ENDURES", "Fifteen people live here now, every planned structure is standing, and the camp has a government people can argue with. There is no ending from here—First Fire simply keeps living.", [
            {"text": "Keep the fire going", "action": "mature_continue"}
        ]))

func _check_game_over():
    if population() <= 0:
        game_over = true
        sim_paused = true
        _queue_event(_event_base("game_over", "FIRST FIRE IS GONE", "No one remains to keep the fire burning.", [
            {"text": "Close", "action": "close"}
        ]))

func _add_history(line):
    history.append(line)
    if history.size() > 200:
        history.pop_front()

# -----------------------------------------------------------------------------
# SAVE / LOAD
# -----------------------------------------------------------------------------

func _normalize_medical_supplies() -> void:
    var legacy_medicine := maxi(0, int(resources.get("Medicine", 0)))
    if legacy_medicine > 0:
        components["First Aid Kit"] = int(components.get("First Aid Kit", 0)) + legacy_medicine
    resources.erase("Medicine")

    var legacy_dressings := maxi(0, int(components.get("Sterile Dressing", 0)))
    if legacy_dressings > 0:
        components["Bandage"] = int(components.get("Bandage", 0)) + legacy_dressings
    components.erase("Sterile Dressing")
    for key in D.STARTING_COMPONENTS.keys():
        components[key] = maxi(0, int(components.get(key, 0)))

    var retained_gear: Array = []
    for gear_value in inventory_gear:
        var gear_name := str(gear_value)
        if gear_name == "First Aid Kit":
            components["First Aid Kit"] = int(components.get("First Aid Kit", 0)) + 1
        else:
            retained_gear.append(gear_value)
    inventory_gear = retained_gear
    inventory_gear_states.erase("First Aid Kit")

    for survivor in survivors:
        var equipment: Dictionary = survivor.get("equipment", {})
        if str(equipment.get("Tool", "")) != "First Aid Kit":
            continue
        components["First Aid Kit"] = int(components.get("First Aid Kit", 0)) + 1
        equipment["Tool"] = ""
        survivor["equipment"] = equipment
        var equipment_state_value = survivor.get("equipment_state", {})
        if equipment_state_value is Dictionary:
            var equipment_state: Dictionary = equipment_state_value
            equipment_state.erase("Tool")
            survivor["equipment_state"] = equipment_state

func save_game():
    if not initialized and survivors.is_empty():
        return
    var data = {
        "version": "0.9.0-beta-candidate-camp-expansion",
        "save_schema": SAVE_SCHEMA_VERSION,
        "day": day, "day_elapsed": day_elapsed,
        "resources": resources, "components": components, "inventory_gear": inventory_gear, "inventory_gear_states": inventory_gear_states,
        "buildings": buildings, "survivors": survivors,
        "next_survivor_id": next_survivor_id, "next_expedition_id": next_expedition_id,
        "expeditions": expeditions, "zone_successes": zone_successes, "zone_pressure": zone_pressure,
        "unlocked_zones": unlocked_zones, "special_sites": special_sites,
        "history": history, "flags": flags, "policies": policies,
        "current_event": current_event, "event_queue": event_queue, "current_combat": current_combat,
        "coordinator_id": coordinator_id, "leader_id": leader_id, "leadership_form": leadership_form,
        "eligible_expeditions_since_recruit": eligible_expeditions_since_recruit,
        "food_shortage_days": food_shortage_days, "water_shortage_days": water_shortage_days,
        "garden_tended_day": garden_tended_day,
        "game_over": game_over, "settlement_mature": settlement_mature, "settlement_mature_shown": settlement_mature_shown,
        "recent_expedition_ids": recent_expedition_ids,
        "fire_level": fire_level, "camp_maintenance": camp_maintenance,
        "pets": pets, "next_pet_id": next_pet_id,
    }
    SaveCodec.write_json(SAVE_PATH, data)

func load_game():
    var parsed = SaveCodec.read_json(SAVE_PATH)
    if parsed == null:
        new_game()
        return
    if not SaveCodec.is_compatible(parsed, SAVE_SCHEMA_VERSION):
        # Alpha development rule: saves are not migrated between schema revisions.
        SaveCodec.invalidate(SAVE_PATH)
        save_existed_on_boot = false
        new_game()
        return
    day = int(parsed.get("day", 1))
    day_elapsed = float(parsed.get("day_elapsed", 0.0))
    resources = parsed.get("resources", D.STARTING_RESOURCES.duplicate(true))
    resources.erase("Ammo")
    components = parsed.get("components", {})
    inventory_gear = parsed.get("inventory_gear", [])
    inventory_gear_states = parsed.get("inventory_gear_states", {})
    if not (inventory_gear_states is Dictionary):
        inventory_gear_states = {}
    buildings = parsed.get("buildings", {})
    survivors = parsed.get("survivors", [])
    _normalize_medical_supplies()
    next_survivor_id = int(parsed.get("next_survivor_id", 1))
    next_expedition_id = int(parsed.get("next_expedition_id", 1))
    expeditions = parsed.get("expeditions", [])
    zone_successes = parsed.get("zone_successes", {})
    zone_pressure = parsed.get("zone_pressure", {})
    unlocked_zones = parsed.get("unlocked_zones", ExpeditionRules.starting_routes())
    special_sites = parsed.get("special_sites", {})
    history = parsed.get("history", [])
    flags = parsed.get("flags", {})
    if not flags.has(ExpeditionRules.VEHICLE_UNLOCK_FLAG):
        flags[ExpeditionRules.VEHICLE_UNLOCK_FLAG] = false
    unlocked_zones = ExpeditionRules.starting_routes()
    if ExpeditionRules.vehicle_unlocked(flags) and not unlocked_zones.has("Industrial Edge"):
        unlocked_zones.append("Industrial Edge")
    policies = parsed.get("policies", {})
    current_event = parsed.get("current_event", {})
    event_queue = parsed.get("event_queue", [])
    current_combat = parsed.get("current_combat", {})
    coordinator_id = int(parsed.get("coordinator_id", -1))
    leader_id = int(parsed.get("leader_id", -1))
    leadership_form = parsed.get("leadership_form", "None")
    eligible_expeditions_since_recruit = int(parsed.get("eligible_expeditions_since_recruit", 0))
    food_shortage_days = int(parsed.get("food_shortage_days", 0))
    water_shortage_days = int(parsed.get("water_shortage_days", 0))
    garden_tended_day = int(parsed.get("garden_tended_day", -1))
    game_over = bool(parsed.get("game_over", false))
    settlement_mature = bool(parsed.get("settlement_mature", false))
    settlement_mature_shown = bool(parsed.get("settlement_mature_shown", false))
    recent_expedition_ids = parsed.get("recent_expedition_ids", [])
    fire_level=clampf(float(parsed.get("fire_level",CampLifeRules.FIRE_START_LEVEL)),0.0,100.0)
    camp_maintenance=clampf(float(parsed.get("camp_maintenance",CampLifeRules.CAMP_MAINTENANCE_START)),0.0,100.0)
    pets=parsed.get("pets",[])
    next_pet_id=int(parsed.get("next_pet_id",1))
    for pet in pets: pet["needs"]=CampLifeRules.normalize_pet_needs(pet.get("needs",{}))
    for s in survivors:
        s["needs"]=CampLifeRules.normalize_needs(s.get("needs",{}))
        if not s.has("camp_activity"): s["camp_activity"]={}
    # Returning to a saved game is always paused until the player explicitly resumes.
    sim_paused = true
    state_changed.emit()
