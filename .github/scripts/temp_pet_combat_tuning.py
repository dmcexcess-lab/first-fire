from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected 1 match, found {count}: {old[:100]!r}")
    p.write_text(text.replace(old, new, 1))


# Pet rules: affection-only retention; no food/water consumption.
path = "game/scripts/FFCampLifeRules.gd"
replace_once(path,
'''const MAX_PETS := 3
const PET_NEED_KEYS := ["hunger", "thirst", "affection", "cleanliness"]
const PET_NAMES := ["Mochi", "Scout", "Beans", "Pepper", "Lucky", "Ash", "Noodle", "Patch", "Sunny", "Rook"]''',
'''const MAX_PETS := 3
const PET_LEAVE_AFFECTION := 14.0
const PET_NEED_KEYS := ["affection"]
const PET_NAMES := ["Mochi", "Scout", "Beans", "Pepper", "Lucky", "Ash", "Noodle", "Patch", "Sunny", "Rook"]''')
replace_once(path,
'''static func default_pet_needs() -> Dictionary:
    return {"hunger":78.0,"thirst":82.0,"affection":70.0,"cleanliness":72.0}

static func normalize_pet_needs(value) -> Dictionary:
    var result:=default_pet_needs()
    var incoming:Dictionary=value.duplicate(true) if value is Dictionary else {}
    for key in PET_NEED_KEYS: result[key]=clampf(float(incoming.get(key,result[key])),0.0,100.0)
    return result

static func update_pet_needs(needs:Dictionary,delta:float)->Dictionary:
    var n:=normalize_pet_needs(needs)
    n["hunger"]=clampf(float(n["hunger"])-delta*0.07,0.0,100.0)
    n["thirst"]=clampf(float(n["thirst"])-delta*0.09,0.0,100.0)
    n["affection"]=clampf(float(n["affection"])-delta*0.04,0.0,100.0)
    n["cleanliness"]=clampf(float(n["cleanliness"])-delta*0.035,0.0,100.0)
    return n

static func apply_pet_care(needs:Dictionary,action:String)->Dictionary:
    var n:=normalize_pet_needs(needs)
    match action:
        "feed": n["hunger"]=clampf(float(n["hunger"])+42.0,0.0,100.0)
        "water": n["thirst"]=clampf(float(n["thirst"])+52.0,0.0,100.0)
        "play": n["affection"]=clampf(float(n["affection"])+38.0,0.0,100.0)
        "groom": n["cleanliness"]=clampf(float(n["cleanliness"])+46.0,0.0,100.0)
    return n

static func pet_mood(needs:Dictionary)->String:
    var n:=normalize_pet_needs(needs)
    var lowest:=100.0
    for key in PET_NEED_KEYS: lowest=minf(lowest,float(n[key]))
    if lowest < 18.0: return "DISTRESSED"
    if lowest < 35.0: return "NEEDS CARE"
    if lowest < 60.0: return "OKAY"
    if float(n["affection"]) >= 82.0: return "BONDED"
    return "CONTENT"

static func pet_can_forage(needs:Dictionary)->bool:
    var n:=normalize_pet_needs(needs)
    return float(n["hunger"])>=42.0 and float(n["thirst"])>=42.0 and float(n["affection"])>=48.0

static func pet_forage_resource(species:String,rng:RandomNumberGenerator)->String:
    var pool:Array = ["Wood","Cloth","Plastic","Raw Food"] if species=="Dog" else ["Cloth","Plastic","Raw Food","Raw Food"]
    return str(pool[rng.randi_range(0,pool.size()-1)])''',
'''static func default_pet_needs() -> Dictionary:
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
    return str(pool[rng.randi_range(0,pool.size()-1)])''')

