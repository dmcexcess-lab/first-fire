extends RefCounted
class_name FFCampLifeRules

# Final feature-freeze camp cadence/tuning. Social selection lives in
# FFCampSocial; presentation lives in FFCampView.
const CAMP_EVENT_INTERVAL := 45.0
const NEW_GAME_EVENT_COOLDOWN := 20.0
const FATIGUE_GAIN_MULTIPLIER := 2.0
const CAMP_CHATTER_MIN_SECONDS := 7.0
const CAMP_CHATTER_MAX_SECONDS := 14.0
const FIRE_START_LEVEL := 72.0
const FIRE_DECAY_PER_SECOND := 0.24
const FIRE_MAINTAIN_THRESHOLD := 36.0
const FIRE_MAINTAIN_GAIN := 58.0
const FIRE_MAINTAIN_SECONDS := 5.0
const NEED_KEYS := ["hunger", "thirst", "sleep", "fun", "safety", "hygiene"]

static func default_needs() -> Dictionary:
    return {"hunger":82.0,"thirst":84.0,"sleep":95.0,"fun":72.0,"safety":70.0,"hygiene":76.0}

static func normalize_needs(value) -> Dictionary:
    var d:=default_needs()
    var n:Dictionary=value.duplicate(true) if value is Dictionary else {}
    for k in NEED_KEYS: n[k]=clampf(float(n.get(k,d[k])),0.0,100.0)
    return n

static func update_needs(needs:Dictionary,fatigue:float,delta:float,safety_target_value:float,hygiene_support:bool,away:bool)->Dictionary:
    var n:=normalize_needs(needs)
    n["hunger"]=clampf(float(n["hunger"])-delta*(0.12 if away else 0.09),0.0,100.0)
    n["thirst"]=clampf(float(n["thirst"])-delta*(0.16 if away else 0.12),0.0,100.0)
    n["sleep"]=clampf(100.0-fatigue,0.0,100.0)
    n["fun"]=clampf(float(n["fun"])-delta*(0.11 if away else 0.075),0.0,100.0)
    n["hygiene"]=clampf(float(n["hygiene"])-delta*(0.12 if away else (0.045 if hygiene_support else 0.07)),0.0,100.0)
    n["safety"]=move_toward(float(n["safety"]),clampf(safety_target_value,0.0,100.0),delta*(0.75 if away else 0.50))
    return n

static func apply_daily_rations(needs:Dictionary,fed:bool,watered:bool)->Dictionary:
    var n:=normalize_needs(needs)
    n["hunger"]=clampf(float(n["hunger"])+(42.0 if fed else -24.0),0.0,100.0)
    n["thirst"]=clampf(float(n["thirst"])+(52.0 if watered else -32.0),0.0,100.0)
    return n

static func safety_target(buildings:Dictionary,population_count:int,shelter_capacity_value:int,fire_level:float,away:bool)->float:
    if away: return 24.0
    var v:=48.0
    if bool(buildings.get("Noise Line",false)): v+=11.0
    if bool(buildings.get("Watch Post",false)): v+=16.0
    if bool(buildings.get("Cabin",false)): v+=5.0
    if bool(buildings.get("Bunkhouse",false)): v+=4.0
    if fire_level>=55.0: v+=8.0
    elif fire_level<=18.0: v-=10.0
    if population_count>shelter_capacity_value: v-=float(population_count-shelter_capacity_value)*8.0
    return clampf(v,5.0,95.0)

static func need_stress_rate(needs:Dictionary)->float:
    var n:=normalize_needs(needs)
    var pressure:=0.0
    for k in NEED_KEYS:
        var v:=float(n[k])
        if v<25.0: pressure+=(25.0-v)/25.0
    if pressure>0.0: return pressure*0.035
    for k in NEED_KEYS:
        if float(n[k])<62.0: return 0.0
    return -0.018

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

static func choose_available_activity(needs:Dictionary,fire_level:float,wood:int,pop:int,has_table:bool,hygiene_support:bool,rng:RandomNumberGenerator)->Dictionary:
    var n:=normalize_needs(needs)
    if fire_level<FIRE_MAINTAIN_THRESHOLD and wood>0: return {"kind":"maintain_fire","label":"Maintaining Fire","remaining":FIRE_MAINTAIN_SECONDS,"duration":FIRE_MAINTAIN_SECONDS}
    if float(n["sleep"])<48.0: return {"kind":"rest","label":"Resting","remaining":7.0,"duration":7.0}
    if float(n["hygiene"])<42.0 and hygiene_support: return {"kind":"wash","label":"Washing Up","remaining":5.0,"duration":5.0}
    if float(n["fun"])<58.0:
        var o:Array=[{"kind":"watch_fire","label":"Watching Fire","remaining":7.0,"duration":7.0},{"kind":"guitar","label":"Playing Guitar","remaining":9.0,"duration":9.0}]
        if pop>=2: o.append({"kind":"cards","label":"Playing Cards","remaining":8.0,"duration":8.0})
        if has_table and pop>=2: o.append({"kind":"cards","label":"Playing Cards","remaining":8.0,"duration":8.0})
        return o[rng.randi_range(0,o.size()-1)].duplicate(true)
    return {}

static func complete_activity(needs:Dictionary,fatigue:float,kind:String)->Dictionary:
    var n:=normalize_needs(needs); var f:=fatigue
    match kind:
        "rest": f=maxf(0.0,fatigue-14.0); n["sleep"]=clampf(100.0-f,0.0,100.0)
        "wash": n["hygiene"]=clampf(float(n["hygiene"])+48.0,0.0,100.0)
        "watch_fire": n["fun"]=clampf(float(n["fun"])+22.0,0.0,100.0); n["safety"]=clampf(float(n["safety"])+6.0,0.0,100.0)
        "cards": n["fun"]=clampf(float(n["fun"])+34.0,0.0,100.0)
        "guitar": n["fun"]=clampf(float(n["fun"])+30.0,0.0,100.0)
    return {"needs":n,"fatigue":f}

static func fatigue_gain(base_amount: float) -> float:
    return maxf(0.0, base_amount) * FATIGUE_GAIN_MULTIPLIER

static func idle_recovery_rates(has_cabin: bool, caretaker_leader: bool, has_communal_table: bool = false) -> Vector2:
    var fatigue_rate: float = 0.5 if has_cabin else (1.0 / 3.0)
    var stress_rate: float = (1.0 / 6.0) if has_cabin else 0.1
    if has_communal_table:
        stress_rate *= 1.25
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
