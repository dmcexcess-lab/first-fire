extends RefCounted
class_name FFCampLifeRules

# Final feature-freeze camp cadence/tuning. Social selection lives in
# FFCampSocial; presentation lives in FFCampView.
# Camp day is 300 real active seconds. Rates below preserve the previous
# per-in-game-hour balance while the day is stretched from 120s to 300s.
const CAMP_EVENT_INTERVAL := 112.5
const NEW_GAME_EVENT_COOLDOWN := 50.0
const FATIGUE_GAIN_MULTIPLIER := 2.0
const CAMP_CHATTER_MIN_SECONDS := 17.5
const CAMP_CHATTER_MAX_SECONDS := 35.0
const FIRE_START_LEVEL := 72.0
const FIRE_DECAY_PER_SECOND := 0.096
const FIRE_MAINTAIN_THRESHOLD := 36.0
const FIRE_MAINTAIN_GAIN := 58.0
const FIRE_MAINTAIN_SECONDS := 12.5
const CAMP_MAINTENANCE_START := 82.0
const CAMP_MAINTENANCE_DECAY_PER_SECOND := 0.014
const CAMP_CONDITION_WELL_KEPT := 85.0
const CAMP_CONDITION_ACCEPTABLE := 60.0
const CAMP_CONDITION_NEGLECTED := 40.0
const CAMP_CONDITION_POOR := 20.0
const DAILY_DRINK_WINDOW_START := 12.0
const DAILY_DRINK_WINDOW_END := 14.0
const DAILY_MEAL_WINDOW_START := 18.0
const DAILY_MEAL_WINDOW_END := 21.0
const DAILY_SLEEP_WINDOW_START := 22.0
const DAILY_SLEEP_WINDOW_END := 6.0
const DAILY_WINDOW_MISS_RATIO := 0.60
const DAILY_AUTONOMOUS_SECONDS := 10.0
const FORCED_REST_MIN_HOURS := 3
const FORCED_REST_MAX_HOURS := 5
const SLEEP_START_FATIGUE := 35.0
const SLEEP_DURATION := 87.5
const SLEEP_RECOVERY_AMOUNT := 72.0
const MEAL_ACTIVITY_SECONDS := 12.5
const DRINK_ACTIVITY_SECONDS := 7.5
const MEAL_HUNGER_GAIN := 55.0
const DRINK_THIRST_GAIN := 65.0
const MISSED_MEAL_HUNGER_PENALTY := 24.0
const MISSED_WATER_THIRST_PENALTY := 32.0
const MISSED_SLEEP_FATIGUE_PENALTY := 18.0
const DAILY_CHORE_KINDS := ["poke_fire", "chop_wood", "clear_area", "stack_supplies"]
const DAILY_CHORE_NEGLECT_LOSS := 4.0
const DUTY_ROTATION_DAYS := 5
const CHORE_TARGET_COUNT := 6
const DAILY_CHORE_CATALOG := {
    "poke_fire": {"label":"Poke Fire","duration":12.5,"goal_min":4,"goal_max":5,"instruction":"Tap the hot spot to settle the logs and wake the coals."},
    "chop_wood": {"label":"Chop Wood","duration":18.75,"goal_min":4,"goal_max":6,"instruction":"Tap CHOP as the target shifts across the log."},
    "clear_area": {"label":"Clear Area","duration":25.0,"goal_min":4,"goal_max":6,"instruction":"Tap the marked debris until the work area is clear."},
    "stack_supplies": {"label":"Stack Supplies","duration":18.75,"goal_min":4,"goal_max":5,"instruction":"Tap the marked crate to build a stable supply stack."},
}
const MAX_PETS := 3
const PET_LEAVE_AFFECTION := 14.0
const PET_NEED_KEYS := ["affection"]
const PET_NAMES := ["Mochi", "Scout", "Beans", "Pepper", "Lucky", "Ash", "Noodle", "Patch", "Sunny", "Rook"]
const NEED_KEYS := ["hunger", "thirst", "sleep", "fun", "safety", "hygiene"]

static func default_needs() -> Dictionary:
    return {"hunger":82.0,"thirst":84.0,"sleep":95.0,"fun":72.0,"safety":70.0,"hygiene":76.0}

