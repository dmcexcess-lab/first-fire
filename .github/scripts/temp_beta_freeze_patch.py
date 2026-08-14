from pathlib import Path
import re

ROOT = Path('.')

def text(path: str) -> str:
    return (ROOT / path).read_text()

def write(path: str, content: str) -> None:
    p = ROOT / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(content)

def replace_once(path: str, old: str, new: str) -> None:
    src = text(path)
    count = src.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one match, found {count}: {old[:120]!r}')
    write(path, src.replace(old, new, 1))

def regex_once(path: str, pattern: str, replacement: str) -> None:
    src = text(path)
    out, count = re.subn(pattern, replacement, src, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f'{path}: regex expected one match, found {count}: {pattern[:120]!r}')
    write(path, out)

# ---------------------------------------------------------------------------
# Final camp-life tuning owner.
# ---------------------------------------------------------------------------
write('game/scripts/FFCampLifeRules.gd', r'''extends RefCounted
class_name FFCampLifeRules

# Final feature-freeze camp cadence/tuning. Social selection lives in
# FFCampSocial; presentation lives in FFCampView.
const CAMP_EVENT_INTERVAL := 45.0
const NEW_GAME_EVENT_COOLDOWN := 20.0
const FATIGUE_GAIN_MULTIPLIER := 2.0
const CAMP_CHATTER_MIN_SECONDS := 7.0
const CAMP_CHATTER_MAX_SECONDS := 14.0

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
''')

# ---------------------------------------------------------------------------
# Finished camp-social owner: relationships, political standing and lightweight
# autonomous chatter. Chatter returns consequences; Game applies them.
# ---------------------------------------------------------------------------
write('game/scripts/FFCampSocial.gd', r'''extends RefCounted
class_name FFCampSocial

static func relationship_label(value: int) -> String:
    if value >= 60: return "Close"
    if value >= 25: return "Friendly"
    if value <= -60: return "Hostile"
    if value <= -25: return "Tense"
    return "Neutral"

static func change_relationship(a: Dictionary, b: Dictionary, amount: int, leader_id: int) -> void:
    if a.is_empty() or b.is_empty():
        return
    var key := str(b["id"])
    var adjusted := float(amount)
    if amount > 0 and a.get("traits", []).has("Friendly"):
        adjusted *= 1.25
    if amount > 0 and a.get("traits", []).has("Loner"):
        adjusted *= 0.5
    if amount < 0 and leader_id == int(a["id"]) and str(a.get("leader_ability", "")) == "Mediator":
        adjusted *= 0.75
    a["relationships"][key] = clampi(int(a["relationships"].get(key, 0)) + int(round(adjusted)), -100, 100)

static func camp_survivors(survivors: Array) -> Array:
    var result: Array = []
    for survivor_value in survivors:
        var survivor: Dictionary = survivor_value
        if str(survivor.get("condition", "Dead")) == "Dead":
            continue
        var status := str(survivor.get("status", "Available"))
        if status in ["Expedition", "Pending Expedition Event", "Tactical Encounter"]:
            continue
        var task: Dictionary = survivor.get("task", {})
        if task.has("expedition_id"):
            continue
        result.append(survivor)
    return result

static func pick_pair(survivors: Array, rng: RandomNumberGenerator) -> Array:
    var camp := camp_survivors(survivors)
    if camp.size() < 2:
        return []
    var first := rng.randi_range(0, camp.size() - 1)
    var second := rng.randi_range(0, camp.size() - 2)
    if second >= first:
        second += 1
    return [camp[first], camp[second]]

static func tense_pair(survivors: Array) -> Array:
    for a in survivors:
        if a["condition"] == "Dead": continue
        for b in survivors:
            if b["condition"] == "Dead" or int(a["id"]) >= int(b["id"]): continue
            if int(a["relationships"].get(str(b["id"]), 0)) <= -25 or int(b["relationships"].get(str(a["id"]), 0)) <= -25:
                return [a, b]
    return []

static func high_stress_survivor(survivors: Array) -> Variant:
    for survivor in survivors:
        if survivor["condition"] != "Dead" and (float(survivor["stress"]) >= 80.0 or float(survivor["fatigue"]) >= 85.0):
            return survivor
    return null

static func highest_stress_survivor(survivors: Array) -> Variant:
    var best: Variant = null
    for survivor in survivors:
        if survivor["condition"] == "Dead": continue
        if best == null or float(survivor["stress"]) > float(best["stress"]):
            best = survivor
    return best

static func highest_skill_survivor(survivors: Array, skill: String) -> Variant:
    var best: Variant = null
    for survivor in survivors:
        if survivor["condition"] == "Dead": continue
        if best == null or int(survivor["skills"].get(skill, 0)) > int(best["skills"].get(skill, 0)):
            best = survivor
    return best

static func candidate_standing(candidate: Dictionary, survivors: Array) -> int:
    var rel_sum := 0
    var rel_count := 0
    for other in survivors:
        if other["condition"] == "Dead" or int(other["id"]) == int(candidate["id"]): continue
        rel_sum += int(other["relationships"].get(str(candidate["id"]), 0))
        rel_count += 1
    var average: float = float(rel_sum) / float(rel_count) if rel_count > 0 else 0.0
    return int(candidate["skills"].get("Social", 0)) * 6 + int(candidate.get("reputation", 0)) + int(clampf(average * 0.5, -25.0, 25.0))

static func top_candidates(survivors: Array) -> Array:
    var living: Array = []
    for survivor in survivors:
        if survivor["condition"] != "Dead":
            living.append(survivor)
    living.sort_custom(func(a, b): return candidate_standing(a, survivors) > candidate_standing(b, survivors))
    if living.size() >= 2:
        return [living[0], living[1]]
    return living

static func strongest_challenger(survivors: Array, incumbent_id: int) -> Variant:
    var living: Array = []
    for survivor in survivors:
        if survivor["condition"] != "Dead" and int(survivor["id"]) != incumbent_id:
            living.append(survivor)
    living.sort_custom(func(a, b): return candidate_standing(a, survivors) > candidate_standing(b, survivors))
    return living[0] if not living.is_empty() else null

static func leader_support_score(leader: Variant, survivors: Array) -> float:
    if leader == null:
        return 0.0
    var total := 0.0
    var count := 0
    for survivor in survivors:
        if survivor["condition"] == "Dead" or int(survivor["id"]) == int(leader["id"]):
            continue
        total += int(survivor["relationships"].get(str(leader["id"]), 0)) + int(survivor.get("leader_support", 0))
        count += 1
    return total / float(count) if count > 0 else 0.0

static func _first_name(survivor: Dictionary) -> String:
    return str(survivor.get("name", "Survivor")).get_slice(" ", 0)

static func _find_survivor(survivors: Array, sid: int) -> Variant:
    for survivor in survivors:
        if int(survivor.get("id", -1)) == sid and survivor.get("condition", "Dead") != "Dead":
            return survivor
    return null

static func roll_chatter(survivors: Array, leader_id: int, coordinator_id: int, food_shortage_days: int, water_shortage_days: int, policies: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
    var pair := pick_pair(survivors, rng)
    if pair.size() != 2:
        return {}
    var speaker: Dictionary = pair[0]
    var listener: Dictionary = pair[1]
    var rel := int(speaker["relationships"].get(str(listener["id"]), 0))
    var reverse_rel := int(listener["relationships"].get(str(speaker["id"]), 0))
    var text := "You holding up?"
    var tone := "neutral"
    var rel_delta := 0
    var reverse_delta := 0
    var speaker_stress_delta := 0.0
    var listener_stress_delta := 0.0
    var decided := false

    if water_shortage_days > 0 and rng.randf() < 0.35:
        text = "We need water before anything else."
        tone = "worry"
        decided = true
    elif food_shortage_days > 0 and rng.randf() < 0.35:
        text = "Food's getting too thin."
        tone = "worry"
        decided = true

    var active_leader_id := leader_id if leader_id != -1 else coordinator_id
    var leader: Variant = _find_survivor(survivors, active_leader_id) if active_leader_id != -1 else null
    if not decided and leader != null and int(speaker["id"]) != active_leader_id and rng.randf() < 0.40:
        var speaker_support := int(speaker["relationships"].get(str(active_leader_id), 0)) + int(speaker.get("leader_support", 0))
        var listener_support := int(listener["relationships"].get(str(active_leader_id), 0)) + int(listener.get("leader_support", 0))
        if speaker_support <= -20:
            text = "I don't trust %s's calls." % _first_name(leader)
            tone = "politics"
            rel_delta = 1 if listener_support <= -10 else -1
            reverse_delta = rel_delta
            decided = true
        elif speaker_support >= 20:
            text = "%s's keeping us together." % _first_name(leader)
            tone = "politics"
            rel_delta = 1 if listener_support >= 5 else -1
            reverse_delta = rel_delta
            decided = true

    if not decided and rel <= -60:
        text = "Stay out of my way."
        tone = "hostile"
        rel_delta = -1
        reverse_delta = -1 if reverse_rel <= -25 else 0
        speaker_stress_delta = 1.0
        decided = true
    elif not decided and rel <= -25:
        text = "I'm still not over that."
        tone = "tense"
        rel_delta = -1 if rng.randf() < 0.45 else 0
        decided = true
    elif not decided and rel >= 60:
        text = "Good to have you here."
        tone = "warm"
        rel_delta = 1
        reverse_delta = 1
        speaker_stress_delta = -1.5
        listener_stress_delta = -1.0
        decided = true
    elif not decided and rel >= 25:
        text = "Need a hand with anything?"
        tone = "friendly"
        rel_delta = 1 if rng.randf() < 0.40 else 0
        reverse_delta = rel_delta
        speaker_stress_delta = -0.5
        decided = true

    if not decided and str(policies.get("Expedition Duty", "")) == "Rotation" and rng.randf() < 0.25:
        text = "Rotation's fair. Nobody gets burned out."
        tone = "politics"
        decided = true
    if not decided and speaker.get("traits", []).has("Optimistic"):
        text = "We'll make this place work."
        tone = "warm"
        listener_stress_delta = -0.5
        decided = true
    if not decided and speaker.get("traits", []).has("Pessimistic"):
        text = "Don't get too comfortable."
        tone = "worry"
        decided = true
    if not decided and speaker.get("traits", []).has("Protective"):
        text = "You take a break. I'll keep an eye out."
        tone = "friendly"
        listener_stress_delta = -1.0
        decided = true
    if not decided and float(listener.get("stress", 0.0)) >= 65.0:
        text = "You look rough. Sit down a minute."
        tone = "friendly"
        listener_stress_delta = -1.0
        decided = true

    return {
        "speaker_id": int(speaker["id"]),
        "listener_id": int(listener["id"]),
        "speaker_name": _first_name(speaker),
        "listener_name": _first_name(listener),
        "text": text,
        "tone": tone,
        "relationship_delta": rel_delta,
        "reverse_delta": reverse_delta,
        "speaker_stress_delta": speaker_stress_delta,
        "listener_stress_delta": listener_stress_delta,
    }
''')