# Camp orchestration: play/love only; daily guaranteed pet contribution; neglect causes departure.
path = "game/scripts/Game.gd"
replace_once(path,
'''func start_pet_care(sid:int,pet_id:int,action:String)->bool:
    var s:Variant=get_survivor(sid); var pet:Variant=get_pet(pet_id)
    if s==null or s["status"]!="Available" or pet==null: return false
    if action=="feed":
        if int(resources.get("Raw Food",0))>0: resources["Raw Food"]=int(resources.get("Raw Food",0))-1
        elif int(resources.get("Cooked Food",0))>0: resources["Cooked Food"]=int(resources.get("Cooked Food",0))-1
        else: toast_requested.emit("Pet feeding needs 1 Raw or Cooked Food."); return false
    elif action=="water":
        if int(resources.get("Clean Water",0))<=0: toast_requested.emit("Pet watering needs 1 Clean Water."); return false
        resources["Clean Water"]=int(resources.get("Clean Water",0))-1
    elif action not in ["play","groom"]: return false
    _clear_camp_activity(s); s["status"]="Pet Care"
    s["task"]={"kind":"pet_care","pet_id":pet_id,"action":action,"label":"%s %s" % [action.capitalize(),pet["name"]],"progress":0,"goal":3 if action in ["feed","water"] else 4}
    save_game(); state_changed.emit(); return true''',
'''func start_pet_care(sid:int,pet_id:int,action:String)->bool:
    var s:Variant=get_survivor(sid); var pet:Variant=get_pet(pet_id)
    if s==null or s["status"]!="Available" or pet==null: return false
    if action not in ["play","love"]: return false
    _clear_camp_activity(s); s["status"]="Pet Care"
    s["task"]={"kind":"pet_care","pet_id":pet_id,"action":action,"label":"%s %s" % [action.capitalize(),pet["name"]],"progress":0,"goal":4 if action=="play" else 3}
    save_game(); state_changed.emit(); return true''')
replace_once(path,
'''    for pet in pets:
        if CampLifeRules.pet_can_forage(pet.get("needs",{})) and rng.randf()<0.35:
            var pet_find:=CampLifeRules.pet_forage_resource(str(pet.get("species","Dog")),rng)
            resources[pet_find]=int(resources.get(pet_find,0))+1
            _add_history("Day %d — %s brought back 1 %s." % [day,pet.get("name","Pet"),pet_find])
''',
'''    var pets_to_leave:Array=[]
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
''')

# CAMP UI: affection-only pet loop.
path = "game/scripts/Main.gd"
replace_once(path,
'''        var n:Dictionary=Game.CampLifeRules.normalize_pet_needs(pet.get("needs",{}))
        v.add_child(_make_label("Food %.0f  Water %.0f  Bond %.0f  Clean %.0f" % [n["hunger"],n["thirst"],n["affection"],n["cleanliness"]],12))
        var buttons=GridContainer.new(); buttons.columns=2
        for action in ["feed","water","play","groom"]:
            var b=Button.new(); b.text=action.to_upper(); b.custom_minimum_size=Vector2(0,42); b.disabled=selected_worker_id<0; b.pressed.connect(Game.start_pet_care.bind(selected_worker_id,int(pet["id"]),action)); buttons.add_child(b)
        v.add_child(buttons); content_box.add_child(panel)''',
'''        var n:Dictionary=Game.CampLifeRules.normalize_pet_needs(pet.get("needs",{}))
        v.add_child(_make_label("Bond %.0f  •  Play with and love them or they may leave camp." % n["affection"],12))
        v.add_child(_make_label("Pets consume no food or water and each bring back 1 material or Raw Food per day.",11))
        var buttons=GridContainer.new(); buttons.columns=2
        for action in ["play","love"]:
            var b=Button.new(); b.text=action.to_upper(); b.custom_minimum_size=Vector2(0,42); b.disabled=selected_worker_id<0; b.pressed.connect(Game.start_pet_care.bind(selected_worker_id,int(pet["id"]),action)); buttons.add_child(b)
        v.add_child(buttons); content_box.add_child(panel)''')

# Movement: enforce large, explicit stance bands in the active three-stat layer.
path = "game/scripts/FFThreeStatRules.gd"
replace_once(path,
'''static func normal_move_cost(agility: int, base_cost: int) -> int:
    return maxi(38, int(round(float(base_cost) * (1.0 - minf(0.25, float(agility) * 0.025)))))

static func sprint_move_cost(agility: int, base_cost: int) -> int:
    var reduction := 0.35 + minf(0.25, float(agility) * 0.025)
    return maxi(24, int(round(float(base_cost) * (1.0 - reduction))))

static func stealth_move_cost(agility: int, base_cost: int) -> int:
    var surcharge := maxf(0.05, 0.30 - float(agility) * 0.025)
    return maxi(45, int(round(float(base_cost) * (1.0 + surcharge))))''',
'''static func normal_move_cost(agility: int, base_cost: int) -> int:
    var reduction:=minf(0.20,float(agility)*0.02)
    return maxi(52,int(round(float(base_cost)*(1.0-reduction))))

static func sprint_move_cost(agility: int, base_cost: int) -> int:
    var reduction:=0.38+minf(0.20,float(agility)*0.02)
    return maxi(28,int(round(float(base_cost)*(1.0-reduction))))

static func stealth_move_cost(agility: int, base_cost: int) -> int:
    var surcharge:=maxf(0.30,0.45-float(agility)*0.015)
    return maxi(78,int(round(float(base_cost)*(1.0+surcharge))))''')