static func degrade_camp_condition(value: float, delta: float) -> float:
    return clampf(value - CAMP_MAINTENANCE_DECAY_PER_SECOND * maxf(0.0, delta), 0.0, 100.0)

static func camp_condition_band(value: float) -> String:
    var score := clampf(value, 0.0, 100.0)
    if score >= CAMP_CONDITION_WELL_KEPT: return "Well Kept"
    if score >= CAMP_CONDITION_ACCEPTABLE: return "Acceptable"
    if score >= CAMP_CONDITION_NEGLECTED: return "Neglected"
    if score >= CAMP_CONDITION_POOR: return "Poor"
    return "Severe"

static func camp_condition_mood_modifier(value: float) -> int:
    match camp_condition_band(value):
        "Well Kept": return 1
        "Neglected": return -1
        "Poor": return -2
        "Severe": return -3
    return 0

static func camp_condition_stress_rate(value: float) -> float:
    return -0.0048 * float(camp_condition_mood_modifier(value))

static func camp_condition_recovery(chore: String) -> float:
    match chore:
        "clean_camp": return 22.0
        "repair_perimeter": return 38.0
        "clear_area": return 12.0
        "stack_supplies": return 9.0
    return 0.0

static func recover_camp_condition(value: float, chore: String) -> float:
    return clampf(value + camp_condition_recovery(chore), 0.0, 100.0)

static func settlement_hour(day_elapsed_value: float, day_seconds: float) -> float:
    if day_seconds <= 0.0: return 8.0
    var wrapped := fmod(maxf(0.0, day_elapsed_value), day_seconds)
    return fmod(8.0 + (wrapped / day_seconds) * 24.0, 24.0)

static func _hour_in_window(hour: float, start_hour: float, end_hour: float) -> bool:
    var h := fmod(hour + 24.0, 24.0)
    if start_hour <= end_hour: return h >= start_hour and h < end_hour
    return h >= start_hour or h < end_hour

static func default_daily_activity(day_value: int) -> Dictionary:
    return {"day":day_value,"assigned_work":false,"expedition":false,"care":false,"autonomous":false,"meal_attempted":false,"water_attempted":false,"ate_normally":false,"drank_normally":false,"slept_normally":false,"missed_meal":false,"missed_water":false,"missed_sleep":false,"water_window_total":0.0,"water_window_blocked":0.0,"water_window_free":0.0,"meal_window_total":0.0,"meal_window_blocked":0.0,"meal_window_free":0.0,"sleep_window_total":0.0,"sleep_window_blocked":0.0,"sleep_window_free":0.0,"sleep_seconds":0.0,"autonomous_seconds":0.0}

static func normalize_daily_activity(value, day_value: int) -> Dictionary:
    var incoming: Dictionary = value.duplicate(true) if value is Dictionary else {}
    if int(incoming.get("day", day_value)) != day_value: return default_daily_activity(day_value)
    var result := default_daily_activity(day_value)
    for key in result.keys():
        if incoming.has(key): result[key] = incoming[key]
    for key in ["assigned_work","expedition","care","autonomous","meal_attempted","water_attempted","ate_normally","drank_normally","slept_normally","missed_meal","missed_water","missed_sleep"]: result[key]=bool(result[key])
    for key in ["water_window_total","water_window_blocked","water_window_free","meal_window_total","meal_window_blocked","meal_window_free","sleep_window_total","sleep_window_blocked","sleep_window_free","sleep_seconds","autonomous_seconds"]: result[key]=maxf(0.0,float(result[key]))
    return result