# ---------------------------------------------------------------------------
# Expedition rules: single-survivor expeditions are final. No vehicle seam.
# ---------------------------------------------------------------------------
write('game/scripts/FFExpeditionRules.gd', r'''extends RefCounted
class_name FFExpeditionRules

const TACTICAL_EVENT_CHANCE := {
    "Camp Perimeter": 0.65,
    "Nearby Streets": 0.70,
    "Residential Blocks": 0.75,
    "Commercial Fringe": 0.82,
    "Industrial Edge": 0.90,
}
const TACTICAL_DROUGHT_LIMIT := 2
const ZONE_CAPS := {
    "Camp Perimeter": 3,
    "Nearby Streets": 4,
    "Residential Blocks": 5,
    "Commercial Fringe": 6,
    "Industrial Edge": 7,
}

static func travel_duration(base_duration: float, survival_skill: float) -> float:
    var reduction: float = minf(0.20, survival_skill * 0.025)
    return base_duration * (1.0 - reduction)

static func should_force_recruit(population: int, shelter_capacity: int, max_population: int, eligible_count: int, recruit_eligible: bool) -> bool:
    if not recruit_eligible or population >= mini(shelter_capacity, max_population):
        return false
    if population <= 1:
        return eligible_count >= 4
    if population < 5:
        return eligible_count >= 6
    if population < 10:
        return eligible_count >= 8
    if population < 15:
        return eligible_count >= 10
    return eligible_count >= 12

static func tactical_event_chance(zone: String) -> float:
    return float(TACTICAL_EVENT_CHANCE.get(zone, 0.0))

static func should_trigger_tactical_event(zone: String, rng: RandomNumberGenerator) -> bool:
    return rng.randf() < tactical_event_chance(zone)

static func should_force_tactical(drought_count: int) -> bool:
    return drought_count >= TACTICAL_DROUGHT_LIMIT

static func zone_cap(zone: String) -> int:
    return int(ZONE_CAPS.get(zone, 3))

static func loot_item_target(zone: String, rng: RandomNumberGenerator) -> int:
    var r: float = rng.randf()
    if zone == "Camp Perimeter":
        if r < 0.25: return 0
        if r < 0.70: return 1
        if r < 0.95: return 2
        return 3
    if zone == "Nearby Streets":
        if r < 0.15: return 0
        if r < 0.45: return 1
        if r < 0.80: return 2
        if r < 0.95: return 3
        return 4
    if zone == "Residential Blocks":
        if r < 0.08: return 0
        if r < 0.30: return 1
        if r < 0.60: return 2
        if r < 0.85: return 3
        if r < 0.97: return 4
        return 5
    if zone == "Commercial Fringe":
        if r < 0.04: return 0
        if r < 0.20: return 1
        if r < 0.45: return 2
        if r < 0.70: return 3
        if r < 0.88: return 4
        if r < 0.97: return 5
        return 6
    if r < 0.02: return 0
    if r < 0.12: return 1
    if r < 0.32: return 2
    if r < 0.57: return 3
    if r < 0.77: return 4
    if r < 0.89: return 5
    if r < 0.97: return 6
    return 7
''')

# ---------------------------------------------------------------------------
# Complete crafting coverage + final building tree.
# ---------------------------------------------------------------------------
ffdata = text('game/scripts/FFData.gd')
new_content = r'''const RECIPES := {
    "Fire Pit": [
        {"id": "Cook Food", "time": 3.0, "cost": {"Raw Food": 1}, "gives_resource": {"Cooked Food": 2}},
        {"id": "Boil Water", "time": 3.0, "cost": {"Dirty Water": 1}, "gives_resource": {"Clean Water": 2}},
        {"id": "Sterile Dressing", "time": 5.0, "cost": {"Cloth": 1, "Clean Water": 1}, "gives_component": {"Sterile Dressing": 1}},
    ],
    "Workbench": [
        {"id": "Utility Knife", "time": 6.0, "cost": {"Scrap Metal": 1, "Cloth": 1}, "gives_gear": "Utility Knife"},
        {"id": "Kitchen Knife", "time": 6.0, "cost": {"Scrap Metal": 1, "Plastic": 1}, "gives_gear": "Kitchen Knife"},
        {"id": "Wooden Club", "time": 6.0, "cost": {"Wood": 2}, "gives_gear": "Wooden Club"},
        {"id": "Baseball Bat", "time": 8.0, "cost": {"Wood": 3}, "gives_gear": "Baseball Bat"},
        {"id": "Hammer", "time": 8.0, "cost": {"Wood": 1, "Scrap Metal": 1}, "gives_gear": "Hammer"},
        {"id": "Improvised Spear", "time": 8.0, "cost": {"Wood": 2, "Scrap Metal": 1}, "gives_gear": "Improvised Spear"},
        {"id": "Crowbar", "time": 9.0, "cost": {"Scrap Metal": 2, "Hardware": 1}, "gives_gear": "Crowbar"},
        {"id": "Hatchet", "time": 10.0, "cost": {"Wood": 1, "Scrap Metal": 2, "Hardware": 1}, "gives_gear": "Hatchet"},
        {"id": "Pistol", "time": 18.0, "cost": {"Scrap Metal": 4, "Hardware": 3, "Plastic": 1}, "requires": ["Armory"], "gives_gear": "Pistol"},
        {"id": "Shotgun", "time": 24.0, "cost": {"Scrap Metal": 6, "Hardware": 4, "Wood": 2}, "requires": ["Armory"], "gives_gear": "Shotgun"},
        {"id": "Flashlight", "time": 7.0, "cost": {"Plastic": 1, "Scrap Metal": 1, "Hardware": 1}, "gives_gear": "Flashlight"},
        {"id": "Headlamp", "time": 8.0, "cost": {"Plastic": 1, "Scrap Metal": 1, "Hardware": 1}, "gives_gear": "Headlamp"},
        {"id": "Lantern", "time": 9.0, "cost": {"Scrap Metal": 1, "Hardware": 2}, "gives_gear": "Lantern"},
        {"id": "Glow Stick", "time": 5.0, "cost": {"Plastic": 1, "Cloth": 1}, "gives_gear": "Glow Stick"},
        {"id": "Road Flare", "time": 6.0, "cost": {"Plastic": 1, "Cloth": 1, "Scrap Metal": 1}, "gives_gear": "Road Flare"},
        {"id": "Screwdriver Set", "time": 7.0, "cost": {"Scrap Metal": 1, "Hardware": 1}, "gives_gear": "Screwdriver Set"},
        {"id": "Bolt Cutters", "time": 11.0, "cost": {"Scrap Metal": 3, "Hardware": 2}, "gives_gear": "Bolt Cutters"},
        {"id": "Toolbox", "time": 12.0, "cost": {"Scrap Metal": 2, "Hardware": 3}, "gives_gear": "Toolbox"},
        {"id": "First Aid Kit", "time": 10.0, "cost": {"Cloth": 2, "Plastic": 1, "Medicine": 1}, "gives_gear": "First Aid Kit"},
        {"id": "Pry Tool", "time": 8.0, "cost": {"Scrap Metal": 1, "Hardware": 1}, "gives_gear": "Pry Tool"},
        {"id": "Framing Kit", "time": 8.0, "cost": {"Wood": 2, "Hardware": 1}, "gives_component": {"Framing Kit": 1}},
        {"id": "Pack Frame", "time": 8.0, "cost": {"Wood": 1, "Hardware": 1}, "gives_component": {"Pack Frame": 1}},
    ],
    "Sewing Table": [
        {"id": "Work Gloves", "time": 5.0, "cost": {"Cloth": 1}, "gives_gear": "Work Gloves"},
        {"id": "Heavy Boots", "time": 8.0, "cost": {"Cloth": 2, "Plastic": 1, "Scrap Metal": 1}, "gives_gear": "Heavy Boots"},
        {"id": "Leather Jacket", "time": 10.0, "cost": {"Cloth": 3, "Plastic": 1}, "gives_gear": "Leather Jacket"},
        {"id": "Work Jacket", "time": 8.0, "cost": {"Cloth": 2, "Plastic": 1}, "gives_gear": "Work Jacket"},
        {"id": "Padded Jacket", "time": 10.0, "cost": {"Cloth": 3, "Plastic": 1}, "gives_gear": "Padded Jacket"},
        {"id": "Worn Backpack", "time": 7.0, "cost": {"Cloth": 2, "Plastic": 1}, "gives_gear": "Worn Backpack"},
        {"id": "School Backpack", "time": 8.0, "cost": {"Cloth": 2, "Plastic": 2}, "gives_gear": "School Backpack"},
        {"id": "Improvised Pack", "time": 8.0, "cost": {"Cloth": 2, "Plastic": 1}, "gives_gear": "Improvised Pack"},
        {"id": "Hiking Pack", "time": 12.0, "cost": {"Cloth": 3, "Plastic": 2, "Hardware": 1}, "gives_gear": "Hiking Pack"},
        {"id": "Reinforced Pack", "time": 12.0, "cost": {"Cloth": 2, "Plastic": 1}, "component_cost": {"Pack Frame": 1}, "gives_gear": "Reinforced Pack"},
        {"id": "Weatherproofing Roll", "time": 8.0, "cost": {"Cloth": 2, "Plastic": 1}, "gives_component": {"Weatherproofing Roll": 1}},
    ]
}

const BUILDINGS := {
    "Rain Catcher": {"time": 10.0, "cost": {"Wood": 2, "Cloth": 1, "Plastic": 1}, "description": "Produces dirty water each day."},
    "Makeshift Shelter": {"time": 15.0, "cost": {"Wood": 4, "Cloth": 2, "Plastic": 1}, "description": "+2 shelter capacity."},
    "Storage Crate": {"time": 8.0, "cost": {"Wood": 2, "Hardware": 1}, "description": "Dedicated camp storage."},
    "Workbench": {"time": 20.0, "cost": {"Wood": 4, "Scrap Metal": 2, "Hardware": 1}, "description": "Unlocks tool, weapon and utility crafting."},
    "Sewing Table": {"time": 18.0, "cost": {"Wood": 3, "Cloth": 2, "Hardware": 1}, "requires": ["Workbench"], "description": "Unlocks clothing and pack crafting."},
    "Garden Plot": {"time": 20.0, "cost": {"Wood": 3, "Seeds": 1}, "requires": ["Workbench"], "description": "Produces raw food on days it is tended."},
    "Noise Line": {"time": 10.0, "cost": {"Scrap Metal": 1, "Hardware": 1, "Cloth": 1}, "description": "Early warning lowers camp intrusion risk."},
    "Cabin": {"time": 45.0, "cost": {"Wood": 4, "Scrap Metal": 2}, "component_cost": {"Framing Kit": 4, "Weatherproofing Roll": 2}, "requires": ["Workbench", "Sewing Table"], "description": "+4 shelter capacity and better idle recovery."},
    "Water Tank": {"time": 24.0, "cost": {"Scrap Metal": 5, "Plastic": 4, "Hardware": 2}, "requires": ["Rain Catcher", "Workbench"], "description": "Doubles daily Rain Catcher output."},
    "Communal Table": {"time": 18.0, "cost": {"Wood": 5, "Hardware": 2}, "requires": ["Cabin"], "description": "Improves idle stress recovery and enables shared-meal camp events."},
    "Infirmary": {"time": 32.0, "cost": {"Wood": 5, "Cloth": 3, "Plastic": 3, "Hardware": 3}, "component_cost": {"Sterile Dressing": 2}, "requires": ["Cabin", "Workbench"], "description": "Speeds treatment and wound recovery; reduces untreated critical decline."},
    "Watch Post": {"time": 28.0, "cost": {"Wood": 5, "Scrap Metal": 2, "Hardware": 2}, "requires": ["Noise Line", "Workbench"], "description": "Further reduces danger from camp-perimeter disturbances."},
    "Bunkhouse": {"time": 42.0, "cost": {"Wood": 8, "Cloth": 4, "Plastic": 2}, "component_cost": {"Framing Kit": 2, "Weatherproofing Roll": 1}, "requires": ["Cabin", "Sewing Table"], "description": "+6 shelter capacity."},
    "Armory": {"time": 38.0, "cost": {"Wood": 8, "Scrap Metal": 8, "Hardware": 6, "Plastic": 2}, "requires": ["Workbench", "Cabin"], "description": "Unlocks firearm construction at the Workbench."},
    "Dormitory": {"time": 55.0, "cost": {"Wood": 12, "Scrap Metal": 6, "Cloth": 4, "Hardware": 4}, "component_cost": {"Framing Kit": 4, "Weatherproofing Roll": 2}, "requires": ["Bunkhouse", "Infirmary", "Sewing Table"], "description": "+5 shelter capacity; completes the 18-person housing ceiling."},
}

const BUILD_ORDER := [
    "Rain Catcher", "Makeshift Shelter", "Storage Crate", "Workbench",
    "Sewing Table", "Garden Plot", "Noise Line", "Cabin", "Water Tank",
    "Communal Table", "Infirmary", "Watch Post", "Bunkhouse", "Armory", "Dormitory"
]

'''
ffdata, count = re.subn(r'const RECIPES := \{.*?\nconst LEADER_ABILITIES :=', new_content + 'const LEADER_ABILITIES :=', ffdata, count=1, flags=re.S)
if count != 1:
    raise SystemExit('FFData.gd: failed to replace recipes/buildings block')