# Base combat exposes one overridable movement-cost seam so backpedaling uses the active stance model too.
path = "game/scripts/FFCombat.gd"
replace_once(path,
'''func step_backward():
''',
'''func movement_action_cost(backwards: bool = false) -> int:
    return TacticalTime.movement_cost(player, backwards)

func step_backward():
''')
replace_once(path, '    commit_action(TacticalTime.movement_cost(player, true))\n', '    commit_action(movement_action_cost(true))\n')
replace_once(path, '    commit_action(TacticalTime.movement_cost(player, false))\n', '    commit_action(movement_action_cost(false))\n')

path = "game/scripts/FFCombatThreeStat.gd"
replace_once(path,
'''func step_backward():
    player["sprinting"] = false
    super.step_backward()

func try_move(dir: Vector2i):''',
'''func movement_action_cost(backwards: bool = false) -> int:
    var timing_actor:Dictionary=player.duplicate(false)
    timing_actor["crouched"]=false
    var base_cost:int=TimeThree.movement_cost(timing_actor,backwards)
    var agility:=int(player.get("skills",{}).get("Agility",0))
    if bool(player.get("sprinting",false)) and not backwards:
        return ThreeStatRules.sprint_move_cost(agility,base_cost)
    if bool(player.get("crouched",false)):
        return ThreeStatRules.stealth_move_cost(agility,base_cost)
    return ThreeStatRules.normal_move_cost(agility,base_cost)

func step_backward():
    player["sprinting"] = false
    super.step_backward()

func try_move(dir: Vector2i):''')
replace_once(path,
'''    var base_cost: int = TimeThree.movement_cost(player, false)
    var cost: int = ThreeStatRules.sprint_move_cost(agility, base_cost) if sprinting else (ThreeStatRules.stealth_move_cost(agility, base_cost) if player.crouched else ThreeStatRules.normal_move_cost(agility, base_cost))
    commit_action(cost)''',
'''    commit_action(movement_action_cost(false))''')

# Slight combat difficulty increase: infected connect a little more often and medium/heavy hits have a slightly higher ceiling.
path = "game/scripts/FFTacticalBalance.gd"
replace_once(path, '    var chance := 0.66 - float(agility) * 0.018\n', '    var chance := 0.70 - float(agility) * 0.018\n')
replace_once(path, '    return clampf(chance, 0.18, 0.82)\n', '    return clampf(chance, 0.20, 0.84)\n')
replace_once(path,
'''static func zombie_damage_range(mass: String) -> Vector2i:
    if mass == "LIGHT": return Vector2i(1, 4)
    if mass == "HEAVY": return Vector2i(3, 6)
    return Vector2i(2, 5)''',
'''static func zombie_damage_range(mass: String) -> Vector2i:
    if mass == "LIGHT": return Vector2i(1, 4)
    if mass == "HEAVY": return Vector2i(3, 7)
    return Vector2i(2, 6)''')

# Deterministic smoke coverage for movement separation, harder infected pressure, and affection-only pets.
path = "game/scripts/ci/FFArchitectureSmoke.gd"
replace_once(path,
'''    if not _check(ThreeStatRules.sprint_move_cost(6, 100) < ThreeStatRules.normal_move_cost(6, 100), "sprint is faster"): return
    if not _check(ThreeStatRules.stealth_noise(7) < ThreeStatRules.stealth_noise(1), "agility improves stealth"): return
    if not _check(ThreeStatRules.sprint_move_cost(7, 100) < ThreeStatRules.sprint_move_cost(1, 100), "agility improves sprint"): return''',
'''    for agility in [0, 5, 10]:
        var walk_cost:=ThreeStatRules.normal_move_cost(agility,100)
        var sprint_cost:=ThreeStatRules.sprint_move_cost(agility,100)
        var crouch_cost:=ThreeStatRules.stealth_move_cost(agility,100)
        if not _check(sprint_cost<=int(floor(float(walk_cost)*0.72)), "sprint materially faster at agility %d" % agility): return
        if not _check(crouch_cost>=int(ceil(float(walk_cost)*1.25)), "crouch materially slower at agility %d" % agility): return
    if not _check(ThreeStatRules.stealth_noise(7) < ThreeStatRules.stealth_noise(1), "agility improves stealth"): return
    if not _check(ThreeStatRules.sprint_move_cost(7, 100) < ThreeStatRules.sprint_move_cost(1, 100), "agility improves sprint"): return''')