static func record_daily_activity(value, day_value: int, status: String, task_kind: String, hour: float, delta: float) -> Dictionary:
    var result := normalize_daily_activity(value, day_value)
    var dt := maxf(0.0, delta)
    var assigned := status in ["Crafting","Building","Tending","Chore","Pet Care","Training","Expedition","Pending Expedition Event"] or task_kind in ["craft","build","garden","chore","pet_care","training"]
    if assigned: result["assigned_work"]=true
    if status in ["Expedition","Pending Expedition Event"]: result["expedition"]=true
    if status=="Recovering" or task_kind in ["treatment","virus_treatment"]:
        result["care"]=true; assigned=true; result["assigned_work"]=true
    if status in ["Sleeping","Exhausted"] or task_kind in ["sleep","forced_rest"]:
        result["autonomous"]=true; result["sleep_seconds"]=float(result["sleep_seconds"])+dt
    elif status=="Available":
        result["autonomous_seconds"]=float(result["autonomous_seconds"])+dt
        if float(result["autonomous_seconds"])>=DAILY_AUTONOMOUS_SECONDS: result["autonomous"]=true
    if _hour_in_window(hour,DAILY_DRINK_WINDOW_START,DAILY_DRINK_WINDOW_END):
        result["water_window_total"]=float(result["water_window_total"])+dt
        if assigned: result["water_window_blocked"]=float(result["water_window_blocked"])+dt
        elif status=="Available": result["water_window_free"]=float(result["water_window_free"])+dt
    if _hour_in_window(hour,DAILY_MEAL_WINDOW_START,DAILY_MEAL_WINDOW_END):
        result["meal_window_total"]=float(result["meal_window_total"])+dt
        if assigned: result["meal_window_blocked"]=float(result["meal_window_blocked"])+dt
        elif status=="Available": result["meal_window_free"]=float(result["meal_window_free"])+dt
    if _hour_in_window(hour,DAILY_SLEEP_WINDOW_START,DAILY_SLEEP_WINDOW_END):
        result["sleep_window_total"]=float(result["sleep_window_total"])+dt
        if assigned: result["sleep_window_blocked"]=float(result["sleep_window_blocked"])+dt
        elif status in ["Available","Sleeping"]: result["sleep_window_free"]=float(result["sleep_window_free"])+dt
    return result

static func finalize_daily_activity(value, day_value: int) -> Dictionary:
    var result := normalize_daily_activity(value, day_value)
    var water_total := float(result["water_window_total"])
    var meal_total := float(result["meal_window_total"])
    var sleep_total := float(result["sleep_window_total"])
    var water_ratio := float(result["water_window_blocked"])/water_total if water_total>0.0 else 0.0
    var meal_ratio := float(result["meal_window_blocked"])/meal_total if meal_total>0.0 else 0.0
    var sleep_ratio := float(result["sleep_window_blocked"])/sleep_total if sleep_total>0.0 else 0.0
    result["slept_normally"]=float(result["sleep_seconds"])>=SLEEP_DURATION*0.70
    result["missed_water"]=bool(result["assigned_work"]) and water_ratio>=DAILY_WINDOW_MISS_RATIO and not bool(result["drank_normally"])
    result["missed_meal"]=bool(result["assigned_work"]) and meal_ratio>=DAILY_WINDOW_MISS_RATIO and not bool(result["ate_normally"])
    result["missed_sleep"]=bool(result["assigned_work"]) and sleep_ratio>=DAILY_WINDOW_MISS_RATIO and not bool(result["slept_normally"])
    return result

static func apply_missed_schedule_consequences(needs: Dictionary, fatigue: float, missed_meal: bool, missed_sleep: bool, missed_water: bool=false) -> Dictionary:
    var n:=normalize_needs(needs); var f:=maxf(0.0,fatigue)
    if missed_meal: n["hunger"]=clampf(float(n["hunger"])-MISSED_MEAL_HUNGER_PENALTY,0.0,100.0)
    if missed_water: n["thirst"]=clampf(float(n["thirst"])-MISSED_WATER_THIRST_PENALTY,0.0,100.0)
    if missed_sleep:
        f=clampf(f+MISSED_SLEEP_FATIGUE_PENALTY,0.0,100.0)
        n["sleep"]=clampf(100.0-f,0.0,100.0)
    return {"needs":n,"fatigue":f}

static func apply_daily_shortage_consequences(needs: Dictionary, missed_food: bool, missed_water: bool) -> Dictionary:
    var n:=normalize_needs(needs)
    if missed_food: n["hunger"]=clampf(float(n["hunger"])-MISSED_MEAL_HUNGER_PENALTY,0.0,100.0)
    if missed_water: n["thirst"]=clampf(float(n["thirst"])-MISSED_WATER_THIRST_PENALTY,0.0,100.0)
    return n