write('game/scripts/FFData.gd', ffdata)

# ---------------------------------------------------------------------------
# Tactical presentation: every equipped slot is readable in tactical HUD.
# ---------------------------------------------------------------------------
replace_once(
    'game/scripts/FFTacticalVisuals.gd',
    'static func _facing_index(facing: Vector2i) -> int:\n',
    '''static func equipment_summary_lines(equipment: Dictionary) -> Array:\n    var primary: Array[String] = []\n    var utility: Array[String] = []\n    var weapon := str(equipment.get("Weapon", ""))\n    var secondary := str(equipment.get("Secondary", ""))\n    var tool := str(equipment.get("Tool", ""))\n    var clothing := str(equipment.get("Clothing", ""))\n    var pack := str(equipment.get("Pack", ""))\n    if weapon != "": primary.append("W " + weapon)\n    if secondary != "": primary.append("S " + secondary)\n    if tool != "": utility.append("T " + tool)\n    if clothing != "": utility.append("C " + clothing)\n    if pack != "": utility.append("P " + pack)\n    if primary.is_empty(): primary.append("W Bare Hands")\n    if utility.is_empty(): utility.append("No utility gear")\n    return [" | ".join(primary), " | ".join(utility)]\n\nstatic func _facing_index(facing: Vector2i) -> int:\n'''
)

# Make malformed/old contexts single-survivor too; no companion can be created.
regex_once(
    'game/scripts/FFCombat.gd',
    r'func make_party\(\):\n.*?\nfunc make_actor',
    '''func make_party():\n    var ids: Array = context.get("survivor_ids", [])\n    var lead = Game.get_survivor(ids[0]) if not ids.is_empty() else null\n    player = make_actor(lead, player_spawn, true)\n    ally = {}\n\nfunc make_actor'''
)
replace_once(
    'game/scripts/FFCombat.gd',
    '''    var gear_line="%s"%player.weapon.name\n    if bool(player.weapon.gun): gear_line += "  |  Ammo %d"%int(Game.resources.get("Ammo",0))\n    if player.clothing!="": gear_line += "  |  %s"%player.clothing\n    if TacticalLighting.item_emits_light(str(player.get("secondary", ""))): gear_line += "  |  LIGHT"\n    draw_string(font,Vector2(10,69),gear_line,HORIZONTAL_ALIGNMENT_LEFT,370,11,Color(.82,.84,.82))\n    if not ally.is_empty():\n        draw_string(font,Vector2(10,90),"With: %s  HP %d/%d  %s"%[ally.name,int(ally.hp),int(ally.max_hp),"DOWN" if ally.dead else ally.weapon.name],HORIZONTAL_ALIGNMENT_LEFT,370,10,Color(.76,.64,.90))\n''',
    '''    var gear_lines: Array = TacticalVisuals.equipment_summary_lines(player.get("equipment", {}))\n    var primary_gear := str(gear_lines[0])\n    if bool(player.weapon.gun): primary_gear += " | Ammo %d" % int(Game.resources.get("Ammo", 0))\n    draw_string(font, Vector2(10,69), primary_gear, HORIZONTAL_ALIGNMENT_LEFT, 370, 9, Color(.82,.84,.82))\n    draw_string(font, Vector2(10,89), str(gear_lines[1]), HORIZONTAL_ALIGNMENT_LEFT, 370, 8, Color(.72,.78,.74))\n'''
)

# ---------------------------------------------------------------------------
# Game orchestration: final cap, single dispatch, social chatter, late politics,
# final buildings, mature-settlement milestone. Schema 7 is the last Alpha reset.
# ---------------------------------------------------------------------------
game = text('game/scripts/Game.gd')
game = game.replace('signal toast_requested(message)\n', 'signal toast_requested(message)\nsignal camp_chatter_requested(data)\n', 1)
game = game.replace('const SAVE_SCHEMA_VERSION := 6\nconst DAY_SECONDS := 120.0', 'const SAVE_SCHEMA_VERSION := 7\nconst DAY_SECONDS := 120.0\nconst MAX_POPULATION := 18', 1)
game = game.replace('var camp_event_cooldown := 0.0\n', 'var camp_event_cooldown := 0.0\nvar camp_chatter_accum := 0.0\nvar next_camp_chatter_at := 10.0\n', 1)
game = game.replace('alpha_complete_shown', 'settlement_mature_shown')
game = game.replace('alpha_complete', 'settlement_mature')
game = game.replace('    camp_event_cooldown = CampLifeRules.NEW_GAME_EVENT_COOLDOWN\n', '    camp_event_cooldown = CampLifeRules.NEW_GAME_EVENT_COOLDOWN\n    camp_chatter_accum = 0.0\n    next_camp_chatter_at = rng.randf_range(CampLifeRules.CAMP_CHATTER_MIN_SECONDS, CampLifeRules.CAMP_CHATTER_MAX_SECONDS)\n', 1)
game = game.replace('    _process_survivors(delta)\n    _process_expeditions(delta)\n', '    _process_survivors(delta)\n    _process_camp_chatter(delta)\n    _process_expeditions(delta)\n', 1)