replace_once(path,
'''    if not _check(TacticalBalance.zombie_hit_chance(sprinting) < TacticalBalance.zombie_hit_chance(actor), "sprint evasion"): return
    if not _check(TacticalBalance.shove_chance(actor, "LIGHT", 1) > TacticalBalance.shove_chance(actor, "HEAVY", 1), "mass resists shove"): return''',
'''    if not _check(TacticalBalance.zombie_hit_chance(sprinting) < TacticalBalance.zombie_hit_chance(actor), "sprint evasion"): return
    if not _check(TacticalBalance.zombie_hit_chance(actor) >= 0.70 and TacticalBalance.zombie_damage_range("HEAVY").y >= 7, "infected pressure tuning"): return
    if not _check(TacticalBalance.shove_chance(actor, "LIGHT", 1) > TacticalBalance.shove_chance(actor, "HEAVY", 1), "mass resists shove"): return''')
replace_once(path,
'''    if not _check(CampLifeRules.default_pet_needs().has("affection") and CampLifeRules.pet_can_forage({"hunger":80,"thirst":80,"affection":80,"cleanliness":50}), "pet care rules"): return''',
'''    var pet_rng:=RandomNumberGenerator.new(); pet_rng.seed=7
    var pet_find:=CampLifeRules.pet_forage_resource("Dog",pet_rng)
    if not _check(CampLifeRules.default_pet_needs().size()==1 and CampLifeRules.default_pet_needs().has("affection"), "affection-only pet needs"): return
    if not _check(CampLifeRules.pet_should_leave({"affection":10}) and not CampLifeRules.pet_should_leave({"affection":60}), "neglected pets leave"): return
    if not _check(pet_find in ["Wood","Scrap Metal","Hardware","Cloth","Plastic","Raw Food"], "daily pet material reward"): return''')

# Keep project docs aligned with the tuned behavior.
path = "README_CONTEXT.md"
replace_once(path,
'''`FFCampLifeRules.gd` owns six survivor needs plus pet needs, fire/maintenance tuning, autonomous idle recovery/downtime, and camp cadence. Productive work is player-directed: fire tending, cleaning, perimeter repair, crafting, building, garden work, pet care, and expeditions require assignment. Camp chores and pet care use short touch-first WORK interactions rather than completing as hidden autonomous behavior.''',
'''`FFCampLifeRules.gd` owns six survivor needs plus pet affection/retention/reward rules, fire/maintenance tuning, autonomous idle recovery/downtime, and camp cadence. Pets do not consume camp food or water: their Bond/Affection falls without attention, PLAY/LOVE assignments restore it, neglected pets can leave camp, and each pet that stays brings back exactly one random material or Raw Food per in-game day. Productive work is player-directed: fire tending, cleaning, perimeter repair, crafting, building, garden work, pet care, and expeditions require assignment. Camp chores and pet care use short touch-first WORK interactions rather than completing as hidden autonomous behavior.''')
replace_once(path,
'''- **Stealth** — Agility-driven quieter movement with positional stealth-attack opportunity; slower than normal movement.
- **Sprint** — Agility-driven faster movement, louder noise, and improved grab avoidance.''',
'''- **Stealth** — Agility-driven quieter crouched movement with positional stealth-attack opportunity; its tactical action cost is deliberately and materially slower than walking.
- **Sprint** — Agility-driven movement with a deliberately and materially lower action cost than walking, louder noise, and improved grab avoidance.''')