static func daily_workload_pressure(value, day_value: int) -> int:
    var a:=normalize_daily_activity(value,day_value); var pressure:=0
    if bool(a["assigned_work"]): pressure+=1
    if bool(a["missed_water"]): pressure+=1
    if bool(a["missed_meal"]): pressure+=1
    if bool(a["missed_sleep"]): pressure+=1
    return pressure

static func daily_chore_data(kind: String) -> Dictionary:
    return DAILY_CHORE_CATALOG.get(kind, {}).duplicate(true)

static func daily_chore_label(kind: String) -> String:
    return str(DAILY_CHORE_CATALOG.get(kind, {}).get("label", kind.replace("_", " ").capitalize()))

static func daily_chore_duration(kind: String) -> float:
    return float(DAILY_CHORE_CATALOG.get(kind, {}).get("duration", 7.5))

static func daily_chore_goal(kind: String, seed: int) -> int:
    var data: Dictionary = DAILY_CHORE_CATALOG.get(kind, {})
    var low := int(data.get("goal_min", 4))
    var high := maxi(low, int(data.get("goal_max", low)))
    return low + posmod(seed, high - low + 1)

static func daily_chore_instruction(kind: String) -> String:
    return str(DAILY_CHORE_CATALOG.get(kind, {}).get("instruction", "Complete the camp chore."))

static func daily_chore_target_index(kind: String, seed: int, progress: int) -> int:
    var kind_index := maxi(0, DAILY_CHORE_KINDS.find(kind))
    return posmod(seed + progress * 17 + kind_index * 11, CHORE_TARGET_COUNT)

static func generate_daily_chores(day_value: int, rng: RandomNumberGenerator) -> Array:
    var result: Array = []
    var count := 1 + (1 if rng.randf() < 0.5 else 0)
    for index in range(count):
        var kind := str(DAILY_CHORE_KINDS[rng.randi_range(0, DAILY_CHORE_KINDS.size() - 1)])
        var seed := rng.randi_range(1, 2147483000)
        result.append({
            "id":"%d-%d-%s" % [day_value, index, kind],
            "day":day_value,
            "kind":kind,
            "label":daily_chore_label(kind),
            "assigned_survivor_id":-1,
            "eligible_ids":[],
            "minigame_seed":seed,
            "minigame_progress":0,
            "minigame_goal":daily_chore_goal(kind, seed),
            "interaction_complete":false,
            "complete":false,
            "rewarded":false,
        })
    return result

static func normalize_daily_chores(value, day_value: int) -> Array:
    if not (value is Array): return []
    var incoming: Array = value
    if incoming.size() < 1 or incoming.size() > 2: return []
    var result: Array = []
    for item_value in incoming:
        if not (item_value is Dictionary): return []
        var item: Dictionary = item_value.duplicate(true)
        var kind := str(item.get("kind", ""))
        if kind not in DAILY_CHORE_KINDS or int(item.get("day", -1)) != day_value: return []
        var seed := maxi(1, int(item.get("minigame_seed", 1)))
        var goal := clampi(int(item.get("minigame_goal", daily_chore_goal(kind, seed))), 1, 8)
        item["label"] = daily_chore_label(kind)
        item["assigned_survivor_id"] = int(item.get("assigned_survivor_id", -1))
        item["eligible_ids"] = item.get("eligible_ids", []).duplicate(true) if item.get("eligible_ids", []) is Array else []
        item["minigame_seed"] = seed
        item["minigame_goal"] = goal
        item["minigame_progress"] = clampi(int(item.get("minigame_progress", 0)), 0, goal)
        item["interaction_complete"] = bool(item.get("interaction_complete", false)) or int(item["minigame_progress"]) >= goal
        item["complete"] = bool(item.get("complete", false))
        item["rewarded"] = bool(item.get("rewarded", false))
        result.append(item)
    return result

static func unfinished_daily_chore_count(chores: Array) -> int:
    var count := 0
    for chore_value in chores:
        if chore_value is Dictionary and not bool(chore_value.get("complete", false)): count += 1
    return count

static func apply_unfinished_chore_neglect(value: float, chores: Array) -> float:
    return clampf(value - float(unfinished_daily_chore_count(chores)) * DAILY_CHORE_NEGLECT_LOSS, 0.0, 100.0)