# Shelter capacity is now additive and tops out exactly at the final 18-person cap.
game, count = re.subn(r'func shelter_capacity\(\):\n.*?\nfunc population\(\):', '''func shelter_capacity():\n    var capacity := 1\n    if buildings.get("Makeshift Shelter", false): capacity += 2\n    if buildings.get("Cabin", false): capacity += 4\n    if buildings.get("Bunkhouse", false): capacity += 6\n    if buildings.get("Dormitory", false): capacity += 5\n    return mini(MAX_POPULATION, capacity)\n\nfunc population():''', game, count=1, flags=re.S)
if count != 1: raise SystemExit('Game.gd: shelter_capacity replacement failed')

game = game.replace('''    if population() >= shelter_capacity() + 1:\n        toast_requested.emit("There is no room for another survivor right now.")\n        return null\n''', '''    if population() >= MAX_POPULATION:\n        toast_requested.emit("First Fire is at its %d-person limit." % MAX_POPULATION)\n        return null\n    if population() >= shelter_capacity():\n        toast_requested.emit("There is no open shelter space right now.")\n        return null\n''', 1)

# Social chatter processing inserted before survivor work processing.
marker = 'func _process_survivors(delta):\n'
if game.count(marker) != 1: raise SystemExit('Game.gd: process survivor marker missing')
chatter_func = r'''func _process_camp_chatter(delta):
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

'''
game = game.replace(marker, chatter_func + marker, 1)

game = game.replace('CampLifeRules.idle_recovery_rates(bool(buildings.get("Cabin", false)), caretaker_leader)', 'CampLifeRules.idle_recovery_rates(bool(buildings.get("Cabin", false)), caretaker_leader, bool(buildings.get("Communal Table", false)))', 1)
game = game.replace('s["injury_remaining"] = max(0.0, float(s["injury_remaining"]) - delta)', 's["injury_remaining"] = max(0.0, float(s["injury_remaining"]) - delta * CampLifeRules.injury_recovery_multiplier(bool(buildings.get("Infirmary", false))))', 1)
game = game.replace('''        s["task"] = {"kind": "treatment", "remaining": base * (1.0 - reduction), "duration": base, "target": sid}\n''', '''        var treatment_time := base * (1.0 - reduction) * CampLifeRules.treatment_time_multiplier(bool(buildings.get("Infirmary", false)))\n        s["task"] = {"kind": "treatment", "remaining": treatment_time, "duration": base, "target": sid}\n''', 1)

# Craft recipes can require an already-built structure (currently firearm/Armory gate).
game = game.replace('''    if recipe == null:\n        return false\n    var cc = recipe.get("component_cost", {})\n''', '''    if recipe == null:\n        return false\n    for req in recipe.get("requires", []):\n        if not buildings.get(req, false):\n            toast_requested.emit("Requires %s." % req)\n            return false\n    var cc = recipe.get("component_cost", {})\n''', 1)

# Single-survivor expedition APIs.
game = game.replace('''func start_expedition(primary_id, companion_id, zone):\n    if not unlocked_zones.has(zone) or not D.ZONES.has(zone):\n        return false\n    var party_ids = [int(primary_id)]\n    if int(companion_id) > 0 and int(companion_id) != int(primary_id):\n        party_ids.append(int(companion_id))\n''', '''func start_expedition(primary_id, zone):\n    if not unlocked_zones.has(zone) or not D.ZONES.has(zone):\n        return false\n    var party_ids = [int(primary_id)]\n''', 1)
game = game.replace('ExpeditionRules.should_force_recruit(population(), shelter_capacity(), eligible_expeditions_since_recruit, recruit_eligible)', 'ExpeditionRules.should_force_recruit(population(), shelter_capacity(), MAX_POPULATION, eligible_expeditions_since_recruit, recruit_eligible)', 1)
game = game.replace('''func start_special_site(primary_id, companion_id, site):\n    if not special_sites.has(site) or not special_sites[site]["discovered"] or special_sites[site]["cleared"]:\n        return false\n    var party_ids = [int(primary_id)]\n    if int(companion_id) > 0 and int(companion_id) != int(primary_id):\n        party_ids.append(int(companion_id))\n''', '''func start_special_site(primary_id, site):\n    if not special_sites.has(site) or not special_sites[site]["discovered"] or special_sites[site]["cleared"]:\n        return false\n    var party_ids = [int(primary_id)]\n''', 1)

# Tactical contexts/results are lead-only from schema 7 onward.
game = game.replace('''    var companion_hp = -1\n    if ids.size() > 1:\n        companion_hp = _combat_condition_hp(get_survivor(ids[1]))\n''', '', 1)
game = game.replace('''            "lead_hp": _combat_condition_hp(lead),\n            "companion_hp": companion_hp,\n            "objective_done": str(exp.get("combat_kind", "ambush")) == "ambush",\n''', '''            "lead_hp": _combat_condition_hp(lead),\n            "objective_done": str(exp.get("combat_kind", "ambush")) == "ambush",\n''', 1)
game = game.replace('''    var lead: Variant = get_survivor(ids[0]) if not ids.is_empty() else null\n    var companion: Variant = get_survivor(ids[1]) if ids.size() > 1 else null\n\n''', '''    var lead: Variant = get_survivor(ids[0]) if not ids.is_empty() else null\n\n''', 1)
game, companion_count = re.subn(r'    if companion != null and result.get\("companion_hp", -1\) >= 0:\n.*?\n\n    current_combat = \{\}', '    current_combat = {}', game, count=1, flags=re.S)
if companion_count != 1: raise SystemExit('Game.gd: companion result cleanup failed')

# Secondary gear participates in field requirement checks.
game = game.replace('for slot in ["Weapon", "Clothing", "Pack", "Tool"]:', 'for slot in ["Weapon", "Secondary", "Clothing", "Pack", "Tool"]:', 1)

# Daily building effects.
game = game.replace('''    if buildings.get("Rain Catcher", false):\n        resources["Dirty Water"] = int(resources.get("Dirty Water", 0)) + 1\n''', '''    if buildings.get("Rain Catcher", false):\n        resources["Dirty Water"] = int(resources.get("Dirty Water", 0)) + CampLifeRules.rain_catcher_yield(bool(buildings.get("Water Tank", false)))\n''', 1)
game = game.replace('''        if s["condition"] == "Critical" and s["status"] != "Recovering" and rng.randf() < 0.25:\n''', '''        if s["condition"] == "Critical" and s["status"] != "Recovering" and rng.randf() < CampLifeRules.critical_decline_chance(bool(buildings.get("Infirmary", false))):\n''', 1)

game = game.replace('''func _has_room_for_recruit():\n    return population() < shelter_capacity() + 1\n''', '''func _has_room_for_recruit():\n    return population() < MAX_POPULATION and population() < shelter_capacity()\n''', 1)

# Camp disturbance risk now reads both defensive buildings.
game = game.replace('''        "camp_outside_investigate":\n            if lead != null and not buildings.get("Noise Line", false) and rng.randf() < 0.20:\n                _apply_injury(lead, "Hurt")\n            else:\n                toast_requested.emit("Nothing made it into camp.")\n''', '''        "camp_outside_investigate":\n            var outside_risk := CampLifeRules.outside_injury_chance(bool(buildings.get("Noise Line", false)), bool(buildings.get("Watch Post", false)))\n            if lead != null and rng.randf() < outside_risk:\n                _apply_injury(lead, "Hurt")\n            else:\n                toast_requested.emit("Nothing made it into camp.")\n''', 1)

# Add shared-meal and shortage-politics events to existing camp event selector.
game = game.replace('''    candidates.append("outside")\n    if int(resources.get("Cloth", 0)) > 0: candidates.append("request")\n''', '''    candidates.append("outside")\n    if int(resources.get("Cloth", 0)) > 0: candidates.append("request")\n    if buildings.get("Communal Table", false) and population() >= 3 and int(resources.get("Cooked Food", 0)) >= population() + 2: candidates.append("meal")\n    if (food_shortage_days > 0 or water_shortage_days > 0) and (leader_id != -1 or coordinator_id != -1): candidates.append("shortage_meeting")\n''', 1)
game = game.replace('''    if key == "request":\n        var requester: Variant = _highest_stress_survivor()\n        return _event_base("camp_request", "A Personal Request", "%s asks for some cloth to repair a personal keepsake. It will not help the camp." % requester["name"], [\n            {"text": "Give them the cloth", "action": "camp_request_give"},\n            {"text": "We need it for the camp", "action": "camp_request_refuse"},\n        ], {"survivor_ids": [requester["id"]]})\n    return {}\n''', '''    if key == "request":\n        var requester: Variant = _highest_stress_survivor()\n        return _event_base("camp_request", "A Personal Request", "%s asks for some cloth to repair a personal keepsake. It will not help the camp." % requester["name"], [\n            {"text": "Give them the cloth", "action": "camp_request_give"},\n            {"text": "We need it for the camp", "action": "camp_request_refuse"},\n        ], {"survivor_ids": [requester["id"]]})\n    if key == "meal":\n        return _event_base("camp_meal", "Eat Together", "There is enough food for once. Someone suggests putting two extra rations on the communal table and eating like people instead of inventory slots.", [\n            {"text": "Use two extra rations and eat together", "action": "camp_meal_share"},\n            {"text": "Save the food", "action": "camp_meal_save"},\n        ])\n    if key == "shortage_meeting":\n        var active_leader: Variant = get_survivor(leader_id if leader_id != -1 else coordinator_id)\n        return _event_base("camp_shortage_meeting", "Rations and Blame", "Short supplies turn into a political argument. People want to know whether %s actually has a plan." % (active_leader["name"] if active_leader != null else "anyone"), [\n            {"text": "Back the current ration plan", "action": "camp_shortage_back_leader"},\n            {"text": "Let everyone say what they think", "action": "camp_shortage_open_floor"},\n        ])\n    return {}\n''', 1)