path = "ARCHITECTURE.md"
replace_once(path,
'''### `FFCampLifeRules.gd`
Pure camp-life tuning for survivor idle needs/moodlets, pet needs/care effects, fire and camp-maintenance decay, recovery/treatment modifiers, defense-building effects, and camp cadence. Eating/drinking, sleeping, and fun remain systemic idle behavior; productive chores, maintenance, crafting/building, pet care, and expeditions are assigned by the player through `Game.gd`.''',
'''### `FFCampLifeRules.gd`
Pure camp-life tuning for survivor idle needs/moodlets, pet affection/retention/daily-reward rules, fire and camp-maintenance decay, recovery/treatment modifiers, defense-building effects, and camp cadence. Pets never consume food or water; PLAY/LOVE restore affection, neglected pets can leave, and retained pets contribute exactly one random material or Raw Food each day. Eating/drinking, sleeping, and fun remain systemic idle behavior; productive chores, maintenance, crafting/building, pet care, and expeditions are assigned by the player through `Game.gd`.''')
replace_once(path,
'''`FFThreeStatRules.gd` owns the canonical stat catalog, weapon-hand classes, class combat profiles, and Agility movement/stealth/sprint math.''',
'''`FFThreeStatRules.gd` owns the canonical stat catalog, weapon-hand classes, class combat profiles, and Agility movement/stealth/sprint math. Active tactical movement preserves a strong crouch > walk > sprint action-cost separation across the full Agility range.''')

path = "ROADMAP.md"
replace_once(path,
'''- rescued dogs/cats as persistent Tamagotchi-style camp pets with hunger/thirst/bond/cleanliness care and small cared-for forage returns;''',
'''- rescued dogs/cats as persistent Tamagotchi-style camp pets whose affection is maintained through PLAY/LOVE assignments; pets consume no camp food/water, can leave if neglected, and each retained pet contributes exactly one random material or Raw Food per day;''')

path = "CHANGELOG.md"
p = Path(path)
text = p.read_text()
header = '''\n## Beta Candidate — Combat Movement & Pet Bond Tuning — 2026-09-12\n\n- Increased tactical danger modestly: infected hit chance is slightly higher and medium/heavy infected can roll one additional point of maximum damage.\n- Made active movement pacing explicit and regression-tested: crouch is materially slower than walking and sprint materially faster than walking across the full Agility range, including crouched backpedaling through the shared movement-cost seam.\n- Simplified pets to Bond/Affection only. Pets no longer consume Raw/Cooked Food or Clean Water; PLAY and LOVE are the only pet-care assignments.\n- Neglected pets can leave First Fire when affection falls too low. Every pet that remains contributes exactly one random material or Raw Food per in-game day.\n- Save schema remains 7; existing pet state is normalized down to its existing affection value.\n\n'''
if "## Beta Candidate — Combat Movement & Pet Bond Tuning — 2026-09-12" in text:
    raise SystemExit("CHANGELOG already patched")
text = header + text
text = text.replace("- Added persistent camp pets with Food, Water, Bond and Cleanliness needs plus small cared-for daily forage returns.", "- Added persistent camp pets; current tuning uses Bond/Affection as the pet retention meter, with no pet food/water consumption and one daily material-or-Raw-Food contribution per retained pet.")
text = text.replace("- Added touch-first pet care assignments (feed/water/play/groom) and manual camp chores (stoke fire, clean camp, repair perimeter). Assigned chores require repeated WORK taps, making camp maintenance an active minigame rather than hidden automation.", "- Added touch-first pet care assignments (PLAY/LOVE in current tuning) and manual camp chores (stoke fire, clean camp, repair perimeter). Assigned chores require repeated WORK taps, making camp maintenance an active minigame rather than hidden automation.")
p.write_text(text)

# Final source-level sanity checks before the workflow commits.
checks = {
    "game/scripts/FFCampLifeRules.gd": ["PET_NEED_KEYS := [\"affection\"]", "func pet_should_leave", '"love": n["affection"]'],
    "game/scripts/Game.gd": ["action not in [\"play\",\"love\"]", "var pets_to_leave:Array=[]"],
    "game/scripts/Main.gd": ["for action in [\"play\",\"love\"]", "Pets consume no food or water"],
    "game/scripts/FFCombat.gd": ["func movement_action_cost", "commit_action(movement_action_cost(true))"],
    "game/scripts/FFCombatThreeStat.gd": ["func movement_action_cost", "ThreeStatRules.stealth_move_cost"],
    "game/scripts/ci/FFArchitectureSmoke.gd": ["crouch materially slower", "neglected pets leave", "infected pressure tuning"],
}
for filename, needles in checks.items():
    body = Path(filename).read_text()
    for needle in needles:
        if needle not in body:
            raise SystemExit(f"missing postcondition {needle!r} in {filename}")

# Remove temporary writer machinery before committing the actual product change.
Path(".github/scripts/temp_pet_combat_tuning.py").unlink(missing_ok=True)
Path(".github/workflows/temp-pet-combat-tuning.yml").unlink(missing_ok=True)