static func daily_chore_effect(kind: String) -> Dictionary:
    match kind:
        "poke_fire": return {"fire_gain":28.0}
        "chop_wood": return {"wood_gain":1}
        "clear_area": return {"condition_gain":camp_condition_recovery("clear_area")}
        "stack_supplies": return {"condition_gain":camp_condition_recovery("stack_supplies")}
    return {}

static func normalize_duty_days(value, current_day: int) -> Array:
    var incoming: Array = value.duplicate() if value is Array else []
    var result: Array = []
    var minimum_day := current_day - DUTY_ROTATION_DAYS + 1
    for day_value in incoming:
        var duty_day := int(day_value)
        if duty_day >= minimum_day and duty_day <= current_day and not result.has(duty_day):
            result.append(duty_day)
    result.sort()
    return result

static func duty_fairness_pressure(completed_days, eligible_days, current_day: int) -> int:
    var completed := normalize_duty_days(completed_days, current_day)
    var eligible := normalize_duty_days(eligible_days, current_day)
    if eligible.is_empty(): return 0
    return maxi(0, eligible.size() - completed.size())

static func normalize_needs(value) -> Dictionary:
    var d:=default_needs()
    var n:Dictionary=value.duplicate(true) if value is Dictionary else {}
    for k in NEED_KEYS: n[k]=clampf(float(n.get(k,d[k])),0.0,100.0)
    return n

static func update_needs(needs:Dictionary,fatigue:float,delta:float,safety_target_value:float,hygiene_support:bool,away:bool)->Dictionary:
    var n:=normalize_needs(needs)
    n["hunger"]=clampf(float(n["hunger"])-delta*(0.048 if away else 0.036),0.0,100.0)
    n["thirst"]=clampf(float(n["thirst"])-delta*(0.064 if away else 0.048),0.0,100.0)
    n["sleep"]=clampf(100.0-fatigue,0.0,100.0)
    n["fun"]=clampf(float(n["fun"])-delta*(0.044 if away else 0.030),0.0,100.0)
    n["hygiene"]=clampf(float(n["hygiene"])-delta*(0.048 if away else (0.018 if hygiene_support else 0.028)),0.0,100.0)
    n["safety"]=move_toward(float(n["safety"]),clampf(safety_target_value,0.0,100.0),delta*(0.30 if away else 0.20))
    return n

static func apply_daily_rations(needs:Dictionary,fed:bool,watered:bool)->Dictionary:
    var n:=normalize_needs(needs)
    n["hunger"]=clampf(float(n["hunger"])+(42.0 if fed else -24.0),0.0,100.0)
    n["thirst"]=clampf(float(n["thirst"])+(52.0 if watered else -32.0),0.0,100.0)
    return n

static func safety_target(buildings:Dictionary,population_count:int,shelter_capacity_value:int,fire_level:float,away:bool,camp_maintenance:float=100.0)->float:
    if away: return 24.0
    var v:=48.0
    if bool(buildings.get("Noise Line",false)): v+=11.0
    if bool(buildings.get("Watch Post",false)): v+=16.0
    if bool(buildings.get("Large Tarp",false)): v+=3.0
    if bool(buildings.get("Barracks",false)): v+=8.0
    if bool(buildings.get("Dormitory",false)): v+=5.0
    if fire_level>=55.0: v+=8.0
    elif fire_level<=18.0: v-=10.0
    if population_count>shelter_capacity_value: v-=float(population_count-shelter_capacity_value)*8.0
    if camp_maintenance < 30.0: v -= 12.0
    elif camp_maintenance < 55.0: v -= 5.0
    elif camp_maintenance >= 85.0: v += 3.0
    return clampf(v,5.0,95.0)

static func need_stress_rate(needs:Dictionary,camp_condition_value:float=70.0)->float:
    var n:=normalize_needs(needs); var pressure:=0.0
    for k in NEED_KEYS:
        var v:=float(n[k])
        if v<25.0: pressure+=(25.0-v)/25.0
    var rate:=0.0
    if pressure>0.0: rate=pressure*0.014
    else:
        var all_good:=true
        for k in NEED_KEYS:
            if float(n[k])<62.0: all_good=false; break
        if all_good: rate=-0.0072
    return rate+camp_condition_stress_rate(camp_condition_value)