game = game.replace('''        "camp_request_refuse":\n            if lead != null: lead["stress"] += 4\n        "politics_support_a", "politics_support_b", "politics_neutral":\n''', '''        "camp_request_refuse":\n            if lead != null: lead["stress"] += 4\n        "camp_meal_share":\n            if int(resources.get("Cooked Food", 0)) >= 2:\n                resources["Cooked Food"] -= 2\n                for survivor in survivors:\n                    if survivor["condition"] != "Dead":\n                        survivor["stress"] = max(0.0, float(survivor["stress"]) - 6.0)\n                var meal_pair := CampSocial.pick_pair(survivors, rng)\n                if meal_pair.size() == 2:\n                    _change_relationship(meal_pair[0], meal_pair[1], 4)\n                    _change_relationship(meal_pair[1], meal_pair[0], 4)\n        "camp_meal_save":\n            pass\n        "camp_shortage_back_leader":\n            for survivor in survivors:\n                if survivor["condition"] != "Dead": survivor["leader_support"] = int(survivor.get("leader_support", 0)) + 2\n        "camp_shortage_open_floor":\n            for survivor in survivors:\n                if survivor["condition"] != "Dead":\n                    survivor["stress"] = max(0.0, float(survivor["stress"]) - 2.0)\n                    survivor["leader_support"] = int(survivor.get("leader_support", 0)) + rng.randi_range(-2, 1)\n        "politics_support_a", "politics_support_b", "politics_neutral":\n''', 1)

# Ongoing confidence politics after the first formal election.
game, politics_count = re.subn(r'func _consider_politics\(\):\n.*?\nfunc _candidate_standing', r'''func _consider_politics():
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

func _candidate_standing''', game, count=1, flags=re.S)
if politics_count != 1: raise SystemExit('Game.gd: politics replacement failed')

game = game.replace('''    leader_id = _run_vote(ids, endorsement)\n    coordinator_id = -1\n    leadership_form = "Elected Leader"\n''', '''    leader_id = _run_vote(ids, endorsement)\n    coordinator_id = -1\n    leadership_form = "Elected Leader"\n    flags["next_confidence_check_day"] = day + 3\n''', 1)

confidence = r'''func _build_confidence_vote(challenger: Dictionary):
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

'''
anchor = 'func _run_vote(candidate_ids, endorsement):\n'
if game.count(anchor) != 1: raise SystemExit('Game.gd: vote anchor missing')
game = game.replace(anchor, confidence + anchor, 1)

game = game.replace('''        "election_support_a", "election_support_b", "election_neutral":\n            _resolve_formal_election(event, action)\n''', '''        "election_support_a", "election_support_b", "election_neutral":\n            _resolve_formal_election(event, action)\n        "confidence_support_a", "confidence_support_b", "confidence_neutral":\n            _resolve_confidence_vote(event, action)\n''', 1)

# Support label delegates to social owner.
game, support_count = re.subn(r'func leader_support_label\(\):\n.*?\nfunc _check_settlement_mature', r'''func leader_support_label():
    var leader: Variant = get_survivor(leader_id if leader_id != -1 else coordinator_id)
    if leader == null: return "None"
    var avg := CampSocial.leader_support_score(leader, survivors)
    if avg >= 50: return "Very Strong"
    if avg >= 20: return "Strong"
    if avg <= -40: return "Hostile"
    if avg <= -15: return "Weak"
    return "Mixed"

func _check_settlement_mature''', game, count=1, flags=re.S)
if support_count != 1: raise SystemExit('Game.gd: leader support replacement failed')

# Mature settlement is a persistent status, not an ending.
game, mature_count = re.subn(r'func _check_settlement_mature\(\):\n.*?\nfunc _check_game_over', r'''func _all_buildings_complete() -> bool:
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

func _check_game_over''', game, count=1, flags=re.S)
if mature_count != 1: raise SystemExit('Game.gd: mature milestone replacement failed')
game = game.replace('"alpha_continue"', '"mature_continue"')
# Global alpha->settlement replacement turned action name into settlement_mature_continue if it ever existed; normalize.
game = game.replace('"settlement_mature_continue"', '"mature_continue"')
game = game.replace('"version": "0.3.0"', '"version": "0.9.0-beta-candidate"', 1)

# Verify API cut and schema before writing.
if 'func start_expedition(primary_id, companion_id' in game or 'func start_special_site(primary_id, companion_id' in game:
    raise SystemExit('Game.gd: companion expedition API still present')
if 'const SAVE_SCHEMA_VERSION := 7' not in game or 'const MAX_POPULATION := 18' not in game:
    raise SystemExit('Game.gd: schema/cap patch missing')
write('game/scripts/Game.gd', game)

# ---------------------------------------------------------------------------
# Main UI: single-survivor dispatch, final population display, recipe gates and
# final build descriptions.
# ---------------------------------------------------------------------------
main = text('game/scripts/Main.gd')
main = main.replace('var expedition_companion: OptionButton\n', '')
main = main.replace('''    v.add_child(_make_label("Companion", 13))\n    expedition_companion = OptionButton.new()\n    expedition_companion.custom_minimum_size = Vector2(0, 44)\n    v.add_child(expedition_companion)\n\n''', '')
main, companion_ui_count = re.subn(r'    expedition_companion.clear\(\)\n.*?    for child in expedition_specials.get_children\(\):', '    for child in expedition_specials.get_children():', main, count=1, flags=re.S)
if companion_ui_count != 1: raise SystemExit('Main.gd: companion picker cleanup failed')
main = main.replace('''    var companion = int(expedition_companion.get_item_metadata(expedition_companion.selected)) if expedition_companion.item_count > 0 else -1\n    if Game.start_expedition(selected_survivor_id, companion, zone):\n''', '''    if Game.start_expedition(selected_survivor_id, zone):\n''', 1)
main = main.replace('''    var companion = int(expedition_companion.get_item_metadata(expedition_companion.selected)) if expedition_companion.item_count > 0 else -1\n    if Game.start_special_site(selected_survivor_id, companion, site):\n''', '''    if Game.start_special_site(selected_survivor_id, site):\n''', 1)

main = main.replace('''    status_label.text = "Day %d  %s  •  Food %d  Water %d  •  Pop %d/%d" % [\n        Game.day,\n        Game.formatted_time(),\n        int(Game.resources.get("Cooked Food", 0)),\n        int(Game.resources.get("Clean Water", 0)),\n        Game.population(),\n        Game.shelter_capacity()\n    ]\n''', '''    status_label.text = "Day %d  %s  •  Food %d  Water %d  •  Pop %d/%d  Beds %d" % [\n        Game.day,\n        Game.formatted_time(),\n        int(Game.resources.get("Cooked Food", 0)),\n        int(Game.resources.get("Clean Water", 0)),\n        Game.population(),\n        Game.MAX_POPULATION,\n        Game.shelter_capacity()\n    ]\n''', 1)
main = main.replace('["Population", "%d / %d" % [Game.population(), Game.shelter_capacity()]],', '["Population", "%d / %d" % [Game.population(), Game.MAX_POPULATION]],\n        ["Shelter Beds", "%d" % Game.shelter_capacity()],\n        ["Settlement", "MATURE" if Game.settlement_mature else "GROWING"],', 1)
main = main.replace('["Shelter", "FULL" if Game.population() >= Game.shelter_capacity() else "SPACE AVAILABLE"],\n', '')
main = main.replace('content_box.add_child(_make_label("All Alpha 0.1 structures are shown here. Gray BUILD buttons mean you are missing materials, a worker, or a prerequisite.", 13))', 'content_box.add_child(_make_label("This is the final First Fire building tree. Gray BUILD buttons mean you are missing materials, a worker, or a prerequisite.", 13))', 1)
main = main.replace('''        var data = D.BUILDINGS[building]\n        v.add_child(_make_label(_format_cost(data.get("cost", {}), data.get("component_cost", {})) + "  •  %.0fs base" % float(data["time"]), 12))\n''', '''        var data = D.BUILDINGS[building]\n        if str(data.get("description", "")) != "":\n            v.add_child(_make_label(str(data["description"]), 12))\n        v.add_child(_make_label(_format_cost(data.get("cost", {}), data.get("component_cost", {})) + "  •  %.0fs base" % float(data["time"]), 12))\n''', 1)

# Recipe prerequisite visibility and button gating.
main = main.replace('''            if not outputs.is_empty():\n                desc += "  →  " + ", ".join(outputs)\n            v.add_child(_make_label(desc, 12))\n            var b = Button.new()\n            b.text = "CRAFT"\n            b.custom_minimum_size = Vector2(0, 40)\n            b.disabled = selected_worker_id < 0 or not _can_pay_ui(recipe.get("cost", {}), recipe.get("component_cost", {}))\n''', '''            if not outputs.is_empty():\n                desc += "  →  " + ", ".join(outputs)\n            v.add_child(_make_label(desc, 12))\n            var recipe_req_ok := true\n            if recipe.has("requires"):\n                v.add_child(_make_label("Requires: " + ", ".join(recipe["requires"]), 12))\n                for req in recipe["requires"]:\n                    if not Game.buildings.get(req, false): recipe_req_ok = false\n            var b = Button.new()\n            b.text = "CRAFT"\n            b.custom_minimum_size = Vector2(0, 40)\n            b.disabled = selected_worker_id < 0 or not recipe_req_ok or not _can_pay_ui(recipe.get("cost", {}), recipe.get("component_cost", {}))\n''', 1)

