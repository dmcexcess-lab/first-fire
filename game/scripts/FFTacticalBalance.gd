extends RefCounted
class_name FFTacticalBalance

const D = preload("res://scripts/FFData.gd")

# Beta tuning owner for the tactical layer. Combat is intentionally built on
# only three survivor stats: Combat, Agility, and Leadership.
const EXPLORE_SITE_COUNTS := {
    "Camp Perimeter": 3,
    "Nearby Streets": 3,
    "Residential Blocks": 3,
    "Commercial Fringe": 3,
    "Industrial Edge": 3,
}

const ZOMBIE_BASE_COUNTS := {
    "Camp Perimeter": 2,
    "Nearby Streets": 3,
    "Residential Blocks": 4,
    "Commercial Fringe": 5,
    "Industrial Edge": 6,
}

const RESCUE_SURVIVOR_HP := 14
const RESCUE_CONTACT_TICKS := 55
const RESCUE_PACE_PENALTY := 12

const CONTAINER_BIASES := {
    "fridge": {"Raw Food": 18, "Dirty Water": 10, "Clean Water": 6},
    "ice_box": {"Raw Food": 14, "Dirty Water": 10, "Clean Water": 5},
    "shelf": {"Raw Food": 8, "Plastic": 8, "Cloth": 5, "Medicine": 2},
    "vending": {"Raw Food": 8, "Dirty Water": 12, "Plastic": 5},
    "cabinet": {"Cloth": 8, "Plastic": 7, "Hardware": 5, "Medicine": 2},
    "crate": {"Scrap Metal": 12, "Hardware": 10, "Plastic": 7, "Cloth": 5},
    "washer": {"Cloth": 14, "Hardware": 4, "Plastic": 4},
    "car": {"Scrap Metal": 9, "Hardware": 8, "Cloth": 5, "Ammo": 2},
    "dumpster": {"Scrap Metal": 9, "Plastic": 9, "Cloth": 7, "Wood": 5},
    "trash": {"Plastic": 10, "Cloth": 7, "Scrap Metal": 5},
    "cart": {"Scrap Metal": 7, "Cloth": 6, "Plastic": 5},
    "debris": {"Scrap Metal": 10, "Wood": 8, "Hardware": 5},
}

static func explore_site_count(zone: String) -> int:
    return int(EXPLORE_SITE_COUNTS.get(zone, 3))

static func zombie_count(zone: String, kind: String) -> int:
    var count := int(ZOMBIE_BASE_COUNTS.get(zone, 4))
    if kind == "rescue":
        count -= 1
    elif kind == "ambush":
        count += 1
    return maxi(2, count)

static func explore_reward_rolls(searches: int, unused_skill: int = 0) -> int:
    if searches <= 0:
        return 0
    var rolls := 1
    if searches >= 3: rolls += 1
    if searches >= 5: rolls += 1
    return clampi(rolls, 1, 3)

static func zombie_hp_range(mass: String) -> Vector2i:
    if mass == "LIGHT": return Vector2i(7, 10)
    if mass == "HEAVY": return Vector2i(12, 16)
    return Vector2i(9, 13)

static func container_label(container_kind: String) -> String:
    match container_kind:
        "ice_box": return "ice box"
        "dumpster": return "dumpster"
        "trash": return "trash pile"
        "car": return "car"
        "shelf": return "shelf"
        "fridge": return "fridge"
        "cabinet": return "cabinet"
        "crate": return "crate"
        "washer": return "washer"
        "vending": return "vending machine"
        "cart": return "shopping cart"
        "debris": return "debris cache"
        _: return "container"

static func container_search_cost(actor: Dictionary) -> int:
    var fatigue := clampf(float(actor.get("fatigue", 0.0)), 0.0, 100.0)
    return clampi(int(round(78.0 + fatigue * 0.16)), 72, 104)

static func container_search_noise(container_kind: String) -> int:
    if container_kind in ["dumpster", "debris", "car"]: return 26
    if container_kind in ["crate", "washer"]: return 22
    return 17