static func moodlets(needs:Dictionary)->Array:
    var n:=normalize_needs(needs); var r:Array=[]
    var v:=float(n["hunger"])
    if v<=24:r.append("Starving")
    elif v<=46:r.append("Hungry")
    elif v>=82:r.append("Well Fed")
    v=float(n["thirst"])
    if v<=24:r.append("Parched")
    elif v<=46:r.append("Thirsty")
    elif v>=84:r.append("Hydrated")
    v=float(n["sleep"])
    if v<=30:r.append("Exhausted")
    elif v<=52:r.append("Sleepy")
    elif v>=86:r.append("Rested")
    v=float(n["fun"])
    if v<=34:r.append("Bored")
    elif v>=78:r.append("Entertained")
    v=float(n["safety"])
    if v<=34:r.append("Afraid")
    elif v>=74:r.append("Safe")
    v=float(n["hygiene"])
    if v<=32:r.append("Dirty")
    elif v>=80:r.append("Clean")
    if r.is_empty(): r.append("Okay")
    return r

static func choose_available_activity(needs:Dictionary,fire_level:float,wood:int,pop:int,has_tavern:bool,hygiene_support:bool,rng:RandomNumberGenerator,hour:float=-1.0,daily_activity:Dictionary={},food:int=0,water:int=0)->Dictionary:
    # Ordinary needs are autonomous. Productive camp labor is never auto-assigned.
    # Schedule-critical needs take priority over flavor idles.
    var n:=normalize_needs(needs)
    var activity:=normalize_daily_activity(daily_activity,int(daily_activity.get("day",1)))
    if hour>=0.0 and _hour_in_window(hour,DAILY_DRINK_WINDOW_START,DAILY_DRINK_WINDOW_END) and not bool(activity["water_attempted"]):
        return {"kind":"drink_water","label":"Drinking Water" if water>0 else "Checking Water","remaining":DRINK_ACTIVITY_SECONDS,"duration":DRINK_ACTIVITY_SECONDS}
    if hour>=0.0 and _hour_in_window(hour,DAILY_MEAL_WINDOW_START,DAILY_MEAL_WINDOW_END) and not bool(activity["meal_attempted"]):
        return {"kind":"eat_meal","label":"Eating Meal" if food>0 else "Checking Rations","remaining":MEAL_ACTIVITY_SECONDS,"duration":MEAL_ACTIVITY_SECONDS}
    if hour>=0.0 and _hour_in_window(hour,DAILY_SLEEP_WINDOW_START,DAILY_SLEEP_WINDOW_END) and (100.0-float(n["sleep"]))>=SLEEP_START_FATIGUE:
        return {"kind":"rest","label":"Sleeping","remaining":SLEEP_DURATION,"duration":SLEEP_DURATION}
    if float(n["hygiene"])<44.0 and hygiene_support: return {"kind":"wash","label":"Washing Up","remaining":12.5,"duration":12.5}
    if float(n["safety"])<44.0: return {"kind":"keep_watch","label":"Watching the Treeline","remaining":15.0,"duration":15.0}
    if float(n["fun"])<58.0:
        if has_tavern: return {"kind":"tavern_social","label":"At the Tavern","remaining":17.5,"duration":17.5}
        return {"kind":"watch_fire","label":"Watching Fire","remaining":17.5,"duration":17.5}
    if rng.randf()<0.18: return {"kind":"wander","label":"Walking Camp","remaining":12.5,"duration":12.5}
    return {}

static func complete_activity(needs:Dictionary,fatigue:float,kind:String)->Dictionary:
    var n:=normalize_needs(needs); var f:=fatigue
    match kind:
        "rest": f=maxf(0.0,fatigue-SLEEP_RECOVERY_AMOUNT); n["sleep"]=clampf(100.0-f,0.0,100.0)
        "eat_meal": n["hunger"]=clampf(float(n["hunger"])+MEAL_HUNGER_GAIN,0.0,100.0)
        "drink_water": n["thirst"]=clampf(float(n["thirst"])+DRINK_THIRST_GAIN,0.0,100.0)
        "wash": n["hygiene"]=clampf(float(n["hygiene"])+48.0,0.0,100.0)
        "watch_fire": n["fun"]=clampf(float(n["fun"])+22.0,0.0,100.0); n["safety"]=clampf(float(n["safety"])+6.0,0.0,100.0)
        "tavern_social": n["fun"]=clampf(float(n["fun"])+34.0,0.0,100.0); n["safety"]=clampf(float(n["safety"])+9.0,0.0,100.0)
    return {"needs":n,"fatigue":f}