if 'expedition_companion' in main:
    raise SystemExit('Main.gd: companion UI symbol remains')
write('game/scripts/Main.gd', main)

# ---------------------------------------------------------------------------
# Living camp: expand final structures, explicit day phase and social callouts.
# ---------------------------------------------------------------------------
camp = text('game/scripts/FFCampView.gd')
camp = camp.replace('''    "Cabin": Vector2i(12, 5),\n}''', '''    "Cabin": Vector2i(12, 5),\n    "Water Tank": Vector2i(1, 2),\n    "Communal Table": Vector2i(7, 6),\n    "Infirmary": Vector2i(14, 6),\n    "Watch Post": Vector2i(14, 2),\n    "Bunkhouse": Vector2i(3, 7),\n    "Armory": Vector2i(14, 4),\n    "Dormitory": Vector2i(10, 7),\n}''', 1)
camp = camp.replace('''var redraw_accum := 0.0\n''', '''var redraw_accum := 0.0\nvar chatter_entry := {}\nvar chatter_until_ms := 0\n''', 1)
camp = camp.replace('''    set_process(true)\n    queue_redraw()\n''', '''    set_process(true)\n    if not Game.camp_chatter_requested.is_connected(_on_camp_chatter):\n        Game.camp_chatter_requested.connect(_on_camp_chatter)\n    queue_redraw()\n''', 1)
camp = camp.replace('''    redraw_accum += delta\n    if moved or redraw_accum >= 0.20:\n''', '''    var now_ms := Time.get_ticks_msec()\n    if not chatter_entry.is_empty() and now_ms >= chatter_until_ms:\n        chatter_entry = {}\n        moved = true\n    elif not chatter_entry.is_empty():\n        moved = true\n    redraw_accum += delta\n    if moved or redraw_accum >= 0.20:\n''', 1)

# Title carries day phase; chatter drawn after people.
camp = camp.replace('''    _draw_night(origin, tile)\n    _draw_survivors(origin, tile)\n    draw_rect(Rect2(origin, map_size),''', '''    _draw_night(origin, tile)\n    _draw_survivors(origin, tile)\n    _draw_chatter(origin, tile)\n    draw_rect(Rect2(origin, map_size),''', 1)
camp = camp.replace('''    draw_string(font, origin + Vector2(7.0, float(title_size) + 4.0), "FIRST FIRE CAMP  •  %s" % Game.formatted_time(), HORIZONTAL_ALIGNMENT_LEFT, -1.0, title_size, Color(0.92, 0.94, 0.88, 0.92))\n''', '''    draw_string(font, origin + Vector2(7.0, float(title_size) + 4.0), "FIRST FIRE CAMP  •  %s  •  %s" % [Game.formatted_time(), _day_phase()], HORIZONTAL_ALIGNMENT_LEFT, -1.0, title_size, Color(0.92, 0.94, 0.88, 0.92))\n''', 1)

# Draw final structures with existing tactical atlas/primitives.
camp = camp.replace('''    if bool(Game.buildings.get("Cabin", false)):\n        _draw_cabin(origin, tile)\n''', '''    if bool(Game.buildings.get("Cabin", false)):\n        _draw_cabin(origin, tile)\n    if bool(Game.buildings.get("Water Tank", false)):\n        var tank_rect := _cell_rect(building_cell("Water Tank"), origin, tile).grow(-tile * 0.03)\n        Tiles.draw_barrel(self, tank_rect)\n        draw_circle(tank_rect.get_center(), tile * 0.38, Color(0.42, 0.70, 0.86, 0.65), false, 1.5)\n    if bool(Game.buildings.get("Communal Table", false)):\n        Tiles.draw_prop(self, _cell_rect(building_cell("Communal Table"), origin, tile).grow(-tile * 0.04), "table")\n    if bool(Game.buildings.get("Infirmary", false)):\n        var infirmary_rect := _cell_rect(building_cell("Infirmary"), origin, tile).grow(-tile * 0.04)\n        Tiles.draw_prop(self, infirmary_rect, "bed")\n        var ic := infirmary_rect.get_center()\n        draw_line(ic + Vector2(-tile * 0.11, 0), ic + Vector2(tile * 0.11, 0), Color("d7e7df"), 2.0)\n        draw_line(ic + Vector2(0, -tile * 0.11), ic + Vector2(0, tile * 0.11), Color("d7e7df"), 2.0)\n    if bool(Game.buildings.get("Watch Post", false)):\n        var wc := _cell_center(building_cell("Watch Post"), origin, tile)\n        draw_rect(Rect2(wc - Vector2(tile * 0.30, tile * 0.30), Vector2(tile * 0.60, tile * 0.60)), Color("4b5146"))\n        draw_line(wc + Vector2(0, tile * 0.28), wc + Vector2(-tile * 0.20, tile * 0.48), Color("897e65"), 2.0)\n        draw_line(wc + Vector2(0, tile * 0.28), wc + Vector2(tile * 0.20, tile * 0.48), Color("897e65"), 2.0)\n    if bool(Game.buildings.get("Bunkhouse", false)):\n        var br := _cell_rect(building_cell("Bunkhouse"), origin, tile).grow(-tile * 0.03)\n        draw_rect(br, Color("5a594d"))\n        draw_polyline(PackedVector2Array([br.position + Vector2(0, br.size.y * 0.35), br.position + Vector2(br.size.x * 0.5, 0), br.position + Vector2(br.size.x, br.size.y * 0.35)]), Color("a69c7b"), 2.0)\n    if bool(Game.buildings.get("Armory", false)):\n        var ar := _cell_rect(building_cell("Armory"), origin, tile).grow(-tile * 0.04)\n        Tiles.draw_prop(self, ar, "crate")\n        draw_rect(ar, Color(0.62, 0.24, 0.18, 0.85), false, 2.0)\n    if bool(Game.buildings.get("Dormitory", false)):\n        var dr := _cell_rect(building_cell("Dormitory"), origin, tile).grow(-tile * 0.02)\n        draw_rect(dr, Color("4d5a55"))\n        Tiles.draw_window(self, Rect2(dr.position + Vector2(dr.size.x * 0.18, dr.size.y * 0.18), dr.size * 0.34))\n        Tiles.draw_window(self, Rect2(dr.position + Vector2(dr.size.x * 0.55, dr.size.y * 0.18), dr.size * 0.28))\n''', 1)

# Explicit dawn/day/dusk/night helper and richer camp tint.
camp, night_count = re.subn(r'func _night_alpha\(\) -> float:\n.*?\nfunc _draw_survivors', r'''func _camp_hour() -> float:
    var fraction: float = clampf(float(Game.day_elapsed) / maxf(1.0, float(Game.DAY_SECONDS)), 0.0, 1.0)
    return fmod(8.0 + fraction * 24.0, 24.0)

func _day_phase() -> String:
    var hour := _camp_hour()
    if hour >= 20.0 or hour < 5.0: return "NIGHT"
    if hour < 7.0: return "DAWN"
    if hour >= 18.0: return "DUSK"
    return "DAY"

func _night_alpha() -> float:
    var hour := _camp_hour()
    if hour >= 20.0 or hour < 5.0:
        return 0.64
    if hour >= 18.0:
        return lerpf(0.0, 0.64, (hour - 18.0) / 2.0)
    if hour < 7.0:
        return lerpf(0.64, 0.0, (hour - 5.0) / 2.0)
    return 0.0

func _draw_night(origin: Vector2, tile: float) -> void:
    var hour := _camp_hour()
    var map_rect := Rect2(origin, Vector2(tile * float(GRID_W), tile * float(GRID_H)))
    if hour >= 17.0 and hour < 20.0:
        var dusk_alpha := 0.10 * clampf((hour - 17.0) / 3.0, 0.0, 1.0)
        draw_rect(map_rect, Color(0.34, 0.12, 0.05, dusk_alpha))
    elif hour >= 5.0 and hour < 7.0:
        var dawn_alpha := 0.08 * clampf((7.0 - hour) / 2.0, 0.0, 1.0)
        draw_rect(map_rect, Color(0.10, 0.18, 0.30, dawn_alpha))
    var alpha := _night_alpha()
    if alpha <= 0.001:
        return
    draw_rect(map_rect, Color(0.015, 0.035, 0.085, alpha))
    var fire_center := _cell_center(FIRE_CELL, origin, tile)
    draw_circle(fire_center, tile * 2.25, Color(1.0, 0.36, 0.10, 0.055))
    draw_circle(fire_center, tile * 1.55, Color(1.0, 0.48, 0.12, 0.085))
    draw_circle(fire_center, tile * 0.90, Color(1.0, 0.68, 0.20, 0.14))
    if bool(Game.buildings.get("Cabin", false)):
        var cabin_center := _cell_center(Vector2i(12, 5), origin, tile)
        draw_circle(cabin_center, tile * 1.7, Color(1.0, 0.72, 0.34, 0.075))
    if bool(Game.buildings.get("Infirmary", false)):
        var infirmary_center := _cell_center(building_cell("Infirmary"), origin, tile)
        draw_circle(infirmary_center, tile * 1.20, Color(0.58, 0.82, 0.90, 0.065))
    if bool(Game.buildings.get("Watch Post", false)):
        var watch_center := _cell_center(building_cell("Watch Post"), origin, tile)
        draw_circle(watch_center, tile * 0.80, Color(0.78, 0.86, 0.72, 0.055))

func _draw_survivors''', camp, count=1, flags=re.S)
if night_count != 1: raise SystemExit('FFCampView.gd: day/night replacement failed')