static func roll_container_loot(zone: String, container_kind: String, rng: RandomNumberGenerator) -> Dictionary:
    var zone_data: Dictionary = D.ZONES.get(zone, D.ZONES["Nearby Streets"])
    var weights: Dictionary = zone_data.get("loot", {}).duplicate(true)
    var bias: Dictionary = CONTAINER_BIASES.get(container_kind, {})
    for key in bias.keys():
        weights[key] = int(weights.get(key, 0)) + int(bias[key])
    var rolls := 1
    if rng.randf() < 0.38:
        rolls += 1
    if zone in ["Commercial Fringe", "Industrial Edge"] and rng.randf() < 0.22:
        rolls += 1
    var found: Dictionary = {}
    for _roll in range(rolls):
        var key := _weighted_pick(weights, rng)
        if key != "":
            found[key] = int(found.get(key, 0)) + 1
    return found

static func _weighted_pick(weights: Dictionary, rng: RandomNumberGenerator) -> String:
    var total := 0
    for key in weights.keys():
        total += maxi(0, int(weights[key]))
    if total <= 0:
        return ""
    var roll := rng.randi_range(1, total)
    var running := 0
    for key in weights.keys():
        running += maxi(0, int(weights[key]))
        if roll <= running:
            return str(key)
    return ""

static func search_cost(actor: Dictionary) -> int:
    var fatigue := clampf(float(actor.get("fatigue", 0.0)), 0.0, 100.0)
    var cost := 108.0 + fatigue * 0.18
    if bool(actor.get("crouched", false)):
        cost += 8.0
    return clampi(int(round(cost)), 84, 138)

static func search_noise(actor: Dictionary) -> int:
    var noise := 28
    if bool(actor.get("crouched", false)):
        noise -= 8
    return clampi(noise, 16, 32)

static func melee_hit_chance(combat: int, penalty: float, stealth: bool, accuracy: float) -> float:
    var chance := 0.58 + float(combat) * 0.045 + accuracy - penalty
    if stealth: chance += 0.12
    return clampf(chance, 0.15, 0.96)

static func gun_hit_chance(combat: int, distance: int, penalty: float, accuracy: float) -> float:
    var range_penalty := float(maxi(0, distance - 3)) * 0.04
    return clampf(0.58 + float(combat) * 0.045 + accuracy - range_penalty - penalty, 0.12, 0.94)

static func shove_chance(actor: Dictionary, mass: String, weapon_push: int) -> float:
    var combat := int(actor.get("skills", {}).get("Combat", 0))
    var agility := int(actor.get("skills", {}).get("Agility", 0))
    var fatigue := clampf(float(actor.get("fatigue", 0.0)), 0.0, 100.0)
    var mass_penalty := 0.22 if mass == "HEAVY" else (0.08 if mass == "MED" else 0.0)
    var chance := 0.68 + float(combat) * 0.03 + float(agility) * 0.012 + float(weapon_push) * 0.03
    chance -= fatigue * 0.0022 + mass_penalty
    return clampf(chance, 0.25, 0.94)

static func shove_stagger_ticks(mass: String, pinned: bool) -> int:
    var stagger := 55
    if mass == "LIGHT": stagger = 75
    elif mass == "HEAVY": stagger = 35
    if pinned: stagger += 25
    return stagger

static func zombie_hit_chance(actor: Dictionary) -> float:
    var agility := int(actor.get("skills", {}).get("Agility", 0))
    var fatigue := float(actor.get("fatigue", 0.0))
    var chance := 0.66 - float(agility) * 0.018
    if fatigue >= 80.0: chance += 0.08
    elif fatigue >= 60.0: chance += 0.04
    if bool(actor.get("sprinting", false)):
        chance -= minf(0.22, 0.05 + float(agility) * 0.017)
    return clampf(chance, 0.18, 0.82)

static func zombie_damage_range(mass: String) -> Vector2i:
    if mass == "LIGHT": return Vector2i(1, 4)
    if mass == "HEAVY": return Vector2i(3, 6)
    return Vector2i(2, 5)