static func default_pet_needs() -> Dictionary:
    return {"affection":72.0}

static func normalize_pet_needs(value) -> Dictionary:
    var result:=default_pet_needs()
    var incoming:Dictionary=value.duplicate(true) if value is Dictionary else {}
    result["affection"]=clampf(float(incoming.get("affection",result["affection"])),0.0,100.0)
    return result

static func update_pet_needs(needs:Dictionary,delta:float)->Dictionary:
    var n:=normalize_pet_needs(needs)
    n["affection"]=clampf(float(n["affection"])-delta*0.08,0.0,100.0)
    return n

static func apply_pet_care(needs:Dictionary,action:String)->Dictionary:
    var n:=normalize_pet_needs(needs)
    match action:
        "play": n["affection"]=clampf(float(n["affection"])+32.0,0.0,100.0)
        "love": n["affection"]=clampf(float(n["affection"])+48.0,0.0,100.0)
    return n

static func pet_mood(needs:Dictionary)->String:
    var affection:=float(normalize_pet_needs(needs)["affection"])
    if affection<=PET_LEAVE_AFFECTION: return "DISTRESSED"
    if affection<35.0: return "LONELY"
    if affection<60.0: return "NEEDS LOVE"
    if affection>=85.0: return "BONDED"
    return "CONTENT"

static func pet_should_leave(needs:Dictionary)->bool:
    return float(normalize_pet_needs(needs)["affection"])<=PET_LEAVE_AFFECTION

static func pet_forage_resource(species:String,rng:RandomNumberGenerator)->String:
    var dog_pool:Array=["Wood","Scrap Metal","Hardware","Cloth","Plastic","Raw Food"]
    var cat_pool:Array=["Cloth","Plastic","Hardware","Wood","Raw Food","Raw Food"]
    var pool:Array=dog_pool if species=="Dog" else cat_pool
    return str(pool[rng.randi_range(0,pool.size()-1)])

static func fatigue_gain(base_amount: float) -> float:
    return maxf(0.0, base_amount) * FATIGUE_GAIN_MULTIPLIER

static func forced_rest_duration(day_seconds: float, rng: RandomNumberGenerator) -> float:
    var hours := rng.randi_range(FORCED_REST_MIN_HOURS, FORCED_REST_MAX_HOURS)
    return maxf(0.1, (maxf(1.0, day_seconds) / 24.0) * float(hours))

static func idle_recovery_rates(has_barracks: bool, caretaker_leader: bool, has_tavern: bool = false, has_dormitory: bool = false) -> Vector2:
    var fatigue_rate: float = 1.0 / 3.0
    var stress_rate: float = 0.1
    if has_barracks:
        fatigue_rate = 0.50
        stress_rate = 1.0 / 6.0
    if has_dormitory:
        fatigue_rate = 0.62
        stress_rate = 0.20
    if has_tavern:
        stress_rate *= 1.30
    if caretaker_leader:
        fatigue_rate *= 1.2
        stress_rate *= 1.2
    return Vector2(fatigue_rate, stress_rate)

static func injury_recovery_multiplier(has_infirmary: bool) -> float:
    return 1.45 if has_infirmary else 1.0

static func treatment_time_multiplier(has_infirmary: bool) -> float:
    return 0.72 if has_infirmary else 1.0

static func critical_decline_chance(has_infirmary: bool) -> float:
    return 0.10 if has_infirmary else 0.25

static func rain_catcher_yield(has_water_tank: bool) -> int:
    return 2 if has_water_tank else 1

static func outside_injury_chance(has_noise_line: bool, has_watch_post: bool) -> float:
    if has_noise_line and has_watch_post:
        return 0.02
    if has_watch_post:
        return 0.05
    if has_noise_line:
        return 0.08
    return 0.22