# Chatter callouts mirror tactical sound markers without owning simulation.
append_marker = 'func _activity_short(status: String) -> String:\n'
if camp.count(append_marker) != 1: raise SystemExit('FFCampView.gd: activity marker missing')
chatter_draw = r'''func _on_camp_chatter(data: Dictionary) -> void:
    if not is_visible_in_tree():
        return
    var speaker_id := int(data.get("speaker_id", -1))
    if not actor_positions.has(speaker_id):
        return
    chatter_entry = data.duplicate(true)
    chatter_until_ms = Time.get_ticks_msec() + 3400
    queue_redraw()

func _draw_chatter(origin: Vector2, tile: float) -> void:
    if chatter_entry.is_empty() or Time.get_ticks_msec() >= chatter_until_ms:
        return
    var sid := int(chatter_entry.get("speaker_id", -1))
    if not actor_positions.has(sid):
        return
    var center := _grid_center(actor_positions[sid], origin, tile)
    var width := minf(tile * 6.2, tile * float(GRID_W) - 8.0)
    var height := maxf(34.0, tile * 1.35)
    var x := clampf(center.x - width * 0.5, origin.x + 4.0, origin.x + tile * float(GRID_W) - width - 4.0)
    var y := clampf(center.y - height - tile * 0.65, origin.y + 20.0, origin.y + tile * float(GRID_H) - height - 4.0)
    var box := Rect2(Vector2(x, y), Vector2(width, height))
    var tone := str(chatter_entry.get("tone", "neutral"))
    var border := Color("d7bd58")
    if tone in ["friendly", "warm"]: border = Color("78b987")
    elif tone in ["hostile", "tense"]: border = Color("c35a4d")
    elif tone == "politics": border = Color("8f78c7")
    elif tone == "worry": border = Color("c9a15a")
    draw_rect(box, Color(0.025, 0.035, 0.032, 0.92))
    draw_rect(box, border, false, 1.3)
    var font := get_theme_default_font()
    var header := "%s → %s" % [str(chatter_entry.get("speaker_name", "?")), str(chatter_entry.get("listener_name", "?"))]
    draw_string(font, box.position + Vector2(4.0, 11.0), header, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 8.0, 8, border)
    draw_string(font, box.position + Vector2(4.0, 25.0), str(chatter_entry.get("text", "...")), HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 8.0, 8, Color(0.94, 0.94, 0.88, 0.98))

'''
camp = camp.replace(append_marker, chatter_draw + append_marker, 1)
write('game/scripts/FFCampView.gd', camp)

# ---------------------------------------------------------------------------
# Architecture smoke: final scope invariants and data completeness.
# ---------------------------------------------------------------------------
smoke = text('game/scripts/ci/FFArchitectureSmoke.gd')
smoke = smoke.replace('ExpeditionRules.should_force_recruit(1, 1, 5, true)', 'ExpeditionRules.should_force_recruit(1, 1, 18, 4, true)', 1)
smoke = smoke.replace('ExpeditionRules.should_force_recruit(1, 1, 4, true)', 'ExpeditionRules.should_force_recruit(1, 1, 18, 3, true)', 1)
insert_after = '    if not _check(str(TacticalVisuals.weapon_visual("Pistol").get("kind", "")) == "pistol", "weapon visual catalog"): return\n'
if smoke.count(insert_after) != 1: raise SystemExit('Smoke: tactical visual anchor missing')
extra_smoke = r'''    var equipped_lines: Array = TacticalVisuals.equipment_summary_lines({"Weapon": "Pistol", "Secondary": "Flashlight", "Tool": "First Aid Kit", "Clothing": "Leather Jacket", "Pack": "Hiking Pack"})
    if not _check(str(equipped_lines[0]).contains("Pistol") and str(equipped_lines[0]).contains("Flashlight"), "tactical primary equipment summary"): return
    if not _check(str(equipped_lines[1]).contains("First Aid Kit") and str(equipped_lines[1]).contains("Leather Jacket") and str(equipped_lines[1]).contains("Hiking Pack"), "tactical utility equipment summary"): return

    var craftable_gear := {}
    for station in D.RECIPES.keys():
        for recipe in D.RECIPES[station]:
            var gives := str(recipe.get("gives_gear", ""))
            if gives != "": craftable_gear[gives] = true
    for gear_name in D.GEAR.keys():
        if not _check(craftable_gear.has(gear_name), "craftable gear: %s" % gear_name): return
    if not _check(D.BUILD_ORDER.size() == 15 and D.BUILDINGS.has("Dormitory") and D.BUILDINGS.has("Armory"), "final building tree"): return

    var chatter_rng := RandomNumberGenerator.new()
    chatter_rng.seed = 44
    var chatter_people := [
        {"id": 1, "name": "Alex Reed", "condition": "Healthy", "status": "Available", "task": {}, "relationships": {"2": 65}, "traits": ["Friendly"], "leader_support": 0, "stress": 10.0, "fatigue": 5.0},
        {"id": 2, "name": "Sam Hale", "condition": "Healthy", "status": "Available", "task": {}, "relationships": {"1": 50}, "traits": ["Optimistic"], "leader_support": 0, "stress": 10.0, "fatigue": 5.0},
    ]
    var chatter: Dictionary = CampSocial.roll_chatter(chatter_people, -1, -1, 0, 0, {}, chatter_rng)
    if not _check(not chatter.is_empty() and str(chatter.get("text", "")) != "", "camp chatter selection"): return
'''
smoke = smoke.replace(insert_after, insert_after + extra_smoke, 1)
write('game/scripts/ci/FFArchitectureSmoke.gd', smoke)

# ---------------------------------------------------------------------------
# Roadmap is now a feature-freeze completion list, not a feature wish list.
# ---------------------------------------------------------------------------
write('ROADMAP.md', r'''# First Fire — Beta Candidate Roadmap

First Fire is now in **feature freeze**. The game loop and its final feature set are decided. Work from here to Beta/1.0 is completion, conversion, balance, content depth, readability, performance, and bug fixing—not new pillars.

## Final game loop

**Camp → prepare one survivor → expedition → tactical field situation → escape → persistent consequences → living camp/politics → recover/build/craft → repeat.**

The game has **no scripted ending**. A settlement with every building completed and roughly **15–18 living survivors** is the mature/top-level state; play can continue indefinitely after that.

The hard population ceiling is **18 survivors**.

## Permanently cut scope

These are no longer planned for First Fire:

- 3D camp rendering—the living 2D tactical-style camp is the final camp presentation;
- pets or pet-care systems;
- vehicles or vehicle logistics;
- multi-survivor expeditions;
- tactical companion AI;
- additional foundational game modes or feature pillars.

Removing these is intentional scope control, not deferred work.

## Beta completion work

### Camp life, politics and events

Finish tuning the systems that already exist:

- autonomous relationship/politics-based chatter in the living camp;
- relationship drift from meaningful positive/negative interactions;
- shortages and repeated expedition duty feeding camp opinion;
- coordinator → formal election progression;
- recurring confidence challenges when an elected leader loses support;
- camp events for shelter pressure, duty complaints, food, theft, fights, burnout, perimeter danger, personal requests, shared meals and shortage politics;
- enough event weighting/cooldowns that camp life feels alive without becoming popup spam.

### Tactical field completion

Outside-world events remain physical/tactical. Finish converting or retiring any remaining legacy field-text path so camp narrative is the only routine text-event space.

Keep deepening the existing tactical language rather than adding another combat system:

- recognizable locations;
- day/night/power/lighting;
- vision, sound, stealth and action timing;
- doors, windows, hazards and exits;
- rescue/search/ambush objectives;
- equipment interactions and readable consequences;
- mobile readability and performance.

### Items and crafting

Every current `FFData.GEAR` item must be represented in the finished equipment loop. All existing gear is craftable through the Fire Pit/Workbench/Sewing Table tree as appropriate; firearms are late-camp Workbench recipes gated by the Armory.

The tactical HUD must expose all five equipment slots: Weapon, Secondary, Tool, Clothing and Pack.

Future work here is balance/art/readability, not introducing a second inventory system.

### Final building tree

The final build list is:

1. Rain Catcher
2. Makeshift Shelter
3. Storage Crate
4. Workbench
5. Sewing Table
6. Garden Plot
7. Noise Line
8. Cabin
9. Water Tank
10. Communal Table
11. Infirmary
12. Watch Post
13. Bunkhouse
14. Armory
15. Dormitory

Housing grows additively to the final 18-person ceiling. Utility buildings deepen existing food/water/recovery/security/social/crafting rules rather than creating new minigames.

### Mature settlement state

A settlement becomes **mature** when it has:

- at least 15 living survivors;
- every planned building completed;
- an elected leader.

This produces a milestone event only. It does **not** end the save.

## Beta → 1.0

Once the above completion work is stable, focus only on:

- long-run economy and progression balance;
- tactical repetition and encounter conversion;
- camp politics/event tuning;
- item/building costs and usefulness;
- onboarding/tutorial clarity;
- final 2D art/UI/audio feedback;
- mobile/browser performance;
- accessibility/readability;
- save stability;
- bug fixing;
- release packaging;
- non-exploitative monetization only after gameplay is stable.

Schema 7 is intended as the final deliberate Alpha reset. Once Beta testing begins, save compatibility becomes a player-facing promise and schema changes should be treated much more conservatively.
''')

