extends "res://scripts/Game.gd"

const ThreeStatRules = preload("res://scripts/FFThreeStatRules.gd")
const SaveCodecThree = preload("res://scripts/FFSaveCodec.gd")
const THREE_STAT_SAVE_SCHEMA := 8

func _generate_survivor(founder = false, preferred_background = ""):
    var s = {
        "id": next_survivor_id,
        "name": "",
        "background": "",
        "skills": ThreeStatRules.default_stats(),
        "skill_xp": ThreeStatRules.default_stats(),
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

    for stat in ThreeStatRules.STAT_NAMES:
        s["skills"][stat] = rng.randi_range(1, 3) if founder else rng.randi_range(0, 3)
    var bonuses := ThreeStatRules.background_bonus(str(s["background"]))
    for stat in ThreeStatRules.STAT_NAMES:
        s["skills"][stat] = mini(5, int(s["skills"][stat]) + int(bonuses.get(stat, 0)))
    if founder:
        for stat in ThreeStatRules.STAT_NAMES:
            s["skills"][stat] = clampi(int(s["skills"][stat]), 1, 4)

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
    var leadership := int(s.get("skills", {}).get("Leadership", 0))
    if leadership >= 5 or s.get("traits", []).has("Diplomatic"):
        return "Mediator"
    if s.get("traits", []).has("Protective"):
        return "Caretaker"
    if s.get("traits", []).has("Hard Worker"):
        return "Organizer"
    if s.get("traits", []).has("Suspicious") or s.get("traits", []).has("Cautious"):
        return "Watchful"
    if leadership >= 3:
        return "Provider"
    return "Pragmatist"

func add_skill_xp(s, skill, amount):
    if s == null or not ThreeStatRules.STAT_NAMES.has(str(skill)):
        return
    if not s["skills"].has(skill):
        return
    s["skill_xp"][skill] = int(s["skill_xp"].get(skill, 0)) + int(amount)
    var rank := int(s["skills"][skill])
    var threshold := 20 + rank * 15
    while rank < 10 and int(s["skill_xp"][skill]) >= threshold:
        s["skill_xp"][skill] = int(s["skill_xp"][skill]) - threshold
        rank += 1
        s["skills"][skill] = rank
        s["history"].append("Day %d — Reached %s %d." % [day, skill, rank])
        _add_history("Day %d — %s reached %s %d." % [day, s["name"], skill, rank])
        threshold = 20 + rank * 15

func skill_check(s, skill, dc, extra = 0):
    if s == null:
        return -1
    var resolved := str(skill)
    if resolved == "Social":
        resolved = "Leadership"
    elif resolved == "Survival":
        resolved = "Agility"
    elif not ThreeStatRules.STAT_NAMES.has(resolved):
        resolved = ""
    var effective := int(s.get("skills", {}).get(resolved, 0)) + int(extra)
    if float(s.get("fatigue", 0.0)) >= 80.0 and resolved in ["Combat", "Agility"]:
        effective -= 2
    elif float(s.get("fatigue", 0.0)) >= 60.0 and resolved in ["Combat", "Agility"]:
        effective -= 1
    if s.get("traits", []).has("Nervous") and float(s.get("stress", 0.0)) >= 50.0 and resolved in ["Combat", "Agility"]:
        effective -= 1
    if s.get("traits", []).has("Calm") and resolved == "Agility":
        effective += 1
    if s.get("traits", []).has("Diplomatic") and resolved == "Leadership":
        effective += 1
    var roll := rng.randi_range(1, 10) + effective
    if roll >= dc + 4: return 2
    if roll >= dc: return 1
    if roll >= dc - 2: return 0
    return -1

func treat_survivor(sid):
    var s: Variant = get_survivor(sid)
    if s == null or s["condition"] in ["Healthy", "Dead"] or s["status"] != "Available":
        return false
    _clear_camp_activity(s)
    var condition := str(s["condition"])
    if condition == "Hurt":
        if int(components.get("Sterile Dressing", 0)) <= 0:
            toast_requested.emit("You need a Sterile Dressing.")
            return false
        components["Sterile Dressing"] -= 1
        s["injury_remaining"] = minf(float(s["injury_remaining"]), 30.0)
        s["history"].append("Day %d — Treated a minor injury with a Sterile Dressing." % day)
        toast_requested.emit("%s treated — Sterile Dressing applied; about %.0fs recovery remains." % [s["name"], float(s["injury_remaining"])])
    else:
        var supply_name := "Sterile Dressing" if condition == "Wounded" else "Medicine"
        if condition == "Wounded":
            if int(components.get("Sterile Dressing", 0)) <= 0:
                toast_requested.emit("You need a Sterile Dressing.")
                return false
            components["Sterile Dressing"] -= 1
        else:
            if int(resources.get("Medicine", 0)) <= 0:
                toast_requested.emit("You need Medicine.")
                return false
            resources["Medicine"] -= 1
        s["status"] = "Recovering"
        var base := 45.0 if condition == "Wounded" else 120.0
        var treatment_time := base * CampLifeRules.treatment_time_multiplier(bool(buildings.get("Infirmary", false)))
        s["task"] = {"kind": "treatment", "remaining": treatment_time, "duration": base, "target": sid}
        s["history"].append("Day %d — Began treatment for %s injuries with %s." % [day, condition.to_lower(), supply_name])
        toast_requested.emit("%s is being treated with %s — about %.0fs of camp time." % [s["name"], supply_name, treatment_time])
    save_game()
    state_changed.emit()
    return true

func _work_duration(s, base):
    var reduction := 0.0
    if s["traits"].has("Hard Worker"):
        reduction += 0.10
    elif s["traits"].has("Lazy"):
        reduction -= 0.10
    var leader: Variant = get_survivor(leader_id)
    if leader != null and leader["leader_ability"] == "Organizer":
        reduction += 0.10
    return maxf(float(base) * 0.55, float(base) * (1.0 - reduction))

func start_expedition(primary_id, zone):
    if not unlocked_zones.has(zone) or not D.ZONES.has(zone):
        return false
    var s: Variant = get_survivor(primary_id)
    if s == null or s["status"] != "Available" or s["condition"] == "Dead":
        return false
    _clear_camp_activity(s)
    if zone in ["Commercial Fringe", "Industrial Edge"] and float(s["fatigue"]) >= 95.0:
        toast_requested.emit("%s is too exhausted for that trip." % s["name"])
        return false
    if zone in ["Commercial Fringe", "Industrial Edge"] and s["condition"] == "Wounded":
        toast_requested.emit("%s is too badly wounded for that trip." % s["name"])
        return false

    var party_ids := [int(primary_id)]
    var recruit_eligible := zone != "Camp Perimeter"
    if recruit_eligible:
        eligible_expeditions_since_recruit += 1
    var agility := int(s.get("skills", {}).get("Agility", 0))
    var duration := ExpeditionRules.travel_duration(float(D.ZONES[zone]["duration"]), agility)
    var force_recruit := ExpeditionRules.should_force_recruit(population(), shelter_capacity(), MAX_POPULATION, eligible_expeditions_since_recruit, recruit_eligible)
    var event_key := ""
    var combat_kind := ""
    var tactical_drought := int(flags.get("tactical_drought", 0))
    if recruit_eligible and flags.has("injured_stranger_return_after"):
        flags["injured_stranger_return_after"] = int(flags["injured_stranger_return_after"]) - 1
        if int(flags["injured_stranger_return_after"]) <= 0:
            flags.erase("injured_stranger_return_after")
            event_key = "injured_stranger_return"
            eligible_expeditions_since_recruit = 0
    if event_key == "" and recruit_eligible and flags.has("dog_return_after"):
        flags["dog_return_after"] = int(flags["dog_return_after"]) - 1
        if int(flags["dog_return_after"]) <= 0:
            flags.erase("dog_return_after")
            event_key = "dog_return"
    if event_key == "" and force_recruit:
        eligible_expeditions_since_recruit = 0
        combat_kind = "rescue"
        flags["tactical_drought"] = 0
    elif event_key == "" and ExpeditionRules.should_force_tactical(tactical_drought):
        combat_kind = _pick_tactical_kind(zone)
        flags["tactical_drought"] = 0
    elif event_key == "" and ExpeditionRules.should_trigger_tactical_event(str(zone), rng):
        combat_kind = _pick_tactical_kind(zone)
        flags["tactical_drought"] = 0
    elif event_key == "" and rng.randf() < float(D.ZONES[zone]["event_chance"]):
        event_key = _select_field_event(zone)
        flags["tactical_drought"] = tactical_drought + 1
    elif event_key == "":
        flags["tactical_drought"] = tactical_drought + 1
    var exp = {
        "id": next_expedition_id, "survivor_ids": party_ids, "zone": zone,
        "duration": duration, "remaining": duration, "state": "traveling",
        "event_key": event_key, "event_triggered": false,
        "event_trigger_remaining": duration * rng.randf_range(0.25, 0.65),
        "combat_kind": combat_kind, "combat_triggered": false,
        "combat_trigger_remaining": duration * rng.randf_range(0.25, 0.65),
        "tactical_resolved": false, "special_site": ""
    }
    next_expedition_id += 1
    expeditions.append(exp)
    s["status"] = "Expedition"
    s["task"] = {"expedition_id": exp["id"]}
    recent_expedition_ids.append(primary_id)
    if recent_expedition_ids.size() > 4:
        recent_expedition_ids.pop_front()
    save_game()
    state_changed.emit()
    return true

func _grant_tactical_explore_reward(exp, lead, searches_completed: int):
    var count := TacticalBalance.explore_reward_rolls(searches_completed, 0)
    var found := {}
    for i in range(count):
        var key = _weighted_loot_pick(exp["zone"])
        resources[key] = int(resources.get(key, 0)) + 1
        found[key] = int(found.get(key, 0)) + 1
    var bits := []
    for key in found.keys():
        bits.append("+%d %s" % [found[key], key])
    return ", ".join(bits)

func _resolve_routine_danger(exp, log_bits):
    var zone = exp["zone"]
    var chance = {"Camp Perimeter": 0.0, "Nearby Streets": 0.05, "Residential Blocks": 0.15, "Commercial Fringe": 0.25, "Industrial Edge": 0.35}[zone]
    if rng.randf() >= chance:
        return
    var target: Variant = get_survivor(exp["survivor_ids"][0])
    if target == null or target["condition"] == "Dead":
        return
    var dc = {"Nearby Streets": 8, "Residential Blocks": 10, "Commercial Fringe": 13, "Industrial Edge": 15}.get(zone, 7)
    var avoid_result := skill_check(target, "Agility", dc)
    if avoid_result >= 1:
        log_bits.append("Avoided trouble")
        add_skill_xp(target, "Agility", 3)
        return
    var combat_result := skill_check(target, "Combat", dc, _equipment_combat_bonus(target))
    add_skill_xp(target, "Combat", rng.randi_range(4, 8))
    if combat_result >= 1:
        log_bits.append("Fought off danger")
    elif zone == "Nearby Streets": _apply_injury(target, "Hurt")
    elif zone == "Residential Blocks": _apply_injury(target, "Wounded" if combat_result < 0 else "Hurt")
    elif zone == "Commercial Fringe": _apply_injury(target, "Critical" if combat_result < 0 else "Wounded")
    elif zone == "Industrial Edge": _apply_injury(target, "Critical" if combat_result < 1 else "Wounded")

func _roll_loot(exp, party):
    var zone = exp["zone"]
    var target_items = _loot_item_target(zone)
    var pressure := int(zone_pressure.get(zone, 0))
    if pressure >= 85: target_items = maxi(0, target_items - 2)
    elif pressure >= 60: target_items = maxi(0, target_items - 1)
    var zone_cap := ExpeditionRules.zone_cap(str(zone))
    var capacity := 0
    for s in party: capacity += _pack_capacity(s)
    target_items = mini(target_items, mini(int(zone_cap), capacity))
    var loot := {}
    for i in range(target_items):
        var key = _weighted_loot_pick(zone)
        loot[key] = int(loot.get(key, 0)) + 1
    var leader: Variant = get_survivor(leader_id)
    if leader != null and int(leader.get("skills", {}).get("Leadership", 0)) >= 5 and target_items < capacity and target_items < int(zone_cap) and rng.randf() < 0.15:
        var bonus_key = _weighted_loot_pick(zone)
        loot[bonus_key] = int(loot.get(bonus_key, 0)) + 1
    return loot

func _roll_gear(exp, party):
    var zone = exp["zone"]
    var chance = {"Camp Perimeter": 0.01, "Nearby Streets": 0.04, "Residential Blocks": 0.10, "Commercial Fringe": 0.16, "Industrial Edge": 0.18}[zone]
    if int(zone_pressure.get(zone, 0)) >= 60:
        chance *= 0.65
    if rng.randf() > chance:
        return ""
    var pool = []
    if zone == "Camp Perimeter": pool = ["Work Gloves"]
    elif zone == "Nearby Streets": pool = ["Kitchen Knife", "Work Gloves", "Heavy Boots", "School Backpack", "Glow Stick"]
    elif zone == "Residential Blocks": pool = ["Kitchen Knife", "Baseball Bat", "Flashlight", "Lantern", "Glow Stick", "Screwdriver Set", "First Aid Kit", "School Backpack", "Leather Jacket"]
    elif zone == "Commercial Fringe": pool = ["Crowbar", "Hatchet", "Flashlight", "Headlamp", "Lantern", "Road Flare", "Bolt Cutters", "Toolbox", "First Aid Kit", "Pistol", "Hiking Pack", "Leather Jacket"]
    else: pool = ["Crowbar", "Hatchet", "Headlamp", "Glow Stick", "Road Flare", "Bolt Cutters", "Toolbox", "Pistol", "Shotgun", "Hiking Pack", "Heavy Boots", "Work Jacket"]
    return pool[rng.randi_range(0, pool.size() - 1)]

func _apply_injury(s, severity):
    if s == null or s["condition"] == "Dead":
        return
    if severity == "Hurt":
        if s["condition"] == "Healthy":
            s["condition"] = "Hurt"; s["injury_remaining"] = 60.0
    elif severity == "Wounded":
        if s["condition"] == "Critical": return
        s["condition"] = "Wounded"; s["injury_remaining"] = 180.0
    elif severity == "Critical":
        if s["condition"] == "Critical":
            _kill_survivor(s, "died from accumulated injuries"); return
        s["condition"] = "Critical"; s["injury_remaining"] = 0.0
    s["stress"] = minf(100.0, float(s["stress"]) + (5.0 if severity == "Hurt" else 12.0))
    s["history"].append("Day %d — Was %s." % [day, severity.to_lower()])

func _run_vote(candidate_ids, endorsement):
    var totals := {}
    for cid in candidate_ids: totals[str(cid)] = 0
    for voter in survivors:
        if voter["condition"] == "Dead": continue
        var best_id = candidate_ids[0]
        var best_score = -99999
        for cid in candidate_ids:
            var c: Variant = get_survivor(cid)
            if c == null: continue
            var score := int(voter["relationships"].get(str(cid), 0)) + int(c.get("skills", {}).get("Leadership", 0)) * 6 + int(c.get("reputation", 0))
            if int(voter["id"]) == int(cid): score += 50
            if int(cid) == int(endorsement): score += 15
            score += rng.randi_range(-8, 8)
            if score > best_score:
                best_score = score; best_id = cid
        totals[str(best_id)] = int(totals.get(str(best_id), 0)) + 1
    var winner = candidate_ids[0]
    for cid in candidate_ids:
        if int(totals[str(cid)]) > int(totals[str(winner)]): winner = cid
        elif int(totals[str(cid)]) == int(totals[str(winner)]) and _candidate_standing(get_survivor(cid)) > _candidate_standing(get_survivor(winner)): winner = cid
    return int(winner)

func save_game():
    if not initialized and survivors.is_empty():
        return
    var data = {
        "version": "0.10.0-beta-candidate", "save_schema": THREE_STAT_SAVE_SCHEMA,
        "day": day, "day_elapsed": day_elapsed, "resources": resources, "components": components, "inventory_gear": inventory_gear,
        "buildings": buildings, "survivors": survivors, "next_survivor_id": next_survivor_id, "next_expedition_id": next_expedition_id,
        "expeditions": expeditions, "zone_successes": zone_successes, "zone_pressure": zone_pressure, "unlocked_zones": unlocked_zones,
        "special_sites": special_sites, "history": history, "flags": flags, "policies": policies, "current_event": current_event,
        "event_queue": event_queue, "current_combat": current_combat, "coordinator_id": coordinator_id, "leader_id": leader_id,
        "leadership_form": leadership_form, "eligible_expeditions_since_recruit": eligible_expeditions_since_recruit,
        "food_shortage_days": food_shortage_days, "water_shortage_days": water_shortage_days, "garden_tended_day": garden_tended_day,
        "game_over": game_over, "settlement_mature": settlement_mature, "settlement_mature_shown": settlement_mature_shown,
        "recent_expedition_ids": recent_expedition_ids, "fire_level": fire_level
    }
    SaveCodecThree.write_json(SAVE_PATH, data)

func load_game():
    var parsed = SaveCodecThree.read_json(SAVE_PATH)
    if parsed == null:
        new_game(); return
    if not SaveCodecThree.is_compatible(parsed, THREE_STAT_SAVE_SCHEMA):
        SaveCodecThree.invalidate(SAVE_PATH)
        save_existed_on_boot = false
        new_game(); return
    day = int(parsed.get("day", 1)); day_elapsed = float(parsed.get("day_elapsed", 0.0))
    resources = parsed.get("resources", D.STARTING_RESOURCES.duplicate(true)); components = parsed.get("components", {})
    inventory_gear = parsed.get("inventory_gear", []); buildings = parsed.get("buildings", {}); survivors = parsed.get("survivors", [])
    next_survivor_id = int(parsed.get("next_survivor_id", 1)); next_expedition_id = int(parsed.get("next_expedition_id", 1))
    expeditions = parsed.get("expeditions", []); zone_successes = parsed.get("zone_successes", {}); zone_pressure = parsed.get("zone_pressure", {})
    unlocked_zones = parsed.get("unlocked_zones", ["Camp Perimeter"]); special_sites = parsed.get("special_sites", {})
    history = parsed.get("history", []); flags = parsed.get("flags", {}); policies = parsed.get("policies", {})
    current_event = parsed.get("current_event", {}); event_queue = parsed.get("event_queue", []); current_combat = parsed.get("current_combat", {})
    coordinator_id = int(parsed.get("coordinator_id", -1)); leader_id = int(parsed.get("leader_id", -1)); leadership_form = parsed.get("leadership_form", "None")
    eligible_expeditions_since_recruit = int(parsed.get("eligible_expeditions_since_recruit", 0)); food_shortage_days = int(parsed.get("food_shortage_days", 0)); water_shortage_days = int(parsed.get("water_shortage_days", 0))
    garden_tended_day = int(parsed.get("garden_tended_day", -1)); game_over = bool(parsed.get("game_over", false)); settlement_mature = bool(parsed.get("settlement_mature", false)); settlement_mature_shown = bool(parsed.get("settlement_mature_shown", false))
    recent_expedition_ids = parsed.get("recent_expedition_ids", []); fire_level = clampf(float(parsed.get("fire_level", CampLifeRules.FIRE_START_LEVEL)), 0.0, 100.0)
    for s in survivors:
        s["skills"] = ThreeStatRules.normalize_stats(s.get("skills", {}))
        var xp := ThreeStatRules.default_stats(); var old_xp: Dictionary = s.get("skill_xp", {}) if s.get("skill_xp", {}) is Dictionary else {}
        for stat in ThreeStatRules.STAT_NAMES: xp[stat] = maxi(0, int(old_xp.get(stat, 0)))
        s["skill_xp"] = xp
        s["needs"] = CampLifeRules.normalize_needs(s.get("needs", {}))
        if not s.has("camp_activity"): s["camp_activity"] = {}
    sim_paused = true
    state_changed.emit()