# ---------------------------------------------------------------------------
# Context/architecture/SOP updated to the frozen scope.
# ---------------------------------------------------------------------------
context = text('README_CONTEXT.md')
context = context.replace('Current milestone: **Alpha 0.3E — Living Camp View**.', 'Current milestone: **Beta Candidate — Feature Freeze**.', 1)
context = context.replace('Current save schema: **6**.', 'Current save schema: **7**.', 1)
context = context.replace('Save schema 6 intentionally invalidates older Alpha state rather than carrying a compatibility path.', 'Save schema 7 is the final planned Alpha invalidation before Beta save stability. Every new founder still starts with a Flashlight equipped in Secondary.', 1)
context = context.replace('`FFCampSocial.gd` owns current relationship/social-selection rules and is the intended owner for Alpha 0.5 autonomous survivor interactions.', '`FFCampSocial.gd` owns relationship/social-selection rules, political standing, and autonomous camp chatter. Chatter is selected from real relationship, shortage, personality, leadership-support and policy state; `Game.gd` applies its small consequences and `FFCampView.gd` only renders the callout.', 1)
# Remove pet future paragraph.
context = re.sub(r'\nPets should eventually get a dedicated owner.*?repetitive button timer\.\n', '\n', context, count=1, flags=re.S)
# Replace expedition vehicle seam paragraph.
context = context.replace('It is also the intended integration seam for vehicles. Vehicles should affect travel/logistics and become the tactical map’s physical entry/exit anchor (“stairs”), not create a driving minigame.\n', 'Expeditions are permanently single-survivor. Multi-survivor dispatch, companion AI, and vehicle logistics are cut from scope.\n', 1)
# Replace roadmap ownership summary block.
context = re.sub(r'## Roadmap ownership summary\n.*?\n## Source-of-truth order', '''## Frozen-scope ownership summary\n\n- tactical field play/conversion → `FFTacticalScenarios` + `FFTacticalEnvironments` + `FFCombat`\n- single-survivor expedition logistics → `FFExpeditionRules`\n- relationships/politics/autonomous chatter → `FFCampSocial`\n- camp cadence/recovery/building effects → `FFCampLifeRules`\n- living 2D camp/menu visualization → `FFCampView`\n- saves → `FFSaveCodec` transport + current Game schema\n\nThere is no future pets, vehicles, companion-expedition, or 3D-camp owner. The 2D camp is final presentation.\n\nFinal population ceiling is **18**. At **15+ survivors + every building + an elected leader**, the settlement is marked mature, but the game continues indefinitely.\n\n## Source-of-truth order''', context, count=1, flags=re.S)
# Remove pet phrase in low micromanagement pillar.
context = context.replace('Idle recovery and social/pet care should be systemic/autonomous when natural.', 'Idle recovery and social behavior should be systemic/autonomous when natural.', 1)
write('README_CONTEXT.md', context)

arch = text('ARCHITECTURE.md')
arch = arch.replace('Current schema: **6**.', 'Current schema: **7**.', 1)
arch = arch.replace('Pure expedition/logistics rules: travel duration, recruit protection, tactical-event share, zone haul caps, and routine haul-count distributions. This is the integration seam for future vehicle speed/range/cargo effects and route/logistics constraints.', 'Pure single-survivor expedition/logistics rules: travel duration, recruit protection, tactical-event share, zone haul caps, and routine haul-count distributions. Multi-survivor dispatch and vehicles are not part of the final design.', 1)
arch = arch.replace('Relationship mutation/labels and survivor social-selection rules. Alpha 0.5 should grow autonomous interactions here: personality, stress, health, fatigue, injuries, shared history, losses/successes, politics, comfort, resentment, friendship, and meaningful camp-story triggers.', 'Relationship mutation/labels, candidate standing, leadership support, pair selection, and autonomous camp chatter. Personality, stress, shortages, relationship state, leadership opinion and policy can shape quiet interactions; Game applies consequences and the camp view renders them.', 1)
arch = arch.replace('Camp-life cadence and idle recovery tuning. Future home for shared camp vibe/comfort/resource-security modifiers that influence autonomous life.', 'Camp-life cadence, idle recovery, injury/treatment modifiers, defensive-building risk, rain-catcher output, and chatter timing.', 1)
# Remove future seams section entirely.
arch = re.sub(r'\n## Planned seams — do not create empty modules early\n.*?\n## Tactical pause boundary', '\n## Frozen scope\n\nThe living **2D** camp is final presentation. Pets, vehicles, 3D camp rendering, multi-survivor expeditions, and tactical companion AI are deliberately cut. New code should complete/tune existing owners rather than create replacement feature pillars.\n\nThe hard population ceiling is 18; the mature-settlement milestone is 15+ survivors with all planned buildings and an elected leader, and it does not end the save.\n\n## Tactical pause boundary', arch, count=1, flags=re.S)
write('ARCHITECTURE.md', arch)

sop = text('README_SOPS.md')
sop = sop.replace('Current schema: **6**.', 'Current schema: **7**.', 1)
sop = sop.replace('- `FFExpeditionRules.gd` — travel/logistics/recruit protection/haul rules; vehicle integration seam.', '- `FFExpeditionRules.gd` — single-survivor travel/logistics/recruit protection/haul rules.', 1)
sop = sop.replace('- `FFCampSocial.gd` — relationships and future autonomous survivor social behavior.', '- `FFCampSocial.gd` — relationships, political standing, and autonomous survivor chatter.', 1)
sop = sop.replace('New tactical locations, encounter variants, pets, vehicles, equipment, etc. should be data-driven until behavior truly differs.', 'New tactical locations, encounter variants, equipment, buildings, etc. should be data-driven until behavior truly differs.', 1)
sop = re.sub(r'### One owner per rule(.*?)## 4\. Roadmap-oriented ownership\n\n.*?\nThe remaining field text-event selector', r'''### One owner per rule\1## 4. Frozen-scope ownership\n\n- Remaining outside-world tactical conversion/variety → `FFTacticalScenarios` + `FFTacticalEnvironments` + `FFCombat`.\n- Single-survivor expedition/logistics rules → `FFExpeditionRules`.\n- Camp relationships, political standing, and autonomous chatter → `FFCampSocial`.\n- Camp recovery/cadence/building effects → `FFCampLifeRules`.\n- Living 2D camp/menu visualization → `FFCampView`, reading `Game` state only.\n- No new pet, vehicle, companion-expedition, or 3D-camp modules: those features are permanently cut.\n\nThe remaining field text-event selector''', sop, count=1, flags=re.S)
# Product rules replace removed future items and add frozen constraints.
sop = sop.replace('- survivor social behavior should become autonomous rather than conversation micromanagement;\n- pet care should be systemic/autonomous where possible;\n- vehicles are expedition/logistics tools and tactical entry/exit anchors, not a driving game;\n', '- survivor social behavior is autonomous rather than conversation micromanagement;\n- expeditions are single-survivor only; no tactical companion AI;\n- living 2D camp is final; no pets, vehicles, or 3D camp;\n- hard population cap is 18; mature settlement is 15+ survivors plus all buildings and elected leadership, with endless continuation;\n- feature freeze: completion/balance/content/bugfixes only, no new foundational pillars;\n', 1)
write('README_SOPS.md', sop)

# ---------------------------------------------------------------------------
# Changelog entry.
# ---------------------------------------------------------------------------
changelog = text('CHANGELOG.md')
anchor = 'This file tracks player-facing changes to the playable Alpha builds, plus major technical changes that affect development/reliability.\n\n'
if changelog.count(anchor) != 1: raise SystemExit('CHANGELOG anchor missing')
entry = r'''## Beta Candidate — Feature Freeze & Living Camp Politics — 2026-08-13

### Final Scope / Population
- First Fire is now in feature freeze: no new gameplay pillars are planned before Beta.
- Permanently cut 3D camp rendering, pets, vehicles, multi-survivor expeditions, and tactical companion AI.
- Expeditions are now single-survivor dispatches in both UI and simulation APIs.
- Added a hard **18-survivor** population ceiling. Housing now grows additively through the final building tree to exactly 18 beds.
- The mature-settlement milestone now requires **15+ living survivors, every planned building, and an elected leader**. It is a milestone only; the game continues indefinitely.
- Save schema advanced to **7**, intended as the last deliberate Alpha reset before Beta save stability.

### Living Camp Day / Night & Chatter
- Kept the existing clock-driven camp darkness and made the cycle explicit as DAWN / DAY / DUSK / NIGHT, including dawn/dusk tinting plus fire, cabin, infirmary, and watch-post night glow.
- Added autonomous survivor chatter rendered as compact tactical-sound-style callouts over the living camp.
- Chatter is selected from real relationship values, personality, stress, shortages, expedition-duty policy, and opinion of the current coordinator/leader.
- Friendly/hostile/political chatter can make small relationship or stress changes; `FFCampSocial` selects them, `Game` applies consequences, and `FFCampView` remains presentation-only.

### Camp Politics / Events
- Formal leadership is no longer one-and-done. Weak elected leaders can now face recurring confidence votes against the strongest available challenger.
- Added communal-meal and shortage-politics camp events alongside the existing shelter, duty, ration, theft, fight, burnout, perimeter and personal-request events.
- Communal Table improves stress recovery and gives the camp a social gathering event hook.

### Final Building Tree
- Expanded the build tree from 8 to **15 planned structures**: Water Tank, Communal Table, Infirmary, Watch Post, Bunkhouse, Armory and Dormitory join the existing eight.
- Water Tank doubles Rain Catcher output; Infirmary speeds treatment/wound recovery and lowers untreated critical decline; Watch Post reduces camp-perimeter danger; Bunkhouse/Dormitory expand housing; Armory gates firearm construction.
- The living camp visually represents every final building using the existing tactical art language.

### Items / Crafting / Tactical Readability
- Every current `FFData.GEAR` item now has a crafting recipe in the existing Workbench/Sewing Table system; firearms are late-camp Workbench recipes requiring the Armory.
- Tactical HUD now exposes all five equipment slots—Weapon, Secondary, Tool, Clothing and Pack—so every equipped item is visible during field play.
- Added deterministic smoke coverage that every gear catalog entry has a crafting path, final building count is complete, social chatter can resolve, and tactical equipment summaries expose all slots.

'''
changelog = changelog.replace(anchor, anchor + entry, 1)
write('CHANGELOG.md', changelog)

print('beta feature-freeze patch prepared')
